module gui

import gg
import sokol.sgl
import sokol.gfx
import log
import vglyph
import math

// A Renderer is the final computed drawing instruction. gui.Window keeps an array
// of Renderers and only uses that array to paint the window. The window can be
// repainted many times before the a new view state is generated.

const password_char = '*'

struct DrawCircle {
	color  gg.Color
	x      f32
	y      f32
	radius f32
	fill   bool
}

struct DrawImage {
	img &gg.Image
	x   f32
	y   f32
	w   f32
	h   f32
}

struct DrawLine {
	cfg gg.PenConfig
	x   f32
	y   f32
	x1  f32
	y1  f32
}

struct DrawNone {}

struct DrawText {
	text string
	cfg  vglyph.TextConfig
	x    f32
	y    f32
}

// DrawShadow represents a deferred command to draw a drop shadow.
// This is required to ensure shadows are drawn in the correct order during the render pass.
struct DrawShadow {
	x           f32
	y           f32
	width       f32
	height      f32
	radius      f32
	blur_radius f32
	color       gg.Color
	offset_x    f32
	offset_y    f32
}

struct DrawStrokeRect {
	x         f32
	y         f32
	w         f32
	h         f32
	radius    f32
	color     gg.Color
	thickness f32
}

struct DrawBlur {
	x           f32
	y           f32
	width       f32
	height      f32
	radius      f32
	blur_radius f32
	color       gg.Color
}

struct DrawGradientBorder {
	x         f32
	y         f32
	w         f32
	h         f32
	radius    f32
	thickness f32
	gradient  &Gradient
}

struct DrawGradient {
	x        f32
	y        f32
	w        f32
	h        f32
	radius   f32
	gradient &Gradient
}

struct DrawCustomShader {
	x      f32
	y      f32
	w      f32
	h      f32
	radius f32
	color  gg.Color
	shader &Shader
}

struct DrawSvg {
	triangles     []f32 // x,y pairs forming triangles
	color         gg.Color
	vertex_colors []gg.Color // per-vertex colors; empty = flat color
	x             f32
	y             f32
	scale         f32
	is_clip_mask  bool // stencil-write geometry
	clip_group    int  // non-zero = uses stencil clipping
}

// DrawFilterBegin marks the start of a filtered SVG group.
struct DrawFilterBegin {
	group_idx int // index into CachedSvg.filtered_groups
	x         f32
	y         f32
	scale     f32
	cached    &CachedSvg = unsafe { nil }
}

// DrawFilterEnd marks the end of a filtered SVG group.
struct DrawFilterEnd {}

// DrawFilterComposite draws a blurred texture as a textured quad.
struct DrawFilterComposite {
	texture gfx.Image
	sampler gfx.Sampler
	x       f32
	y       f32
	width   f32
	height  f32
	layers  int // draw blur texture this many times (glow intensity)
}

struct DrawLayout {
	layout   &vglyph.Layout
	x        f32
	y        f32
	gradient &vglyph.GradientConfig = unsafe { nil }
}

struct DrawLayoutTransformed {
	layout    &vglyph.Layout
	x         f32
	y         f32
	transform vglyph.AffineTransform
	gradient  &vglyph.GradientConfig = unsafe { nil }
}

struct DrawLayoutPlaced {
	layout     &vglyph.Layout
	placements []vglyph.GlyphPlacement
}

type DrawClip = gg.Rect
type DrawRect = gg.DrawRectParams
type Renderer = DrawCircle
	| DrawClip
	| DrawImage
	| DrawLayout
	| DrawLayoutTransformed
	| DrawLayoutPlaced
	| DrawLine
	| DrawNone
	| DrawRect
	| DrawStrokeRect
	| DrawSvg
	| DrawText
	| DrawShadow
	| DrawBlur
	| DrawGradient
	| DrawGradientBorder
	| DrawCustomShader
	| DrawFilterBegin
	| DrawFilterEnd
	| DrawFilterComposite

// renderers_draw walks the array of renderers and draws them.
// This function and renderer_draw constitute then entire
// draw logic of GUI
fn renderers_draw(mut window Window) {
	renderers := window.renderers

	mut i := 0
	for i < renderers.len {
		renderer := renderers[i]
		// Batch consecutive DrawSvg with same color, position, scale
		if renderer is DrawSvg {
			// Handle stencil clip groups
			if renderer.clip_group > 0 {
				draw_clipped_svg_group(renderers, mut i, mut window)
				continue
			}
			// Per-vertex colored SVGs cannot batch
			if renderer.vertex_colors.len > 0 {
				draw_triangles_gradient(renderer.triangles, renderer.vertex_colors, renderer.x,
					renderer.y, renderer.scale, mut window)
				i++
				continue
			}
			mut batch := []f32{}
			color := renderer.color
			x := renderer.x
			y := renderer.y
			scale := renderer.scale
			// Collect consecutive matching DrawSvg (non-clipped, non-gradient)
			for i < renderers.len {
				if renderers[i] is DrawSvg {
					svg := renderers[i] as DrawSvg
					if svg.clip_group == 0 && svg.vertex_colors.len == 0 && svg.color == color
						&& svg.x == x && svg.y == y && svg.scale == scale {
						batch << svg.triangles
						i++
						continue
					}
				}
				break
			}
			draw_triangles(batch, color, x, y, scale, mut window)
		} else {
			renderer_draw(renderer, mut window)
			i++
		}
	}
	window.text_system.commit()
}

// draw_clipped_svg_group renders a stencil-clipped SVG group.
// Collects all DrawSvg renderers sharing the same clip_group,
// draws mask geometry to stencil, then draws content with
// stencil test.
fn draw_clipped_svg_group(renderers []Renderer, mut idx &int, mut window Window) {
	first := renderers[*idx] as DrawSvg
	group := first.clip_group

	mut masks := []DrawSvg{}
	mut content := []DrawSvg{}

	// Collect all renderers in this clip group
	for *idx < renderers.len {
		if renderers[*idx] is DrawSvg {
			svg := renderers[*idx] as DrawSvg
			if svg.clip_group == group {
				if svg.is_clip_mask {
					masks << svg
				} else {
					content << svg
				}
				(*idx)++
				continue
			}
		}
		break
	}

	if masks.len == 0 || content.len == 0 {
		// No mask or no content — draw content unclipped
		for c in content {
			draw_triangles(c.triangles, c.color, c.x, c.y, c.scale, mut window)
		}
		return
	}

	init_stencil_pipelines(mut window)

	// Step 1: Write clip mask to stencil buffer (ref=1)
	sgl.load_pipeline(window.pip.stencil_write)
	for m in masks {
		draw_triangles_raw(m.triangles, m.x, m.y, m.scale, mut window)
	}

	// Step 2: Draw content where stencil == 1
	sgl.load_pipeline(window.pip.stencil_test)
	for c in content {
		sgl.c4b(c.color.r, c.color.g, c.color.b, c.color.a)
		draw_triangles_raw(c.triangles, c.x, c.y, c.scale, mut window)
	}

	// Step 3: Clear stencil by re-drawing mask with ref=0
	sgl.load_pipeline(window.pip.stencil_clear)
	for m in masks {
		draw_triangles_raw(m.triangles, m.x, m.y, m.scale, mut window)
	}

	sgl.load_default_pipeline()
}

// draw_triangles_raw emits triangle vertices without setting
// color (caller sets pipeline and color).
fn draw_triangles_raw(triangles []f32, x f32, y f32, tri_scale f32, mut window Window) {
	if triangles.len < 6 {
		return
	}
	scale := window.ui.scale
	sgl.begin_triangles()
	mut i := 0
	for i < triangles.len - 5 {
		x0 := (x + triangles[i] * tri_scale) * scale
		y0 := (y + triangles[i + 1] * tri_scale) * scale
		x1 := (x + triangles[i + 2] * tri_scale) * scale
		y1 := (y + triangles[i + 3] * tri_scale) * scale
		x2 := (x + triangles[i + 4] * tri_scale) * scale
		y2 := (y + triangles[i + 5] * tri_scale) * scale
		sgl.v2f(x0, y0)
		sgl.v2f(x1, y1)
		sgl.v2f(x2, y2)
		i += 6
	}
	sgl.end()
}

