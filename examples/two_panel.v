import gui

// Two Panel
// =================================
// One of the first programs I wrote to test layouts in GUI.
// Simple but it helped pave the way for more complex layouts
// like test-layout.v.

fn main() {
	mut window := gui.window(
		width:   300
		height:  350
		title:   'two panel'
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(mut w gui.Window) gui.View {
	width, height := w.window_size()

	return gui.row(
		width:   width
		height:  height
		sizing:  gui.fixed_fixed
		content: [
			gui.column(
				fill:       true
				sizing:     gui.fill_fill
				max_width:  150
				max_height: 330
				h_align:    .center
				v_align:    .middle
				color:      gui.rgb(215, 125, 0)
				content:    [
					gui.text(
						text:       'Hello'
						text_style: gui.TextStyle{
							...gui.theme().b2
							color: gui.black
						}
					),
				]
			),
			gui.column(
				text:      ' Container Title  '
				sizing:    gui.fill_fill
				h_align:   .end
				v_align:   .bottom
				min_width: 150
				color:     gui.theme().text_style.color
				content:   [
					gui.text(
						text:       'There!'
						text_style: gui.TextStyle{
							...gui.theme().b1
							size: gui.theme().size_text_large
						}
					),
				]
			),
		]
	)
}
