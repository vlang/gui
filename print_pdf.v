module gui

import gg
import math
import strings
import time
import vglyph

struct PdfRenderContext {
	page_width    f32
	page_height   f32
	source_width  f32
	source_height f32
	scale         f32
	margins       PrintMargins
	page_offset_y f32
}

struct PdfSvgShadingRef {
	name  string
	alpha u8
}

struct PdfSvgShadingObject {
	ref         PdfSvgShadingRef
	object_body string
}

struct PdfSvgIndexed {
	idx int
	svg DrawSvg
}

fn (ctx PdfRenderContext) map_x(x f32) f32 {
	return ctx.margins.left + x * ctx.scale
}

fn (ctx PdfRenderContext) map_y(y f32) f32 {
	return ctx.page_height - ctx.margins.top - (y - ctx.page_offset_y) * ctx.scale
}

fn (ctx PdfRenderContext) map_rect_y(y f32, h f32) f32 {
	return ctx.page_height - ctx.margins.top - (y - ctx.page_offset_y + h) * ctx.scale
}

fn pdf_num(value f32) string {
	if math.is_nan(value) || math.is_inf(value, 0) {
		return '0'
	}
	mut s := '${value:.3f}'
	for s.ends_with('0') && s.contains('.') {
		s = s[..s.len - 1]
	}
	if s.ends_with('.') {
		return s[..s.len - 1]
	}
	return s
}

fn pdf_color(value u8) string {
	return pdf_num(f32(value) / 255.0)
}

fn pdf_escape_text(text string) string {
	mut out := strings.new_builder(text.len + 8)
	for ch in text.runes() {
		match ch {
			`\\` {
				out.write_string('\\\\')
			}
			`(` {
				out.write_string('\\(')
			}
			`)` {
				out.write_string('\\)')
			}
			`\r`, `\n`, `\t` {
				out.write_u8(` `)
			}
			else {
				if ch < 32 || ch > 126 {
					out.write_u8(`?`)
				} else {
					out.write_rune(ch)
				}
			}
		}
	}
	return out.bytestr()
}

fn pdf_pad_10(value int) string {
	s := value.str()
	if s.len >= 10 {
		return s
	}
	return '0'.repeat(10 - s.len) + s
}

fn pdf_collect_alphas(renderers []Renderer) []u8 {
	mut seen := map[u8]bool{}
	seen[u8(255)] = true

	for renderer in renderers {
		match renderer {
			DrawRect {
				seen[renderer.color.a] = true
			}
			DrawStrokeRect {
				seen[renderer.color.a] = true
			}
			DrawCircle {
				seen[renderer.color.a] = true
			}
			DrawLine {
				seen[renderer.cfg.color.a] = true
			}
			DrawText {
				seen[renderer.cfg.style.color.a] = true
			}
			DrawSvg {
				seen[renderer.color.a] = true
				if alpha := pdf_svg_gradient_alpha(renderer) {
					seen[alpha] = true
				}
			}
			DrawLayout {
				for item in renderer.layout.items {
					seen[item.color.a] = true
				}
			}
			DrawLayoutTransformed {
				for item in renderer.layout.items {
					seen[item.color.a] = true
				}
			}
			DrawLayoutPlaced {
				for item in renderer.layout.items {
					seen[item.color.a] = true
				}
			}
			else {}
		}
	}

	mut alphas := []u8{cap: seen.len}
	for alpha, _ in seen {
		alphas << alpha
	}
	alphas.sort()
	return alphas
}

fn pdf_svg_gradient_alpha(renderer DrawSvg) ?u8 {
	if renderer.is_clip_mask || renderer.vertex_colors.len == 0 || renderer.triangles.len < 6 {
		return none
	}
	if renderer.triangles.len % 6 != 0 {
		return none
	}
	if renderer.vertex_colors.len != renderer.triangles.len / 2 {
		return none
	}
	alpha := renderer.vertex_colors[0].a
	for c in renderer.vertex_colors {
		if c.a != alpha {
			return none
		}
	}
	return alpha
}

