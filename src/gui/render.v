module gui

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

fn render(shapes ShapeTree, ctx &gg.Context) []Renderer {
	mut renderers := []Renderer{}
	renderers << render_shape(shapes.shape, ctx)
	for child in shapes.children {
		renderers << render(child, ctx)
	}
	return renderers
}

fn render_shape(shape Shape, ctx &gg.Context) []Renderer {
	return match shape.type {
		.container { render_rectangle(shape, ctx) }
		.text { render_text(shape, ctx) }
		.none { [Renderer(DrawNone{})] }
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
		color:      shape.color
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
	for line in shape.lines {
		renderers << DrawText{
			x:    shape.x
			y:    y
			text: line
			cfg:  shape.text_cfg
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
fn shape_clip(shape Shape, ctx &gg.Context) Renderer {
	// Perhaps this is a round off error some where (maybe sokol), but need
	// to expand width and height by 0.5 to keep the right/bottom edges
	// unclipped.
	// if !is_empty_rect(shape.bounds) {
	// 	x := shape.bounds.x
	// 	y := shape.bounds.y
	// 	w := shape.bounds.width + 0.5
	// 	h := shape.bounds.height + 0.5
	// 	return DrawClip{
	// 		x:      x
	// 		y:      y
	// 		width:  w
	// 		height: h
	// 	}
	// }
	return DrawNone{}
}

// shape_unclip resets the clipping region. Internal use mostly, but useful if
// designing a new Shape
fn shape_unclip(ctx &gg.Context) DrawClip {
	return DrawClip{
		x:      0
		y:      0
		width:  max_int
		height: max_int
	}
}

// is_empty_rect returns true if the rectangle has no area, positive or
// negative.
fn is_empty_rect(rect gg.Rect) bool {
	return (rect.x + rect.width) == 0 && (rect.y + rect.height) == 0
}
