module gui

import gg

pub struct Shape {
pub:
	type      ShapeType
	direction ShapeDirection
mut:
	x       int
	y       int
	sizing  Sizing
	padding Padding
	fill    bool
	radius  int
	spacing int
	color   gg.Color
pub mut:
	width  int
	height int
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
		.text {}
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
