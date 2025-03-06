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
			view := gui.Column{
				width:    400
				height:   300
				children: [
					gui.Rectangle{
						width:  100
						height: 100
						color:  gx.green
					},
					gui.Rectangle{
						width:  100
						height: 100
						color:  gx.orange
					},
				]
			}
			w.set_view(view)
		}
	)
	window.ui.run()
}