fn pdf_u16_from_range(value f32, min_v f32, max_v f32) int {
	range := max_v - min_v
	if range <= 0.00001 {
		return 0
	}
	mut t := (value - min_v) / range
	if t < 0 {
		t = 0
	} else if t > 1 {
		t = 1
	}
	mut result := int(t * 65535.0 + 0.5)
	if result < 0 {
		result = 0
	} else if result > 65535 {
		result = 65535
	}
	return result
}

fn pdf_hex_encode(data []u8) string {
	hex_chars := '0123456789ABCDEF'
	mut out := strings.new_builder(data.len * 2 + 1)
	for b in data {
		out.write_u8(hex_chars[int((b >> 4) & 0x0F)])
		out.write_u8(hex_chars[int(b & 0x0F)])
	}
	out.write_u8(`>`)
	return out.bytestr()
}

fn pdf_build_svg_shading(renderer DrawSvg, name string, ctx PdfRenderContext) ?PdfSvgShadingObject {
	alpha := pdf_svg_gradient_alpha(renderer) or { return none }
	vertex_count := renderer.triangles.len / 2
	mut points := []f32{len: renderer.triangles.len}
	mut min_x := f32(1e20)
	mut min_y := f32(1e20)
	mut max_x := f32(-1e20)
	mut max_y := f32(-1e20)

	for vi := 0; vi < vertex_count; vi++ {
		ti := vi * 2
		x := ctx.map_x(renderer.x + renderer.triangles[ti] * renderer.scale)
		y := ctx.map_y(renderer.y + renderer.triangles[ti + 1] * renderer.scale)
		if math.is_nan(x) || math.is_inf(x, 0) || math.is_nan(y) || math.is_inf(y, 0) {
			return none
		}
		points[ti] = x
		points[ti + 1] = y
		if x < min_x {
			min_x = x
		}
		if x > max_x {
			max_x = x
		}
		if y < min_y {
			min_y = y
		}
		if y > max_y {
			max_y = y
		}
	}

	mut payload := []u8{cap: vertex_count * 8}
	for vi := 0; vi < vertex_count; vi++ {
		ti := vi * 2
		color := renderer.vertex_colors[vi]
		x16 := pdf_u16_from_range(points[ti], min_x, max_x)
		y16 := pdf_u16_from_range(points[ti + 1], min_y, max_y)
		payload << u8(0)
		payload << u8((x16 >> 8) & 0xFF)
		payload << u8(x16 & 0xFF)
		payload << u8((y16 >> 8) & 0xFF)
		payload << u8(y16 & 0xFF)
		payload << color.r
		payload << color.g
		payload << color.b
	}

	hex_stream := pdf_hex_encode(payload)
	object_body :=
		'<< /ShadingType 4 /ColorSpace /DeviceRGB /BitsPerCoordinate 16 /BitsPerComponent 8 ' +
		'/BitsPerFlag 8 /Decode [${pdf_num(min_x)} ${pdf_num(max_x)} ${pdf_num(min_y)} ${pdf_num(max_y)} 0 1 0 1 0 1] /Length ${hex_stream.len} /Filter /ASCIIHexDecode >>\n' +
		'stream\n${hex_stream}\nendstream'
	return PdfSvgShadingObject{
		ref:         PdfSvgShadingRef{
			name:  name
			alpha: alpha
		}
		object_body: object_body
	}
}

fn pdf_collect_svg_shadings(renderers []Renderer, ctx PdfRenderContext) (map[int]PdfSvgShadingRef, []PdfSvgShadingObject) {
	mut refs := map[int]PdfSvgShadingRef{}
	mut objects := []PdfSvgShadingObject{}
	mut next_id := 1
	for idx, renderer in renderers {
		if renderer is DrawSvg {
			name := 'SH${next_id}'
			shading := pdf_build_svg_shading(renderer, name, ctx) or { continue }
			refs[idx] = shading.ref
			objects << shading
			next_id++
		}
	}
	return refs, objects
}

