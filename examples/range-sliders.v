import gui

// Range Sliders
// =============================

@[heap]
struct RangeSliderApp {
pub mut:
	percent f32 = f32(0.40)
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
				percent:         slider_app.percent
				sizing:          gui.fill_fit
				percent_changed: fn (percent f32, mut e gui.Event, mut w gui.Window) {
					mut app := w.state[RangeSliderApp]()
					app.percent = percent
				}
			),
		]
	)
}
