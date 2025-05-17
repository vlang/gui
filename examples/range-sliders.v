import gui

// Range Sliders
// =============================

@[heap]
struct RangeSliderApp {
pub mut:
	range_value f32 = 20
}

fn main() {
	mut window := gui.window(
		title:   'Range Sliders'
		state:   &RangeSliderApp{}
		width:   300
		height:  300
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	slider_app := window.state[RangeSliderApp]()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		h_align: .center
		v_align: .middle
		content: [
			gui.range_slider(
				value:       slider_app.range_value
				round_value: true
				sizing:      gui.fill_fit
				on_change:   fn (value f32, mut e gui.Event, mut w gui.Window) {
					mut app := w.state[RangeSliderApp]()
					app.range_value = value
				}
			),
			gui.text(text: slider_app.range_value.str()),
		]
	)
}
