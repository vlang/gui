module gui

import time
import log

// DatePickerWeekdays is used in allowed_weekdays property of [date_picker](date_picker)
pub enum DatePickerWeekdays {
	monday = 1
	tuesday
	wednesday
	thursday
	friday
	saturday
	sunday
}

// DatePickerMonths is used in allowed_monthgs property of [date_picker](date_picker)
pub enum DatePickerMonths {
	january = 1
	february
	march
	april
	may
	june
	july
	august
	september
	october
	november
	december
}

// DatePickerWeekdayLen is used in the weekdays property of [date_picker](date_picker)
pub enum DatePickerWeekdayLen {
	one_letter
	three_letter
	full
}

struct DatePickerState {
pub mut:
	show_year_month_picker bool
	calendar_width         f32 // width and height needed to fix the size of the view, so showing
	calendar_height        f32 // select months/years does not cause the view to change size.
	view_month             int // displayed month
	view_year              int // displayed year
	cell_size              f32 = 40
	month_width            f32 = 70
}

// DatePickerCfg configures a [date_picker](#date_picker)
pub struct DatePickerCfg {
pub:
	id                       string      @[required] // unique only to other date_pickers
	dates                    []time.Time @[required]
	id_scroll                u32 = u32(459342148) // used in year-month picker
	disabled                 bool
	invisible                bool
	select_multiple          bool
	allowed_weekdays         []DatePickerWeekdays
	allowed_months           []DatePickerMonths
	allowed_years            []int
	allowed_dates            []time.Time
	weekdays_len             DatePickerWeekdayLen                    = gui_theme.date_picker_style.weekdays_len
	hide_today_indicator     bool                                    = gui_theme.date_picker_style.hide_today_indicator
	monday_first_day_of_week bool                                    = gui_theme.date_picker_style.monday_first_day_of_week
	show_adjacent_months     bool                                    = gui_theme.date_picker_style.show_adjacent_months
	cell_spacing             f32                                     = gui_theme.date_picker_style.cell_spacing
	color                    Color                                   = gui_theme.date_picker_style.color
	color_hover              Color                                   = gui_theme.date_picker_style.color_hover
	color_focus              Color                                   = gui_theme.date_picker_style.color_focus
	color_click              Color                                   = gui_theme.date_picker_style.color_click
	color_border             Color                                   = gui_theme.date_picker_style.color_border
	color_border_focus       Color                                   = gui_theme.date_picker_style.color_border_focus
	color_select             Color                                   = gui_theme.date_picker_style.color_select
	fill                     bool                                    = gui_theme.date_picker_style.fill
	fill_border              bool                                    = gui_theme.date_picker_style.fill_border
	padding                  Padding                                 = gui_theme.date_picker_style.padding
	padding_border           Padding                                 = gui_theme.date_picker_style.padding_border
	radius                   f32                                     = gui_theme.date_picker_style.radius
	radius_border            f32                                     = gui_theme.date_picker_style.radius_border
	text_style               TextStyle                               = gui_theme.date_picker_style.text_style
	on_select                fn ([]time.Time, mut Event, mut Window) = unsafe { nil }
}

// date_picker creates a date-picker view from the given [DatePickerCfg](DatePickerCfg)
pub fn (mut window Window) date_picker(cfg DatePickerCfg) View {
	mut state := window.view_state.date_picker_state[cfg.id]
	if state.view_year == 0 {
		now := time.now()
		v_time := if cfg.dates.len > 0 { cfg.dates[0] } else { date(now.day, now.month, now.year) }
		state.view_month = v_time.month
		state.view_year = v_time.year
	}
	state.cell_size = cfg.cell_size(window)
	state.month_width = cfg.month_picker_width(window)
	window.view_state.date_picker_state[cfg.id] = state

	return row(
		name:      'date_picker border'
		fill:      cfg.fill_border
		color:     cfg.color_border
		invisible: cfg.invisible
		padding:   cfg.padding_border
		content:   [
			column(
				fill:    cfg.fill
				color:   cfg.color
				padding: cfg.padding
				name:    'date_picker interior'
				content: [
					cfg.controls(state),
					cfg.body(state),
				]
			),
		]
	)
}

pub fn (mut window Window) date_picker_reset(id string) {
	window.view_state.date_picker_state[id] = DatePickerState{}
}

