module gui

import gg
import sokol.sgl
import log
import vglyph

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
	x        f32
	y        f32
	w        f32
	h        f32
	radius   f32
	gradient &Gradient
}

struct DrawGradient {
	x        f32
	y        f32
	w        f32
	h        f32
	radius   f32
	gradient &Gradient
}

struct DrawLayout {
	layout &vglyph.Layout
	x      f32
	y      f32
}

type DrawClip = gg.Rect
type DrawRect = gg.DrawRectParams
type Renderer = DrawCircle
	| DrawClip
	| DrawImage
	| DrawLayout
	| DrawLine
	| DrawNone
	| DrawRect
	| DrawStrokeRect
	| DrawText
	| DrawShadow
	| DrawBlur
	| DrawGradient
	| DrawGradientBorder

// renderers_draw walks the array of renderers and drawings them.
// This function and renderer_draw constitute then entire
// draw logic of GUI
fn renderers_draw(renderers []Renderer, mut window Window) {
	for renderer in renderers {
		renderer_draw(renderer, mut window)
	}
	window.text_system.commit()
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
				// Continue without crashing - text simply won't appear
			}
		}
		DrawLayout {
			window.text_system.draw_layout(renderer.layout, renderer.x, renderer.y)
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
				renderer.gradient, mut window)
		}
		DrawNone {}
	}
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
		if layout.shape.name == scrollbar_vertical_name {
			shape_clip = DrawClip{
				...shape_clip
				y:      clip.y
				height: clip.height
			}
		}
		if layout.shape.name == scrollbar_horizontal_name {
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
	// Apply opacity to colors
	if shape.opacity < 1.0 {
		shape.color = shape.color.with_opacity(shape.opacity)
		shape.color_border = shape.color_border.with_opacity(shape.opacity)
		shape.text_style = TextStyle{
			...shape.text_style
			color: shape.text_style.color.with_opacity(shape.opacity)
		}
	}

	has_visible_border := shape.size_border > 0 && shape.color_border != color_transparent
	has_visible_text := shape.shape_type == .text && shape.text_style.color != color_transparent
	if shape.color == color_transparent && shape.gradient == unsafe { nil }
		&& shape.border_gradient == unsafe { nil } && !has_visible_border && !has_visible_text {
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
		.none {}
	}
}

