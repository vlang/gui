module gui

import gg
import math
import nativebridge
import sokol.gfx
import sokol.sgl
import sokol.sapp
import strings
import stbi as _

struct C.sg_mtl_image_info {
	tex         [2]voidptr
	active_slot int
}

fn C.sg_mtl_query_image_info(img gfx.Image) C.sg_mtl_image_info
fn C.sg_mtl_command_queue() voidptr

struct PrintPageRaster {
	tex   gfx.Image
	depth gfx.Image
	att   gfx.Attachments
	w     int
	h     int
}

fn create_print_page_raster(w int, h int) !PrintPageRaster {
	if w <= 0 || h <= 0 || w > 8192 || h > 8192 {
		return error('invalid raster dimensions ${w}x${h}')
	}
	color_fmt := gfx.PixelFormat.from(sapp.color_format()) or { gfx.PixelFormat.bgra8 }
	depth_fmt := gfx.PixelFormat.from(sapp.depth_format()) or { gfx.PixelFormat.depth_stencil }
	tex := gfx.make_image(&gfx.ImageDesc{
		render_target: true
		width:         w
		height:        h
		pixel_format:  color_fmt
		label:         c'print_page_tex'
	})
	depth := gfx.make_image(&gfx.ImageDesc{
		render_target: true
		width:         w
		height:        h
		pixel_format:  depth_fmt
		label:         c'print_page_depth'
	})
	mut att_colors := [4]gfx.AttachmentDesc{}
	att_colors[0] = gfx.AttachmentDesc{
		image: tex
	}
	att := gfx.make_attachments(gfx.AttachmentsDesc{
		colors:        att_colors
		depth_stencil: gfx.AttachmentDesc{
			image: depth
		}
		label:         c'print_page_att'
	})
	return PrintPageRaster{
		tex:   tex
		depth: depth
		att:   att
		w:     w
		h:     h
	}
}

fn (pr PrintPageRaster) destroy() {
	gfx.destroy_attachments(pr.att)
	gfx.destroy_image(pr.tex)
	gfx.destroy_image(pr.depth)
}

// render_page_to_pixels renders a page slice of the view
// into a pixel buffer using the GPU pipeline. Must be
// called within frame_fn, outside any active gfx pass.
fn render_page_to_pixels(mut window Window, raster PrintPageRaster, source_width f32, page_source_height f32, page_offset_y f32) ![]u8 {
	// Scale factor: logical source coords → raster pixels.
	// Mirrors how normal rendering uses ui.scale to map
	// logical coords to framebuffer pixels. All draw fns
	// and DrawClip renderers multiply by ui.scale, so the
	// projection must be in raster pixel space to match.
	print_scale := f32(raster.w) / source_width
	rw := f32(raster.w)
	rh := f32(raster.h)

	sgl.defaults()
	sgl.viewport(0, 0, raster.w, raster.h, true)
	sgl.scissor_rect(0, 0, raster.w, raster.h, true)
	sgl.matrix_mode_projection()
	sgl.ortho(0.0, rw, rh, 0.0, -1.0, 1.0)
	// Translate to show the correct page slice.
	sgl.matrix_mode_modelview()
	sgl.load_identity()
	sgl.translate(0.0, -page_offset_y * print_scale, 0.0)

	// Record renderer drawing commands via SGL.
	// Set ui.scale to print_scale so draw functions and
	// DrawClip renderers produce raster pixel coords,
	// matching the pixel-space projection above.
	saved_scale := window.ui.scale
	window.ui.scale = print_scale
	renderers_draw(mut window)
	window.ui.scale = saved_scale

	// Begin offscreen pass and flush SGL into it.
	mut pass_action := gfx.PassAction{}
	pass_action.colors[0] = gfx.ColorAttachmentAction{
		load_action: .clear
		clear_value: gfx.Color{1.0, 1.0, 1.0, 1.0}
	}
	gfx.begin_pass(gfx.Pass{
		action:      pass_action
		attachments: raster.att
	})
	sgl.draw()
	gfx.end_pass()
	// Submit the command buffer so the GPU starts rendering.
	gfx.commit()

	// Blit render target to shared staging texture and read
	// back. Uses sokol's command queue for correct ordering.
	$if macos {
		info := C.sg_mtl_query_image_info(raster.tex)
		mtl_tex := info.tex[info.active_slot]
		mtl_queue := C.sg_mtl_command_queue()
		return nativebridge.readback_metal_texture(mtl_tex, mtl_queue, raster.w, raster.h)
	} $else {
		return error('raster PDF export not yet supported on this platform')
	}
}

