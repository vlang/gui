import gui
import time

// Date Picker Example
// =============================

@[heap]
struct DatePickerApp {
pub mut:
	date_picker_time time.Time = time.now()
	light_theme      bool
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
			gui.row(
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
					gui.rectangle(width: 1, height: 10, sizing: gui.fit_fill),
					gui.column(
						padding: gui.padding_none
						sizing:  gui.fit_fill
						content: [
							gui.text(text: 'Configuration', text_style: gui_theme.m3),
							gui.rectangle(color: gui.color_transparent, sizing: gui.fit_fill),
							gui.row(
								padding: gui.padding_none
								v_align: .middle
								content: [
									gui.button(
										content:  [gui.text(text: 'Reset')]
										on_click: fn (_ &gui.ButtonCfg, mut e gui.Event, mut w gui.Window) {
											w.date_picker_reset('example')
											mut app := w.state[DatePickerApp]()
											app.date_picker_time = time.now()
											e.is_handled = true
										}
									),
									toggle_theme(app),
								]
							),
						]
					),
				]
			),
		]
	)
}

fn toggle_theme(app &DatePickerApp) gui.View {
	return gui.row(
		sizing:  gui.fill_fit
		padding: gui.padding_none
		content: [
			gui.toggle(
				text_select:   gui.icon_moon
				text_unselect: gui.icon_sunny_o
				text_style:    gui.theme().icon3
				padding:       gui.padding_small
				select:        app.light_theme
				on_click:      fn (_ &gui.ToggleCfg, mut _ gui.Event, mut w gui.Window) {
					mut app := w.state[DatePickerApp]()
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
