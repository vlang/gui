module gui

import time
import log

// DatePickerWeekdays is used in allowed_weekdays property of [date_picker](#date_picker)
pub enum DatePickerWeekdays as u8 {
	monday = 1
	tuesday
	wednesday
	thursday
	friday
	saturday
	sunday
}

// DatePickerMonths is used in allowed_months property of [date_picker](#date_picker)
pub enum DatePickerMonths as u16 {
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

// DatePickerWeekdayLen is used in the weekdays property of [date_picker](#date_picker)
pub enum DatePickerWeekdayLen as u8 {
	one_letter
	three_letter
	full
}

const date_picker_weekdays_one = ['S', 'M', 'T', 'W', 'T', 'F', 'S']!
const date_picker_weekdays_three = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']!
const date_picker_weekdays_full = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday',
	'Saturday']!

@[minify]
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

// date_picker creates a date-picker view from the given [DatePickerCfg](#DatePickerCfg)
pub fn (mut window Window) date_picker(cfg DatePickerCfg) View {
	mut state := window.view_state.date_picker_state[cfg.id]
	if state.view_year == 0 {
		now := time.now()
		v_time := if cfg.dates.len > 0 { cfg.dates[0] } else { date(now.day, now.month, now.year) }
		state.view_month = v_time.month
		state.view_year = v_time.year
	}
	state.cell_size = cfg.cell_size(mut window)
	state.month_width = cfg.month_picker_width(mut window)
	window.view_state.date_picker_state[cfg.id] = state

	return row(
		name:      'date_picker border'
		fill:      cfg.fill_border
		color:     cfg.color_border
		invisible: cfg.invisible
		border_width: cfg.border_width

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

// DatePickerCfg configures a [date_picker](#date_picker)
pub struct DatePickerCfg {
pub:
	id                       string      @[required] // unique only to other date_pickers
	dates                    []time.Time @[required]
	allowed_weekdays         []DatePickerWeekdays // [link](#DatePickerWeekdays)
	allowed_months           []DatePickerMonths   // [link](#DatePickerMonths)
	allowed_years            []int
	allowed_dates            []time.Time
	on_select                fn ([]time.Time, mut Event, mut Window) = unsafe { nil }
	weekdays_len             DatePickerWeekdayLen                    = gui_theme.date_picker_style.weekdays_len // [link](#DatePickerWeekdayLen)
	text_style               TextStyle = gui_theme.date_picker_style.text_style
	color                    Color     = gui_theme.date_picker_style.color
	color_hover              Color     = gui_theme.date_picker_style.color_hover
	color_focus              Color     = gui_theme.date_picker_style.color_focus
	color_click              Color     = gui_theme.date_picker_style.color_click
	color_border             Color     = gui_theme.date_picker_style.color_border
	color_border_focus       Color     = gui_theme.date_picker_style.color_border_focus
	color_select             Color     = gui_theme.date_picker_style.color_select
	padding                  Padding   = gui_theme.date_picker_style.padding
	border_width           f32       = gui_theme.date_picker_style.border_width

	cell_spacing             f32       = gui_theme.date_picker_style.cell_spacing
	radius                   f32       = gui_theme.date_picker_style.radius
	radius_border            f32       = gui_theme.date_picker_style.radius_border
	disabled                 bool
	invisible                bool
	select_multiple          bool
	fill                     bool = gui_theme.date_picker_style.fill
	fill_border              bool = gui_theme.date_picker_style.fill_border
	hide_today_indicator     bool = gui_theme.date_picker_style.hide_today_indicator
	monday_first_day_of_week bool = gui_theme.date_picker_style.monday_first_day_of_week
	show_adjacent_months     bool = gui_theme.date_picker_style.show_adjacent_months
}

// date_picker_reset clears the internal view state of the given date picker
pub fn (mut window Window) date_picker_reset(id string) {
	window.view_state.date_picker_state[id] = DatePickerState{}
}

// controls creates the top row of navigation buttons (month/year picker, prev/next month)
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

// month_picker creates the button that toggles the month/year selection view
fn (cfg DatePickerCfg) month_picker(state DatePickerState) View {
	id := cfg.id
	return button(
		color_border: color_transparent
		content:      [text(text: view_time(state).custom_format('MMMM YYYY'))]
		on_click:     fn [id] (_ &Layout, mut e Event, mut w Window) {
			mut state := w.view_state.date_picker_state[id]
			state.show_year_month_picker = !state.show_year_month_picker
			w.view_state.date_picker_state[id] = state
			if state.show_year_month_picker {
				w.set_id_focus(date_picker_roller_id_focus)
			}
			e.is_handled = true
		}
	)
}

fn (cfg DatePickerCfg) prev_month(state DatePickerState) View {
	id := cfg.id
	return button(
		disabled:     state.show_year_month_picker
		color_border: color_transparent
		content:      [text(text: icon_arrow_left, text_style: gui_theme.icon3)]
		on_click:     fn [id] (_ &Layout, mut e Event, mut w Window) {
			mut dps := w.view_state.date_picker_state[id]
			dps.view_month = dps.view_month - 1
			if dps.view_month < 1 {
				dps.view_month = 12
			}
			if dps.view_month == 12 {
				dps.view_year -= 1
			}
			w.view_state.date_picker_state[id] = dps
		}
	)
}

fn (cfg DatePickerCfg) next_month(state DatePickerState) View {
	id := cfg.id
	return button(
		disabled:     state.show_year_month_picker
		color_border: color_transparent
		content:      [text(text: icon_arrow_right, text_style: gui_theme.icon3)]
		on_click:     fn [id] (_ &Layout, mut e Event, mut w Window) {
			mut dps := w.view_state.date_picker_state[id]
			dps.view_month = dps.view_month + 1
			if dps.view_month > 12 {
				dps.view_month = 1
			}
			if dps.view_month == 1 {
				dps.view_year += 1
			}
			w.view_state.date_picker_state[id] = dps
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
	id := cfg.id
	return column(
		name:         'date_picker calendar'
		padding:      padding_none
		spacing:      0
		content:      [
			cfg.weekdays(state),
			cfg.month(state),
		]
		amend_layout: fn [id] (mut layout Layout, mut w Window) {
			mut state := w.view_state.date_picker_state[id]
			state.calendar_width = layout.shape.width
			state.calendar_height = layout.shape.height
			w.view_state.date_picker_state[id] = state
		}
	)
}

fn (cfg DatePickerCfg) weekdays(state DatePickerState) View {
	mut weekdays := []View{cap: 7}
	weekdays_names := match cfg.weekdays_len {
		.one_letter { date_picker_weekdays_one }
		.three_letter { date_picker_weekdays_three }
		.full { date_picker_weekdays_full }
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
	mut month := []View{cap: 6}

	today := time.now()
	vt := view_time(state)
	days_in_month := time.days_in_month(vt.month, vt.year) or { 0 }
	first_day_of_month := time.day_of_week(vt.year, vt.month, 1)
	last_month := if vt.month == 1 { 12 } else { vt.month - 1 }
	year := if vt.month == 12 { vt.year - 1 } else { vt.year }
	days_prev_month := time.days_in_month(last_month, year) or { 0 }

	// Calculate the offset for the first day of the month.
	// 1 = Monday, 7 = Sunday.
	// We want to map this to an offset where Monday starts at 0 (or similar depending on week start).
	// The offsets below shift the starting position in the 7-cell row.
	// e.g. if the month starts on Tuesday (2), we want to skip 1 cell, so offset is -1.
	mut count := match cfg.monday_first_day_of_week {
		true { 2 - first_day_of_month }
		else { 1 - (first_day_of_month % 7) }
	}

	for _ in 0 .. 6 { // six weeks to display a month
		mut week := []View{cap: 7}
		for _ in 0 .. 7 { // 7 days in a week
			day := match true {
				count <= 0 {
					if cfg.show_adjacent_months { (days_prev_month + count).str() } else { '' }
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

			// Check selection without allocating new arrays
			mut is_selected_day := false
			if count > 0 && count <= days_in_month {
				// We only check exact date matches for valid days in this month
				if cfg.select_multiple {
					for d in cfg.dates {
						if d.day == count && d.month == vt.month && d.year == vt.year {
							is_selected_day = true
							break
						}
					}
				} else {
					if cfg.dates.len > 0 {
						d := cfg.dates[0]
						if d.day == count && d.month == vt.month && d.year == vt.year {
							is_selected_day = true
						}
					} else {
						// Default to today if nothing selected
						if count == today.day && vt.month == today.month && vt.year == today.year {
							is_selected_day = true
						}
					}
				}
			}

			dt := date(count, vt.month, vt.year)
			is_disabled := cfg.disabled(dt, state)

			color := if is_selected_day { cfg.color_select } else { cfg.color }
			color_border := if is_today { cfg.text_style.color } else { color_transparent }
			color_hover := if is_selected_day { cfg.color_select } else { cfg.color_hover }
			on_select := cfg.on_select
			update_selections := cfg.update_selections

			week << button(
				color:          color
				color_border:   color_border
				color_click:    cfg.color_select
				color_hover:    color_hover
				disabled:       count <= 0 || count > days_in_month || is_disabled
				min_width:      state.cell_size
				max_width:      state.cell_size
				max_height:     state.cell_size
				border_width:   2
				content:        [text(text: day)]
				on_click:       fn [on_select, update_selections, count, state] (_ &Layout, mut e Event, mut w Window) {
					if on_select != unsafe { nil } {
						selected_dates := update_selections(count, state)
						on_select(selected_dates, mut e, mut w)
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

fn (cfg DatePickerCfg) cell_size(mut w Window) f32 {
	w_size := match cfg.weekdays_len {
		.one_letter { text_width('W', cfg.text_style, mut w) }
		.three_letter { text_width('Wed', cfg.text_style, mut w) }
		.full { text_width('Wednesday', cfg.text_style, mut w) }
	}
	d_size := text_width('00', cfg.text_style, mut w)
	return f32_max(w_size, d_size) + gui_theme.button_style.padding.width() + padding_two.width()
}

fn (cfg DatePickerCfg) month_picker_width(mut w Window) f32 {
	return text_width('May', cfg.text_style, mut w) + gui_theme.button_style.padding.width() +
		(gui_theme.button_style.border_width * 2)
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
	if cfg.allowed_years.len > 0 {
		if state.view_year !in cfg.allowed_years {
			return true
		}
	}
	if cfg.allowed_dates.len > 0 {
		for allowed in cfg.allowed_dates {
			if allowed.day == date.day && allowed.month == date.month && allowed.year == date.year {
				return false
			}
		}
		return true
	}
	return false
}

const date_picker_roller_id = '23995934'
const date_picker_roller_id_focus = 23995934

fn (cfg DatePickerCfg) year_month_picker(state DatePickerState) View {
	id := cfg.id

	return column(
		name:       'date_picker select_month_year'
		h_align:    .center
		v_align:    .middle
		min_width:  state.calendar_width
		max_width:  state.calendar_width
		min_height: state.calendar_height
		max_height: state.calendar_height
		padding:    padding_none
		content:    [
			date_picker_roller(
				id:            cfg.id + date_picker_roller_id
				id_focus:      date_picker_roller_id_focus
				display_mode:  .month_year
				color:         cfg.color
				selected_date: time.new(
					month: state.view_month
					year:  state.view_year
				)
				on_change:     fn [id] (t time.Time, mut w Window) {
					mut state := w.view_state.date_picker_state[id]
					state.view_month = t.month
					state.view_year = t.year
					w.view_state.date_picker_state[id] = state
				}
			),
		]
	)
}
