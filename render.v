module gui

import gg
import sokol.sgl

// A Renderer is the final computed drawing instruction. gui.Window keeps an array
// of Renderers and only uses that array to paint the window. The window can be
// repainted many times before the a new view state is generated. Drawing, as
// implemented in V's gg.Context, happens in a separate thread. By only using the
// final draw instructions (i.e. Renderers), along with the appropriate mutexes,
// Gui isolates view generation and layout calculations from the UI thread. This
// eliminates the need to, "dispatch to the UI thread", that many other UI
// frameworks require.

struct DrawCircle {
	x      f32
	y      f32
	radius f32
	fill   bool
	color  gg.Color
}

struct DrawImage {
	x   f32
	y   f32
	w   f32
	h   f32
	img &gg.Image
}

struct DrawLine {
	x   f32
	y   f32
	x1  f32
	y1  f32
	cfg gg.PenConfig
}

struct DrawNone {}

struct DrawText {
	x    f32
	y    f32
	text string
	cfg  gg.TextCfg
}

type DrawClip = gg.Rect
type DrawRect = gg.DrawRectParams
type Renderer = DrawCircle | DrawClip | DrawImage | DrawLine | DrawNone | DrawRect | DrawText

// renderers_draw walks the array of renderers and draws them.
// This function and renderer_draw constitute then entire
// draw logic of GUI
fn renderers_draw(renderers []Renderer, window &Window) {
	for renderer in renderers {
		renderer_draw(renderer, window)
	}
}