fn C.stbi_write_jpg_to_func(func fn (ctx voidptr, data voidptr, size int), ctx voidptr, x int, y int, comp int, data voidptr, quality int) int

struct JpegWriteContext {
mut:
	buf []u8
}

fn jpeg_write_callback(ctx voidptr, data voidptr, size int) {
	mut wctx := unsafe { &JpegWriteContext(ctx) }
	old_len := wctx.buf.len
	unsafe {
		wctx.buf.grow_len(size)
		vmemcpy(&wctx.buf[old_len], data, size)
	}
}

// jpeg_encode_rgba encodes a BGRA pixel buffer to JPEG
// bytes in memory.
fn jpeg_encode_rgba(pixels []u8, width int, height int, quality int) ![]u8 {
	if pixels.len < width * height * 4 {
		return error('pixel buffer too small')
	}
	// Convert BGRA to RGB for JPEG
	mut rgb := []u8{len: width * height * 3}
	for i := 0; i < width * height; i++ {
		si := i * 4
		di := i * 3
		rgb[di] = pixels[si + 2] // R from BGRA.B position
		rgb[di + 1] = pixels[si + 1] // G
		rgb[di + 2] = pixels[si] // B from BGRA.R position
	}
	mut wctx := JpegWriteContext{}
	result := C.stbi_write_jpg_to_func(jpeg_write_callback, voidptr(&wctx), width, height,
		3, rgb.data, quality)
	if result == 0 {
		return error('JPEG encoding failed')
	}
	return wctx.buf
}

// pdf_render_document_raster generates a PDF where each
// page body is a JPEG image captured from the GPU.
// Header/footer remain as vector text overlay.
fn pdf_render_document_raster(mut window Window, source_width f32, source_height f32, job PrintJob) !string {
	page_width, page_height := print_page_size(job.paper, job.orientation)
	header_h := print_header_footer_reserved_height(job.header)
	footer_h := print_header_footer_reserved_height(job.footer)
	content_width := page_width - job.margins.left - job.margins.right
	content_height := page_height - job.margins.top - job.margins.bottom - header_h - footer_h

	if content_width <= 0 || content_height <= 0 {
		return error('invalid page/margin configuration')
	}

	// Source-space page height via scale.
	mut scale := f32(1.0)
	if job.scale_mode == .fit_to_page {
		scale_x := content_width / source_width
		scale_y := content_height / source_height
		scale = f32_min(scale_x, scale_y)
	}
	if scale <= 0 {
		return error('computed invalid scale')
	}
	page_source_height := content_height / scale

	mut page_count := 1
	if job.paginate {
		page_count = int(math.ceil(source_height / page_source_height))
		if page_count < 1 {
			page_count = 1
		}
	}

	// Raster dimensions from source area at DPI resolution.
	// Size from source_width × page_source_height so the
	// raster captures exactly the source content per page.
	// print_scale = raster_w / source_width stays consistent
	// for both axes when raster matches source aspect ratio.
	dpi := if job.raster_dpi > 0 { job.raster_dpi } else { 300 }
	dpi_scale := f32(dpi) / 72.0
	raster_w := int(math.ceil(source_width * dpi_scale))
	raster_h := int(math.ceil(page_source_height * dpi_scale))

	// PDF image placement dimensions. For fit_to_page the
	// image is scaled to fit within the content area. For
	// actual_size the image fills the content area.
	mut place_w := content_width
	mut place_h := content_height
	if job.scale_mode == .fit_to_page {
		place_w = source_width * scale
		place_h = page_source_height * scale
	}

	// Generate print-specific renderers covering the full
	// source area. The OS may constrain the actual window
	// smaller than source_height, causing scroll containers
	// to clip content beyond the visible region. Build a
	// separate layout for print without modifying the
	// window's active layout (which event handlers still
	// reference).
	saved_size := window.window_size
	saved_renderers := window.renderers
	print_height := int(math.ceil(source_height))
	mut print_view := View(ContainerView{})
	mut print_layout := Layout{}
	if window.window_size.height < print_height {
		window.window_size = gg.Size{
			width:  window.window_size.width
			height: print_height
		}
		print_view = window.view_generator(window)
		print_layout = window.compose_layout(mut print_view)
		clip_rect := window.window_rect()
		bg := window.color_background()
		window.renderers = []Renderer{}
		render_layout(mut print_layout, bg, clip_rect, mut window)
	}
	defer {
		if window.window_size.height != saved_size.height {
			unsafe { window.renderers.free() }
			window.renderers = saved_renderers
			window.window_size = saved_size
			layout_clear(mut print_layout)
			view_clear(mut print_view)
		}
	}

	// Create offscreen render target.
	raster := create_print_page_raster(raster_w, raster_h) or {
		return error('failed to create render target: ${err}')
	}
	defer {
		raster.destroy()
	}

	// Render and encode each page.
	mut page_jpegs := [][]u8{cap: page_count}
	quality := if job.jpeg_quality > 0 { job.jpeg_quality } else { 85 }
	for idx in 0 .. page_count {
		offset_y := if job.paginate {
			f32(idx) * page_source_height
		} else {
			f32(0.0)
		}
		pixels := render_page_to_pixels(mut window, raster, source_width, page_source_height,
			offset_y) or { return error('page ${idx + 1} render failed: ${err}') }
		jpeg := jpeg_encode_rgba(pixels, raster_w, raster_h, quality) or {
			return error('page ${idx + 1} JPEG encode failed: ${err}')
		}
		page_jpegs << jpeg
	}

	// Build PDF with embedded JPEG images.
	return pdf_build_raster_document(page_jpegs, page_width, page_height, place_w,
		place_h, raster_w, raster_h, job, page_count)
}