fn (cfg DatePickerCfg) controls(state DatePickerState) View {
	return row(
		name:    'date_picker controls'
		v_align: .middle
		padding: padding_none
		sizing:  fill_fit
		content: [
			cfg.month_picker(state),
			rectangle(sizing: fill_fit),
			cfg.prev_month(state),
			cfg.next_month(state),
		]
	)
}

fn (cfg DatePickerCfg) month_picker(state DatePickerState) View {
	return button(
		color_border: color_transparent
		content:      [text(text: view_time(state).custom_format('MMMM YYYY'))]
		on_click:     fn [cfg] (_ &ButtonCfg, mut e Event, mut w Window) {
			mut state := w.view_state.date_picker_state[cfg.id]
			state.show_year_month_picker = !state.show_year_month_picker
			w.view_state.date_picker_state[cfg.id] = state
			e.is_handled = true
		}
	)
}

fn (cfg DatePickerCfg) prev_month(state DatePickerState) View {
	return button(
		disabled:     state.show_year_month_picker
		color_border: color_transparent
		content:      [text(text: icon_arrow_left, text_style: gui_theme.icon3)]
		on_click:     fn [cfg] (_ &ButtonCfg, mut e Event, mut w Window) {
			mut dps := w.view_state.date_picker_state[cfg.id]
			dps.view_month = dps.view_month - 1
			if dps.view_month < 1 {
				dps.view_month = 12
			}
			if dps.view_month == 12 {
				dps.view_year -= 1
			}
			w.view_state.date_picker_state[cfg.id] = dps
		}
	)
}

fn (cfg DatePickerCfg) next_month(state DatePickerState) View {
	return button(
		disabled:     state.show_year_month_picker
		color_border: color_transparent
		content:      [text(text: icon_arrow_right, text_style: gui_theme.icon3)]
		on_click:     fn [cfg] (_ &ButtonCfg, mut e Event, mut w Window) {
			mut dps := w.view_state.date_picker_state[cfg.id]
			dps.view_month = dps.view_month + 1
			if dps.view_month > 12 {
				dps.view_month = 1
			}
			if dps.view_month == 1 {
				dps.view_year += 1
			}
			w.view_state.date_picker_state[cfg.id] = dps
		}
	)
}

// body is either a calendar, year-month-picker
fn (cfg DatePickerCfg) body(state DatePickerState) View {
	return match state.show_year_month_picker {
		true { cfg.year_month_picker(state) }
		else { cfg.calendar(state) }
	}
}

fn (cfg DatePickerCfg) calendar(state DatePickerState) View {
	return column(
		name:         'date_picker calendar'
		padding:      padding_none
		spacing:      0
		content:      [
			cfg.weekdays(state),
			cfg.month(state),
		]
		amend_layout: fn [cfg] (mut layout Layout, mut w Window) {
			mut state := w.view_state.date_picker_state[cfg.id]
			state.calendar_width = layout.shape.width
			state.calendar_height = layout.shape.height
			w.view_state.date_picker_state[cfg.id] = state
		}
	)
}

fn (cfg DatePickerCfg) weekdays(state DatePickerState) View {
	mut weekdays := []View{}
	weekdays_one := ['S', 'M', 'T', 'W', 'T', 'F', 'S']!
	weekdays_three := ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']!
	weekdays_full := ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']!

	weekdays_names := match cfg.weekdays_len {
		.one_letter { weekdays_one }
		.three_letter { weekdays_three }
		.full { weekdays_full }
	}
	for i in 0 .. 7 {
		mut weekday := match cfg.monday_first_day_of_week {
			true { weekdays_names[(i + 1) % 7] }
			else { weekdays_names[i] }
		}

		is_disabled := if cfg.allowed_weekdays.len > 0 {
			// Sunday is 7 and not 0. Not sure if that's standard but not
			// what I expected. Rather than change all the other logic here,
			// handle the edge case in an error handler. (sigh)
			wd := DatePickerWeekdays.from(i) or { DatePickerWeekdays.sunday }
			wd !in cfg.allowed_weekdays
		} else {
			false
		}

		weekdays << button(
			color:        color_transparent
			color_border: color_transparent
			disabled:     is_disabled
			min_width:    state.cell_size
			max_width:    state.cell_size
			padding:      padding_two
			content:      [text(text: weekday)]
		)
	}
	return row(
		name:    'date_picker weekdays'
		spacing: cfg.cell_spacing
		padding: padding_none
		content: weekdays
	)
}

