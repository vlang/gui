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
	weekdays_len         string = 'one'
	allow_monday         bool
	allow_tuesday        bool
	allow_wednesday      bool
	allow_thursday       bool
	allow_friday         bool
	allow_saturday       bool
	allow_sunday         bool
	allow_january        bool
	allow_february       bool
	allow_march          bool
	allow_april          bool
	allow_may            bool
	allow_june           bool
	allow_july           bool
	allow_august         bool
	allow_september      bool
	allow_october        bool
	allow_november       bool
	allow_december       bool
	// example allowed years
	allow_year_now  bool
	allow_year_last bool
	allow_year_next bool
	// example allowed dates
	allow_today          bool
	allow_yesterday      bool
	allow_first_of_month bool
	light_theme          bool
	use_system_font      bool
}

fn main() {
	mut window := gui.window(
		title:   'Date Picker Options Demo'
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
	app := window.state[DatePickerApp]()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		h_align: .center
		v_align: .middle
		spacing: gui.spacing_large
		content: [
			gui.row(
				v_align: .middle
				content: [
					example_date_picker(app, mut window),
				]
			),
			gui.row(
				padding: gui.padding_none
				spacing: gui.spacing_large * 2
				content: [
					options_group(app),
					weekdays_group(app),
					months_group(app),
					years_dates_group(app),
				]
			),
		]
	)
}

fn example_date_picker(app DatePickerApp, mut window gui.Window) gui.View {
	weekdays_len := match app.weekdays_len {
		'one' { gui.DatePickerWeekdayLen.one_letter }
		'three' { gui.DatePickerWeekdayLen.three_letter }
		else { gui.DatePickerWeekdayLen.full }
	}

	mut allowed_weekdays := []gui.DatePickerWeekdays{}
	unsafe { allowed_weekdays.flags.set(.noslices) }
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

	mut allowed_months := []gui.DatePickerMonths{}
	if app.allow_january {
		allowed_months << .january
	}
	if app.allow_february {
		allowed_months << .february
	}
	if app.allow_march {
		allowed_months << .march
	}
	if app.allow_april {
		allowed_months << .april
	}
	if app.allow_may {
		allowed_months << .may
	}
	if app.allow_june {
		allowed_months << .june
	}
	if app.allow_july {
		allowed_months << .july
	}
	if app.allow_august {
		allowed_months << .august
	}
	if app.allow_september {
		allowed_months << .september
	}
	if app.allow_october {
		allowed_months << .october
	}
	if app.allow_november {
		allowed_months << .november
	}
	if app.allow_december {
		allowed_months << .december
	}

	today := time.now()
	mut allowed_years := []int{}
	if app.allow_year_now {
		allowed_years << today.year
	}
	if app.allow_year_last {
		allowed_years << today.year - 1
	}
	if app.allow_year_next {
		allowed_years << today.year + 1
	}

	mut allowed_dates := []time.Time{}
	if app.allow_today {
		allowed_dates << today
	}
	if app.allow_yesterday {
		allowed_dates << today.add_days(-1)
	}
	if app.allow_first_of_month {
		allowed_dates << time.new(day: 1, month: today.month, year: today.year)
	}

	return window.date_picker(
		id:                       'example'
		dates:                    app.date_picker_dates
		hide_today_indicator:     app.hide_today_indicator
		monday_first_day_of_week: app.monday_first
		show_adjacent_months:     app.show_adjacent_months
		select_multiple:          app.select_multiple
		weekdays_len:             weekdays_len
		allowed_weekdays:         allowed_weekdays
		allowed_months:           allowed_months
		allowed_years:            allowed_years
		allowed_dates:            allowed_dates
		on_select:                fn (times []time.Time, mut e gui.Event, mut w gui.Window) {
			mut app := w.state[DatePickerApp]()
			app.date_picker_dates = times
			e.is_handled = true
		}
	)
}

