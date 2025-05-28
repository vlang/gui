import gui

// Range Sliders
// =============================

@[heap]
struct RangeSliderApp {
pub mut:
	range_value f32 = 20
	light_theme bool
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
		content: [
			gui.row(
				h_align: .end
				sizing:  gui.fill_fit
				padding: gui.padding_none
				content: [toggle_theme(slider_app)]
			),
			gui.row(
				sizing:  gui.fill_fill
				content: [
					gui.column(
						sizing:  gui.fill_fill
						content: [
							gui.range_slider(
								id:          'rs1'
								id_focus:    1
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
					),
					gui.column(
						sizing:  gui.fit_fill
						content: [
							gui.range_slider(
								id:          'rs2'
								id_focus:    2
								value:       slider_app.range_value
								round_value: true
								vertical:    true
								sizing:      gui.fit_fill
								on_change:   fn (value f32, mut e gui.Event, mut w gui.Window) {
									mut app := w.state[RangeSliderApp]()
									app.range_value = value
								}
							),
						]
					),
				]
			),
		]
	)
}

fn toggle_theme(app &RangeSliderApp) gui.View {
	return gui.row(
		h_align: .end
		sizing:  gui.fill_fit
		padding: gui.padding_none
		content: [
			gui.toggle(
				text_select:   gui.icon_moon
				text_unselect: gui.icon_sunny_o
				text_style:    gui.theme().icon3
				padding:       gui.theme().padding_small
				select:        app.light_theme
				on_click:      fn (_ &gui.ToggleCfg, mut _ gui.Event, mut w gui.Window) {
					mut app := w.state[RangeSliderApp]()
					app.light_theme = !app.light_theme
					theme := if app.light_theme {
						gui.theme_light_bordered
					} else {
						gui.theme_dark_bordered
					}
					w.set_theme(theme)
				}
			),
		]
	)
}
