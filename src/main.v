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
			w.update_view(main_view())
		}
	)
	window.ui.run()
}

fn main_view() gui.UI_Tree {
	return gui.Stack{
		direction: .left_to_right
		x:         10
		y:         10
		width:     500
		height:    300
		spacing:   10
		radius:    5
		padding:   gui.Padding{10, 10, 10, 10}
		color:     gx.dark_blue
		children:  [
			gui.Rectangle{
				width:  75
				height: 50
				fill:   true
				radius: 5
				color:  gx.purple
			},
			gui.Rectangle{
				width:  75
				height: 50
				fill:   true
				radius: 5
				color:  gx.pink
			},
			gui.Rectangle{
				width:  75
				height: 50
				fill:   true
				radius: 5
				color:  gx.red
			},
			gui.Rectangle{
				width:  75
				height: 50
				fill:   true
				radius: 5
				color:  gx.indigo
			},
		]
	}
}
