module gui

import gx

struct Button {
pub:
	id      string
	width   f32
	height  f32
	padding Padding
	sizing  Sizing
	text    string
}

pub struct ButtonConfig {
pub:
	id      string
	width   f32
	height  f32
	padding Padding = Padding{5, 10, 7, 10}
	text    string
	color   gx.Color
}

pub fn button(c ButtonConfig) &UI_Tree {
	return row(
		id:       c.id
		width:    c.width
		height:   c.height
		padding:  c.padding
		radius:   5
		fill:     true
		color:    gx.blue
		children: [
			label(text: c.text),
		]
	)
}
