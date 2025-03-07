module gui

import gg

pub struct Shape {
pub:
	type      ShapeType
	direction ShapeDirection
mut:
	x       int
	y       int
	width   int
	height  int
	fill    bool
	radius  int
	spacing int
	padding Padding
	color   gg.Color
}

pub enum ShapeType {
	none
	rectangle
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

pub struct Padding {
pub mut:
	top    int
	right  int
	bottom int
	left   int
}

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

fn fit_sizing(mut node ShapeTree) {
	padding := node.shape.padding
	spacing := node.shape.spacing
	direction := node.shape.direction

	mut width := node.shape.width
	mut height := node.shape.height

	for mut child in node.children {
		fit_sizing(mut child)
		match direction {
			.none {}
			.left_to_right {
				width += child.shape.width
				height = int_max(height, child.shape.height)
			}
			.top_to_bottom {
				height += child.shape.height
				width = int_max(width, child.shape.width)
			}
		}
	}

	node.shape.width = width + padding.left + padding.right
	node.shape.height = height + padding.top + padding.bottom
	total_spacing := spacing * (node.children.len - 1)

	if node.shape.direction == .left_to_right {
		node.shape.width += total_spacing
	}
	if node.shape.direction == .top_to_bottom {
		node.shape.height += total_spacing
	}
}

fn grow_sizing(mut node ShapeTree) {
}

fn set_positions(mut node ShapeTree, offset_x int, offset_y int) {
	node.shape.x += offset_x
	node.shape.y += offset_y

	padding := node.shape.padding
	spacing := node.shape.spacing
	direction := node.shape.direction

	mut x := node.shape.x + padding.left
	mut y := node.shape.y + padding.top

	for mut child in node.children {
		set_positions(mut child, x, y)
		match direction {
			.none {}
			.left_to_right { x += child.shape.width + spacing }
			.top_to_bottom { y += child.shape.height + spacing }
		}
	}
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
