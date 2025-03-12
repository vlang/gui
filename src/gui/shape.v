module gui

import gg
import gx

// Shape is the only data structure in GUI used to draw to the screen.
pub struct Shape {
pub:
	id        string // asigned by user
	uid       string
	type      ShapeType
	direction ShapeDirection
mut:
	x          f32
	y          f32
	width      f32
	height     f32
	spacing    f32
	sizing     Sizing
	padding    Padding
	fill       bool
	radius     int
	color      gg.Color
	text       string
	lines      []string
	text_cfg   gx.TextCfg
	wrap       bool
	min_width  f32
	min_height f32
	bounds     gg.Rect
}

// ShapeType describes the only shapes a Shape can be. All
// screen rendering is comprised of these ShapeTypes.
pub enum ShapeType {
	none
	container
	rectangle
	text
	line
	image
}

// ShapeDirection determines if a Shape arranges its child
// shapes horizontally, vertically or not at all.
pub enum ShapeDirection {
	none
	top_to_bottom
	left_to_right
}

// ShapeTree describes a tree of Shapes. UI_Trees generate ShapeTrees
pub struct ShapeTree {
pub mut:
	shape    Shape
	children []ShapeTree
}

const empty_shape_tree = ShapeTree{}

fn (node ShapeTree) clone() ShapeTree {
	mut clone := ShapeTree{
		shape: Shape{
			...node.shape
		}
	}
	for child in node.children {
		clone.children << child.clone()
	}
	return clone
}

// draw
// Drawing a shape it just that. No decisions about UI state are considered.
// If the UI state of your view changes, Generate an new view and update the window
// with the new view. New shapes are generated based on the view (UI_Tree).
// Data flows one way from view -> shapes or in terms of data structures
// from UI_Tree -> ShapeTree
pub fn (shape Shape) draw(ctx gg.Context) {
	match shape.type {
		.container { shape.draw_rectangle(ctx) }
		.rectangle { shape.draw_rectangle(ctx) }
		.text { shape.draw_text(ctx) }
		.image {}
		.line {}
		.none {}
	}
}

// draw_rectangle draws a shape as a rectangle.
pub fn (shape Shape) draw_rectangle(ctx gg.Context) {
	assert shape.type in [.container, .rectangle]
	shape_clip(shape, ctx)
	defer { shape_unclip(shape, ctx) }

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

// draw_text draws a shape as text
pub fn (shape Shape) draw_text(ctx gg.Context) {
	assert shape.type == .text
	shape_clip(shape, ctx)
	defer { shape_unclip(shape, ctx) }

	lh := line_height(shape, ctx)
	mut y := int(shape.y + f32(0.49999))
	for line in shape.lines {
		ctx.draw_text(int(shape.x), y, line, shape.text_cfg)
		y += lh
	}
}

// is_empty_rect returns true if the rectangle has no area, positive
// or negative.
pub fn is_empty_rect(rect gg.Rect) bool {
	return (rect.x + rect.width) == 0 && (rect.y + rect.height) == 0
}

// shape_clip sets up a clipping region based on the shapes's bounds property.'
pub fn shape_clip(shape Shape, ctx gg.Context) {
	if !is_empty_rect(shape.bounds) {
		x := int(shape.bounds.x - 1)
		y := int(shape.bounds.y - 1)
		w := int(shape.bounds.width + 1)
		h := int(shape.bounds.height + 1)
		ctx.scissor_rect(x, y, w, h)
	}
}

// shape_unclip resets the clipping region.
pub fn shape_unclip(shape Shape, ctx gg.Context) {
	ctx.scissor_rect(0, 0, max_int, max_int)
}