fn (cfg DatePickerCfg) month(state DatePickerState) View {
	mut month := []View{}

	today := time.now()
	vt := view_time(state)
	days_in_month := time.days_in_month(vt.month, vt.year) or { 0 }
	first_day_of_month := time.day_of_week(vt.year, vt.month, 1)
	last_month := if vt.month == 1 { 12 } else { vt.month - 1 }
	year := if vt.month == 12 { vt.year - 1 } else { vt.year }
	days_prev_month := time.days_in_month(last_month, year) or { 0 }

	mut selected_times := []time.Time{}
	if cfg.select_multiple {
		selected_times << dates(cfg.dates)
	} else if cfg.dates.len > 0 {
		selected_times << date(cfg.dates[0].day, cfg.dates[0].month, cfg.dates[0].year)
	} else {
		selected_times << date(today.day, today.month, today.year)
	}

	mut count := match first_day_of_month {
		1 { 0 } // Mon
		2 { -1 } // Tue
		3 { -2 } // Wed
		4 { -3 } // Thu
		5 { -4 } // Fri
		6 { -5 } // Sat
		7 { 1 } // Sun
		else { first_day_of_month }
	}
	if cfg.monday_first_day_of_week {
		count += 1
		if count > 1 {
			count = -5
		}
	}

	for _ in 0 .. 6 { // six weeks to display a month
		mut week := []View{}
		for _ in 0 .. 7 { // 7 days in a week
			day := match true {
				count <= 0 {
					if cfg.show_adjacent_months { (days_prev_month - count).str() } else { '' }
				}
				count > days_in_month {
					if cfg.show_adjacent_months { (count - days_in_month).str() } else { '' }
				}
				else {
					count.str()
				}
			}

			is_today := count == today.day && vt.month == today.month && vt.year == today.year
				&& !cfg.hide_today_indicator
			dt := date(count, vt.month, vt.year)
			is_selected_day := dt in selected_times
			is_disabled := cfg.disabled(dt, state)

			color := if is_selected_day { cfg.color_select } else { cfg.color }
			color_border := if is_today { cfg.text_style.color } else { color_transparent }
			color_hover := if is_selected_day { cfg.color_select } else { cfg.color_hover }

			week << button(
				color:          color
				color_border:   color_border
				color_click:    cfg.color_select
				color_hover:    color_hover
				disabled:       count <= 0 || count > days_in_month || is_disabled
				min_width:      state.cell_size
				max_width:      state.cell_size
				max_height:     state.cell_size
				padding_border: padding_two
				content:        [text(text: day)]
				on_click:       fn [cfg, count, state] (_ &ButtonCfg, mut e Event, mut w Window) {
					if cfg.on_select != unsafe { nil } {
						selected_dates := cfg.update_selections(count, state)
						cfg.on_select(selected_dates, mut e, mut w)
					}
				}
			)
			count += 1
		}
		month << row(
			padding: padding_none
			spacing: cfg.cell_spacing
			content: week
		)
	}
	return column(
		name:    'date_picker month'
		padding: padding_none
		spacing: cfg.cell_spacing
		content: month
	)
}

fn (cfg DatePickerCfg) update_selections(day int, state DatePickerState) []time.Time {
	selected := date(day, state.view_month, state.view_year)
	if !cfg.select_multiple {
		return [selected]
	}

	mut selections := []time.Time{}
	selections << dates(cfg.dates)
	if selected in selections {
		selections = selections.filter(it != selected)
	} else {
		selections << selected
	}
	return selections
}

fn view_time(state DatePickerState) time.Time {
	return date(1, state.view_month, state.view_year)
}

fn date(day int, month int, year int) time.Time {
	if day < 1 {
		return time.unix(time.absolute_zero_year)
	}
	return time.new(day: day, month: month, year: year)
}

fn dates(times []time.Time) []time.Time {
	return times.map(date(it.day, it.month, it.year))
}

