module gui

import datatypes
import gg
import gx
import sokol.sgl

// A Renderer is the final computed drawing command. The window keeps an array
// of Renderer and only uses this array to paint the window. The window can be
// rapainted many times before the view state changes. Storing the final draw
// commands vs. calling render_shape() is faster because there is no computation
// to build the draw command.

struct DrawTextCfg {
	x    f32
	y    f32
	text string
	cfg  gx.TextCfg
}

struct DrawLineCfg {
	x   f32
	y   f32
	x1  f32
	y1  f32
	cfg gg.PenConfig
}

struct DrawNoneCfg {}

type DrawRect = gg.DrawRectParams
type DrawText = DrawTextCfg
type DrawLine = DrawLineCfg
type DrawClip = gg.Rect
type DrawNone = DrawNoneCfg
type Renderer = DrawRect | DrawText | DrawClip | DrawLine | DrawNone

type ClipStack = datatypes.Stack[DrawClip]

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
			ctx.draw_rect(renderer)
		}
		DrawText {
			ctx.draw_text(int(renderer.x), int(renderer.y), renderer.text, renderer.cfg)
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
// then a clip rectangle is added to the context. Clip rectangles are
// pushed/poped onto an internal stack allowing nested, none overlapping
// clip rectangles (I think I said that right)
fn render_layout(layout &Layout, mut renderers []Renderer, bg_color Color, window &Window) {
	mut clip_stack := ClipStack{}

	parent_color := if layout.shape.color != color_transparent {
		layout.shape.color
	} else {
		bg_color
	}

	render_shape(layout.shape, mut renderers, bg_color, window)

	if layout.shape.clip {
		renderers << render_clip(layout.shape, mut clip_stack)
	}

	for child in layout.children {
		render_layout(child, mut renderers, parent_color, window)
	}

	if layout.shape.clip {
		renderers << render_unclip(mut clip_stack)
	}
}

// render_shape examines the Shape.type and calls the appropriate renderer.
fn render_shape(shape &Shape, mut renderers []Renderer, parent_color Color, window &Window) {
	if shape.color == color_transparent {
		return
	}
	match shape.type {
		.container {
			render_container(shape, mut renderers, parent_color, window)
		}
		.text {
			render_text(shape, mut renderers, window)
		}
		.none {}
	}
}

fn render_container(shape &Shape, mut renderers []Renderer, parent_color Color, window &Window) {
	ctx := window.ui
	render_rectangle(shape, mut renderers, window)
	// This group box stuff is likely temporary
	// Examine after floating containers implemented
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

// draw_rectangle draws a shape as a rectangle.
fn render_rectangle(shape &Shape, mut renderers []Renderer, window &Window) {
	assert shape.type == .container
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

// render_cursor figures out where the cursor goes
fn render_cursor(shape &Shape, mut renderers []Renderer, window &Window) {
	if window.is_focus(shape.id_focus) && shape.type == .text {
		lh := line_height(shape)
		mut cursor_x := -1
		mut cursor_y := -1
		input_state := window.input_state[shape.id_focus]
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

// render_clip creates a clipping region based on the layout's dimensions
// minus padding and some adjustments for round off.
fn render_clip(shape &Shape, mut clip_stack ClipStack) Renderer {
	clip_rect := shape_clip_rect(shape)
	clip := DrawClip{
		x:      clip_rect.x
		y:      clip_rect.y
		width:  clip_rect.width
		height: clip_rect.height
	}
	clip_stack.push(clip)
	return clip
}

const clip_reset = DrawClip{
	x:      0
	y:      0
	width:  max_int
	height: max_int
}

// shape_unclip sets the clip region to the previous clip region
fn render_unclip(mut clip_stack ClipStack) DrawClip {
	clip_stack.pop() or { return clip_reset }
	return clip_stack.peek() or { clip_reset }
}

// dim_alpha is used for visually indicating disabled
fn dim_alpha(color Color) Color {
	return Color{
		...color
		a: color.a / u8(2)
	}
}

// shape_clip_rect constructs a clip rectangle based on the shape's
// diemensions plus some adjustments for round off
fn shape_clip_rect(shape &Shape) gg.Rect {
	return gg.Rect{
		x:      shape.x + shape.padding.left
		y:      shape.y + shape.padding.top
		width:  shape.width - shape.padding.width()
		height: shape.height - shape.padding.height()
	}
}

// make_renderer_rect creates a rectangle that represents the renderable region.
// If the shape is clipped, then use the shape dimensions otherwise used
// the window size.
fn make_renderer_rect(shape &Shape, window &Window) gg.Rect {
	return match shape.clip {
		true {
			shape_clip_rect(shape)
		}
		else {
			width, height := window.window_size()
			gg.Rect{
				x:      0
				y:      0
				width:  width
				height: height
			}
		}
	}
}

// rects_overlap check for non-overlapping conditions. If none are met, they overlap.
@[inline]
fn rects_overlap(r1 gg.Rect, r2 gg.Rect) bool {
	xo := r1.x < r2.x + r2.width && r2.x < r1.x + r1.width
	yo := r1.y < r2.y + r2.height && r2.y < r1.y + r1.height
	return xo && yo
}
