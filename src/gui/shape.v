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
	filled  bool
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

fn set_positions(mut node ShapeTree, offset_x int, offset_y int) {
	node.shape.x += offset_x
	node.shape.y += offset_y

	padding := node.shape.padding
	spacing := node.shape.spacing
	direction := node.shape.direction

	mut x := node.shape.x + padding.left
	mut y := node.shape.y + padding.top
	mut width := node.shape.width
	mut height := node.shape.height

	for mut child in node.children {
		set_positions(mut child, x, y)
		match direction {
			.none {}
			.left_to_right {
				w := child.shape.width + spacing
				x += w
				width += w
				height = int_max(height, child.shape.height + padding.top)
			}
			.top_to_bottom {
				h := child.shape.height + spacing
				y += h
				height += h
				width = int_max(width, child.shape.width + padding.left)
			}
		}
	}

	node.shape.width = width + padding.right
	node.shape.height = height + padding.bottom
}

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
		style:      if shape.filled { .fill } else { .stroke }
		is_rounded: shape.radius > 0
		radius:     shape.radius
	)
}
