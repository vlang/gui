import gui

// Column Scrolling
// =============================
// Demonstrates column scrolling with 10,000 different text items.
// No virtualization, just pure layout calculated 10's of thousands
// of times. Build with the -prod flag for buttery smooth performance.
// Gui layout/rendering is fast!

@[heap]
struct App {
	items []gui.View
}

fn main() {
	size := 10_000 // 10K!
	mut items := []gui.View{cap: size + 1}
	for i in 1 .. size + 1 {
		items << gui.text(text: '${i:05} text list item')
	}

	mut window := gui.window(
		width:   300
		height:  300
		state:   &App{
			items: items
		}
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.run()
}

fn main_view(window &gui.Window) gui.View {
	app := window.state[App]()
	w, h := window.window_size()

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
				id_focus:  1
				id_scroll: 1
				scrollbar: true
				fill:      true
				color:     gui.theme().color_2
				sizing:    gui.fit_fill
				spacing:   gui.spacing_small
				padding:   gui.padding(3, 10, 3, 13)
				content:   app.items
			),
		]
	)
}
