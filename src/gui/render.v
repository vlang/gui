module gui

import gg

fn render(shapes ShapeTree, ctx &gg.Context) {
	render_shape(shapes.shape, ctx)
	for child in shapes.children {
		render(child, ctx)
	}
}

fn render_shape(shape Shape, ctx &gg.Context) {
	match shape.type {
		.container { render_rectangle(shape, ctx) }
		.text { render_text(shape, ctx) }
		.none {}
	}
}

// draw_rectangle draws a shape as a rectangle.
fn render_rectangle(shape Shape, ctx &gg.Context) {
	assert shape.type == .container
	shape_clip(shape, ctx)
	defer { shape_unclip(ctx) }

	ctx.draw_rect(
		x:          shape.x
		y:          shape.y
		w:          shape.width
		h:          shape.height
		color:      shape.color
		style:      if shape.fill { .fill } else { .stroke }
		is_rounded: shape.radius > 0
		radius:     shape.radius
	)
}

fn render_text(shape Shape, ctx &gg.Context) {
	assert shape.type == .text
	shape_clip(shape, ctx)
	defer { shape_unclip(ctx) }

	lh := line_height(shape, ctx)
	mut y := int(shape.y + f32(0.49999))
	for line in shape.lines {
		ctx.draw_text(int(shape.x), y, line, shape.text_cfg)
		y += lh
	}

	if shape.cursor_x >= 0 && shape.cursor_y >= 0 {
		if shape.cursor_y < shape.lines.len {
			ln := shape.lines[shape.cursor_y]
			if shape.cursor_x <= ln.len {
				cx := shape.x + ctx.text_width(ln[..shape.cursor_x])
				cy := shape.y + (lh * shape.cursor_y)
				ctx.draw_line(cx, cy, cx, cy + lh, shape.text_cfg.color)
			}
		}
	}
}

// shape_clip creates a clipping region based on the shapes's bounds property.
// Internal use mostly, but useful if designing a new Shape
pub fn shape_clip(shape Shape, ctx &gg.Context) {
	if !is_empty_rect(shape.bounds) {
		x := int(shape.bounds.x - 1)
		y := int(shape.bounds.y - 1)
		w := int(shape.bounds.width + 1)
		h := int(shape.bounds.height + 1)
		ctx.scissor_rect(x, y, w, h)
	}
}

// shape_unclip resets the clipping region.
// Internal use mostly, but useful if designing a new Shape
pub fn shape_unclip(ctx &gg.Context) {
	ctx.scissor_rect(0, 0, max_int, max_int)
}

// is_empty_rect returns true if the rectangle has no area, positive
// or negative.
pub fn is_empty_rect(rect gg.Rect) bool {
	return (rect.x + rect.width) == 0 && (rect.y + rect.height) == 0
}
