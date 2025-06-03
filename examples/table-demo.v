import gui

// Table Demo
// =============================

@[heap]
struct TableDemoApp {
pub mut:
	clicks int
}

fn main() {
	mut window := gui.window(
		state:   &TableDemoApp{}
		width:   600
		height:  300
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(mut window gui.Window) gui.View {
	w, h := window.window_size()
	app := window.state[TableDemoApp]()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		h_align: .center
		content: [
			// vfmt off
			gui.table(
				window: window
				data:   [
					gui.tr([gui.td('First'), gui.td('Last'),     gui.td('Email')]),
					gui.tr([gui.td('Matt'),  gui.td('Williams'), gui.td('non.egestas.a@protonmail.org')]),
					gui.tr([gui.td('Clara'), gui.td('Nelson'),   gui.td('mauris.sagittis@icloud.net')]),
					gui.tr([gui.td('Frank'), gui.td('Johnson'),  gui.td('ac.libero.nec@aol.com')]),
					gui.tr([gui.td('Elmer'), gui.td('Fudd'),     gui.td('mus@aol.couk')]),
					gui.tr([gui.td('Roy'),   gui.td('Rogers'),   gui.td('amet.ultricies@yahoo.com')]),
				]
			),
			// vfmt on
		]
	)
}
