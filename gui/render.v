module gui

import gg
import gx
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
	color  gx.Color
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
	cfg  gx.TextCfg
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
		DrawCircle {
			if renderer.fill {
				ctx.draw_circle_filled(renderer.x, renderer.y, renderer.radius, renderer.color)
			} else {
				ctx.draw_circle_empty(renderer.x, renderer.y, renderer.radius, renderer.color)
			}
		}
		DrawRect {
			ctx.draw_rect(renderer)
		}
		DrawText {
			ctx.draw_text(int(renderer.x), int(renderer.y), renderer.text, renderer.cfg)
		}
		DrawImage {
			ctx.draw_image(renderer.x, renderer.y, renderer.w, renderer.h, renderer.img)
		}
		DrawLine {
			ctx.draw_line_with_config(renderer.x, renderer.y, renderer.x1, renderer.y1,
				renderer.cfg)
		}
		DrawClip {
			sgl.scissor_rectf(ctx.scale * renderer.x, ctx.scale * renderer.y, ctx.scale * renderer.width,
				ctx.scale * renderer.height, true)
		}
		DrawNone {}
	}
}

// render_layout walks the layout and generates renderers. If a shape is clipped,
// then a clip rectangle is added to the context. Clip rectangles are added to the
// draw context and the later, 'removed' by setting the clip rectangle to the
// previous rectangle of if not present, infinity.
fn render_layout(layout &Layout, mut renderers []Renderer, bg_color Color, clip ?Renderer, window &Window) {
	render_shape(layout.shape, mut renderers, bg_color, window)

	mut shape_clip := clip
	if layout.shape.clip {
		shape_clip = render_clip_rect(shape_clip_rect(layout.shape))
		renderers << shape_clip or { DrawNone{} }
	}

	color := if layout.shape.color != color_transparent { layout.shape.color } else { bg_color }
	for child in layout.children {
		render_layout(child, mut renderers, color, shape_clip, window)
	}

	if layout.shape.clip {
		renderers << clip or { render_clip_rect(clip_reset) }
	}
}

// render_shape examines the Shape.type and calls the appropriate renderer.
fn render_shape(shape &Shape, mut renderers []Renderer, parent_color Color, window &Window) {
	if shape.color == color_transparent {
		return
	}
	match shape.type {
		.rectangle { render_container(shape, mut renderers, parent_color, window) }
		.text { render_text(shape, mut renderers, window) }
		.image { render_image(shape, mut renderers, window) }
		.circle { render_circle(shape, mut renderers, window) }
		.none {}
	}
}