fn pdf_draw_svg_shading(mut out strings.Builder, shading PdfSvgShadingRef) {
	out.writeln('q')
	out.writeln('/GS${shading.alpha} gs')
	out.writeln('/${shading.name} sh')
	out.writeln('Q')
}

fn pdf_extgstate_dict(alphas []u8) string {
	mut out := strings.new_builder(128 + alphas.len * 20)
	out.write_string('/ExtGState << ')
	for alpha in alphas {
		opacity := f32(alpha) / 255.0
		out.write_string('/GS${alpha} << /ca ${pdf_num(opacity)} /CA ${pdf_num(opacity)} >> ')
	}
	out.write_string('>>')
	return out.bytestr()
}

fn pdf_set_fill_color(mut out strings.Builder, color gg.Color) {
	out.writeln('/GS${color.a} gs')
	out.writeln('${pdf_color(color.r)} ${pdf_color(color.g)} ${pdf_color(color.b)} rg')
}

fn pdf_set_stroke_color(mut out strings.Builder, color gg.Color) {
	out.writeln('/GS${color.a} gs')
	out.writeln('${pdf_color(color.r)} ${pdf_color(color.g)} ${pdf_color(color.b)} RG')
}

fn pdf_draw_circle(mut out strings.Builder, ctx PdfRenderContext, x f32, y f32, radius f32, fill bool) {
	if radius <= 0 {
		return
	}
	cx := ctx.map_x(x)
	cy := ctx.map_y(y)
	r := radius * ctx.scale
	k := f32(0.5522847498) * r

	out.writeln('${pdf_num(cx + r)} ${pdf_num(cy)} m')
	out.writeln('${pdf_num(cx + r)} ${pdf_num(cy + k)} ${pdf_num(cx + k)} ${pdf_num(cy + r)} ${pdf_num(cx)} ${pdf_num(
		cy + r)} c')
	out.writeln('${pdf_num(cx - k)} ${pdf_num(cy + r)} ${pdf_num(cx - r)} ${pdf_num(cy + k)} ${pdf_num(cx - r)} ${pdf_num(cy)} c')
	out.writeln('${pdf_num(cx - r)} ${pdf_num(cy - k)} ${pdf_num(cx - k)} ${pdf_num(cy - r)} ${pdf_num(cx)} ${pdf_num(cy - r)} c')
	out.writeln('${pdf_num(cx + k)} ${pdf_num(cy - r)} ${pdf_num(cx + r)} ${pdf_num(cy - k)} ${pdf_num(
		cx + r)} ${pdf_num(cy)} c')
	out.writeln(if fill { 'f' } else { 'S' })
}

fn pdf_draw_image_placeholder(mut out strings.Builder, ctx PdfRenderContext, image DrawImage) {
	w := image.w * ctx.scale
	h := image.h * ctx.scale
	if w <= 0 || h <= 0 {
		return
	}
	x := ctx.map_x(image.x)
	y := ctx.map_rect_y(image.y, image.h)
	out.writeln('/GS255 gs')
	out.writeln('0.7 0.7 0.7 RG')
	out.writeln('0.5 w')
	out.writeln('${pdf_num(x)} ${pdf_num(y)} ${pdf_num(w)} ${pdf_num(h)} re S')
	out.writeln('${pdf_num(x)} ${pdf_num(y)} m ${pdf_num(x + w)} ${pdf_num(y + h)} l S')
	out.writeln('${pdf_num(x)} ${pdf_num(y + h)} m ${pdf_num(x + w)} ${pdf_num(y)} l S')
}

