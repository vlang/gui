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
	mut state := window.view_state.date_picker_state.get(cfg.id) or { DatePickerState{} }
	if state.view_year == 0 {
		now := time.now()
		v_time := if cfg.dates.len > 0 { cfg.dates[0] } else { date(now.day, now.month, now.year) }
		state.view_month = v_time.month
		state.view_year = v_time.year
	}
	state.cell_size = cfg.cell_size(mut window)
	state.month_width = cfg.month_picker_width(mut window)
	window.view_state.date_picker_state.set(cfg.id, state)

	return column(
		name:         'date_picker'
		color:        cfg.color
		color_border: cfg.color_border
		size_border:  cfg.size_border
		radius:       cfg.radius
		padding:      cfg.padding
		invisible:    cfg.invisible
		content:      [
			cfg.controls(state),
			cfg.body(state),
		]
	)
}

// DatePickerCfg configures a [date_picker](#date_picker)
pub struct DatePickerCfg {
pub:
	id                 string      @[required] // unique only to other date_pickers
	dates              []time.Time @[required]
	allowed_weekdays   []DatePickerWeekdays // [link](#DatePickerWeekdays)
	allowed_months     []DatePickerMonths   // [link](#DatePickerMonths)
	allowed_years      []int
	allowed_dates      []time.Time
	on_select          fn ([]time.Time, mut Event, mut Window) = unsafe { nil }
	weekdays_len       DatePickerWeekdayLen                    = gui_theme.date_picker_style.weekdays_len // [link](#DatePickerWeekdayLen)
	text_style         TextStyle = gui_theme.date_picker_style.text_style
	color              Color     = gui_theme.date_picker_style.color
	color_hover        Color     = gui_theme.date_picker_style.color_hover
	color_focus        Color     = gui_theme.date_picker_style.color_focus
	color_click        Color     = gui_theme.date_picker_style.color_click
	color_border       Color     = gui_theme.date_picker_style.color_border
	color_border_focus Color     = gui_theme.date_picker_style.color_border_focus
	color_select       Color     = gui_theme.date_picker_style.color_select
	padding            Padding   = gui_theme.date_picker_style.padding
	size_border        f32       = gui_theme.date_picker_style.size_border

	cell_spacing             f32 = gui_theme.date_picker_style.cell_spacing
	radius                   f32 = gui_theme.date_picker_style.radius
	radius_border            f32 = gui_theme.date_picker_style.radius_border
	disabled                 bool
	invisible                bool
	select_multiple          bool
	hide_today_indicator     bool = gui_theme.date_picker_style.hide_today_indicator
	monday_first_day_of_week bool = gui_theme.date_picker_style.monday_first_day_of_week
	show_adjacent_months     bool = gui_theme.date_picker_style.show_adjacent_months
}

// date_picker_reset clears the internal view state of the given date picker
pub fn (mut window Window) date_picker_reset(id string) {
	window.view_state.date_picker_state.set(id, DatePickerState{})
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
		content:      [
			text(text: locale_format_date(view_time(state), gui_locale.date.month_year)),
		]
		on_click:     fn [id] (_ &Layout, mut e Event, mut w Window) {
			mut state := w.view_state.date_picker_state.get(id) or { DatePickerState{} }
			state.show_year_month_picker = !state.show_year_month_picker
			w.view_state.date_picker_state.set(id, state)
			if state.show_year_month_picker {
				w.set_id_focus(date_picker_roller_id_focus)
			}
			e.is_handled = true
		}
	)
}

fn (cfg DatePickerCfg) prev_month(state DatePickerState) View {
	id := cfg.id
	icon := if gui_locale.text_dir == .rtl { icon_arrow_right } else { icon_arrow_left }
	return button(
		disabled:     state.show_year_month_picker
		color_border: color_transparent
		content:      [text(text: icon, text_style: gui_theme.icon3)]
		on_click:     fn [id] (_ &Layout, mut e Event, mut w Window) {
			mut dps := w.view_state.date_picker_state.get(id) or { DatePickerState{} }
			dps.view_month = dps.view_month - 1
			if dps.view_month < 1 {
				dps.view_month = 12
				dps.view_year -= 1
			}
			w.view_state.date_picker_state.set(id, dps)
		}
	)
}

