import gui
import time

// Date Picker Example
// =============================

@[heap]
struct DatePickerApp {
pub mut:
	date_picker_times    []time.Time
	hide_today_indicator bool
	monday_first         bool
	show_adjacent_months bool
	select_multiple      bool
	week_days            string = 'one'
	light_theme          bool
}

fn main() {
	mut window := gui.window(
		state:   &DatePickerApp{}
		width:   1200
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
	mut app := window.state[DatePickerApp]()

	options := [
		gui.radio_option('One letter', 'one'), // label, value,
		gui.radio_option('Three letter', 'three'),
		gui.radio_option('Full', 'full'),
	]

	week_days := match app.week_days {
		'one' { gui.DatePickerWeekdays.one_letter }
		'three' { gui.DatePickerWeekdays.three_letter }
		else { gui.DatePickerWeekdays.full }
	}
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
						id:                       'example'
						times:                    app.date_picker_times
						hide_today_indicator:     app.hide_today_indicator
						monday_first_day_of_week: app.monday_first
						show_adjacent_months:     app.show_adjacent_months
						select_multiple:          app.select_multiple
						week_days:                week_days
						on_select:                fn (times []time.Time, mut e gui.Event, mut w gui.Window) {
							mut app := w.state[DatePickerApp]()
							app.date_picker_times = times
							e.is_handled = true
						}
					),
					gui.rectangle(width: 1, height: 10, sizing: gui.fit_fill),
					gui.column(
						padding: gui.padding_none
						sizing:  gui.fit_fill
						content: [
							gui.text(text: 'Configuration', text_style: gui_theme.m3),
							gui.toggle(
								label:    'Monday first day of week'
								select:   app.monday_first
								on_click: fn (_ &gui.ToggleCfg, mut e gui.Event, mut w gui.Window) {
									mut app := w.state[DatePickerApp]()
									app.monday_first = !app.monday_first
								}
							),
							gui.toggle(
								label:    'Show adjacent months'
								select:   app.show_adjacent_months
								on_click: fn (_ &gui.ToggleCfg, mut e gui.Event, mut w gui.Window) {
									mut app := w.state[DatePickerApp]()
									app.show_adjacent_months = !app.show_adjacent_months
								}
							),
							gui.toggle(
								label:    'Hide today indicator'
								select:   app.hide_today_indicator
								on_click: fn (_ &gui.ToggleCfg, mut e gui.Event, mut w gui.Window) {
									mut app := w.state[DatePickerApp]()
									app.hide_today_indicator = !app.hide_today_indicator
								}
							),
							gui.toggle(
								label:    'Multiple select'
								select:   app.select_multiple
								on_click: fn (_ &gui.ToggleCfg, mut e gui.Event, mut w gui.Window) {
									mut app := w.state[DatePickerApp]()
									app.select_multiple = !app.select_multiple
								}
							),
							gui.rectangle(color: gui.color_transparent),
							gui.radio_button_group_column(
								title:     'Weekdays'
								value:     app.week_days
								options:   options
								id_focus:  100
								on_select: fn [mut app] (value string, mut _ gui.Window) {
									app.week_days = value
								}
							),
							gui.rectangle(sizing: gui.fit_fill),
							gui.row(
								padding: gui.padding_none
								v_align: .middle
								content: [
									gui.button(
										content:  [gui.text(text: 'Reset')]
										on_click: fn (_ &gui.ButtonCfg, mut e gui.Event, mut w gui.Window) {
											w.date_picker_reset('example')
											mut app := w.state[DatePickerApp]()
											app.date_picker_times = [
												time.now()]
											app.monday_first = false
											app.show_adjacent_months = false
											app.select_multiple = false
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
