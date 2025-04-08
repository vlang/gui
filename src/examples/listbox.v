import gui
import gg

struct App {
pub mut:
	clicks int
}

fn main() {
	mut window := gui.window(
		state:   &App{}
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
	app := window.state[App]()

	mut items := []gui.View{}
	for i in 1 .. 100 {
		items << gui.text(text: '${i} item')
	}

	return gui.column(
		width:   w
		height:  h
		h_align: .center
		spacing: gui.spacing_small
		sizing:  gui.fixed_fixed
		content: [
			gui.text(text: 'top'),
			gui.column(
				id_scroll_v: 1
				sizing:      gui.fit_fill
				padding:     gui.padding_none
				spacing:     gui.spacing_small
				content:     items
			),
			gui.text(text: 'bottom'),
		]
	)
}
