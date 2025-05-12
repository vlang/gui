import gui

@[heap]
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

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		h_align: .center
		v_align: .middle
		content: [
			gui.image(file_name: 'sample.jpeg'),
			gui.text(text: 'Pretty Water Fall', text_style: gui.theme().b2),
		]
	)
}
