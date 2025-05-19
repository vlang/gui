import gui

// Select Demo
// =============================

@[heap]
struct SelectDemoApp {
pub mut:
	selected string = 'pick one'
}

fn main() {
	mut window := gui.window(
		state:   &SelectDemoApp{}
		width:   300
		height:  300
		on_init: fn (mut w gui.Window) {
			// Call update_view() any where in your
			// business logic to change views.
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

// The view generator set in update_view() is called on
// every user event (mouse move, click, resize, etc.).
fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	app := window.state[SelectDemoApp]()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		content: [
			gui.row(
				content: [
					gui.select(
						id:        'sel1'
						selected:  app.selected
						options:   [
							'one space for rent',
							'two space for rent',
							'three space for rent',
							'four space for rent',
							'five space for rent',
						]
						on_select: fn (s string, mut e gui.Event, mut w gui.Window) {
							mut app_ := w.state[SelectDemoApp]()
							app_.selected = s
							e.is_handled = true
						}
					),
				]
			),
		]
	)
}