// renderer_draw draws a single renderer
fn renderer_draw(renderer Renderer, mut window Window) {
	mut ctx := window.ui
	match renderer {
		DrawRect {
			if renderer.w <= 0 || renderer.h <= 0 {
				return
			}
			if renderer.style == .fill {
				draw_rounded_rect_filled(renderer.x, renderer.y, renderer.w, renderer.h,
					renderer.radius, renderer.color, mut window)
			} else {
				// Fallback for default thickness if DrawRect is used directly (should generally use DrawStrokeRect for strokes now)
				draw_rounded_rect_empty(renderer.x, renderer.y, renderer.w, renderer.h,
					renderer.radius, 1.0, renderer.color, mut window)
			}
		}
		DrawStrokeRect {
			if renderer.w <= 0 || renderer.h <= 0 {
				return
			}
			draw_rounded_rect_empty(renderer.x, renderer.y, renderer.w, renderer.h, renderer.radius,
				renderer.thickness, renderer.color, mut window)
		}
		DrawText {
			window.text_system.draw_text(renderer.x, renderer.y, renderer.text, renderer.cfg) or {
				// Log error with context for debugging
				log.error('Text render failed at (${renderer.x}, ${renderer.y}): ${err.msg()}')
				log.debug('Failed text content: "${renderer.text}"')

				// Fallback: draw small magenta indicator
				draw_error_placeholder(renderer.x, renderer.y, 10, 10, mut window)
			}
		}
		DrawLayout {
			if renderer.gradient != unsafe { nil } {
				window.text_system.draw_layout_with_gradient(renderer.layout, renderer.x,
					renderer.y, renderer.gradient)
			} else {
				window.text_system.draw_layout(renderer.layout, renderer.x, renderer.y)
			}
		}
		DrawLayoutTransformed {
			if renderer.gradient != unsafe { nil } {
				window.text_system.draw_layout_transformed_with_gradient(renderer.layout,
					renderer.x, renderer.y, renderer.transform, renderer.gradient)
			} else {
				window.text_system.draw_layout_transformed(renderer.layout, renderer.x,
					renderer.y, renderer.transform)
			}
		}
		DrawLayoutPlaced {
			window.text_system.draw_layout_placed(renderer.layout, renderer.placements)
		}
		DrawClip {
			sgl.scissor_rectf(ctx.scale * renderer.x, ctx.scale * renderer.y, ctx.scale * renderer.width,
				ctx.scale * renderer.height, true)
		}
		DrawCircle {
			if renderer.fill {
				ctx.draw_circle_filled(renderer.x, renderer.y, renderer.radius, renderer.color)
			} else {
				ctx.draw_circle_empty(renderer.x, renderer.y, renderer.radius, renderer.color)
			}
		}
		DrawImage {
			ctx.draw_image(renderer.x, renderer.y, renderer.w, renderer.h, renderer.img)
		}
		DrawLine {
			ctx.draw_line_with_config(renderer.x, renderer.y, renderer.x1, renderer.y1,
				renderer.cfg)
		}
		DrawShadow {
			draw_shadow_rect(renderer.x, renderer.y, renderer.width, renderer.height,
				renderer.radius, renderer.blur_radius, renderer.color, renderer.offset_x,
				renderer.offset_y, mut window)
		}
		DrawBlur {
			draw_blur_rect(renderer.x, renderer.y, renderer.width, renderer.height, renderer.radius,
				renderer.blur_radius, renderer.color, mut window)
		}
		DrawGradient {
			draw_gradient_rect(renderer.x, renderer.y, renderer.w, renderer.h, renderer.radius,
				renderer.gradient, mut window)
		}
		DrawGradientBorder {
			draw_gradient_border(renderer.x, renderer.y, renderer.w, renderer.h, renderer.radius,
				renderer.thickness, renderer.gradient, mut window)
		}
		DrawCustomShader {
			draw_custom_shader_rect(renderer.x, renderer.y, renderer.w, renderer.h, renderer.radius,
				renderer.color, renderer.shader, mut window)
		}
		DrawSvg {
			if renderer.vertex_colors.len > 0 {
				draw_triangles_gradient(renderer.triangles, renderer.vertex_colors, renderer.x,
					renderer.y, renderer.scale, mut window)
			} else {
				draw_triangles(renderer.triangles, renderer.color, renderer.x, renderer.y,
					renderer.scale, mut window)
			}
		}
		DrawFilterComposite {
			draw_filter_composite(renderer, mut window)
		}
		DrawFilterBegin {}
		DrawFilterEnd {}
		DrawNone {}
	}
}

// process_svg_filters scans renderers for DrawFilterBegin..End brackets,
// renders the content to offscreen textures, applies Gaussian blur,
// and replaces the bracket with DrawFilterComposite + original content.
fn process_svg_filters(mut window Window) {
	mut i := 0
	mut new_renderers := []Renderer{cap: window.renderers.len}
	renderers := window.renderers

	for i < renderers.len {
		r := renderers[i]
		if r is DrawFilterBegin {
			begin := r
			cached := begin.cached
			if cached == unsafe { nil } || begin.group_idx >= cached.filtered_groups.len {
				i++
				continue
			}
			fg := cached.filtered_groups[begin.group_idx]
			filter := fg.filter

			// Collect content renderers between Begin and End
			i++
			mut content := []Renderer{cap: 32}
			for i < renderers.len {
				cr := renderers[i]
				if cr is DrawFilterEnd {
					i++
					break
				}
				content << cr
				i++
			}

			// Compute screen-space bbox with blur padding
			scale := begin.scale
			ui_scale := window.ui.scale
			padding := filter.std_dev * 3.0 * scale
			bbox_x := (begin.x + fg.bbox[0] * scale - padding) * ui_scale
			bbox_y := (begin.y + fg.bbox[1] * scale - padding) * ui_scale
			bbox_w := (fg.bbox[2] * scale + padding * 2) * ui_scale
			bbox_h := (fg.bbox[3] * scale + padding * 2) * ui_scale

			tex_w := int(math.ceil(bbox_w))
			tex_h := int(math.ceil(bbox_h))

			if tex_w <= 0 || tex_h <= 0 {
				new_renderers << content
				continue
			}

			ensure_filter_state(mut window)
			ensure_filter_textures(mut window, tex_w, tex_h)

			// Render content to tex_a via raw gfx offscreen pass
			render_filter_content(content, bbox_x, bbox_y, bbox_w, bbox_h, ui_scale, mut
				window)

			// Blur: H (tex_a → tex_b), V (tex_b → tex_a)
			blur_filter_pass(filter.std_dev, mut window)

			// Emit composite: draw blurred texture on swapchain
			new_renderers << Renderer(DrawFilterComposite{
				texture: window.filter_state.tex_a
				sampler: window.filter_state.sampler
				x:       bbox_x / ui_scale
				y:       bbox_y / ui_scale
				width:   bbox_w / ui_scale
				height:  bbox_h / ui_scale
				layers:  filter.blur_layers
			})

			if filter.keep_source {
				new_renderers << content
			}
		} else {
			new_renderers << r
			i++
		}
	}

	window.renderers = new_renderers
}

