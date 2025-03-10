module gui

import gg
import gx

pub struct Shape {
pub:
	id        string
	type      ShapeType
	direction ShapeDirection
mut:
	x       f32
	y       f32
	width   f32
	height  f32
	spacing f32
	sizing  Sizing
	padding Padding
	fill    bool
	radius  int
	color   gg.Color
	text    string
}

pub enum ShapeType {
	none
	rectangle
	text
}

pub enum ShapeDirection {
	none
	top_to_bottom
	left_to_right
}

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
// If the UI state of your view changes, Generate and update the window with
// the new view. New shapes are generated based on the view (UI_Tree).
// Data flows one way from view -> shapes or in terms of data structures
// from UI_Tree -> ShapeTree
pub fn (shape Shape) draw(ctx gg.Context) {
	match shape.type {
		.rectangle { shape.draw_rectangle(ctx) }
		.text { shape.draw_text(ctx) }
		.none {}
	}
}

pub fn (shape Shape) draw_rectangle(ctx gg.Context) {
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

pub fn (shape Shape) draw_text(ctx gg.Context) {
	ctx.draw_text(int(shape.x), int(shape.y), shape.text,
		color: gx.white
	)
}
