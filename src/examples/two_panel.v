import gui
import gx

fn main() {
	mut window := gui.window(
		width:    300
		height:   350
		title:    'test layout'
		bg_color: gx.rgb(0x30, 0x30, 0x30)
		on_init:  fn (mut w gui.Window) {
			w.update_view(main_view)
			// w.resize_to_content()
		}
	)
	window.run()
}

fn main_view(mut w gui.Window) gui.View {
	width, height := w.window_size()
	return gui.row(
		id:       'row'
		width:    width
		height:   height
		sizing:   gui.fixed_fixed
		spacing:  10
		children: [
			gui.column(
				width:  150
				color:  gx.dark_gray
				fill:   true
				sizing: gui.fixed_flex
			),
			gui.column(
				id:     'green'
				color:  gx.dark_green
				fill:   true
				sizing: gui.flex_flex
			),
		]
	)
}
