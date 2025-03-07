module gui

import gx

// Stack is the fundamental layout container in gui.
// It can be used to layout its children top-to-bottom or left_to_right.
// A `.none` direction allows stack to behave as a canvas with no additional layout.
//
// direction ShapeDirection = .top_to_bottom
// x        int
// y        int
// width    int
// height   int
// spacing  int
// padding  Padding
// fill     bool = true
// radius   int
// color    gx.Color = gx.black
// children []UI_Tree
pub struct Stack implements UI_Tree {
pub:
	direction ShapeDirection = .top_to_bottom
pub mut:
	x        int
	y        int
	width    int
	height   int
	spacing  int
	sizing   Sizing
	padding  Padding
	fill     bool = true
	radius   int
	color    gx.Color = gx.rgba(0, 0, 0, 0)
	children []UI_Tree
}

fn (c Stack) generate() Shape {
	return Shape{
		type:      .rectangle
		direction: c.direction
		x:         c.x
		y:         c.y
		width:     c.width
		height:    c.height
		spacing:   c.spacing
		padding:   c.padding
		color:     c.color
		fill:      c.fill
		radius:    c.radius
	}
}