fn pdf_draw_svg(mut out strings.Builder, ctx PdfRenderContext, renderer DrawSvg) {
	if renderer.is_clip_mask || renderer.color.a == 0 || renderer.triangles.len < 6 {
		return
	}
	pdf_set_fill_color(mut out, renderer.color)
	mut i := 0
	for i < renderer.triangles.len - 5 {
		x0 := ctx.map_x(renderer.x + renderer.triangles[i] * renderer.scale)
		y0 := ctx.map_y(renderer.y + renderer.triangles[i + 1] * renderer.scale)
		x1 := ctx.map_x(renderer.x + renderer.triangles[i + 2] * renderer.scale)
		y1 := ctx.map_y(renderer.y + renderer.triangles[i + 3] * renderer.scale)
		x2 := ctx.map_x(renderer.x + renderer.triangles[i + 4] * renderer.scale)
		y2 := ctx.map_y(renderer.y + renderer.triangles[i + 5] * renderer.scale)
		out.writeln('${pdf_num(x0)} ${pdf_num(y0)} m ${pdf_num(x1)} ${pdf_num(y1)} l ${pdf_num(x2)} ${pdf_num(y2)} l h f')
		i += 6
	}
}

fn pdf_append_svg_triangles_path(mut out strings.Builder, ctx PdfRenderContext, renderer DrawSvg) {
	if renderer.triangles.len < 6 {
		return
	}
	mut i := 0
	for i < renderer.triangles.len - 5 {
		x0 := ctx.map_x(renderer.x + renderer.triangles[i] * renderer.scale)
		y0 := ctx.map_y(renderer.y + renderer.triangles[i + 1] * renderer.scale)
		x1 := ctx.map_x(renderer.x + renderer.triangles[i + 2] * renderer.scale)
		y1 := ctx.map_y(renderer.y + renderer.triangles[i + 3] * renderer.scale)
		x2 := ctx.map_x(renderer.x + renderer.triangles[i + 4] * renderer.scale)
		y2 := ctx.map_y(renderer.y + renderer.triangles[i + 5] * renderer.scale)
		out.writeln('${pdf_num(x0)} ${pdf_num(y0)} m ${pdf_num(x1)} ${pdf_num(y1)} l ${pdf_num(x2)} ${pdf_num(y2)} l h')
		i += 6
	}
}

fn pdf_draw_svg_clip_group(renderers []Renderer, idx int, mut out strings.Builder, ctx PdfRenderContext, shading_refs map[int]PdfSvgShadingRef) int {
	mut next_idx := idx
	if idx < 0 || idx >= renderers.len {
		return idx + 1
	}
	first := renderers[idx] as DrawSvg
	group := first.clip_group

	mut masks := []DrawSvg{}
	mut content := []PdfSvgIndexed{}

	for next_idx < renderers.len {
		if renderers[next_idx] is DrawSvg {
			svg := renderers[next_idx] as DrawSvg
			if svg.clip_group == group {
				if svg.is_clip_mask {
					masks << svg
				} else {
					content << PdfSvgIndexed{
						idx: next_idx
						svg: svg
					}
				}
				next_idx++
				continue
			}
		}
		break
	}

	if content.len == 0 {
		return next_idx
	}
	if masks.len == 0 {
		for item in content {
			if shading := shading_refs[item.idx] {
				pdf_draw_svg_shading(mut out, shading)
			} else {
				pdf_draw_svg(mut out, ctx, item.svg)
			}
		}
		return next_idx
	}

	out.writeln('q')
	for svg in masks {
		pdf_append_svg_triangles_path(mut out, ctx, svg)
	}
	out.writeln('W n')
	for item in content {
		if shading := shading_refs[item.idx] {
			pdf_draw_svg_shading(mut out, shading)
		} else {
			pdf_draw_svg(mut out, ctx, item.svg)
		}
	}
	out.writeln('Q')
	return next_idx
}