// renderer_draw draws a single renderer
fn renderer_draw(renderer Renderer, window &Window) {
	ctx := window.ui
	match renderer {
		DrawRect {
			if renderer.style == .fill {
				draw_rounded_rect_filled(renderer.x, renderer.y, renderer.w, renderer.h,
					renderer.radius, renderer.color, ctx)
			} else {
				draw_rounded_rect_empty(renderer.x, renderer.y, renderer.w, renderer.h,
					renderer.radius, renderer.color, ctx)
			}
		}
		DrawText {
			ctx.draw_text(int(renderer.x), int(renderer.y), renderer.text, renderer.cfg)
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
fn render_layout(mut layout Layout, mut renderers []Renderer, bg_color Color, clip DrawClip, window &Window) {
	render_shape(mut layout.shape, mut renderers, bg_color, clip, window)

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
		renderers << shape_clip
	} else if layout.shape.clip {
		sc := layout.shape.shape_clip
		padding := layout.shape.padding
		shape_clip = DrawClip{
			x:      sc.x + padding.left
			y:      sc.y + padding.top
			width:  sc.width - padding.width()
			height: sc.height - padding.height()
		}
		renderers << shape_clip
	}

	color := if layout.shape.color != color_transparent { layout.shape.color } else { bg_color }
	for mut child in layout.children {
		render_layout(mut child, mut renderers, color, shape_clip, window)
	}

	if layout.shape.clip || layout.shape.over_draw {
		renderers << clip
	}
}

// render_shape examines the Shape.type and calls the appropriate renderer.
fn render_shape(mut shape Shape, mut renderers []Renderer, parent_color Color, clip DrawClip, window &Window) {
	if shape.color == color_transparent {
		return
	}
	match shape.type {
		.rectangle { render_container(mut shape, mut renderers, parent_color, clip, window) }
		.text { render_text(mut shape, mut renderers, clip, window) }
		.image { render_image(mut shape, mut renderers, clip, window) }
		.circle { render_circle(mut shape, mut renderers, clip, window) }
		.rtf { render_rtf(mut shape, mut renderers, clip, window) }
		.none {}
	}
}

// render_container mostly draws a rectangle. Containers are more about layout than drawing.
// One complication is the title text that is drawn in the upper left corner of the rectangle.
// At some point, it should be moved to the container logic, along with some layout amend logic.
// Honestly, it was more expedient to put it here.
fn render_container(mut shape Shape, mut renderers []Renderer, parent_color Color, clip DrawClip, window &Window) {
	ctx := window.ui
	// Here is where the mighty container is drawn. Yeah, it really is just a rectangle.
	render_rectangle(mut shape, mut renderers, clip, window)

	// The group box title complicated things. Maybe move it?
	if shape.text.len != 0 {
		draw_rect := gg.Rect{
			x:      shape.x
			y:      shape.y
			width:  shape.width
			height: shape.height
		}
		if rects_overlap(draw_rect, clip) {
			ctx.set_text_cfg(shape.text_style.to_text_cfg())
			w, h := ctx.text_size(shape.text)
			x := shape.x + 20
			y := shape.y
			// erase portion of rectangle where text goes.
			p_color := if shape.disabled {
				dim_alpha(parent_color)
			} else {
				parent_color
			}
			renderers << DrawRect{
				x:     x
				y:     y - 2 - h / 2
				w:     w
				h:     h + 1
				style: .fill
				color: p_color.to_gx_color()
			}
			color := if shape.disabled {
				dim_alpha(shape.text_style.color)
			} else {
				shape.text_style.color
			}
			// The height of a lowercase char usually splits
			// the text just right.
			eh := ctx.text_height('e')
			renderers << DrawText{
				x:    x
				y:    y - eh
				text: shape.text
				cfg:  TextStyle{
					...shape.text_style
					color: color
				}.to_text_cfg()
			}
		}
	}
}

// render_circle draws a shape as a circle in the middle of the shape's
// rectangular region. Radius is half of the shortest side.
fn render_circle(mut shape Shape, mut renderers []Renderer, clip DrawClip, window &Window) {
	assert shape.type == .circle
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
		renderers << DrawCircle{
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
fn render_rectangle(mut shape Shape, mut renderers []Renderer, clip DrawClip, window &Window) {
	assert shape.type == .rectangle
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
			renderers << DrawRect{
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

// render_text renders text including multiline text.
// If cursor coordinates are present, it draws the input cursor.
// The highlighting of selected text happens here also.
fn render_text(mut shape Shape, mut renderers []Renderer, clip DrawClip, window &Window) {
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
	color := if shape.disabled { dim_alpha(shape.text_style.color) } else { shape.text_style.color }
	text_cfg := TextStyle{
		...shape.text_style
		color: color
	}.to_text_cfg()

	ctx.set_text_cfg(text_cfg)
	lh := line_height(shape)

	mut char_count := 0
	x := shape.x
	mut y := shape.y
	beg := int(shape.text_sel_beg)
	end := int(shape.text_sel_end)

	for line in shape.text_lines {
		// line.runes is expensive. Don't call it unless needed
		lnr := if beg != end { line.runes() } else { [] }
		len := lnr.len
		draw_rect := gg.Rect{
			x:      x
			y:      y
			width:  shape.width
			height: lh
		}
		// Cull any renderers outside of clip/context region.
		if rects_overlap(clip, draw_rect) && color != color_transparent {
			mut lnl := line.replace('\n', '')
			if shape.text_is_password && !shape.text_is_placeholder {
				// replace with '*'s
				lnl = '*'.repeat(utf8_str_visible_length(lnl))
			}
			renderers << DrawText{
				x:    x
				y:    y
				text: lnl.clone()
				cfg:  text_cfg
			}

			// Draw text selection
			if beg < char_count + len && end > beg {
				b := if beg >= char_count && beg < char_count + len { beg - char_count } else { 0 }
				e := if end > char_count + len { len } else { end - char_count }
				if b < e {
					stob := lnr[..b].string()
					sbtoe := lnr[b..e].string()
					sb := ctx.text_width(stob)
					se := ctx.text_width(sbtoe)
					renderers << DrawRect{
						x:     draw_rect.x + sb
						y:     draw_rect.y
						w:     se
						h:     draw_rect.height
						color: gg.Color{
							...text_cfg.color
							a: 60 // make themeable?
						}
					}
					unsafe { sbtoe.free() }
					unsafe { stob.free() }
				}
			}
			unsafe { lnl.free() }
		}
		y += lh
		char_count += len
		unsafe { lnr.free() }
	}

	render_cursor(shape, mut renderers, clip, window)
}

// render_cursor figures out where the darn cursor goes.
fn render_cursor(shape &Shape, mut renderers []Renderer, clip DrawClip, window &Window) {
	if window.is_focus(shape.id_focus) && shape.type == .text && window.view_state.cursor_on {
		lh := line_height(shape)
		mut cursor_x := -1
		mut cursor_y := -1
		input_state := window.view_state.input_state[shape.id_focus]
		mut cursor_pos := input_state.cursor_pos
		if cursor_pos >= 0 {
			mut length := 0
			for idx, line in shape.text_lines {
				ln_len := utf8_str_visible_length(line)
				if length + ln_len > cursor_pos {
					cursor_x = cursor_pos - length
					cursor_y = idx
					break
				}
				length += ln_len
			}
			// edge condition. Algorithm misses the
			// last character of the last line.
			if cursor_x == -1 {
				cursor_x = shape.text_lines.last().len
				cursor_y = shape.text_lines.len - 1
			}
		}
		if cursor_x >= 0 && cursor_y >= 0 {
			ctx := window.ui
			if cursor_y < shape.text_lines.len {
				ln := shape.text_lines[cursor_y]
				x := int_min(cursor_x, ln.len)
				cx := shape.x + ctx.text_width(ln[..x])
				cy := shape.y + (lh * cursor_y)
				dr := gg.Rect{
					x:      cx
					y:      cy
					width:  cx
					height: cy + lh
				}
				if rects_overlap(dr, clip) {
					renderers << DrawLine{
						x:   cx
						y:   cy
						x1:  cx
						y1:  cy + lh
						cfg: gg.PenConfig{
							color: shape.text_style.color.to_gx_color()
						}
					}
				}
			}
		}
	}
}

fn render_rtf(mut shape Shape, mut renderers []Renderer, clip DrawClip, window &Window) {
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
			text_cfg := span.style.to_text_cfg()
			ctx.set_text_cfg(text_cfg)

			renderers << DrawText{
				x:    shape.x + span.x
				y:    shape.y + span.y
				text: span.text
				cfg:  text_cfg
			}

			if span.underline {
				renderers << DrawRect{
					x:     shape.x + span.x
					y:     shape.y + span.y + span.h - 2
					w:     span.w
					h:     1
					color: span.style.color.to_gx_color()
				}
			}

			if span.strike_through {
				renderers << DrawRect{
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

fn render_image(mut shape Shape, mut renderers []Renderer, clip DrawClip, window &Window) {
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
	mut ctx := window.context()
	image := ctx.get_cached_image_by_idx(window.view_state.image_map[shape.image_name])
	renderers << DrawImage{
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
	// vfmt off
	return r1.x < (r2.x + r2.width)
            && r2.x < (r1.x + r1.width)
            && r1.y < (r2.y + r2.height)
            && r2.y < (r1.y + r1.height)
	// vfmt on
}
