module gui

import gx

pub struct Column implements UI_Tree {
pub mut:
	x        int
	y        int
	width    int
	height   int
	spacing  int
	padding  Padding
	color    gx.Color = gx.rgba(0, 0, 0, 0)
	children []UI_Tree
}

fn (c Column) generate() []Shape {
	return [
		Shape{
			type:      .rectangle
			direction: .top_to_bottom
			x:         c.x
			y:         c.y
			width:     c.width
			height:    c.height
			spacing:   c.spacing
			padding:   c.padding
			color:     c.color
			filled:    true
		},
	]
}
