module main

import gui
import gx

fn main() {
	mut window := gui.window(
		title:      'test layout'
		width:      1000
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
	padding := gui.Padding{10, 10, 10, 10}
	return gui.row(
		width:    width
		height:   height
		sizing:   gui.Sizing{.fixed, .fixed}
		spacing:  10
		padding:  padding
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
			gui.row(
				id:       'col'
				spacing:  10
				padding:  padding
				radius:   5
				color:    gx.orange
				sizing:   gui.Sizing{.grow, .grow}
				children: [
					gui.column(
						spacing:  10
						padding:  padding
						fill:     true
						radius:   5
						sizing:   gui.Sizing{.fit, .grow}
						color:    gx.black
						children: [
							gui.rectangle(
								width:  25
								height: 25
								radius: 5
								color:  gx.orange
							),
							gui.column(
								color:    gx.white
								children: [
									gui.label(text: 'Hello world!'),
								]
							),
							gui.label(text: 'This is text'),
							gui.label(text: 'Embedded in a column'),
							gui.button(
								id:   'button'
								text: 'Button Text'
							),
						]
					),
					gui.rectangle(
						width:  25
						height: 25
						fill:   true
						radius: 5
						sizing: gui.Sizing{.grow, .grow}
						color:  gx.dark_green
					),
				]
			),
			gui.rectangle(
				width:  75
				height: 50
				fill:   true
				radius: 5
				sizing: gui.Sizing{.grow, .grow}
				color:  gx.red
			),
			gui.rectangle(
				width:  75
				height: 50
				fill:   true
				radius: 5
				color:  gx.orange
			),
		]
	)
}
