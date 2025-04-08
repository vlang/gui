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

// The view generator set in update_view() is called on
// every user event (mouse move, click, resize, etc.).
fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()

	mut items := []gui.View{}
	for i in 1 .. 100 {
		items << gui.text(text: '${i} text list item')
	}

	return gui.column(
		width:   w
		height:  h
		h_align: .center
		spacing: gui.spacing_small
		sizing:  gui.fixed_fixed
		content: [
			gui.text(text: 'top'),
			// Columns can function as list boxes
			gui.column(
				id_scroll_v: 1
				fill:        true
				color:       gui.theme().color_2
				sizing:      gui.fit_fill
				spacing:     gui.spacing_small
				padding:     gui.padding(3, 20, 3, 20)
				content:     items
			),
			gui.text(text: 'bottom'),
		]
	)
}