// render_filter_content renders SVG content to offscreen tex_a
// using raw gfx calls (no SGL, avoids vertex buffer conflicts).
fn render_filter_content(content []Renderer, bbox_x f32, bbox_y f32, bbox_w f32, bbox_h f32, ui_scale f32, mut window Window) {
	// Count triangle vertices needed
	mut n_verts := 0
	for r in content {
		if r is DrawSvg {
			n_verts += r.triangles.len / 2 // x,y pairs → vertices
		}
	}

	if n_verts == 0 {
		// Nothing to render; just clear tex_a
		mut pa := gfx.PassAction{}
		pa.colors[0] = gfx.ColorAttachmentAction{
			load_action: .clear
			clear_value: gfx.Color{0.0, 0.0, 0.0, 0.0}
		}
		gfx.begin_pass(gfx.Pass{
			action:      pa
			attachments: window.filter_state.att_a
		})
		gfx.end_pass()
		return
	}

	// Build vertex buffer from SVG content
	mut verts := []FilterVertex{cap: n_verts}
	for r in content {
		if r is DrawSvg {
			c := r.color
			has_vcols := r.vertex_colors.len > 0
			mut vi := 0
			mut i := 0
			for i < r.triangles.len - 1 {
				x0 := (r.x + r.triangles[i] * r.scale) * ui_scale
				y0 := (r.y + r.triangles[i + 1] * r.scale) * ui_scale
				if has_vcols && vi < r.vertex_colors.len {
					vc := r.vertex_colors[vi]
					verts << FilterVertex{x0, y0, 0, 0, 0, vc.r, vc.g, vc.b, vc.a}
				} else {
					verts << FilterVertex{x0, y0, 0, 0, 0, c.r, c.g, c.b, c.a}
				}
				vi++
				i += 2
			}
		}
	}

	// Create or resize dynamic vertex buffer
	buf_size := int(sizeof(FilterVertex)) * verts.len
	if window.filter_state.content_vbuf_sz < buf_size {
		if window.filter_state.content_vbuf_sz > 0 {
			gfx.destroy_buffer(window.filter_state.content_vbuf)
		}
		window.filter_state.content_vbuf = gfx.make_buffer(gfx.BufferDesc{
			size:  usize(buf_size)
			usage: .dynamic
			label: c'filter_content_vbuf'
		})
		window.filter_state.content_vbuf_sz = buf_size
	}
	gfx.update_buffer(window.filter_state.content_vbuf, gfx.Range{
		ptr:  unsafe { verts.data }
		size: usize(buf_size)
	})

	// Ortho projection mapping bbox to clip space
	mvp := ortho_column_major(bbox_x, bbox_x + bbox_w, bbox_y + bbox_h, bbox_y, -1.0,
		1.0)
	mut tm := [16]f32{}
	tm[5] = 1.0
	tm[10] = 1.0
	tm[15] = 1.0

	// Pack uniforms: mvp + tm = 128 bytes
	mut uniforms := [32]f32{}
	for j in 0 .. 16 {
		uniforms[j] = mvp[j]
	}
	for j in 0 .. 16 {
		uniforms[16 + j] = tm[j]
	}

	mut pass_action := gfx.PassAction{}
	pass_action.colors[0] = gfx.ColorAttachmentAction{
		load_action: .clear
		clear_value: gfx.Color{0.0, 0.0, 0.0, 0.0}
	}

	gfx.begin_pass(gfx.Pass{
		action:      pass_action
		attachments: window.filter_state.att_a
	})
	gfx.apply_pipeline(window.filter_state.content_pip)
	mut bindings := gfx.Bindings{}
	bindings.vertex_buffers[0] = window.filter_state.content_vbuf
	gfx.apply_bindings(&bindings)
	gfx.apply_uniforms(.vs, 0, &gfx.Range{
		ptr:  unsafe { &uniforms[0] }
		size: 128
	})
	gfx.draw(0, verts.len, 1)
	gfx.end_pass()
}

// blur_filter_pass applies separable Gaussian blur using raw gfx:
// horizontal (tex_a → tex_b) then vertical (tex_b → tex_a).
fn blur_filter_pass(std_dev f32, mut window Window) {
	fs := &window.filter_state

	// Unit-quad ortho: maps (0,0)-(1,1) to full render target
	mvp := ortho_column_major(0, 1, 1, 0, -1, 1)
	mut tm := [16]f32{}
	tm[0] = std_dev
	tm[5] = 1.0
	tm[10] = 1.0
	tm[15] = 1.0

	mut uniforms := [32]f32{}
	for j in 0 .. 16 {
		uniforms[j] = mvp[j]
	}
	for j in 0 .. 16 {
		uniforms[16 + j] = tm[j]
	}

	mut pass_action := gfx.PassAction{}
	pass_action.colors[0] = gfx.ColorAttachmentAction{
		load_action: .clear
		clear_value: gfx.Color{0.0, 0.0, 0.0, 0.0}
	}

	// Horizontal blur: tex_a → tex_b
	gfx.begin_pass(gfx.Pass{
		action:      pass_action
		attachments: fs.att_b
	})
	gfx.apply_pipeline(fs.blur_h_pip)
	mut bindings := gfx.Bindings{}
	bindings.vertex_buffers[0] = fs.quad_vbuf
	bindings.fs.images[0] = fs.tex_a
	bindings.fs.samplers[0] = fs.sampler
	gfx.apply_bindings(&bindings)
	gfx.apply_uniforms(.vs, 0, &gfx.Range{
		ptr:  unsafe { &uniforms[0] }
		size: 128
	})
	gfx.draw(0, 6, 1)
	gfx.end_pass()

	// Vertical blur: tex_b → tex_a
	gfx.begin_pass(gfx.Pass{
		action:      pass_action
		attachments: fs.att_a
	})
	gfx.apply_pipeline(fs.blur_v_pip)
	bindings.fs.images[0] = fs.tex_b
	gfx.apply_bindings(&bindings)
	gfx.apply_uniforms(.vs, 0, &gfx.Range{
		ptr:  unsafe { &uniforms[0] }
		size: 128
	})
	gfx.draw(0, 6, 1)
	gfx.end_pass()
}

// draw_filter_composite draws a blurred texture quad to the screen.
fn draw_filter_composite(c DrawFilterComposite, mut window Window) {
	ensure_filter_state(mut window)

	scale := window.ui.scale
	sx := c.x * scale
	sy := c.y * scale
	sw := c.width * scale
	sh := c.height * scale

	sgl.load_pipeline(window.filter_state.texture_quad_pip)
	sgl.enable_texture()
	sgl.texture(c.texture, c.sampler)

	// Draw multiple times for glow intensity
	for _ in 0 .. c.layers {
		sgl.c4b(255, 255, 255, 255)
		draw_filter_quad(sx, sy, sw, sh)
	}

	sgl.disable_texture()
	sgl.load_default_pipeline()
}

// render_layout walks the layout and generates renderers. If a shape is clipped,
// then a clip rectangle is added to the context. Clip rectangles are added to the
// draw context and the later, 'removed' by setting the clip rectangle to the
// previous rectangle of if not present, infinity.
fn render_layout(mut layout Layout, bg_color Color, clip DrawClip, mut window Window) {
	render_shape(mut layout.shape, bg_color, clip, mut window)

	mut shape_clip := clip
	if layout.shape.over_draw { // allow drawing in the padded area of shape
		shape_clip = layout.shape.shape_clip
		if layout.shape.scrollbar_orientation == .vertical {
			shape_clip = DrawClip{
				...shape_clip
				y:      clip.y
				height: clip.height
			}
		}
		if layout.shape.scrollbar_orientation == .horizontal {
			shape_clip = DrawClip{
				...shape_clip
				x:     clip.x
				width: clip.width
			}
		}
		window.renderers << shape_clip
	} else if layout.shape.clip {
		sc := layout.shape.shape_clip
		shape_clip = DrawClip{
			x:      sc.x + layout.shape.padding_left()
			y:      sc.y + layout.shape.padding_top()
			width:  f32_max(0, sc.width - layout.shape.padding_width())
			height: f32_max(0, sc.height - layout.shape.padding_height())
		}
		window.renderers << shape_clip
	}

	color := if layout.shape.color != color_transparent { layout.shape.color } else { bg_color }
	for mut child in layout.children {
		render_layout(mut child, color, shape_clip, mut window)
	}

	if layout.shape.clip || layout.shape.over_draw {
		window.renderers << clip
	}
}

