module gui

import gx

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
	text_cfg gx.TextCfg
	on_click fn (string, MouseEvent, &Window) = unsafe { nil }
}

// button is a factory function for a button.
pub fn button(c ButtonConfig) &UI_Tree {
	return canvas(
		id:       c.id
		width:    c.width
		height:   c.height
		padding:  c.padding
		radius:   5
		fill:     true
		color:    gx.blue
		on_click: c.on_click
		children: [
			text(
				text:     c.text
				text_cfg: c.text_cfg
			),
		]
	)
}