fn pdf_draw_text(mut out strings.Builder, ctx PdfRenderContext, text string, x f32, y f32, size f32, color gg.Color) {
	if text.len == 0 || color.a == 0 {
		return
	}
	mut font_size := size
	if font_size <= 0 {
		font_size = 12
	}
	pdf_set_fill_color(mut out, color)
	pdf_x := ctx.map_x(x)
	pdf_y := ctx.map_y(y + font_size * 0.8)
	escaped := pdf_escape_text(text)
	out.writeln('BT')
	out.writeln('/F1 ${pdf_num(font_size * ctx.scale)} Tf')
	out.writeln('${pdf_num(pdf_x)} ${pdf_num(pdf_y)} Td')
	out.writeln('(${escaped}) Tj')
	out.writeln('ET')
}

fn pdf_draw_text_local(mut out strings.Builder, text string, x f32, y f32, size f32, color gg.Color) {
	if text.len == 0 || color.a == 0 {
		return
	}
	mut font_size := size
	if font_size <= 0 {
		font_size = 12
	}
	pdf_set_fill_color(mut out, color)
	escaped := pdf_escape_text(text)
	out.writeln('BT')
	out.writeln('/F1 ${pdf_num(font_size)} Tf')
	out.writeln('${pdf_num(x)} ${pdf_num(y)} Td')
	out.writeln('(${escaped}) Tj')
	out.writeln('ET')
}

fn pdf_transform_is_valid(transform vglyph.AffineTransform) bool {
	values := [
		transform.xx,
		transform.xy,
		transform.yx,
		transform.yy,
		transform.x0,
		transform.y0,
	]
	for value in values {
		if math.is_nan(value) || math.is_inf(value, 0) {
			return false
		}
	}
	return true
}

fn pdf_draw_layout_transformed(mut out strings.Builder, ctx PdfRenderContext, renderer DrawLayoutTransformed) {
	if !pdf_transform_is_valid(renderer.transform) {
		for item in renderer.layout.items {
			if item.is_object || item.run_text.trim_space().len == 0 {
				continue
			}
			size := f32(item.ascent + item.descent)
			pdf_draw_text(mut out, ctx, item.run_text, renderer.x + f32(item.x), renderer.y +
				f32(item.y - item.ascent), size, item.color)
		}
		return
	}

	scale := ctx.scale
	a := scale * renderer.transform.xx
	b := scale * -renderer.transform.yx
	c := scale * -renderer.transform.xy
	d := scale * renderer.transform.yy
	e := ctx.margins.left + scale * (renderer.x + renderer.transform.x0)
	f := ctx.page_height - ctx.margins.top - scale * (renderer.y + renderer.transform.y0)

	out.writeln('q')
	out.writeln('${pdf_num(a)} ${pdf_num(b)} ${pdf_num(c)} ${pdf_num(d)} ${pdf_num(e)} ${pdf_num(f)} cm')
	for item in renderer.layout.items {
		if item.is_object || item.run_text.trim_space().len == 0 {
			continue
		}
		size := f32(item.ascent + item.descent)
		local_x := f32(item.x)
		local_y := -(f32(item.y - item.ascent) + size * 0.8)
		pdf_draw_text_local(mut out, item.run_text, local_x, local_y, size, item.color)
	}
	out.writeln('Q')
}