fn options_group(app DatePickerApp) gui.View {
	return gui.column(
		padding: gui.padding_none
		content: [
			toggles_group(app),
			gui.rectangle(id: 'spacier'),
			gui.rectangle(height: 1, sizing: gui.fill_fit),
			gui.toggle(
				label:    'Use system font'
				select:   app.use_system_font
				on_click: fn (_ &gui.ToggleCfg, mut e gui.Event, mut w gui.Window) {
					mut app := w.state[DatePickerApp]()
					app.use_system_font = !app.use_system_font
					set_theme(mut w)
				}
			),
		]
	)
}

fn toggles_group(app DatePickerApp) gui.View {
	return gui.column(
		color:     gui.theme().color_active
		min_width: 200
		padding:   gui.theme().padding_large
		text:      ' Options  '
		content:   [
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
		]
	)
}

fn weekdays_group(app DatePickerApp) gui.View {
	return gui.column(
		padding: gui.padding_none
		content: [
			weekdays_len_group(app),
			gui.rectangle(color: gui.color_transparent),
			allowed_weekdays_group(app),
		]
	)
}

fn weekdays_len_group(app DatePickerApp) gui.View {
	options := [
		gui.radio_option('One letter', 'one'), // label, value,
		gui.radio_option('Three letter', 'three'),
		gui.radio_option('Full', 'full'),
	]

	return gui.radio_button_group_column(
		title:     ' Weekdays  '
		sizing:    gui.fill_fit
		value:     app.weekdays_len
		options:   options
		id_focus:  100
		on_select: fn (value string, mut w gui.Window) {
			mut app := w.state[DatePickerApp]()
			app.weekdays_len = value
		}
	)
}

fn allowed_weekdays_group(app DatePickerApp) gui.View {
	return gui.column(
		color:     gui.theme().color_active
		min_width: 200
		padding:   gui.theme().padding_large
		text:      ' Allowed weekdays  '
		content:   [
			gui.toggle(
				id:       'mon'
				label:    'Monday'
				select:   app.allow_monday
				on_click: click_allow_weekday_toggles
			),
			gui.toggle(
				id:       'tue'
				label:    'Tuesday'
				select:   app.allow_tuesday
				on_click: click_allow_weekday_toggles
			),
			gui.toggle(
				id:       'wed'
				label:    'Wednesday'
				select:   app.allow_wednesday
				on_click: click_allow_weekday_toggles
			),
			gui.toggle(
				id:       'thu'
				label:    'Thursday'
				select:   app.allow_thursday
				on_click: click_allow_weekday_toggles
			),
			gui.toggle(
				id:       'fri'
				label:    'Friday'
				select:   app.allow_friday
				on_click: click_allow_weekday_toggles
			),
			gui.toggle(
				id:       'sat'
				label:    'Saturday'
				select:   app.allow_saturday
				on_click: click_allow_weekday_toggles
			),
			gui.toggle(
				id:       'sun'
				label:    'Sunday'
				select:   app.allow_sunday
				on_click: click_allow_weekday_toggles
			),
		]
	)
}

fn click_allow_weekday_toggles(cfg &gui.ToggleCfg, mut e gui.Event, mut w gui.Window) {
	mut app := w.state[DatePickerApp]()
	match cfg.id {
		'mon' { app.allow_monday = !app.allow_monday }
		'tue' { app.allow_tuesday = !app.allow_tuesday }
		'wed' { app.allow_wednesday = !app.allow_wednesday }
		'thu' { app.allow_thursday = !app.allow_thursday }
		'fri' { app.allow_friday = !app.allow_friday }
		'sat' { app.allow_saturday = !app.allow_saturday }
		'sun' { app.allow_sunday = !app.allow_sunday }
		else {}
	}
	e.is_handled = true
}

