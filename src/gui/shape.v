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
	shapes   []Shape
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

fn shape_width(shapes []Shape) int {
	mut width := 0
	for shape in shapes {
		if shape.width > width {
			width = shape.width
		}
	}
	return width
}

fn shape_height(shapes []Shape) int {
	mut height := 0
	for shape in shapes {
		if shape.height > height {
			height = shape.height
		}
	}
	return height
}

fn set_positions(mut node ShapeTree, offset_x int, offset_y int) {
	for mut shape in node.shapes {
		shape.x += offset_x
		shape.y += offset_y
	}

	first_shape := node.shapes.first()
	padding := first_shape.padding
	spacing := first_shape.spacing
	direction := first_shape.direction

	mut x := first_shape.x + padding.left
	mut y := first_shape.y + padding.top

	for mut child in node.children {
		set_positions(mut child, x, y)
		match direction {
			.none {}
			.left_to_right { x += shape_width(child.shapes) + spacing }
			.top_to_bottom { y += shape_height(child.shapes) + spacing }
		}
	}
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