fn pdf_render_stream(renderers []Renderer, ctx PdfRenderContext, shading_refs map[int]PdfSvgShadingRef) string {
	mut out := strings.new_builder(4096)
	mut clip_active := false
	out.writeln('q')

	mut i := 0
	for i < renderers.len {
		renderer := renderers[i]
		mut advance := true
		match renderer {
			DrawClip {
				if clip_active {
					out.writeln('Q')
				}
				if renderer.width <= 0 || renderer.height <= 0 {
					clip_active = false
				} else {
					x := ctx.map_x(renderer.x)
					y := ctx.map_rect_y(renderer.y, renderer.height)
					w := renderer.width * ctx.scale
					h := renderer.height * ctx.scale
					out.writeln('q')
					out.writeln('${pdf_num(x)} ${pdf_num(y)} ${pdf_num(w)} ${pdf_num(h)} re W n')
					clip_active = true
				}
			}
			DrawRect {
				if renderer.w > 0 && renderer.h > 0 && renderer.color.a > 0 {
					x := ctx.map_x(renderer.x)
					y := ctx.map_rect_y(renderer.y, renderer.h)
					w := renderer.w * ctx.scale
					h := renderer.h * ctx.scale
					if renderer.style == .fill {
						pdf_set_fill_color(mut out, renderer.color)
						out.writeln('${pdf_num(x)} ${pdf_num(y)} ${pdf_num(w)} ${pdf_num(h)} re f')
					} else {
						pdf_set_stroke_color(mut out, renderer.color)
						out.writeln('1 w')
						out.writeln('${pdf_num(x)} ${pdf_num(y)} ${pdf_num(w)} ${pdf_num(h)} re S')
					}
				}
			}
			DrawStrokeRect {
				if renderer.w > 0 && renderer.h > 0 && renderer.color.a > 0 {
					x := ctx.map_x(renderer.x)
					y := ctx.map_rect_y(renderer.y, renderer.h)
					w := renderer.w * ctx.scale
					h := renderer.h * ctx.scale
					pdf_set_stroke_color(mut out, renderer.color)
					line_width := f32_max(0.25, renderer.thickness * ctx.scale)
					out.writeln('${pdf_num(line_width)} w')
					out.writeln('${pdf_num(x)} ${pdf_num(y)} ${pdf_num(w)} ${pdf_num(h)} re S')
				}
			}
			DrawLine {
				if renderer.cfg.color.a > 0 {
					pdf_set_stroke_color(mut out, renderer.cfg.color)
					line_width := f32_max(0.25, renderer.cfg.thickness * ctx.scale)
					out.writeln('${pdf_num(line_width)} w')
					x0 := ctx.map_x(renderer.x)
					y0 := ctx.map_y(renderer.y)
					x1 := ctx.map_x(renderer.x1)
					y1 := ctx.map_y(renderer.y1)
					out.writeln('${pdf_num(x0)} ${pdf_num(y0)} m ${pdf_num(x1)} ${pdf_num(y1)} l S')
				}
			}
			DrawCircle {
				if renderer.color.a > 0 {
					if renderer.fill {
						pdf_set_fill_color(mut out, renderer.color)
					} else {
						pdf_set_stroke_color(mut out, renderer.color)
						out.writeln('1 w')
					}
					pdf_draw_circle(mut out, ctx, renderer.x, renderer.y, renderer.radius,
						renderer.fill)
				}
			}
			DrawText {
				pdf_draw_text(mut out, ctx, renderer.text, renderer.x, renderer.y, renderer.cfg.style.size,
					renderer.cfg.style.color)
			}
			DrawLayout {
				for item in renderer.layout.items {
					if item.is_object || item.run_text.trim_space().len == 0 {
						continue
					}
					size := f32(item.ascent + item.descent)
					pdf_draw_text(mut out, ctx, item.run_text, renderer.x + f32(item.x),
						renderer.y + f32(item.y - item.ascent), size, item.color)
				}
			}
			DrawLayoutTransformed {
				pdf_draw_layout_transformed(mut out, ctx, renderer)
			}
			DrawLayoutPlaced {}
			DrawSvg {
				if renderer.clip_group > 0 {
					i = pdf_draw_svg_clip_group(renderers, i, mut out, ctx, shading_refs)
					advance = false
				} else if shading := shading_refs[i] {
					pdf_draw_svg_shading(mut out, shading)
				} else {
					pdf_draw_svg(mut out, ctx, renderer)
				}
			}
			DrawImage {
				pdf_draw_image_placeholder(mut out, ctx, renderer)
			}
			DrawShadow, DrawBlur, DrawGradient, DrawGradientBorder, DrawCustomShader,
			DrawFilterBegin, DrawFilterEnd, DrawFilterComposite, DrawNone {}
		}
		if advance {
			i++
		}
	}

	if clip_active {
		out.writeln('Q')
	}
	out.writeln('Q')
	return out.bytestr()
}