fn months_group(app DatePickerApp) gui.View {
	return gui.column(
		text:      ' Allowed months  '
		color:     gui.theme().color_active
		min_width: 200
		padding:   gui.padding_large
		content:   [
			gui.toggle(
				id:       'jan'
				label:    'January'
				select:   app.allow_january
				on_click: click_allow_month_toggles
			),
			gui.toggle(
				id:       'feb'
				label:    'February'
				select:   app.allow_february
				on_click: click_allow_month_toggles
			),
			gui.toggle(
				id:       'mar'
				label:    'March'
				select:   app.allow_march
				on_click: click_allow_month_toggles
			),
			gui.toggle(
				id:       'apr'
				label:    'April'
				select:   app.allow_april
				on_click: click_allow_month_toggles
			),
			gui.toggle(
				id:       'may'
				label:    'May'
				select:   app.allow_may
				on_click: click_allow_month_toggles
			),
			gui.toggle(
				id:       'jun'
				label:    'June'
				select:   app.allow_june
				on_click: click_allow_month_toggles
			),
			gui.toggle(
				id:       'jul'
				label:    'July'
				select:   app.allow_july
				on_click: click_allow_month_toggles
			),
			gui.toggle(
				id:       'aug'
				label:    'August'
				select:   app.allow_august
				on_click: click_allow_month_toggles
			),
			gui.toggle(
				id:       'sep'
				label:    'September'
				select:   app.allow_september
				on_click: click_allow_month_toggles
			),
			gui.toggle(
				id:       'oct'
				label:    'October'
				select:   app.allow_october
				on_click: click_allow_month_toggles
			),
			gui.toggle(
				id:       'nov'
				label:    'November'
				select:   app.allow_november
				on_click: click_allow_month_toggles
			),
			gui.toggle(
				id:       'dec'
				label:    'December'
				select:   app.allow_december
				on_click: click_allow_month_toggles
			),
		]
	)
}

fn click_allow_month_toggles(cfg &gui.ToggleCfg, mut e gui.Event, mut w gui.Window) {
	mut app := w.state[DatePickerApp]()
	match cfg.id {
		'jan' { app.allow_january = !app.allow_january }
		'feb' { app.allow_february = !app.allow_february }
		'mar' { app.allow_march = !app.allow_march }
		'apr' { app.allow_april = !app.allow_april }
		'may' { app.allow_may = !app.allow_may }
		'jun' { app.allow_june = !app.allow_june }
		'jul' { app.allow_july = !app.allow_july }
		'aug' { app.allow_august = !app.allow_august }
		'sep' { app.allow_september = !app.allow_september }
		'oct' { app.allow_october = !app.allow_october }
		'nov' { app.allow_november = !app.allow_november }
		'dec' { app.allow_december = !app.allow_december }
		else {}
	}
	e.is_handled = true
}

fn years_dates_group(app DatePickerApp) gui.View {
	return gui.column(
		padding: gui.padding_none
		sizing:  gui.fit_fill
		content: [
			allowed_years_group(app),
			gui.rectangle(color: gui.color_transparent), // spacer
			allowed_dates_group(app),
			gui.rectangle(sizing: gui.fit_fill),
			gui.row(
				h_align: .right
				v_align: .middle
				padding: gui.padding_none
				sizing:  gui.fill_fit
				content: [
					gui.button(
						content:  [
							gui.text(text: 'Reset'),
						]
						on_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
							w.date_picker_reset('example')
							mut app := w.state[DatePickerApp]()
							app.date_picker_dates = [
								time.now(),
							]
							app.weekdays_len = 'one'
							app.monday_first = false
							app.show_adjacent_months = false
							app.hide_today_indicator = false
							app.select_multiple = false
							app.allow_monday = false
							app.allow_tuesday = false
							app.allow_wednesday = false
							app.allow_thursday = false
							app.allow_friday = false
							app.allow_saturday = false
							app.allow_sunday = false
							app.allow_january = false
							app.allow_february = false
							app.allow_march = false
							app.allow_april = false
							app.allow_may = false
							app.allow_june = false
							app.allow_july = false
							app.allow_august = false
							app.allow_september = false
							app.allow_october = false
							app.allow_november = false
							app.allow_december = false
							app.allow_year_now = false
							app.allow_year_last = false
							app.allow_year_next = false
							app.allow_today = false
							app.allow_yesterday = false
							app.allow_first_of_month = false
							e.is_handled = true
						}
					),
					toggle_theme(app),
				]
			),
		]
	)
}