fn (cfg DatePickerCfg) next_month(state DatePickerState) View {
	id := cfg.id
	icon := if gui_locale.text_dir == .rtl { icon_arrow_left } else { icon_arrow_right }
	return button(
		disabled:     state.show_year_month_picker
		color_border: color_transparent
		content:      [text(text: icon, text_style: gui_theme.icon3)]
		on_click:     fn [id] (_ &Layout, mut e Event, mut w Window) {
			mut dps := w.view_state.date_picker_state.get(id) or { DatePickerState{} }
			dps.view_month = dps.view_month + 1
			if dps.view_month > 12 {
				dps.view_month = 1
				dps.view_year += 1
			}
			w.view_state.date_picker_state.set(id, dps)
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
			mut state := w.view_state.date_picker_state.get(id) or { DatePickerState{} }
			state.calendar_width = layout.shape.width
			state.calendar_height = layout.shape.height
			w.view_state.date_picker_state.set(id, state)
		}
	)
}

fn (cfg DatePickerCfg) weekdays(state DatePickerState) View {
	mut weekdays := []View{cap: 7}
	weekdays_names := match cfg.weekdays_len {
		.one_letter { gui_locale.weekdays_short }
		.three_letter { gui_locale.weekdays_med }
		.full { gui_locale.weekdays_full }
	}

	// Shift days based on first-day-of-week (locale or per-widget)
	// Standard array is Sun..Sat (0..6)
	first_day := if cfg.monday_first_day_of_week {
		1
	} else {
		int(gui_locale.date.first_day_of_week)
	}
	for i in 0 .. 7 {
		day_idx := (i + first_day) % 7

		is_disabled := if cfg.allowed_weekdays.len > 0 {
			// day_idx: 0=Sun, 1=Mon, ..., 6=Sat
			// DatePickerWeekdays: 1=Monday ... 7=Sunday
			// We need to map 0->7 (Sunday), others match directly if we treat Sun as 7
			// Actually DatePickerWeekdays enum values are:
			// Mon=1, Tue=2, Wed=3, Thu=4, Fri=5, Sat=6, Sun=7

			dw_val := if day_idx == 0 { 7 } else { day_idx }
			wd := DatePickerWeekdays.from(u8(dw_val)) or { DatePickerWeekdays.sunday }
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
			content:      [text(text: weekdays_names[day_idx])]
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
	mut month_rows := []View{cap: 6}

	today := time.now()
	vt := view_time(state)
	days_in_month := time.days_in_month(vt.month, vt.year) or { 0 }

	// day_of_week returns 1 (Mon) to 7 (Sun)
	first_dow := time.day_of_week(vt.year, vt.month, 1)

	// Determine starting offset using locale first day of week.
	// first_dow: 1=Mon..7=Sun. first_day: 0=Sun,1=Mon.
	month_first_day := if cfg.monday_first_day_of_week {
		1
	} else {
		int(gui_locale.date.first_day_of_week)
	}
	start_offset := if month_first_day == 1 {
		first_dow - 1
	} else {
		if first_dow == 7 { 0 } else { first_dow }
	}

	prev_month := if vt.month == 1 { 12 } else { vt.month - 1 }
	prev_year := if vt.month == 1 { vt.year - 1 } else { vt.year }
	days_prev_month := time.days_in_month(prev_month, prev_year) or { 30 }

	mut current_day_counter := 1
	// We iterate 42 cells (6 rows * 7 cols) to ensure full month coverage
	for _ in 0 .. 6 {
		mut week := []View{cap: 7}
		for _ in 0 .. 7 {
			mut day_num := 0
			mut is_prev_month := false
			mut is_next_month := false

			// Determine which day number to show
			if current_day_counter <= start_offset {
				// Previous month
				day_num = days_prev_month - (start_offset - current_day_counter)
				is_prev_month = true
			} else if current_day_counter > start_offset + days_in_month {
				// Next month
				day_num = current_day_counter - (start_offset + days_in_month)
				is_next_month = true
			} else {
				// Current month
				day_num = current_day_counter - start_offset
			}

			// Text and visibility
			day_str := if (!is_prev_month && !is_next_month) || cfg.show_adjacent_months {
				day_num.str()
			} else {
				''
			}

			// State checks
			is_current_month_day := !is_prev_month && !is_next_month
			is_today := is_current_month_day && day_num == today.day && vt.month == today.month
				&& vt.year == today.year && !cfg.hide_today_indicator

			mut is_selected_day := false
			if is_current_month_day {
				// Check selection
				target_time := date(day_num, vt.month, vt.year)
				if cfg.select_multiple {
					for d in cfg.dates {
						if is_same_day(d, target_time) {
							is_selected_day = true
							break
						}
					}
				} else if cfg.dates.len > 0 {
					if is_same_day(cfg.dates[0], target_time) {
						is_selected_day = true
					}
				} else if is_today && cfg.dates.len == 0 {
					// Default to today if nothing selected?? Original logic did this.
					is_selected_day = true
				}
			}

			dt := if is_current_month_day { date(day_num, vt.month, vt.year) } else { time.unix(0) }
			is_disabled_cell := is_current_month_day && cfg.disabled(dt, state)

			// Styling
			color := if is_selected_day { cfg.color_select } else { cfg.color }
			color_border := if is_today { cfg.text_style.color } else { color_transparent }
			color_hover := if is_selected_day { cfg.color_select } else { cfg.color_hover }

			// Captures for closure
			on_select := cfg.on_select
			update_selections_fn := cfg.update_selections
			selected_day_val := day_num // capture by value

			week << button(
				color:        color
				color_border: color_border
				color_click:  cfg.color_select
				color_hover:  color_hover
				disabled:     !is_current_month_day || is_disabled_cell
				min_width:    state.cell_size
				max_width:    state.cell_size
				max_height:   state.cell_size
				size_border:  2
				content:      [text(text: day_str)]
				on_click:     fn [on_select, update_selections_fn, selected_day_val, state] (_ &Layout, mut e Event, mut w Window) {
					if on_select != unsafe { nil } {
						selected_dates := update_selections_fn(selected_day_val, state)
						on_select(selected_dates, mut e, mut w)
					}
				}
			)
			current_day_counter++
		}
		month_rows << row(
			padding: padding_none
			spacing: cfg.cell_spacing
			content: week
		)
	}
	return column(
		name:    'date_picker month'
		padding: padding_none
		spacing: cfg.cell_spacing
		content: month_rows
	)
}

fn (cfg DatePickerCfg) update_selections(day int, state DatePickerState) []time.Time {
	selected := date(day, state.view_month, state.view_year)
	if !cfg.select_multiple {
		return [selected]
	}

	mut selections := []time.Time{}
	selections << dates(cfg.dates)

	// Check if already selected to toggle
	mut found := false
	for i, s in selections {
		if is_same_day(s, selected) {
			selections.delete(i)
			found = true
			break
		}
	}
	if !found {
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

fn is_same_day(a time.Time, b time.Time) bool {
	return a.day == b.day && a.month == b.month && a.year == b.year
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
		(gui_theme.button_style.size_border * 2)
}

fn (cfg DatePickerCfg) disabled(date time.Time, state DatePickerState) bool {
	if cfg.allowed_weekdays.len > 0 {
		// V time.day_of_week: 1=Mon, ..., 7=Sun
		// DatePickerWeekdays: 1=Mon, ..., 7=Sun
		// Direct mapping works
		dow_int := time.day_of_week(date.year, date.month, date.day)
		dow := DatePickerWeekdays.from(u8(dow_int)) or {
			log.error(err.msg())
			return true
		}
		if dow !in cfg.allowed_weekdays {
			return true
		}
	}
	if cfg.allowed_months.len > 0 {
		month := DatePickerMonths.from(u16(state.view_month)) or {
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
			if is_same_day(allowed, date) {
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
					mut state := w.view_state.date_picker_state.get(id) or { DatePickerState{} }
					state.view_month = t.month
					state.view_year = t.year
					w.view_state.date_picker_state.set(id, state)
				}
			),
		]
	)
}
