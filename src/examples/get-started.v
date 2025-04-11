import gui
import gg

// GUI uses a view generator (a function that returns a View) to
// render the contents of the Window. As the state of the app
// changes, either through user actions or business logic, GUI
// calls the view generator to build a new view. The new view is
// used to render the contents of the window.
//
// There are several advantages to this approach.
// - The view is simply a function of the model (state).
// - No data binding or other observation mechanisms required.
// - No worries about synchronizing with the UI thread.
// - No need to remember to undo previous UI states.
// - Microsecond performance.

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
			// Call update_view() any where in your
			// business logic to change views.
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

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		h_align: .center
		v_align: .middle
		content: [
			gui.text(
				text:       'Welcome to GUI'
				text_style: gui.theme().h1
			),
			gui.button(
				id_focus:       1
				padding_border: gui.padding_two
				content:        [gui.text(text: '${app.clicks} Clicks')]
				on_click:       fn (_ &gui.ButtonCfg, _ &gg.Event, mut w gui.Window) bool {
					mut app := w.state[App]()
					app.clicks += 1
					return true // true says click was handled
				}
			),
		]
	)
}
