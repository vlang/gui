import gui
import time

// Date Picker Example
// =============================

@[heap]
struct DatePickerApp {
pub mut:
	date_picker_dates    []time.Time
	hide_today_indicator bool
	monday_first         bool
	show_adjacent_months bool
	select_multiple      bool
	week_days_len        string = 'one'
	allow_monday         bool
	allow_tuesday        bool
	allow_wednesday      bool
	allow_thursday       bool
	allow_friday         bool
	allow_saturday       bool
	allow_sunday         bool
	light_theme          bool
}

fn main() {
	mut window := gui.window(
		title:   'Date Picker Demo'
		state:   &DatePickerApp{}
		width:   1200
		height:  800
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

	week_days_len := match app.week_days_len {
		'one' { gui.DatePickerWeekdayLen.one_letter }
		'three' { gui.DatePickerWeekdayLen.three_letter }
		else { gui.DatePickerWeekdayLen.full }
	}

	// Enabling only weekdays disables weekends.
	mut allowed_weekdays := []gui.DatePickerWeekdays{}
	if app.allow_monday {
		allowed_weekdays << .monday
	}
	if app.allow_tuesday {
		allowed_weekdays << .tuesday
	}
	if app.allow_wednesday {
		allowed_weekdays << .wednesday
	}
	if app.allow_thursday {
		allowed_weekdays << .thursday
	}
	if app.allow_friday {
		allowed_weekdays << .friday
	}
	if app.allow_saturday {
		allowed_weekdays << .saturday
	}
	if app.allow_sunday {
		allowed_weekdays << .sunday
	}

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		h_align: .center
		v_align: .middle
		content: [
			gui.row(
				v_align: .middle
				spacing: gui.spacing_large
				content: [
					window.date_picker(
						id:                       'example'
						dates:                    app.date_picker_dates
						hide_today_indicator:     app.hide_today_indicator
						monday_first_day_of_week: app.monday_first
						show_adjacent_months:     app.show_adjacent_months
						select_multiple:          app.select_multiple
						week_days_len:            week_days_len
						allowed_weekdays:         allowed_weekdays
						on_select:                fn (times []time.Time, mut e gui.Event, mut w gui.Window) {
							mut app := w.state[DatePickerApp]()
							app.date_picker_dates = times
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
								sizing:    gui.fill_fit
								value:     app.week_days_len
								options:   options
								id_focus:  100
								on_select: fn [mut app] (value string, mut _ gui.Window) {
									app.week_days_len = value
								}
							),
							gui.rectangle(color: gui.color_transparent),
							gui.column(
								color:   gui.theme().color_active
								sizing:  gui.fill_fit
								padding: gui.theme().padding_large
								text:    'Allowed weekdays'
								content: [
									gui.toggle(
										label:    'Monday'
										select:   app.allow_monday
										on_click: click_weekday_toggle
									),
									gui.toggle(
										label:    'Tuesday'
										select:   app.allow_tuesday
										on_click: click_weekday_toggle
									),
									gui.toggle(
										label:    'Wednesday'
										select:   app.allow_wednesday
										on_click: click_weekday_toggle
									),
									gui.toggle(
										label:    'Thursday'
										select:   app.allow_thursday
										on_click: click_weekday_toggle
									),
									gui.toggle(
										label:    'Friday'
										select:   app.allow_friday
										on_click: click_weekday_toggle
									),
									gui.toggle(
										label:    'Saturday'
										select:   app.allow_saturday
										on_click: click_weekday_toggle
									),
									gui.toggle(
										label:    'Sunday'
										select:   app.allow_sunday
										on_click: click_weekday_toggle
									),
								]
							),
							gui.row(
								padding: gui.padding_none
								v_align: .middle
								content: [
									gui.button(
										content:  [gui.text(text: 'Reset')]
										on_click: fn (_ &gui.ButtonCfg, mut e gui.Event, mut w gui.Window) {
											w.date_picker_reset('example')
											mut app := w.state[DatePickerApp]()
											app.date_picker_dates = [
												time.now()]
											app.monday_first = false
											app.show_adjacent_months = false
											app.select_multiple = false
											app.allow_monday = false
											app.allow_tuesday = false
											app.allow_wednesday = false
											app.allow_thursday = false
											app.allow_friday = false
											app.allow_saturday = false
											app.allow_sunday = false
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

fn click_weekday_toggle(cfg &gui.ToggleCfg, mut _ gui.Event, mut w gui.Window) {
	mut app := w.state[DatePickerApp]()
	match cfg.label {
		'Monday' { app.allow_monday = !app.allow_monday }
		'Tuesday' { app.allow_tuesday = !app.allow_tuesday }
		'Wednesday' { app.allow_wednesday = !app.allow_wednesday }
		'Thursday' { app.allow_thursday = !app.allow_thursday }
		'Friday' { app.allow_friday = !app.allow_friday }
		'Saturday' { app.allow_saturday = !app.allow_saturday }
		'Sunday' { app.allow_sunday = !app.allow_sunday }
		else {}
	}
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
