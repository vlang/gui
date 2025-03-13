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

// ButtonConfig
// A UI without buttons is not very useful. GUI keeps it
// simple. Buttons can have a size and color and text
// and not much else.
pub struct ButtonConfig {
pub:
	id       string
	width    f32
	height   f32
	padding  Padding = Padding{5, 10, 7, 10}
	text     string
	color    gx.Color
	on_click fn (string, MouseEvent, &Window) = unsafe { nil }
}

// button is a factory function for a button.
pub fn button(c ButtonConfig) &UI_Tree {
	return row(
		id:       c.id
		width:    c.width
		height:   c.height
		padding:  c.padding
		radius:   5
		fill:     true
		color:    gx.blue
		on_click: c.on_click
		children: [
			label(text: c.text),
		]
	)
}
