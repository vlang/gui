import gui

fn main() {
	mut window := gui.window(
		width:   300
		height:  300
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.run()
}

fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()

	mut items := []gui.View{}
	for i in 1 .. 1_000 {
		items << gui.text(text: '${i} text list item')
	}

	return gui.column(
		width:   w
		height:  h
		h_align: .center
		spacing: gui.spacing_small
		sizing:  gui.fixed_fixed
		content: [
			// Columns can function as list boxes.
			// TODO: add selection logic
			gui.column(
				id_scroll_v: 1
				id_focus:    1
				fill:        true
				color:       gui.theme().color_2
				sizing:      gui.fit_fill
				spacing:     gui.spacing_small
				padding:     gui.padding(3, 20, 3, 20)
				content:     items
			),
		]
	)
}
