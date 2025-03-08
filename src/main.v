module main

import gui
import gx

fn main() {
	mut window := gui.window(
		title:      'test layout'
		width:      600
		height:     400
		bg_color:   gx.rgb(0x30, 0x30, 0x30)
		on_init:    fn (mut w gui.Window) {
			w.update_view(main_view(w))
		}
		on_resized: fn (mut w gui.Window) {
			w.update_view(main_view(w))
		}
	)
	window.run()
}

fn main_view(w &gui.Window) gui.UI_Tree {
	width, height := w.window_size()
	return gui.row(
		width:    width
		height:   height
		sizing:   gui.Sizing{.fixed, .fixed}
		spacing:  10
		padding:  gui.Padding{10, 10, 10, 10}
		fill:     true
		color:    gx.dark_blue
		children: [
			gui.rectangle(
				width:  75
				height: 50
				fill:   true
				radius: 5
				color:  gx.purple
			),
			gui.rectangle(
				width:  75
				height: 50
				sizing: gui.Sizing{.dynamic, .dynamic}
				fill:   true
				radius: 5
				color:  gx.pink
			),
			gui.rectangle(
				width:  75
				height: 50
				fill:   true
				radius: 5
				color:  gx.red
			),
			gui.rectangle(
				width:  75
				height: 50
				fill:   true
				radius: 5
				color:  gx.indigo
			),
		]
	)
}
