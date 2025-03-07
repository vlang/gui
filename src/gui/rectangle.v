module gui

import gx

// `Rectangle` can express empty, filled and rounded rectangles
// x      int
// y      int
// width  int
// height int
// fill   bool
// radius int
// color  gx.Color
pub struct Rectangle implements UI_Tree {
pub:
	x      int
	y      int
	width  int
	height int
	sizing Sizing
	fill   bool
	radius int
	color  gx.Color
mut:
	children []UI_Tree
}

pub fn (rectangle &Rectangle) generate() Shape {
	return Shape{
		type:      .rectangle
		direction: .none
		x:         rectangle.x
		y:         rectangle.y
		width:     rectangle.width
		height:    rectangle.height
		sizing:    rectangle.sizing
		fill:      rectangle.fill
		radius:    rectangle.radius
		color:     rectangle.color
	}
}