fn (cfg DatePickerCfg) cell_size(w &Window) f32 {
	w_size := match cfg.weekdays_len {
		.one_letter { get_text_width_no_cache('W', cfg.text_style, w) }
		.three_letter { get_text_width_no_cache('Wed', cfg.text_style, w) }
		.full { get_text_width_no_cache('Wednesday', cfg.text_style, w) }
	}
	d_size := get_text_width_no_cache('00', cfg.text_style, w)
	return f32_max(w_size, d_size) + gui_theme.button_style.padding.width() + padding_two.width()
}

fn (cfg DatePickerCfg) month_picker_width(w &Window) f32 {
	return get_text_width_no_cache('May', cfg.text_style, w) +
		gui_theme.button_style.padding.width() + gui_theme.button_style.padding_border.width()
}

fn (cfg DatePickerCfg) disabled(date time.Time, state DatePickerState) bool {
	if cfg.allowed_weekdays.len > 0 {
		dow := DatePickerWeekdays.from(time.day_of_week(date.year, date.month, date.day)) or {
			log.error(err.msg())
			return true
		}
		if dow !in cfg.allowed_weekdays {
			return true
		}
	}
	if cfg.allowed_months.len > 0 {
		month := DatePickerMonths.from(state.view_month) or {
			log.error(err.msg())
			return true
		}
		if month !in cfg.allowed_months {
			return true
		}
	}
	return false
}

fn (cfg DatePickerCfg) year_month_picker(state DatePickerState) View {
	mut rows := []View{}
	variants := font_variants(gui_theme.text_style)
	bold_style := TextStyle{
		...cfg.text_style
		family: variants.bold
	}
	bold_invisible_style := TextStyle{
		...bold_style
		color: color_transparent
	}

	for year in (state.view_year - 20) .. (state.view_year + 20) {
		rows << row(
			v_align: .middle
			padding: padding_none
			spacing: gui_theme.spacing_small
			content: [
				text(text: year.str(), text_style: bold_style),
				rectangle(width: 0),
				cfg.button_month(.january, year, state.month_width),
				cfg.button_month(.february, year, state.month_width),
				cfg.button_month(.march, year, state.month_width),
				cfg.button_month(.april, year, state.month_width),
			]
		)
		rows << row(
			v_align: .middle
			padding: padding_none
			spacing: gui_theme.spacing_small
			content: [
				text(
					text:       year.str()
					text_style: bold_invisible_style
				),
				rectangle(width: 0),
				cfg.button_month(.may, year, state.month_width),
				cfg.button_month(.june, year, state.month_width),
				cfg.button_month(.july, year, state.month_width),
				cfg.button_month(.august, year, state.month_width),
			]
		)
		rows << row(
			v_align: .middle
			padding: padding_none
			spacing: gui_theme.spacing_small
			content: [
				text(
					text:       year.str()
					text_style: bold_invisible_style
				),
				rectangle(width: 0),
				cfg.button_month(.september, year, state.month_width),
				cfg.button_month(.october, year, state.month_width),
				cfg.button_month(.november, year, state.month_width),
				cfg.button_month(.december, year, state.month_width),
			]
		)
	}

	return row(
		name:       'date_picker select_year'
		h_align:    .center
		v_align:    .middle
		min_width:  state.calendar_width
		max_width:  state.calendar_width
		min_height: state.calendar_height
		max_height: state.calendar_height
		padding:    padding_none
		spacing:    gui_theme.spacing_small
		content:    [
			column(
				id_scroll: cfg.id_scroll
				sizing:    fit_fill
				padding:   Padding{
					...padding_none
					right: gui_theme.padding_large.right
				}
				spacing:   gui_theme.spacing_small
				content:   rows
			),
		]
	)
}

fn (cfg DatePickerCfg) button_month(month DatePickerMonths, year int, width f32) View {
	int_month := int(month)
	month_str := time.months_string[(int_month - 1) * 3..int_month * 3]
	mut disabled := cfg.allowed_months.len > 0 && month !in cfg.allowed_months
	return button(
		disabled:  disabled
		min_width: width
		max_width: width
		on_click:  fn [cfg, int_month, year] (_ &ButtonCfg, mut e Event, mut w Window) {
			mut state := w.view_state.date_picker_state[cfg.id]
			state.view_month = int_month
			state.view_year = year
			state.show_year_month_picker = false
			w.view_state.date_picker_state[cfg.id] = state
			e.is_handled = true
		}
		content:   [
			text(text: month_str),
		]
	)
}
