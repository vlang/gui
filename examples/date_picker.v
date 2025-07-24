import gui

// Data Picker
// =============================

@[heap]
struct DataPickerApp {
pub mut:
	clicks int
}

fn main() {
	mut window := gui.window(
		state:   &DataPickerApp{}
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
	app := window.state[DataPickerApp]()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		h_align: .center
		v_align: .middle
		content: [
			gui.date_picker(id_focus: 1),
		]
	)
}