// render_container mostly draws a rectangle. Containers are more about layout than drawing.
// One complication is the title text that is drawn in the upper left corner of the rectangle.
// At some point, it should be moved to the container logic, along with some layout amend logic.
// Honestly, it was more epedient to put it here.
fn render_container(shape &Shape, mut renderers []Renderer, parent_color Color, window &Window) {
	ctx := window.ui
	// Here is where the mighty container is drawn. Yeah, it really is just a rectangle.
	render_rectangle(shape, mut renderers, window)

	// The group box title complicated things. Maybe move it?
	if shape.text.len != 0 {
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

// render_circle draws a shape as a circle in the middle of the shape's
// rectangular region. Radius is half of the shortest side.
fn render_circle(shape &Shape, mut renderers []Renderer, window &Window) {
	assert shape.type == .circle
	renderer_rect := make_renderer_rect(shape, window)
	draw_rect := gg.Rect{
		x:      shape.x
		y:      shape.y
		width:  shape.width
		height: shape.height
	}
	color := if shape.disabled { dim_alpha(shape.color) } else { shape.color }
	gx_color := color.to_gx_color()
	if rects_overlap(draw_rect, renderer_rect) {
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
	}
}

// draw_rectangle draws a shape as a rectangle.
fn render_rectangle(shape &Shape, mut renderers []Renderer, window &Window) {
	assert shape.type == .rectangle
	renderer_rect := make_renderer_rect(shape, window)
	draw_rect := gg.Rect{
		x:      shape.x
		y:      shape.y
		width:  shape.width
		height: shape.height
	}
	color := if shape.disabled { dim_alpha(shape.color) } else { shape.color }
	gx_color := color.to_gx_color()
	if rects_overlap(draw_rect, renderer_rect) {
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
}

// render_text renders text including multiline text.
// If cursor coordinates are present, it draws the input cursor.
// The highlighting of selected text happens here also.
fn render_text(shape &Shape, mut renderers []Renderer, window &Window) {
	ctx := window.ui
	color := if shape.disabled { dim_alpha(shape.text_style.color) } else { shape.text_style.color }
	text_cfg := TextStyle{
		...shape.text_style
		color: color
	}.to_text_cfg()

	ctx.set_text_cfg(text_cfg)
	lh := line_height(shape)
	renderer_rect := make_renderer_rect(shape, window)

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
		// Cull any renderers outside of clip/conteext region.
		if rects_overlap(renderer_rect, draw_rect) {
			mut lnl := line.replace('\n', '')
			if shape.text_is_password {
				// replace with '*'s
				lnl = []u8{len: lnl.runes().len, init: u8(42)}.bytestr()
			}
			renderers << DrawText{
				x:    x
				y:    y
				text: lnl
				cfg:  text_cfg
			}

			// Draw text selection
			if beg < char_count + len && end > beg {
				b := if beg >= char_count && beg < char_count + len { beg - char_count } else { 0 }
				e := if end > char_count + len { len } else { end - char_count }
				if b < e {
					sb := ctx.text_width(lnr[..b].string())
					se := ctx.text_width(lnr[b..e].string())
					renderers << DrawRect{
						x:     draw_rect.x + sb
						y:     draw_rect.y
						w:     se
						h:     draw_rect.height
						color: gx.Color{
							...text_cfg.color
							a: 60 // make themeable?
						}
					}
				}
			}
		}
		y += lh
		char_count += len
	}

	render_cursor(shape, mut renderers, window)
}

// render_cursor figures out where the darn cursor goes.
fn render_cursor(shape &Shape, mut renderers []Renderer, window &Window) {
	if window.is_focus(shape.id_focus) && shape.type == .text {
		lh := line_height(shape)
		mut cursor_x := -1
		mut cursor_y := -1
		input_state := window.view_state.input_state[shape.id_focus]
		mut cursor_pos := input_state.cursor_pos
		if cursor_pos >= 0 {
			mut length := 0
			for idx, line in shape.text_lines {
				ln := line.runes()
				if length + ln.len > cursor_pos {
					cursor_x = cursor_pos - length
					cursor_y = idx
					break
				}
				length += ln.len
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

fn render_image(shape &Shape, mut renderers []Renderer, window &Window) {
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

// make_renderer_rect creates a rectangle that represents the renderable region.
// If the shape is clipped, then use the shape dimensions otherwise use
// the window size.
fn make_renderer_rect(shape &Shape, window &Window) gg.Rect {
	return match shape.clip {
		true {
			shape_clip_rect(shape)
		}
		else {
			width, height := window.window_size()
			gg.Rect{
				width:  width
				height: height
			}
		}
	}
}

// shape_clip_rect constructs a clipping rectangle based on the shape's
// dimensions minus its padding
fn shape_clip_rect(shape &Shape) gg.Rect {
	return gg.Rect{
		x:      shape.x + shape.padding.left
		y:      shape.y + shape.padding.top
		width:  shape.width - shape.padding.width()
		height: shape.height - shape.padding.height()
	}
}

// render_clip_rect creates a DrawClip renderer
fn render_clip_rect(clip_rect gg.Rect) Renderer {
	return DrawClip{
		x:      clip_rect.x
		y:      clip_rect.y
		width:  clip_rect.width
		height: clip_rect.height
	}
}

const clip_reset = gg.Rect{
	x:      0
	y:      0
	width:  max_int
	height: max_int
}

// rects_overlap checks if two rectangels overlap.
@[inline]
fn rects_overlap(r1 gg.Rect, r2 gg.Rect) bool {
	// vfmt off
	return r1.x < (r2.x + r2.width)
            && r2.x < (r1.x + r1.width)
            && r1.y < (r2.y + r2.height)
            && r2.y < (r1.y + r1.height)
	// vfmt on
}
