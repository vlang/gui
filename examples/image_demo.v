import os
import gui

fn main() {
	mut window := gui.window(
		width:   600
		height:  400
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	sample_path := os.join_path(os.dir(@FILE), 'sample.jpeg')

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		h_align: .center
		v_align: .middle
		content: [
			gui.image(
				src:      sample_path
				on_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
					w.dialog(
						align_buttons: .end
						dialog_type:   .message
						title:         'Image Demo'
						body:          'Click!'
					)
				}
			),
			gui.text(text: 'Pinard Falls, Oregon', text_style: gui.theme().b2),
		]
	)
}