fn pdf_encode(objects []string) string {
	mut out := strings.new_builder(2048)
	out.writeln('%PDF-1.4')

	mut offsets := []int{len: objects.len + 1, init: 0}
	for i, object_body in objects {
		offsets[i + 1] = out.len
		out.writeln('${i + 1} 0 obj')
		out.write_string(object_body)
		if !object_body.ends_with('\n') {
			out.writeln('')
		}
		out.writeln('endobj')
	}

	start_xref := out.len
	out.writeln('xref')
	out.writeln('0 ${offsets.len}')
	out.writeln('0000000000 65535 f ')
	for i in 1 .. offsets.len {
		out.writeln('${pdf_pad_10(offsets[i])} 00000 n ')
	}

	out.writeln('trailer')
	out.writeln('<< /Size ${offsets.len} /Root 1 0 R >>')
	out.writeln('startxref')
	out.writeln('${start_xref}')
	out.writeln('%%EOF')
	return out.bytestr()
}

fn print_header_footer_reserved_height(cfg PrintHeaderFooterCfg) f32 {
	return if cfg.enabled { f32(18.0) } else { f32(0.0) }
}

fn print_expand_tokens(text string, job PrintJob, page_num int, page_count int) string {
	return text.replace('{page}', page_num.str()).replace('{pages}', page_count.str()).replace('{title}',
		job.title).replace('{job}', job.job_name).replace('{date}', time.now().format_ss())
}

fn pdf_draw_header_footer_line(mut out strings.Builder, text string, x f32, y f32) {
	if text.trim_space().len == 0 {
		return
	}
	out.writeln('BT')
	out.writeln('/F1 9 Tf')
	out.writeln('${pdf_num(x)} ${pdf_num(y)} Td')
	out.writeln('(${pdf_escape_text(text)}) Tj')
	out.writeln('ET')
}

fn pdf_append_header_footer(mut out strings.Builder, job PrintJob, page_width f32, page_height f32, page_num int, page_count int) {
	header_h := print_header_footer_reserved_height(job.header)
	footer_h := print_header_footer_reserved_height(job.footer)
	left_x := job.margins.left
	center_x := page_width * 0.5 - 80
	right_x := page_width - job.margins.right - 140
	if job.header.enabled {
		// Place baseline in reserved header space (between
		// margin top and content area). 9pt font needs ~12pt
		// from top of reserved space for readable placement.
		base_y := page_height - job.margins.top - header_h + 12
		pdf_draw_header_footer_line(mut out, print_expand_tokens(job.header.left, job,
			page_num, page_count), left_x, base_y)
		pdf_draw_header_footer_line(mut out, print_expand_tokens(job.header.center, job,
			page_num, page_count), center_x, base_y)
		pdf_draw_header_footer_line(mut out, print_expand_tokens(job.header.right, job,
			page_num, page_count), right_x, base_y)
	}
	if job.footer.enabled {
		// Place baseline in reserved footer space (between
		// content area and margin bottom).
		base_y := job.margins.bottom + footer_h - 12
		pdf_draw_header_footer_line(mut out, print_expand_tokens(job.footer.left, job,
			page_num, page_count), left_x, base_y)
		pdf_draw_header_footer_line(mut out, print_expand_tokens(job.footer.center, job,
			page_num, page_count), center_x, base_y)
		pdf_draw_header_footer_line(mut out, print_expand_tokens(job.footer.right, job,
			page_num, page_count), right_x, base_y)
	}
}