fn pdf_build_raster_document(page_jpegs [][]u8, page_width f32, page_height f32, place_w f32, place_h f32, raster_w int, raster_h int, job PrintJob, page_count int) !string {
	_ := print_header_footer_reserved_height(job.header)
	footer_h := print_header_footer_reserved_height(job.footer)

	mut objects := []string{}
	// Object 1: Catalog
	objects << '<< /Type /Catalog /Pages 2 0 R >>'
	// Object 2: Pages
	mut kids := []string{}
	for idx in 0 .. page_count {
		page_obj_num := 3 + idx * 3
		kids << '${page_obj_num} 0 R'
	}
	objects << '<< /Type /Pages /Kids [${kids.join(' ')}] /Count ${page_count} >>'

	for idx in 0 .. page_count {
		jpeg_data := page_jpegs[idx]
		page_obj_num := 3 + idx * 3
		content_obj_num := page_obj_num + 1
		image_obj_num := page_obj_num + 2

		// Image XObject (JPEG via DCTDecode)
		image_obj :=
			'<< /Type /XObject /Subtype /Image /Width ${raster_w} /Height ${raster_h} /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length ${jpeg_data.len} >>\nstream\n' +
			jpeg_data.bytestr() + '\nendstream'

		// Content stream: place image + header/footer
		img_x := job.margins.left
		img_y := job.margins.bottom + footer_h
		mut stream := strings.new_builder(256)
		// Draw JPEG image at placement dimensions
		stream.writeln('q')
		stream.writeln('${pdf_num(place_w)} 0 0 ${pdf_num(place_h)} ${pdf_num(img_x)} ${pdf_num(img_y)} cm')
		stream.writeln('/Img${idx} Do')
		stream.writeln('Q')
		// Vector header/footer overlay
		pdf_append_header_footer(mut stream, job, page_width, page_height, idx + 1, page_count)
		content := stream.bytestr()
		content_obj := '<< /Length ${content.len} >>\nstream\n${content}endstream'

		// Page object
		page_obj := '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${pdf_num(page_width)} ${pdf_num(page_height)}] /Resources << /Font << /F1 << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> >> /XObject << /Img${idx} ${image_obj_num} 0 R >> >> /Contents ${content_obj_num} 0 R >>'

		objects << page_obj
		objects << content_obj
		objects << image_obj
	}

	return pdf_encode(objects)
}