// render_container mostly draws a rectangle. Containers are more about layout than drawing.
// One complication is the title text that is drawn in the upper left corner of the rectangle.
// At some point, it should be moved to the container logic, along with some layout amend logic.
// Honestly, it was more expedient to put it here.
fn render_container(mut shape Shape, parent_color Color, clip DrawClip, mut window Window) {
	if shape.shadow != unsafe { nil } && shape.shadow.color.a > 0 && shape.shadow.blur_radius > 0 {
		window.renderers << DrawShadow{
			x:           shape.x + shape.shadow.offset_x
			y:           shape.y + shape.shadow.offset_y
			width:       shape.width
			height:      shape.height
			radius:      shape.radius
			blur_radius: shape.shadow.blur_radius
			color:       shape.shadow.color.to_gx_color()
			offset_x:    shape.shadow.offset_x
			offset_y:    shape.shadow.offset_y
		}
	}
	// Here is where the mighty container is drawn. Yeah, it really is just a rectangle.
	if shape.gradient != unsafe { nil } {
		window.renderers << DrawGradient{
			x:        shape.x
			y:        shape.y
			w:        shape.width
			h:        shape.height
			radius:   shape.radius
			gradient: shape.gradient
		}
	} else if shape.blur_radius > 0 && shape.color.a > 0 {
		window.renderers << DrawBlur{
			x:           shape.x
			y:           shape.y
			width:       shape.width
			height:      shape.height
			radius:      shape.radius
			blur_radius: shape.blur_radius
			color:       shape.color.to_gx_color()
		}
	} else {
		// Check for Border Gradient
		if shape.border_gradient != unsafe { nil } {
			window.renderers << DrawGradientBorder{
				x:        shape.x
				y:        shape.y
				w:        shape.width
				h:        shape.height
				radius:   shape.radius
				gradient: shape.border_gradient
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

// render_rectangle draw_rectangle draws a shape as a rectangle.
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
	color := if shape.disabled { dim_alpha(shape.text_style.color) } else { shape.text_style.color }
	text_cfg := TextStyle{
		...shape.text_style
		color: color
	}.to_vglyph_cfg()

	lh := line_height(shape, mut window)
	beg := int(shape.text_sel_beg)
	end := int(shape.text_sel_end)

	// Convert selection range to byte indices because vglyph uses bytes
	byte_beg := rune_to_byte_index(shape.text, beg)
	byte_end := rune_to_byte_index(shape.text, end)

	if shape.has_text_layout() {
		for line in shape.vglyph_layout.lines {
			draw_x := shape.x + shape.padding_left() + line.rect.x
			draw_y := shape.y + shape.padding_top() + line.rect.y

			// Extract text for this line
			if line.start_index >= shape.text.len {
				continue
			}
			mut line_end := line.start_index + line.length
			if line_end > shape.text.len {
				line_end = shape.text.len
			}

			// Drawing
			draw_rect := gg.Rect{
				x:      draw_x
				y:      draw_y
				width:  shape.width // approximate, or use line.rect.width
				height: lh
			}

			// Cull
			if rects_overlap(clip, draw_rect) && color != color_transparent {
				// Remove newlines for rendering (draw_text usually handles one line)
				// Optimization: Slice instead of replace/alloc if possible
				mut slice_end := line_end
				if slice_end > line.start_index && shape.text[slice_end - 1] == `\n` {
					slice_end--
				}
				mut render_str := shape.text[line.start_index..slice_end]

				if shape.text_is_password && !shape.text_is_placeholder {
					render_str = password_char.repeat(utf8_str_visible_length(render_str))
				}

				window.renderers << DrawText{
					x:    draw_x
					y:    draw_y
					text: render_str
					cfg:  text_cfg
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
		if shape.text_is_password {
			// Password fields still need measurement because the rendered text (*)
			// is different from the logical text.
			pre_text := shape.text[line.start_index..i_start]
			sel_text := shape.text[i_start..i_end]

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
			r_start := shape.vglyph_layout.get_char_rect(i_start) or { gg.Rect{} }

			// Get rect for end char (or end of line)
			x_end := if i_end < (line.start_index + line.length) && shape.text[i_end] != `\n` {
				r_end := shape.vglyph_layout.get_char_rect(i_end) or {
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
		input_state := window.view_state.input_state[shape.id_focus]
		cursor_pos := input_state.cursor_pos

		if cursor_pos >= 0 {
			byte_idx := rune_to_byte_index(shape.text, cursor_pos)

			// Use vglyph to get the rect
			rect := if shape.has_text_layout() {
				shape.vglyph_layout.get_char_rect(byte_idx) or {
					// If not found, check if it's at the very end
					if byte_idx >= shape.text.len && shape.vglyph_layout.lines.len > 0 {
						last_line := shape.vglyph_layout.lines.last()
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
				color: shape.text_style.color.to_gx_color()
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
	image := window.load_image(shape.image_name) or {
		log.error('${@FILE_LINE} > ${err.msg()}')
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
			window.renderers << DrawLayout{
				layout: shape.vglyph_layout
				x:      shape.x
				y:      shape.y
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

	sgl.load_pipeline(window.blur_pip)
	sgl.c4b(c.r, c.g, c.b, c.a)

	z_val := pack_shader_params(r, b)

	draw_quad(sx, sy, sw, sh, z_val)
	sgl.load_default_pipeline()

	sgl.pop_matrix()
	sgl.matrix_mode_modelview()
}

fn draw_gradient_rect(x f32, y f32, w f32, h f32, radius f32, gradient &Gradient, mut window Window) {
	if w <= 0 || h <= 0 {
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

	// Use the rounded rect pipeline for clipping/shape
	init_rounded_rect_pipeline(mut window)
	sgl.load_pipeline(window.rounded_rect_pip)

	// We need to calculate colors for vertices based on the gradient.
	// For a simple linear gradient implementation using vertex colors:
	// This only supports 2 stops accurately for a quad.
	// For comprehensive support, we'd need a fragment shader or texture.
	// HACK: For now, interpolate start and end colors for the 4 corners.

	mut c_start := gradient.stops[0].color
	mut c_end := gradient.stops.last().color

	// If using sgl pipeline, the fragment shader uses the color passed in `sgl.c4b`.
	// The current shader multiplies texture color (if any) or uses flat color.
	// The vertex color attribute is `color0`.
	// If I set `sgl.c4b` per vertex, it *should* interpolate.

	z_val := pack_shader_params(r, 0)

	draw_quad_gradient(sx, sy, sw, sh, z_val, c_start, c_end, gradient.type)

	sgl.load_default_pipeline()
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

fn draw_gradient_border(x f32, y f32, w f32, h f32, radius f32, gradient &Gradient, mut window Window) {
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
	sgl.load_pipeline(window.rounded_rect_pip)

	// Determine colors based on gradient stops (simplification for 2 stops)
	c1 := if gradient.stops.len > 0 {
		gradient.stops[0].color.to_gx_color()
	} else {
		gg.Color{0, 0, 0, 255}
	}
	c2 := if gradient.stops.len > 1 { gradient.stops[1].color.to_gx_color() } else { c1 }

	// Pack params for STROKE (thickness > 0)

	// Pack params for STROKE (thickness > 0)
	// Pack params for STROKE (thickness > 0)
	thickness := 10.0 * scale // DEBUG: Thick border
	z_val := pack_shader_params(r, thickness)

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