// render_shape examines the Shape.type and calls the appropriate renderer.
fn render_shape(mut shape Shape, parent_color Color, clip DrawClip, mut window Window) {
	// Degrade safely if a text-like shape is missing text config.
	if shape.shape_type in [.text, .rtf] && shape.tc == unsafe { nil } {
		return
	}

	// Apply opacity to colors
	if shape.opacity < 1.0 {
		shape.color = shape.color.with_opacity(shape.opacity)
		shape.color_border = shape.color_border.with_opacity(shape.opacity)
		if shape.tc != unsafe { nil } {
			shape.tc.text_style = TextStyle{
				...shape.tc.text_style
				color: shape.tc.text_style.color.with_opacity(shape.opacity)
			}
		}
	}

	has_visible_border := shape.size_border > 0 && shape.color_border != color_transparent
	has_visible_text := shape.shape_type == .text && shape.tc != unsafe { nil }
		&& (shape.tc.text_style.color != color_transparent || shape.tc.text_style.stroke_width > 0)
	// SVG shapes have their own internal colors, so don't skip them
	is_svg := shape.shape_type == .svg
	has_effects := shape.fx != unsafe { nil } && (shape.fx.gradient != unsafe { nil }
		|| shape.fx.shader != unsafe { nil }
		|| shape.fx.border_gradient != unsafe { nil })
	if shape.color == color_transparent && !has_effects && !has_visible_border && !has_visible_text
		&& !is_svg {
		return
	}
	match shape.shape_type {
		.rectangle {
			render_container(mut shape, parent_color, clip, mut window)
		}
		.text {
			render_text(mut shape, clip, mut window)
		}
		.image {
			render_image(mut shape, clip, mut window)
		}
		.circle {
			render_circle(mut shape, clip, mut window)
		}
		.rtf {
			render_rtf(mut shape, clip, mut window)
		}
		.svg {
			render_svg(mut shape, clip, mut window)
		}
		.none {}
	}
}

// render_container mostly draws a rectangle. Containers are more about layout than drawing.
// One complication is the title text that is drawn in the upper left corner of the rectangle.
// At some point, it should be moved to the container logic, along with some layout amend logic.
// Honestly, it was more expedient to put it here.
fn render_container(mut shape Shape, parent_color Color, clip DrawClip, mut window Window) {
	fx := shape.fx
	has_fx := fx != unsafe { nil }
	if has_fx && fx.shadow != unsafe { nil } && fx.shadow.color.a > 0 && fx.shadow.blur_radius > 0 {
		window.renderers << DrawShadow{
			x:           shape.x + fx.shadow.offset_x
			y:           shape.y + fx.shadow.offset_y
			width:       shape.width
			height:      shape.height
			radius:      shape.radius
			blur_radius: fx.shadow.blur_radius
			color:       fx.shadow.color.to_gx_color()
			offset_x:    fx.shadow.offset_x
			offset_y:    fx.shadow.offset_y
		}
	}
	// Here is where the mighty container is drawn. Yeah, it really is just a rectangle.
	if has_fx && fx.shader != unsafe { nil } {
		color := if shape.disabled { dim_alpha(shape.color) } else { shape.color }
		window.renderers << DrawCustomShader{
			x:      shape.x
			y:      shape.y
			w:      shape.width
			h:      shape.height
			radius: shape.radius
			color:  color.to_gx_color()
			shader: fx.shader
		}
		// Draw border separately if present
		if shape.size_border > 0 && shape.color_border != color_transparent {
			c_border := if shape.disabled {
				dim_alpha(shape.color_border)
			} else {
				shape.color_border
			}
			if c_border.a > 0 {
				window.renderers << DrawStrokeRect{
					x:         shape.x
					y:         shape.y
					w:         shape.width
					h:         shape.height
					color:     c_border.to_gx_color()
					radius:    shape.radius
					thickness: shape.size_border
				}
			}
		}
		return
	} else if has_fx && fx.gradient != unsafe { nil } {
		window.renderers << DrawGradient{
			x:        shape.x
			y:        shape.y
			w:        shape.width
			h:        shape.height
			radius:   shape.radius
			gradient: fx.gradient
		}
	} else if has_fx && fx.blur_radius > 0 && shape.color.a > 0 {
		window.renderers << DrawBlur{
			x:           shape.x
			y:           shape.y
			width:       shape.width
			height:      shape.height
			radius:      shape.radius
			blur_radius: fx.blur_radius
			color:       shape.color.to_gx_color()
		}
	} else {
		// Check for Border Gradient
		if has_fx && fx.border_gradient != unsafe { nil } {
			window.renderers << DrawGradientBorder{
				x:         shape.x
				y:         shape.y
				w:         shape.width
				h:         shape.height
				radius:    shape.radius
				thickness: shape.size_border
				gradient:  fx.border_gradient
			}
		} else {
			render_rectangle(mut shape, clip, mut window)
		}
	}
}

// render_circle draws a shape as a circle in the middle of the shape's
// rectangular region. Radius is half of the shortest side.
fn render_circle(mut shape Shape, clip DrawClip, mut window Window) {
	assert shape.shape_type == .circle
	draw_rect := gg.Rect{
		x:      shape.x
		y:      shape.y
		width:  shape.width
		height: shape.height
	}
	color := if shape.disabled { dim_alpha(shape.color) } else { shape.color }
	gx_color := color.to_gx_color()
	if rects_overlap(draw_rect, clip) {
		radius := f32_min(shape.width, shape.height) / 2
		x := shape.x + shape.width / 2
		y := shape.y + shape.height / 2

		// Fill
		if color.a > 0 {
			window.renderers << DrawCircle{
				x:      x
				y:      y
				radius: radius
				fill:   true
				color:  gx_color
			}
		}

		// Border
		if shape.size_border > 0 {
			c_border := if shape.disabled {
				dim_alpha(shape.color_border)
			} else {
				shape.color_border
			}
			if c_border.a > 0 {
				window.renderers << DrawStrokeRect{
					x:         draw_rect.x
					y:         draw_rect.y
					w:         draw_rect.width
					h:         draw_rect.height
					color:     c_border.to_gx_color()
					radius:    radius
					thickness: shape.size_border
				}
			}
		}
	} else {
		shape.disabled = true
	}
}

// render_rectangle draws a shape as a rectangle.
fn render_rectangle(mut shape Shape, clip DrawClip, mut window Window) {
	assert shape.shape_type == .rectangle
	draw_rect := gg.Rect{
		x:      shape.x
		y:      shape.y
		width:  shape.width
		height: shape.height
	}
	color := if shape.disabled { dim_alpha(shape.color) } else { shape.color }
	gx_color := color.to_gx_color()

	if rects_overlap(draw_rect, clip) {
		// Fill
		if color.a > 0 {
			window.renderers << DrawRect{
				x:          draw_rect.x
				y:          draw_rect.y
				w:          draw_rect.width
				h:          draw_rect.height
				color:      gx_color
				style:      .fill
				is_rounded: shape.radius > 0
				radius:     shape.radius
			}
		}

		// Border
		if shape.size_border > 0 {
			c_border := if shape.disabled {
				dim_alpha(shape.color_border)
			} else {
				shape.color_border
			}

			if c_border.a > 0 {
				window.renderers << DrawStrokeRect{
					x:         draw_rect.x
					y:         draw_rect.y
					w:         draw_rect.width
					h:         draw_rect.height
					color:     c_border.to_gx_color()
					radius:    shape.radius
					thickness: shape.size_border
				}
			}
		}
	} else {
		shape.disabled = true
	}
}

fn text_shape_draw_transform(shape &Shape) ?vglyph.AffineTransform {
	if shape.id_focus > 0 {
		return none
	}
	if !shape.tc.text_style.has_text_transform() {
		return none
	}
	return shape.tc.text_style.effective_text_transform()
}

fn clone_layout_for_draw(src &vglyph.Layout) &vglyph.Layout {
	if src == unsafe { nil } {
		return &vglyph.Layout{}
	}
	return &vglyph.Layout{
		cloned_object_ids:  src.cloned_object_ids.clone()
		items:              src.items.clone()
		glyphs:             src.glyphs.clone()
		char_rects:         src.char_rects.clone()
		char_rect_by_index: src.char_rect_by_index.clone()
		lines:              src.lines.clone()
		log_attrs:          src.log_attrs.clone()
		log_attr_by_index:  src.log_attr_by_index.clone()
		width:              src.width
		height:             src.height
		visual_width:       src.visual_width
		visual_height:      src.visual_height
	}
}

fn password_mask_text_keep_newlines(text string) string {
	mut out := []rune{cap: utf8_str_visible_length(text)}
	for r in text.runes_iterator() {
		if r == `\n` {
			out << `\n`
		} else {
			out << `*`
		}
	}
	return out.string()
}

