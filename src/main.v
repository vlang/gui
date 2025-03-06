module main

import gui
import gx

fn main() {
	mut window := gui.window(
		title:    'test layout'
		width:    600
		height:   400
		bg_color: gx.rgb(0x30, 0x30, 0x30)
		on_init:  fn (mut w gui.Window) {
			w.set_view(main_view())
		}
	)
	window.ui.run()
}

fn main_view() gui.UI_Tree {
	return gui.Column{
		x:        10
		y:        10
		spacing:  10
		padding:  gui.Padding{10, 10, 10, 10}
		color:    gx.blue
		children: [
			gui.Rectangle{
				width:  100
				height: 100
				radius: 5
				color:  gx.green
			},
			gui.Rectangle{
				width:  100
				height: 100
				filled: true
				radius: 5
				color:  gx.orange
			},
		]
	}
}