fn allowed_years_group(app DatePickerApp) gui.View {
	return gui.column(
		text:      ' Allowed years  '
		color:     gui.theme().color_active
		min_width: 200
		padding:   gui.padding_large
		content:   [
			gui.text(text: 'Examples'),
			gui.toggle(
				id:       'year_now'
				label:    'This year'
				select:   app.allow_year_now
				on_click: click_allow_years_toggles
			),
			gui.toggle(
				id:       'year_last'
				label:    'Last year'
				select:   app.allow_year_last
				on_click: click_allow_years_toggles
			),
			gui.toggle(
				id:       'year_next'
				label:    'Next year'
				select:   app.allow_year_next
				on_click: click_allow_years_toggles
			),
		]
	)
}

fn click_allow_years_toggles(cfg &gui.ToggleCfg, mut e gui.Event, mut w gui.Window) {
	mut app := w.state[DatePickerApp]()
	match cfg.id {
		'year_now' { app.allow_year_now = !app.allow_year_now }
		'year_last' { app.allow_year_last = !app.allow_year_last }
		'year_next' { app.allow_year_next = !app.allow_year_next }
		else {}
	}
	e.is_handled = true
}

fn allowed_dates_group(app DatePickerApp) gui.View {
	return gui.column(
		text:      ' Allowed dates  '
		color:     gui.theme().color_active
		min_width: 200
		padding:   gui.padding_large
		content:   [
			gui.text(text: 'Examples'),
			gui.toggle(
				id:       'tdy'
				label:    'Today'
				select:   app.allow_today
				on_click: click_allow_dates_toggles
			),
			gui.toggle(
				id:       'ydy'
				label:    'Yesterday'
				select:   app.allow_yesterday
				on_click: click_allow_dates_toggles
			),
			gui.toggle(
				id:       'fdy'
				label:    'First of month'
				select:   app.allow_first_of_month
				on_click: click_allow_dates_toggles
			),
		]
	)
}

fn click_allow_dates_toggles(cfg &gui.ToggleCfg, mut e gui.Event, mut w gui.Window) {
	mut app := w.state[DatePickerApp]()
	match cfg.id {
		'tdy' { app.allow_today = !app.allow_today }
		'ydy' { app.allow_yesterday = !app.allow_yesterday }
		'fdy' { app.allow_first_of_month = !app.allow_first_of_month }
		else {}
	}
	e.is_handled = true
}

fn toggle_theme(app &DatePickerApp) gui.View {
	return gui.toggle(
		text_select:   gui.icon_moon
		text_unselect: gui.icon_sunny_o
		text_style:    gui.theme().icon3
		padding:       gui.padding_small
		select:        app.light_theme
		on_click:      fn (_ &gui.ToggleCfg, mut _ gui.Event, mut w gui.Window) {
			mut app := w.state[DatePickerApp]()
			app.light_theme = !app.light_theme
			set_theme(mut w)
		}
	)
}

fn create_system_font_theme(theme_cfg gui.ThemeCfg, text_style gui.TextStyle) gui.Theme {
	return gui.theme_maker(gui.ThemeCfg{
		...theme_cfg
		text_style: gui.TextStyle{
			...text_style
			family: ''
		}
	})
}

fn set_theme(mut window gui.Window) {
	app := window.state[DatePickerApp]()
	theme := if app.light_theme {
		if app.use_system_font {
			create_system_font_theme(gui.theme_light_bordered_cfg, gui.theme_light_bordered_cfg.text_style)
		} else {
			gui.theme_light_bordered
		}
	} else {
		if app.use_system_font {
			create_system_font_theme(gui.theme_dark_bordered_cfg, gui.theme_dark_bordered_cfg.text_style)
		} else {
			gui.theme_dark_bordered
		}
	}
	window.set_theme(theme)
}