// render_text renders text including multiline text using vglyph layout.
// If cursor coordinates are present, it draws the input cursor.
// The highlighting of selected text happens here also.
fn render_text(mut shape Shape, clip DrawClip, mut window Window) {
	dr := gg.Rect{
		x:      shape.x
		y:      shape.y
		width:  shape.width
		height: shape.height
	}
	if !rects_overlap(dr, clip) {
		shape.disabled = true
		return
	}
	color := if shape.disabled {
		dim_alpha(shape.tc.text_style.color)
	} else {
		shape.tc.text_style.color
	}
	text_cfg := TextStyle{
		...shape.tc.text_style
		color: color
	}.to_vglyph_cfg()

	has_stroke := shape.tc.text_style.stroke_width > 0
	if shape.has_text_layout() && (color != color_transparent || has_stroke) {
		if transform := text_shape_draw_transform(shape) {
			mut layout_to_draw := clone_layout_for_draw(shape.tc.vglyph_layout)
			if window.text_system != unsafe { nil } {
				mut cfg := text_cfg
				cfg.block.width = shape.tc.last_constraint_width
				cfg.no_hit_testing = true
				text_to_layout := if shape.tc.text_is_password && !shape.tc.text_is_placeholder {
					password_mask_text_keep_newlines(shape.tc.text)
				} else {
					shape.tc.text
				}
				mut transformed_layout := window.text_system.layout_text(text_to_layout,
					cfg) or {
					log.error('Transformed text layout failed at (${shape.x}, ${shape.y}): ${err.msg()}')
					return
				}
				if transformed_layout.lines.len > 0 || text_to_layout.len == 0 {
					layout_to_draw = clone_layout_for_draw(&transformed_layout)
				}
			}
			window.renderers << DrawLayoutTransformed{
				layout:    layout_to_draw
				x:         shape.x + shape.padding_left()
				y:         shape.y + shape.padding_top()
				transform: transform
				gradient:  shape.tc.text_style.gradient
			}
			return
		}
	}

	lh := line_height(shape, mut window)
	beg := int(shape.tc.text_sel_beg)
	end := int(shape.tc.text_sel_end)

	// Convert selection range to byte indices because vglyph uses bytes
	byte_beg := rune_to_byte_index(shape.tc.text, beg)
	byte_end := rune_to_byte_index(shape.tc.text, end)

	has_gradient := shape.tc.text_style.gradient != unsafe { nil }

	if shape.has_text_layout() {
		// Gradient text: emit single DrawLayout for full layout
		if has_gradient && (color != color_transparent || has_stroke) {
			layout_to_draw := clone_layout_for_draw(shape.tc.vglyph_layout)
			window.renderers << DrawLayout{
				layout:   layout_to_draw
				x:        shape.x + shape.padding_left()
				y:        shape.y + shape.padding_top()
				gradient: shape.tc.text_style.gradient
			}
		}

		for line in shape.tc.vglyph_layout.lines {
			draw_x := shape.x + shape.padding_left() + line.rect.x
			draw_y := shape.y + shape.padding_top() + line.rect.y

			// Extract text for this line
			if line.start_index >= shape.tc.text.len {
				continue
			}
			mut line_end := line.start_index + line.length
			if line_end > shape.tc.text.len {
				line_end = shape.tc.text.len
			}

			// Drawing
			draw_rect := gg.Rect{
				x:      draw_x
				y:      draw_y
				width:  shape.width // approximate, or use line.rect.width
				height: lh
			}

			// Cull
			if rects_overlap(clip, draw_rect) && (color != color_transparent || has_stroke) {
				if !has_gradient {
					// Remove newlines for rendering
					mut slice_end := line_end
					if slice_end > line.start_index && shape.tc.text[slice_end - 1] == `\n` {
						slice_end--
					}
					mut render_str := shape.tc.text[line.start_index..slice_end]

					if shape.tc.text_is_password && !shape.tc.text_is_placeholder {
						render_str = password_char.repeat(utf8_str_visible_length(render_str))
					}

					if render_str.len > 0 {
						window.renderers << DrawText{
							x:    draw_x
							y:    draw_y
							text: render_str
							cfg:  text_cfg
						}
					}
				}

				// Draw text selection
				if byte_beg < line_end && byte_end > line.start_index {
					draw_text_selection(mut window, DrawTextSelectionParams{
						shape:    shape
						line:     line
						draw_x:   draw_x
						draw_y:   draw_y
						byte_beg: byte_beg
						byte_end: byte_end
						text_cfg: text_cfg
					})
				}
			}
		}
	}

	render_cursor(shape, clip, mut window)
}

struct DrawTextSelectionParams {
	shape    &Shape
	line     vglyph.Line
	draw_x   f32
	draw_y   f32
	byte_beg int
	byte_end int
	text_cfg vglyph.TextConfig
}

fn draw_text_selection(mut window Window, params DrawTextSelectionParams) {
	shape := params.shape
	line := params.line
	draw_x := params.draw_x
	draw_y := params.draw_y
	byte_beg := params.byte_beg
	byte_end := params.byte_end
	text_cfg := params.text_cfg

	// Intersection
	i_start := int_max(byte_beg, line.start_index)
	i_end := int_min(byte_end, line.start_index + line.length)

	if i_start < i_end {
		if shape.tc.text_is_password {
			// Password fields still need measurement because the rendered text (*)
			// is different from the logical text.
			pre_text := shape.tc.text[line.start_index..i_start]
			sel_text := shape.tc.text[i_start..i_end]

			pw_pre := password_char.repeat(utf8_str_visible_length(pre_text))
			start_x_offset := window.text_system.text_width(pw_pre, text_cfg) or { 0 }

			pw_sel := password_char.repeat(utf8_str_visible_length(sel_text))
			sel_width := window.text_system.text_width(pw_sel, text_cfg) or { 0 }

			window.renderers << DrawRect{
				x:     draw_x + start_x_offset
				y:     draw_y
				w:     sel_width
				h:     line.rect.height
				color: gg.Color{
					...text_cfg.style.color
					a: 60
				}
			}
		} else {
			// Optimization: Use cached layout geometry
			// Get rect for start char
			r_start := shape.tc.vglyph_layout.get_char_rect(i_start) or { gg.Rect{} }

			// Get rect for end char (or end of line)
			x_end := if i_end < (line.start_index + line.length) && shape.tc.text[i_end] != `\n` {
				r_end := shape.tc.vglyph_layout.get_char_rect(i_end) or {
					gg.Rect{
						x: line.rect.width
					}
				}
				r_end.x
			} else {
				// End of selection is end of line (or newline)
				line.rect.width
			}

			sel_width := x_end - r_start.x

			window.renderers << DrawRect{
				x:     draw_x + r_start.x
				y:     draw_y
				w:     sel_width
				h:     line.rect.height
				color: gg.Color{
					...text_cfg.style.color
					a: 60
				}
			}
		}
	}
}

// render_cursor figures out where the darn cursor goes using vglyph.
fn render_cursor(shape &Shape, clip DrawClip, mut window Window) {
	if window.is_focus(shape.id_focus) && shape.shape_type == .text
		&& window.view_state.input_cursor_on {
		input_state := window.view_state.input_state.get(shape.id_focus) or { InputState{} }
		cursor_pos := if shape.tc.text_is_placeholder {
			0
		} else {
			int_min(input_state.cursor_pos, shape.tc.text.runes().len)
		}

		if cursor_pos >= 0 {
			byte_idx := rune_to_byte_index(shape.tc.text, cursor_pos)

			// Use vglyph to get the rect
			rect := if shape.has_text_layout() {
				shape.tc.vglyph_layout.get_char_rect(byte_idx) or {
					// If not found, check if it's at the very end
					if byte_idx >= shape.tc.text.len && shape.tc.vglyph_layout.lines.len > 0 {
						last_line := shape.tc.vglyph_layout.lines.last()
						// Correction: use layout logic relative to shape
						gg.Rect{
							x:      last_line.rect.x + last_line.rect.width
							y:      last_line.rect.y
							height: last_line.rect.height
						}
					} else {
						gg.Rect{
							height: line_height(shape, mut window)
						} // Fallback
					}
				}
			} else {
				gg.Rect{
					height: line_height(shape, mut window)
				}
			}
			cx := shape.x + shape.padding_left() + rect.x
			cy := shape.y + shape.padding_top() + rect.y
			ch := rect.height

			// Draw cursor line
			window.renderers << DrawRect{
				x:     cx
				y:     cy
				w:     1.5 // slightly thicker
				h:     ch
				color: shape.tc.text_style.color.to_gx_color()
				style: .fill
			}
		}
	}

	// Draw IME composition underlines when composing
	if window.is_focus(shape.id_focus) && shape.has_text_layout()
		&& window.text_system != unsafe { nil } && window.text_system.is_composing()
		&& !shape.tc.text_is_password {
		render_composition(shape, mut window)
	}
}

