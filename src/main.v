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
	return gui.Stack{
		x:        10
		y:        10
		spacing:  10
		radius:   5
		padding:  gui.Padding{10, 10, 10, 10}
		color:    gx.dark_blue
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
				fill:   true
				radius: 5
				color:  gx.orange
			},
			gui.Stack{
				direction: gui.ShapeDirection.left_to_right
				spacing:   10
				radius:    5
				fill:      false
				color:     gx.light_gray
				padding:   gui.Padding{10, 10, 10, 10}
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
			},
		]
	}
}
