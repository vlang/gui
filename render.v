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

type DrawClip = gg.Rect
type DrawRect = gg.DrawRectParams
type Renderer = DrawCircle | DrawClip | DrawImage | DrawLine | DrawNone | DrawRect | DrawText

// renderers_draw walks the array of renderers and draws them.
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
					renderer.radius, renderer.color, ctx)
			} else {
				draw_rounded_rect_empty(renderer.x, renderer.y, renderer.w, renderer.h,
					renderer.radius, renderer.color, ctx)
			}
		}
		DrawText {
			window.text_system.draw_text(renderer.x, renderer.y, renderer.text, renderer.cfg) or {
				log.error(err.msg())
			}
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
		padding := layout.shape.padding
		shape_clip = DrawClip{
			x:      sc.x + padding.left
			y:      sc.y + padding.top
			width:  sc.width - padding.width()
			height: sc.height - padding.height()
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
	if shape.color == color_transparent {
		return
	}
	match shape.shape_type {
		.rectangle { render_container(mut shape, parent_color, clip, mut window) }
		.text { render_text(mut shape, clip, mut window) }
		.image { render_image(mut shape, clip, mut window) }
		.circle { render_circle(mut shape, clip, mut window) }
		.rtf { render_rtf(mut shape, clip, mut window) }
		.none {}
	}
}

// render_container mostly draws a rectangle. Containers are more about layout than drawing.
// One complication is the title text that is drawn in the upper left corner of the rectangle.
// At some point, it should be moved to the container logic, along with some layout amend logic.
// Honestly, it was more expedient to put it here.
fn render_container(mut shape Shape, parent_color Color, clip DrawClip, mut window Window) {
	// Here is where the mighty container is drawn. Yeah, it really is just a rectangle.
	render_rectangle(mut shape, clip, mut window)
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
	if rects_overlap(draw_rect, clip) && color != color_transparent {
		radius := f32_min(shape.width, shape.height) / 2
		x := shape.x + shape.width / 2
		y := shape.y + shape.height / 2
		window.renderers << DrawCircle{
			x:      x
			y:      y
			radius: radius
			fill:   shape.fill
			color:  gx_color
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
	if rects_overlap(draw_rect, clip) && color != color_transparent {
		if color != color_transparent {
			window.renderers << DrawRect{
				x:          draw_rect.x
				y:          draw_rect.y
				w:          draw_rect.width
				h:          draw_rect.height
				color:      gx_color
				style:      if shape.fill { .fill } else { .stroke }
				is_rounded: shape.radius > 0
				radius:     shape.radius
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
		for line in shape.text_layout.lines {
			draw_x := shape.x + shape.padding.left + line.rect.x
			draw_y := shape.y + shape.padding.top + line.rect.y

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
				// Check overlap with byte range
				l_start := line.start_index
				l_end := line_end

				if byte_beg < l_end && byte_end > l_start {
					// Intersection
					i_start := int_max(byte_beg, l_start)
					i_end := int_min(byte_end, l_end)

					if i_start < i_end {
						if shape.text_is_password {
							// Password fields still need measurement because the rendered text (*)
							// is different from the logical text.
							pre_text := shape.text[l_start..i_start]
							sel_text := shape.text[i_start..i_end]

							pw_pre := password_char.repeat(utf8_str_visible_length(pre_text))
							start_x_offset := window.text_system.text_width(pw_pre, text_cfg) or {
								0
							}

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
							r_start := shape.text_layout.get_char_rect(i_start) or { gg.Rect{} }

							// Get rect for end char (or end of line)
							x_end := if i_end < l_end && shape.text[i_end] != `\n` {
								r_end := shape.text_layout.get_char_rect(i_end) or {
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
			}
		}
	}

	render_cursor(shape, clip, mut window)
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
				shape.text_layout.get_char_rect(byte_idx) or {
					// If not found, check if it's at the very end
					if byte_idx >= shape.text.len && shape.text_layout.lines.len > 0 {
						last_line := shape.text_layout.lines.last()
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

			cx := shape.x + shape.padding.left + rect.x
			cy := shape.y + shape.padding.top + rect.y
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

fn render_rtf(mut shape Shape, clip DrawClip, mut window Window) {
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
	ctx := window.ui

	for span in shape.text_spans {
		span_rect := gg.Rect{
			x:      shape.x + span.x
			y:      shape.y + span.y
			width:  span.w
			height: span.h
		}
		if rects_overlap(span_rect, clip) {
			text_cfg := span.style.to_vglyph_cfg()
			ctx.set_text_cfg(span.style.to_text_cfg())

			window.renderers << DrawText{
				x:    shape.x + span.x
				y:    shape.y + span.y
				text: span.text
				cfg:  text_cfg
			}

			if span.underline {
				window.renderers << DrawRect{
					x:     shape.x + span.x
					y:     shape.y + span.y + span.h - 2
					w:     span.w
					h:     1
					color: span.style.color.to_gx_color()
				}
			}

			if span.strike_through {
				window.renderers << DrawRect{
					x:     shape.x + span.x
					y:     shape.y + span.y + span.h / 2
					w:     span.w
					h:     1
					color: span.style.color.to_gx_color()
				}
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