// render_composition draws clause underlines for active IME
// preedit text. Thick underline for selected clause, thin for
// others.
fn render_composition(shape &Shape, mut window Window) {
	cs := window.text_system.composition
	clause_rects := cs.get_clause_rects(*shape.tc.vglyph_layout)
	text_color := shape.tc.text_style.color.to_gx_color()
	underline_color := gg.Color{
		r: text_color.r
		g: text_color.g
		b: text_color.b
		a: 178 // ~70% opacity
	}

	ox := shape.x + shape.padding_left()
	oy := shape.y + shape.padding_top()

	for cr in clause_rects {
		thickness := if cr.style == .selected {
			f32(2.0)
		} else {
			f32(1.0)
		}
		for rect in cr.rects {
			window.renderers << DrawRect{
				x:     ox + rect.x
				y:     oy + rect.y + rect.height - thickness
				w:     rect.width
				h:     thickness
				color: underline_color
				style: .fill
			}
		}
	}
}

fn render_image(mut shape Shape, clip DrawClip, mut window Window) {
	dr := gg.Rect{
		x:      shape.x
		y:      shape.y
		width:  shape.width
		height: shape.height
	}
	if !rects_overlap(dr, clip) {
		shape.disabled = true
		return
	}
	image := window.load_image(shape.resource) or {
		log.error('${@FILE_LINE} > ${err.msg()}')
		draw_error_placeholder(shape.x, shape.y, shape.width, shape.height, mut window)
		return
	}
	window.renderers << DrawImage{
		x:   shape.x
		y:   shape.y
		w:   shape.width
		h:   shape.height
		img: image
	}
}

fn render_rtf(mut shape Shape, clip DrawClip, mut window Window) {
	if shape.has_rtf_layout() {
		dr := gg.Rect{
			x:      shape.x
			y:      shape.y
			width:  shape.width
			height: shape.height
		}
		if rects_overlap(dr, clip) {
			mut has_transform := false
			mut transform := vglyph.AffineTransform{}
			mut mixed_transform := false
			mut has_inline_objects := false
			if shape.tc.rich_text != unsafe { nil } {
				if draw_transform := shape.tc.rich_text.uniform_text_transform() {
					has_transform = true
					transform = draw_transform
				}
				mixed_transform = shape.tc.rich_text.has_mixed_text_transform()
			}
			for item in shape.tc.vglyph_layout.items {
				if item.is_object {
					has_inline_objects = true
					break
				}
			}
			if mixed_transform {
				log.warn('RTF transform ignored for shape "${shape.id}": mixed run transforms')
			}
			if has_transform && has_inline_objects {
				log.warn('RTF transform ignored for shape "${shape.id}": inline objects not supported')
				has_transform = false
			}
			if has_transform {
				window.renderers << DrawLayoutTransformed{
					layout:    clone_layout_for_draw(shape.tc.vglyph_layout)
					x:         shape.x
					y:         shape.y
					transform: transform
				}
			} else {
				window.renderers << DrawLayout{
					layout: shape.tc.vglyph_layout
					x:      shape.x
					y:      shape.y
				}
			}
			// Draw inline math images at InlineObject positions
			for item in shape.tc.vglyph_layout.items {
				if item.is_object && item.object_id != '' {
					ihash := math_cache_hash(item.object_id)
					if entry := window.view_state.diagram_cache.get(ihash) {
						if entry.state == .ready && entry.png_path.len > 0 {
							img := window.load_image(entry.png_path) or { continue }
							window.renderers << DrawImage{
								x:   shape.x + f32(item.x)
								y:   shape.y + f32(item.y) - f32(item.ascent)
								w:   f32(item.width)
								h:   f32(item.ascent + item.descent)
								img: img
							}
						}
					}
				}
			}
		} else {
			shape.disabled = true
		}
	}
}

// dim_alpha is used for visually indicating disabled.
fn dim_alpha(color Color) Color {
	return Color{
		...color
		a: color.a / u8(2)
	}
}

// rects_overlap checks if two rectangles overlap.
@[inline]
fn rects_overlap(r1 gg.Rect, r2 gg.Rect) bool {
	return r1.x < (r2.x + r2.width) && r2.x < (r1.x + r1.width) && r1.y < (r2.y + r2.height)
		&& r2.y < (r1.y + r1.height)
}

// draw_blur_rect draws a blurred rounded rectangle.
// It is similar to draw_shadow_rect but the blur is "filled".
pub fn draw_blur_rect(x f32, y f32, w f32, h f32, radius f32, blur f32, c gg.Color, mut window Window) {
	if c.a == 0 {
		return
	}

	scale := window.ui.scale
	padding := blur * 1.5

	sx := (x - padding) * scale
	sy := (y - padding) * scale
	sw := (w + padding * 2) * scale
	sh := (h + padding * 2) * scale

	r := radius * scale
	b := blur * scale

	init_blur_pipeline(mut window)

	// Since we used vs_shadow which expects 'tm' uniform (offset), we must provide it even if 0.
	sgl.matrix_mode_texture()
	sgl.push_matrix()
	sgl.load_identity()
	// No offset for generic blur
	sgl.translate(0, 0, 0)

	sgl.load_pipeline(window.pip.blur)
	sgl.c4b(c.r, c.g, c.b, c.a)

	z_val := pack_shader_params(r, b)

	draw_quad(sx, sy, sw, sh, z_val)
	sgl.load_default_pipeline()
	sgl.c4b(255, 255, 255, 255) // Reset color state

	sgl.pop_matrix()
	sgl.matrix_mode_modelview()
}

// angle_to_direction converts CSS angle (degrees) to unit direction vector
// CSS: 0deg=top, clockwise. Math: 0rad=right, counter-clockwise.
fn angle_to_direction(css_degrees f32) (f32, f32) {
	rad := (90.0 - css_degrees) * math.pi / 180.0
	return f32(math.cos(rad)), -f32(math.sin(rad))
}

// gradient_direction computes direction vector from Gradient config
// Handles both explicit angle and direction keywords
fn gradient_direction(gradient &Gradient, width f32, height f32) (f32, f32) {
	// If explicit angle provided, use it
	if angle := gradient.angle {
		return angle_to_direction(angle)
	}

	// Convert direction keyword to angle
	css_angle := match gradient.direction {
		.to_top { f32(0.0) }
		.to_right { f32(90.0) }
		.to_bottom { f32(180.0) }
		.to_left { f32(270.0) }
		.to_top_right { 90.0 - f32(math.atan2(height, width)) * 180.0 / math.pi }
		.to_bottom_right { 90.0 + f32(math.atan2(height, width)) * 180.0 / math.pi }
		.to_bottom_left { 270.0 - f32(math.atan2(height, width)) * 180.0 / math.pi }
		.to_top_left { 270.0 + f32(math.atan2(height, width)) * 180.0 / math.pi }
	}
	return angle_to_direction(css_angle)
}

// pack_rgb packs Red, Green, Blue into a single f32 (up to 16.7M, safe for f32 mantissa).
fn pack_rgb(c Color) f32 {
	return f32(c.r) + f32(c.g) * 256.0 + f32(c.b) * 65536.0
}

// pack_alpha_pos packs Alpha (0..255) and Position (0.0..1.0) into a single f32.
// Position precision is 1/10000.
fn pack_alpha_pos(c Color, pos f32) f32 {
	return f32(c.a) + f32(math.floor(pos * 10000.0)) * 256.0
}

