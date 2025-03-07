module gui

import gx

pub struct Stack implements UI_Tree {
pub:
	direction ShapeDirection
pub mut:
	x        int
	y        int
	width    int
	height   int
	spacing  int
	padding  Padding
	fill     bool = true
	radius   int
	color    gx.Color = gx.rgba(0, 0, 0, 0)
	children []UI_Tree
}

fn (c Stack) generate() Shape {
	return Shape{
		type:      .rectangle
		direction: if c.direction == .none { .top_to_bottom } else { c.direction }
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