fn pdf_page_stream(renderers []Renderer, ctx PdfRenderContext, shading_refs map[int]PdfSvgShadingRef, clip_x f32, clip_y f32, clip_w f32, clip_h f32, job PrintJob, page_num int, page_count int) string {
	body_stream := pdf_render_stream(renderers, ctx, shading_refs)
	mut out := strings.new_builder(body_stream.len + 512)
	out.writeln('q')
	out.writeln('${pdf_num(clip_x)} ${pdf_num(clip_y)} ${pdf_num(clip_w)} ${pdf_num(clip_h)} re W n')
	out.write_string(body_stream)
	out.writeln('Q')
	pdf_append_header_footer(mut out, job, ctx.page_width, ctx.page_height, page_num,
		page_count)
	return out.bytestr()
}

fn pdf_render_document(renderers []Renderer, source_width f32, source_height f32, job PrintJob) !string {
	page_width, page_height := print_page_size(job.paper, job.orientation)
	header_h := print_header_footer_reserved_height(job.header)
	footer_h := print_header_footer_reserved_height(job.footer)
	content_width := page_width - job.margins.left - job.margins.right
	content_height := page_height - job.margins.top - job.margins.bottom - header_h - footer_h
	if content_width <= 0 || content_height <= 0 {
		return error('invalid page/margin configuration')
	}
	if source_width <= 0 || source_height <= 0 {
		return error('source dimensions must be positive')
	}

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

	base_ctx := PdfRenderContext{
		page_width:    page_width
		page_height:   page_height
		source_width:  source_width
		source_height: source_height
		scale:         scale
		margins:       PrintMargins{
			top:    job.margins.top + header_h
			right:  job.margins.right
			bottom: job.margins.bottom + footer_h
			left:   job.margins.left
		}
	}
	shading_refs, shading_objects := pdf_collect_svg_shadings(renderers, base_ctx)
	alphas := pdf_collect_alphas(renderers)
	extgstate := pdf_extgstate_dict(alphas)

	mut shading_resource := ''
	if shading_objects.len > 0 {
		mut out := strings.new_builder(shading_objects.len * 16 + 16)
		out.write_string('/Shading << ')
		for i, shading in shading_objects {
			out.write_string('/${shading.ref.name} ${3 + page_count * 2 + i + 1} 0 R ')
		}
		out.write_string('>>')
		shading_resource = out.bytestr()
	}

	mut objects := []string{}
	objects << '<< /Type /Catalog /Pages 2 0 R >>'
	mut kids := []string{}
	for idx in 0 .. page_count {
		kids << '${3 + idx * 2} 0 R'
	}
	objects << '<< /Type /Pages /Kids [${kids.join(' ')}] /Count ${page_count} >>'

	for idx in 0 .. page_count {
		ctx := PdfRenderContext{
			page_width:    base_ctx.page_width
			page_height:   base_ctx.page_height
			source_width:  base_ctx.source_width
			source_height: base_ctx.source_height
			scale:         base_ctx.scale
			margins:       base_ctx.margins
			page_offset_y: if job.paginate { f32(idx) * page_source_height } else { f32(0.0) }
		}
		clip_x := job.margins.left
		clip_y := page_height - (job.margins.top + header_h) - content_height
		stream := pdf_page_stream(renderers, ctx, shading_refs, clip_x, clip_y, content_width,
			content_height, job, idx + 1, page_count)
		page_obj_idx := 3 + idx * 2
		content_obj_idx := page_obj_idx + 1
		page_obj :=
			'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${pdf_num(page_width)} ${pdf_num(page_height)}]' +
			' /Resources << /Font << /F1 << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> >> ' +
			'${extgstate} ${shading_resource} >> /Contents ${content_obj_idx} 0 R >>'
		content_obj := '<< /Length ${stream.len} >>\nstream\n${stream}endstream'
		objects << page_obj
		objects << content_obj
	}
	for shading in shading_objects {
		objects << shading.object_body
	}
	return pdf_encode(objects)
}