fn draw_gradient_rect(x f32, y f32, w f32, h f32, radius f32, gradient &Gradient, mut window Window) {
	if w <= 0 || h <= 0 || gradient.stops.len == 0 {
		return
	}

	scale := window.ui.scale
	sx := x * scale
	sy := y * scale
	sw := w * scale
	sh := h * scale
	mut r := radius * scale

	min_dim := if sw < sh { sw } else { sh }
	if r > min_dim / 2.0 {
		r = min_dim / 2.0
	}
	if r < 0 {
		r = 0
	}

	init_gradient_pipeline(mut window)

	// Pack gradient stops into tm matrix via sgl
	sgl.matrix_mode_texture()
	sgl.push_matrix()

	// Pack up to 5 stops into tm matrix (indices 10-11 reserved
	// for direction/radius metadata)
	mut tm_data := [16]f32{}
	stop_count := if gradient.stops.len > 5 {
		if !window.pip.gradient_stop_warned {
			window.pip.gradient_stop_warned = true
			eprintln('warning: gradient has ${gradient.stops.len} stops,' +
				' max 5 supported; extra stops ignored')
		}
		5
	} else {
		gradient.stops.len
	}
	for i in 0 .. stop_count {
		stop := gradient.stops[i]
		// Each stop takes 2 floats: [packed_rgb, packed_alpha_pos]
		midx := i * 2
		tm_data[midx] = pack_rgb(stop.color)
		tm_data[midx + 1] = pack_alpha_pos(stop.color, stop.pos)
	}

	// tm[3] (index 12..15) stores core metadata

	tm_data[12] = sw / 2.0 // hw

	tm_data[13] = sh / 2.0 // hh

	tm_data[14] = if gradient.type == .radial { f32(1.0) } else { f32(0.0) } // type

	tm_data[15] = f32(stop_count) // count

	// Additional metadata in unused stop slots (Stop 6 slots: 10, 11)

	if gradient.type == .radial {
		target_radius := math.sqrt((sw / 2.0) * (sw / 2.0) + (sh / 2.0) * (sh / 2.0))

		tm_data[11] = f32(target_radius)
	} else {
		dx, dy := gradient_direction(gradient, sw, sh)

		tm_data[10] = dx

		tm_data[11] = dy
	}

	// Load the gradient data matrix

	sgl.load_matrix(tm_data[0..])

	sgl.load_pipeline(window.pip.gradient)
	sgl.c4b(255, 255, 255, 255) // White base color (shader computes actual color)

	z_val := pack_shader_params(r, 0)

	draw_quad(sx, sy, sw, sh, z_val)

	sgl.load_default_pipeline()
	sgl.c4b(255, 255, 255, 255) // Reset color state
	sgl.pop_matrix()
	sgl.matrix_mode_modelview()
}

fn draw_quad_gradient(x f32, y f32, w f32, h f32, z f32, c1 Color, c2 Color, g_type GradientType) {
	sgl.begin_quads()

	// Top Left
	sgl.t2f(-1.0, -1.0)
	sgl.c4b(c1.r, c1.g, c1.b, c1.a)
	sgl.v3f(x, y, z)

	// Top Right
	sgl.t2f(1.0, -1.0)
	if g_type == .linear {
		sgl.c4b(c2.r, c2.g, c2.b, c2.a)
	} else {
		sgl.c4b(c1.r, c1.g, c1.b, c1.a)
	}
	sgl.v3f(x + w, y, z)

	// Bottom Right
	sgl.t2f(1.0, 1.0)
	sgl.c4b(c2.r, c2.g, c2.b, c2.a)
	sgl.v3f(x + w, y + h, z)

	// Bottom Left
	sgl.t2f(-1.0, 1.0)
	if g_type == .linear {
		sgl.c4b(c1.r, c1.g, c1.b, c1.a)
	} else {
		sgl.c4b(c2.r, c2.g, c2.b, c2.a)
	}
	sgl.v3f(x, y + h, z)

	sgl.end()
}

fn draw_gradient_border(x f32, y f32, w f32, h f32, radius f32, thickness f32, gradient &Gradient, mut window Window) {
	if w <= 0 || h <= 0 {
		return
	}

	// For now, simple implementation: mapping colors to corners for a stroke.
	// Since sgl doesn't have a simple "gradient stroke" primitive that respects rounded corners perfectly
	// without a custom shader that knows about stroke width AND gradient, we will use the existing
	// rounded rect pipeline but with a hack:
	// We use `draw_quad_gradient` logic but applied to the `rounded_rect` pipeline?
	// NO, `rounded_rect_pip` expects a single color in `color0` attribute for the whole quad usually?
	// Wait, `vs_glsl` takes `color0` attribute per vertex.
	// So we CAN pass different colors per vertex to `rounded_rect_pip`!

	scale := window.ui.scale
	sx := x * scale
	sy := y * scale
	sw := w * scale
	sh := h * scale
	mut r := radius * scale

	min_dim := if sw < sh { sw } else { sh }
	if r > min_dim / 2.0 {
		r = min_dim / 2.0
	}
	if r < 0 {
		r = 0
	}

	init_rounded_rect_pipeline(mut window)
	sgl.load_pipeline(window.pip.rounded_rect)

	// Determine colors based on gradient stops (simplification for 2 stops)
	c1 := if gradient.stops.len > 0 {
		gradient.stops[0].color.to_gx_color()
	} else {
		gg.Color{0, 0, 0, 255}
	}
	c2 := if gradient.stops.len > 1 { gradient.stops[1].color.to_gx_color() } else { c1 }

	// Pack params for STROKE (thickness > 0)
	z_val := pack_shader_params(r, thickness * scale)

	// Draw Quad with Per-Vertex Colors
	sgl.begin_quads()

	// Top Left
	sgl.t2f(-1.0, -1.0)
	sgl.c4b(c1.r, c1.g, c1.b, c1.a)
	sgl.v3f(sx, sy, z_val)

	// Top Right
	sgl.t2f(1.0, -1.0)
	if gradient.type == .linear {
		sgl.c4b(c2.r, c2.g, c2.b, c2.a)
	} else {
		sgl.c4b(c1.r, c1.g, c1.b, c1.a)
	}
	sgl.v3f(sx + sw, sy, z_val)

	// Bottom Right
	sgl.t2f(1.0, 1.0)
	sgl.c4b(c2.r, c2.g, c2.b, c2.a)
	sgl.v3f(sx + sw, sy + sh, z_val)

	// Bottom Left
	sgl.t2f(-1.0, 1.0)
	if gradient.type == .linear {
		sgl.c4b(c1.r, c1.g, c1.b, c1.a)
	} else {
		sgl.c4b(c2.r, c2.g, c2.b, c2.a)
	}
	sgl.v3f(sx, sy + sh, z_val)

	sgl.end()
	sgl.load_default_pipeline()
}

