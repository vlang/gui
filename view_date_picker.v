module gui

import time

pub enum DataPickerWeekdays {
	one_letter
	three_letter
	full
}

struct DatePickerState {
pub mut:
	show_year_month_picker bool
	calendar_width         f32 // width and height needed to fix the size of the view, so showing
	calendar_height        f32 // select months/years does not cause the view to change size.
	view_month             int
	view_year              int
}

// DatePickerCfg configures a [date_picker](#date_picker)
pub struct DatePickerCfg {
pub:
	id                             string    @[required] // unique only to other date_pickers
	time                           time.Time @[required]
	monday_first_day_of_week       bool
	show_adjacent_months           bool
	show_week                      bool
	cell_size                      f32 = 40
	cell_spacing                   f32 = 3
	month_button_width             f32 = 120
	year_month_picker_button_width f32 = 50
	disabled                       bool
	invisible                      bool
	color                          Color     = gui_theme.button_style.color
	color_hover                    Color     = gui_theme.button_style.color_hover
	color_focus                    Color     = gui_theme.button_style.color_focus
	color_click                    Color     = gui_theme.button_style.color_click
	color_border                   Color     = gui_theme.button_style.color_border
	color_border_focus             Color     = gui_theme.button_style.color_border_focus
	color_select                   Color     = gui_theme.color_select
	fill                           bool      = gui_theme.button_style.fill
	fill_border                    bool      = gui_theme.button_style.fill_border
	padding                        Padding   = gui_theme.button_style.padding
	padding_border                 Padding   = gui_theme.button_style.padding_border
	radius                         f32       = gui_theme.button_style.radius
	radius_border                  f32       = gui_theme.button_style.radius_border
	text_style                     TextStyle = gui_theme.text_style
	on_select                      fn ([]time.Time, mut Event, mut Window) = unsafe { nil }
}

pub fn (mut window Window) date_picker(cfg DatePickerCfg) View {
	mut state := window.view_state.date_picker_state[cfg.id]
	if state.view_year == 0 {
		state.view_month = cfg.time.month
		state.view_year = cfg.time.year
		window.view_state.date_picker_state[cfg.id] = state
	}

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

// body is either a calendar, month picker or year picker
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
			cfg.week_days(state),
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

fn (cfg DatePickerCfg) week_days(state DatePickerState) View {
	mut week_days := []View{}
	week_days_short := ['S', 'M', 'T', 'W', 'T', 'F', 'S']!
	for i in 0 .. 7 {
		mut week_day := match cfg.monday_first_day_of_week {
			true { week_days_short[(i + 1) % 7] }
			else { week_days_short[i] }
		}
		week_days << button(
			color:        color_transparent
			color_border: color_transparent
			min_width:    cfg.cell_size
			max_width:    cfg.cell_size
			padding:      padding_two
			content:      [text(text: week_day)]
		)
	}
	return row(
		name:    'date_picker week_days'
		spacing: cfg.cell_spacing
		padding: padding_none
		content: week_days
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
			is_selected_day := count == cfg.time.day && cfg.time.month == vt.month
				&& cfg.time.year == vt.year

			color := if is_selected_day { cfg.color_select } else { cfg.color }
			color_border := if is_today { cfg.text_style.color } else { color_transparent }
			color_hover := if is_selected_day { cfg.color_select } else { cfg.color_hover }

			week << button(
				color:          color
				color_border:   color_border
				color_click:    cfg.color_select
				color_hover:    color_hover
				disabled:       count <= 0 || count > days_in_month
				min_width:      cfg.cell_size
				min_height:     cfg.cell_size
				max_width:      cfg.cell_size
				max_height:     cfg.cell_size
				padding_border: padding_two
				content:        [text(text: day)]
				on_click:       fn [cfg, count, state] (_ &ButtonCfg, mut e Event, mut w Window) {
					if cfg.on_select != unsafe { nil } {
						cfg.on_select([get_select_date(count, state)], mut e, mut w)
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

fn view_time(state DatePickerState) time.Time {
	return time.parse_format('${state.view_month} ${state.view_year}', 'M YYYY') or { time.now() }
}

fn get_select_date(day int, state DatePickerState) time.Time {
	return time.parse_format('${day} ${state.view_month} ${state.view_year}', 'D M YYYY') or {
		time.now()
	}
}

fn (cfg DatePickerCfg) year_month_picker(state DatePickerState) View {
	mut rows := []View{}
	id_scroll := u32(459342148)

	for year in (state.view_year - 20) .. (state.view_year + 20) {
		rows << row(
			v_align: .middle
			padding: padding_none
			spacing: gui_theme.spacing_small
			content: [
				text(text: year.str(), text_style: gui_theme.b3),
				rectangle(width: 0),
				cfg.button_month(1, year),
				cfg.button_month(2, year),
				cfg.button_month(3, year),
				cfg.button_month(4, year),
			]
		)
		rows << row(
			v_align: .middle
			padding: padding_none
			spacing: gui_theme.spacing_small
			content: [
				text(
					text:       year.str()
					text_style: TextStyle{
						...gui_theme.b3
						color: color_transparent
					}
				),
				rectangle(width: 0),
				cfg.button_month(5, year),
				cfg.button_month(6, year),
				cfg.button_month(7, year),
				cfg.button_month(8, year),
			]
		)
		rows << row(
			v_align: .middle
			padding: padding_none
			spacing: gui_theme.spacing_small
			content: [
				text(
					text:       year.str()
					text_style: TextStyle{
						...gui_theme.b3
						color: color_transparent
					}
				),
				rectangle(width: 0),
				cfg.button_month(9, year),
				cfg.button_month(10, year),
				cfg.button_month(11, year),
				cfg.button_month(12, year),
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
				id_scroll: id_scroll
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

fn (cfg DatePickerCfg) button_month(month int, year int) View {
	month_str := time.months_string[(month - 1) * 3..month * 3]
	return button(
		min_width: cfg.year_month_picker_button_width
		max_width: cfg.year_month_picker_button_width
		on_click:  fn [cfg, month, year] (_ &ButtonCfg, mut e Event, mut w Window) {
			mut state := w.view_state.date_picker_state[cfg.id]
			state.view_month = month
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
