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
fn renderers_draw(renderers []Renderer, ctx &gg.Context) {
	for renderer in renderers {
		renderer_draw(renderer, ctx)
	}
}

// renderer_draw draws a single renderer
fn renderer_draw(renderer Renderer, ctx &gg.Context) {
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

// render walks the layout and generates renderers. If a shape is clipped,
// then a clip rectangle is added to the context. Clip rectangles are
// pushed/poped onto an internal stack allowing nested, none overlapping
// clip rectangles (I think I said that right)
fn render(layout Layout, bg_color Color, offset_v f32, ctx &gg.Context) []Renderer {
	mut renderers := []Renderer{}
	mut clip_stack := ClipStack{}

	parent_color := if layout.shape.color != color_transparent {
		layout.shape.color
	} else {
		bg_color
	}

	renderers << render_shape(layout.shape, bg_color, offset_v, ctx)

	if layout.shape.clip {
		renderers << render_clip(layout.shape, mut clip_stack)
	}

	for child in layout.children {
		v_offset := layout.shape.scroll_v + child.shape.scroll_v
		renderers << render(child, parent_color, v_offset, ctx)
	}

	if layout.shape.clip {
		renderers << render_unclip(mut clip_stack)
	}

	return renderers
}

// render_shape examines the Shape.type and calls the appropriate renderer.
fn render_shape(shape Shape, parent_color Color, offset_v f32, ctx &gg.Context) []Renderer {
	if shape.color == color_transparent {
		return []
	}
	return match shape.type {
		.container {
			mut renderers := []Renderer{}
			renderers << render_rectangle(shape, offset_v)
			// This group box stuff is likely temporary
			// Examine after floating containers implemented
			if shape.text.len != 0 {
				ctx.set_text_cfg(shape.text_style.to_text_cfg())
				w, h := ctx.text_size(shape.text)
				x := shape.x + 20
				y := shape.y + offset_v
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
				renderers << DrawText{
					x:    x
					y:    y - h + 1.5
					text: shape.text
					cfg:  TextStyle{
						...shape.text_style
						color: color
					}.to_text_cfg()
				}
			}
			renderers
		}
		.text {
			render_text(shape, offset_v, ctx)
		}
		.none {
			[]
		}
	}
}

// draw_rectangle draws a shape as a rectangle.
fn render_rectangle(shape Shape, offset_v f32) []Renderer {
	assert shape.type == .container
	mut renderers := []Renderer{}
	renderer_rect := make_renderer_rect(shape)
	draw_rect := gg.Rect{
		x:      shape.x
		y:      shape.y + offset_v
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
	return renderers
}

// render_text renders text including multiline text.
// If cursor coordinates are present, it draws the input cursor.
fn render_text(shape Shape, offset_v f32, ctx &gg.Context) []Renderer {
	assert shape.type == .text
	mut renderers := []Renderer{}
	mut y := shape.y + offset_v
	color := if shape.disabled {
		dim_alpha(shape.text_style.color)
	} else {
		shape.text_style.color
	}
	mut text_cfg := TextStyle{
		...shape.text_style
		color: color
	}.to_text_cfg()
	lh := line_height(shape, ctx)
	renderer_rect := make_renderer_rect(shape)

	for line in shape.lines {
		draw_rect := gg.Rect{
			x:      shape.x
			y:      y
			width:  shape.width
			height: lh
		}
		// Cull any renderers outside of clip/conteext region.
		if rects_overlap(renderer_rect, draw_rect) {
			renderers << DrawText{
				x:    shape.x
				y:    y
				text: line
				cfg:  text_cfg
			}
		}
		y += lh
	}

	if shape.cursor_x >= 0 && shape.cursor_y >= 0 {
		if shape.cursor_y < shape.lines.len {
			ln := shape.lines[shape.cursor_y]
			if shape.cursor_x <= ln.len {
				cx := shape.x + ctx.text_width(ln[..shape.cursor_x])
				cy := shape.y + (lh * shape.cursor_y)
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

	return renderers
}

// render_clip creates a clipping region based on the layout's dimensions
// minus padding and some adjustments for round off.
fn render_clip(shape Shape, mut clip_stack ClipStack) Renderer {
	// Appears to be some round-off issues in sokol's clipping that cause
	// off by one errors. Not a big deal. Bump the region out by one in
	// either direction to compensate.
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
fn shape_clip_rect(shape Shape) gg.Rect {
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
fn make_renderer_rect(shape Shape) gg.Rect {
	return match shape.clip {
		true {
			shape_clip_rect(shape)
		}
		else {
			size := gg.window_size()
			gg.Rect{
				x:      0
				y:      0
				width:  size.width
				height: size.height
			}
		}
	}
}

// rects_overlap check for non-overlapping conditions. If none are met, they overlap.
fn rects_overlap(r1 gg.Rect, r2 gg.Rect) bool {
	return !(r1.x + r1.width <= r2.x || r1.y + r1.height <= r2.y || r1.x >= r2.x + r2.width
		|| r1.y >= r2.y + r2.height)
}