// render_svg renders an SVG shape
fn render_svg(mut shape Shape, clip DrawClip, mut window Window) {
	dr := gg.Rect{
		x:      shape.x
		y:      shape.y
		width:  shape.width
		height: shape.height
	}
	if !rects_overlap(dr, clip) {
		shape.disabled = true
		return
	}

	cached := window.load_svg(shape.resource, shape.width, shape.height) or {
		log.error('${@FILE_LINE} > ${err.msg()}')
		draw_error_placeholder(shape.x, shape.y, shape.width, shape.height, mut window)
		return
	}

	color := if shape.disabled { dim_alpha(shape.color) } else { shape.color }

	// Clip SVG content to shape bounds (viewBox overflow)
	window.renderers << DrawClip{
		x:      shape.x
		y:      shape.y
		width:  shape.width
		height: shape.height
	}

	for tpath in cached.triangles {
		// Use shape color if set (monochrome override), otherwise path color
		has_vcols := tpath.vertex_colors.len > 0
		c := if color.a > 0 && !has_vcols { color } else { tpath.color }
		mut gx_vcols := []gg.Color{}
		if has_vcols && color.a == 0 {
			gx_vcols = []gg.Color{cap: tpath.vertex_colors.len}
			for vc in tpath.vertex_colors {
				gx_vcols << vc.to_gx_color()
			}
		}
		window.renderers << DrawSvg{
			triangles:     tpath.triangles
			color:         c.to_gx_color()
			vertex_colors: gx_vcols
			x:             shape.x
			y:             shape.y
			scale:         cached.scale
			is_clip_mask:  tpath.is_clip_mask
			clip_group:    tpath.clip_group
		}
	}

	// Emit text elements
	for svg_txt in cached.texts {
		render_svg_text(svg_txt, shape.x, shape.y, cached.scale, cached.gradients, mut
			window)
	}
	// Emit textPath elements
	for tp in cached.text_paths {
		render_svg_text_path(tp, cached.defs_paths, shape.x, shape.y, cached.scale, cached.gradients, mut
			window)
	}

	// Emit filtered groups
	for i, fg in cached.filtered_groups {
		window.renderers << DrawFilterBegin{
			group_idx: i
			x:         shape.x
			y:         shape.y
			scale:     cached.scale
			cached:    cached
		}
		// Emit DrawSvg for filtered group triangles
		for tpath in fg.triangles {
			has_vcols := tpath.vertex_colors.len > 0
			c := if color.a > 0 && !has_vcols { color } else { tpath.color }
			mut gx_vcols := []gg.Color{}
			if has_vcols && color.a == 0 {
				gx_vcols = []gg.Color{cap: tpath.vertex_colors.len}
				for vc in tpath.vertex_colors {
					gx_vcols << vc.to_gx_color()
				}
			}
			window.renderers << DrawSvg{
				triangles:     tpath.triangles
				color:         c.to_gx_color()
				vertex_colors: gx_vcols
				x:             shape.x
				y:             shape.y
				scale:         cached.scale
				is_clip_mask:  tpath.is_clip_mask
				clip_group:    tpath.clip_group
			}
		}
		// Emit text elements for filtered group
		for svg_txt in fg.texts {
			render_svg_text(svg_txt, shape.x, shape.y, cached.scale, fg.gradients, mut
				window)
		}
		// Emit textPath elements for filtered group
		for tp in fg.text_paths {
			render_svg_text_path(tp, cached.defs_paths, shape.x, shape.y, cached.scale,
				fg.gradients, mut window)
		}
		window.renderers << DrawFilterEnd{}
	}

	// Restore parent clip
	window.renderers << clip
}

// render_svg_text converts an SvgText into a DrawText renderer.
fn render_svg_text(t SvgText, shape_x f32, shape_y f32, scale f32, gradients map[string]SvgGradientDef, mut window Window) {
	if t.text.len == 0 {
		return
	}
	typeface := match true {
		t.bold && t.italic { vglyph.Typeface.bold_italic }
		t.bold { vglyph.Typeface.bold }
		t.italic { vglyph.Typeface.italic }
		else { vglyph.Typeface.regular }
	}
	// Convert SVG gradient def to vglyph gradient config
	gradient := if t.fill_gradient_id.len > 0 {
		if gdef := gradients[t.fill_gradient_id] {
			mut stops := []vglyph.GradientStop{cap: gdef.stops.len}
			for s in gdef.stops {
				stops << vglyph.GradientStop{
					color:    s.color.to_gx_color()
					position: s.offset
				}
			}
			dx := gdef.x2 - gdef.x1
			dy := gdef.y2 - gdef.y1
			dir := if math.abs(dx) >= math.abs(dy) {
				vglyph.GradientDirection.horizontal
			} else {
				vglyph.GradientDirection.vertical
			}
			&vglyph.GradientConfig{
				stops:     stops
				direction: dir
			}
		} else {
			unsafe { &vglyph.GradientConfig(nil) }
		}
	} else {
		unsafe { &vglyph.GradientConfig(nil) }
	}
	text_style := TextStyle{
		family:         t.font_family
		size:           t.font_size * scale
		typeface:       typeface
		color:          if t.opacity < 1.0 {
			Color{t.color.r, t.color.g, t.color.b, u8(f32(t.color.a) * t.opacity)}
		} else {
			t.color
		}
		underline:      t.underline
		strikethrough:  t.strikethrough
		letter_spacing: t.letter_spacing * scale
		gradient:       gradient
		stroke_width:   t.stroke_width * scale
		stroke_color:   if t.opacity < 1.0 {
			Color{t.stroke_color.r, t.stroke_color.g, t.stroke_color.b, u8(f32(t.stroke_color.a) * t.opacity)}
		} else {
			t.stroke_color
		}
	}
	cfg := text_style.to_vglyph_cfg()

	// Measure for anchor adjustment
	tw := window.text_system.text_width(t.text, cfg) or { 0 }
	fh := window.text_system.font_height(cfg) or { t.font_size * scale }
	// Approximate baseline→top: ascent ≈ 80% of font height
	ascent := fh * 0.8

	mut x := shape_x + t.x * scale
	y := shape_y + t.y * scale - ascent

	// text-anchor adjustment
	if t.anchor == 1 {
		x -= tw / 2
	} else if t.anchor == 2 {
		x -= tw
	}

	window.renderers << DrawText{
		text: t.text
		cfg:  cfg
		x:    x
		y:    y
	}
}

// draw_triangles renders triangulated geometry using SGL
fn draw_triangles(triangles []f32, c gg.Color, x f32, y f32, tri_scale f32, mut window Window) {
	if triangles.len < 6 {
		return
	}

	scale := window.ui.scale

	sgl.load_pipeline(window.ui.pipeline.alpha)
	sgl.begin_triangles()
	sgl.c4b(c.r, c.g, c.b, c.a)

	mut i := 0
	for i < triangles.len - 5 {
		// Triangle vertices
		x0 := (x + triangles[i] * tri_scale) * scale
		y0 := (y + triangles[i + 1] * tri_scale) * scale
		x1 := (x + triangles[i + 2] * tri_scale) * scale
		y1 := (y + triangles[i + 3] * tri_scale) * scale
		x2 := (x + triangles[i + 4] * tri_scale) * scale
		y2 := (y + triangles[i + 5] * tri_scale) * scale

		sgl.v2f(x0, y0)
		sgl.v2f(x1, y1)
		sgl.v2f(x2, y2)

		i += 6
	}

	sgl.end()
}

// draw_triangles_gradient renders triangles with per-vertex colors.
fn draw_triangles_gradient(triangles []f32, vertex_colors []gg.Color, x f32, y f32, tri_scale f32, mut window Window) {
	if triangles.len < 6 || vertex_colors.len < 3 {
		return
	}

	scale := window.ui.scale

	sgl.load_pipeline(window.ui.pipeline.alpha)
	sgl.begin_triangles()

	mut vi := 0 // vertex index into vertex_colors
	mut i := 0
	for i < triangles.len - 5 {
		if vi + 2 < vertex_colors.len {
			c0 := vertex_colors[vi]
			c1 := vertex_colors[vi + 1]
			c2 := vertex_colors[vi + 2]

			x0 := (x + triangles[i] * tri_scale) * scale
			y0 := (y + triangles[i + 1] * tri_scale) * scale
			x1 := (x + triangles[i + 2] * tri_scale) * scale
			y1 := (y + triangles[i + 3] * tri_scale) * scale
			x2 := (x + triangles[i + 4] * tri_scale) * scale
			y2 := (y + triangles[i + 5] * tri_scale) * scale

			sgl.c4b(c0.r, c0.g, c0.b, c0.a)
			sgl.v2f(x0, y0)
			sgl.c4b(c1.r, c1.g, c1.b, c1.a)
			sgl.v2f(x1, y1)
			sgl.c4b(c2.r, c2.g, c2.b, c2.a)
			sgl.v2f(x2, y2)
		}

		i += 6
		vi += 3
	}

	sgl.end()
}

// draw_error_placeholder draws a magenta box with a white cross to indicate a missing resource.
fn draw_error_placeholder(x f32, y f32, w f32, h f32, mut window Window) {
	draw_rounded_rect_filled(x, y, w, h, 0, magenta.to_gx_color(), mut window)
	draw_rounded_rect_empty(x, y, w, h, 0, 1.0, white.to_gx_color(), mut window)
	// Draw a white cross
	window.ui.draw_line(x, y, x + w, y + h, white.to_gx_color())
	window.ui.draw_line(x + w, y, x, y + h, white.to_gx_color())
}
