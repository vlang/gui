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

fn render_draw(renderer Renderer, ctx &gg.Context) {
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

fn render(shapes ShapeTree, bg_color gx.Color, ctx &gg.Context) []Renderer {
	mut renderers := []Renderer{}
	mut clip_stack := ClipStack{}

	renderers << render_shape(shapes.shape, bg_color, ctx)

	if shapes.shape.clip {
		renderers << render_clip(shapes.shape, ctx, mut clip_stack)
	}
	for child in shapes.children {
		parent_color := if shapes.shape.color != color_transparent {
			shapes.shape.color
		} else {
			bg_color
		}
		renderers << render(child, parent_color, ctx)
	}
	if shapes.shape.clip {
		renderers << render_unclip(ctx, mut clip_stack)
	}

	return renderers
}

fn render_shape(shape Shape, parent_color gx.Color, ctx &gg.Context) []Renderer {
	return match shape.type {
		.container {
			mut renderers := []Renderer{}
			renderers << render_rectangle(shape, ctx)
			if shape.text.len != 0 {
				ctx.set_text_cfg(shape.text_cfg)
				w, h := ctx.text_size(shape.text)
				x := shape.x + 20
				// erase portion of rectangle where text goes.
				p_color := if shape.disabled {
					dim_alpha(parent_color)
				} else {
					parent_color
				}
				renderers << DrawRect{
					x:     x
					y:     shape.y - 2 - h / 2
					w:     w
					h:     h + 1
					style: .fill
					color: p_color
				}
				color := if shape.disabled {
					dim_alpha(shape.text_cfg.color)
				} else {
					shape.text_cfg.color
				}
				renderers << DrawText{
					x:    x
					y:    shape.y - h + 1.5
					text: shape.text
					cfg:  gx.TextCfg{
						...shape.text_cfg
						color: color
					}
				}
			}
			renderers
		}
		.text {
			render_text(shape, ctx)
		}
		.none {
			[Renderer(DrawNone{})]
		}
	}
}

// draw_rectangle draws a shape as a rectangle.
fn render_rectangle(shape Shape, ctx &gg.Context) []Renderer {
	assert shape.type == .container
	mut renderers := []Renderer{}
	renderers << DrawRect{
		x:          shape.x
		y:          shape.y
		w:          shape.width
		h:          shape.height
		color:      if shape.disabled { dim_alpha(shape.color) } else { shape.color }
		style:      if shape.fill { .fill } else { .stroke }
		is_rounded: shape.radius > 0
		radius:     shape.radius
	}
	return renderers
}

fn render_text(shape Shape, ctx &gg.Context) []Renderer {
	assert shape.type == .text
	mut renderers := []Renderer{}
	lh := line_height(shape, ctx)
	mut y := int(shape.y + f32(0.49999))
	color := if shape.disabled { dim_alpha(shape.text_cfg.color) } else { shape.text_cfg.color }
	text_cfg := gx.TextCfg{
		...shape.text_cfg
		color: color
	}
	for line in shape.lines {
		renderers << DrawText{
			x:    shape.x
			y:    y
			text: line
			cfg:  text_cfg
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
						color: shape.text_cfg.color
					}
				}
			}
		}
	}
	return renderers
}

// shape_clip creates a clipping region based on the shapes's bounds property.
// Internal use mostly, but useful if designing a new Shape
fn render_clip(shape Shape, ctx &gg.Context, mut clip_stack ClipStack) Renderer {
	// Appears to be some round-off issues in sokol's clipping that cause
	// off by one errors. Not a big deal. Bump the region out by one in
	// either direction to compensate.
	clip := DrawClip{
		x:      shape.x + shape.padding.left - 1
		y:      shape.y + shape.padding.top - 1
		width:  shape.width - shape.padding.left - shape.padding.right + 2
		height: shape.height - shape.padding.top - shape.padding.bottom + 2
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
fn render_unclip(ctx &gg.Context, mut clip_stack ClipStack) DrawClip {
	clip_stack.pop() or { return clip_reset }
	return clip_stack.peek() or { clip_reset }
}

// dim_alpha is used for visually indicating disabled
fn dim_alpha(color gx.Color) gx.Color {
	return gx.Color{
		...color
		a: color.a / u8(2)
	}
}
