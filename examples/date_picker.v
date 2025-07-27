import gui
import time

// Date Picker Example
// =============================

@[heap]
struct DatePickerApp {
pub mut:
	date_picker_time time.Time = time.now()
}

fn main() {
	mut window := gui.window(
		state:   &DatePickerApp{}
		width:   800
		height:  600
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(mut window gui.Window) gui.View {
	w, h := window.window_size()
	app := window.state[DatePickerApp]()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		h_align: .center
		v_align: .middle
		content: [
			window.date_picker(
				id:        'example'
				time:      app.date_picker_time
				on_select: fn (times []time.Time, mut e gui.Event, mut w gui.Window) {
					mut app := w.state[DatePickerApp]()
					app.date_picker_time = times[0]
					e.is_handled = true
				}
			),
		]
	)
}
