module gui

import time

pub struct DatePickerState {
pub mut:
	view_month             int
	view_year              int
	show_select_year_view  bool
	show_select_month_view bool
	calendar_width         f32
	calendar_height        f32
}

@[params]
pub struct DatePickerCfg {
pub:
	id                  string    @[required] // unique only to other date_pickers
	time                time.Time @[required]
	first_day_of_week   int
	show_adjacent_month bool
	show_week           bool
	cell_size           f32 = 40
	cell_spacing        f32 = 3
	width               f32
	height              f32
	min_width           f32
	min_height          f32
	max_width           f32
	max_height          f32
	disabled            bool
	invisible           bool
	sizing              Sizing
	color               Color     = gui_theme.button_style.color
	color_hover         Color     = gui_theme.button_style.color_hover
	color_focus         Color     = gui_theme.button_style.color_focus
	color_click         Color     = gui_theme.button_style.color_click
	color_border        Color     = gui_theme.button_style.color_border
	color_border_focus  Color     = gui_theme.button_style.color_border_focus
	color_select        Color     = gui_theme.color_select
	fill                bool      = gui_theme.button_style.fill
	fill_border         bool      = gui_theme.button_style.fill_border
	padding             Padding   = gui_theme.button_style.padding
	padding_border      Padding   = gui_theme.button_style.padding_border
	radius              f32       = gui_theme.button_style.radius
	radius_border       f32       = gui_theme.button_style.radius_border
	text_style          TextStyle = gui_theme.text_style
	on_select           fn ([]time.Time, mut Event, mut Window) = unsafe { nil }
}

pub fn (mut window Window) date_picker(cfg DatePickerCfg) View {
	mut state := window.view_state.date_picker_state[cfg.id]
	if state.view_year == 0 {
		state.view_month = cfg.time.month
		state.view_year = cfg.time.year
		window.view_state.date_picker_state[cfg.id] = state
	}

	return row(
		name:    'date_picker border'
		fill:    cfg.fill_border
		color:   cfg.color_border
		padding: cfg.padding_border
		content: [
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
		v_align: .middle
		padding: padding_none
		sizing:  fill_fit
		content: [
			cfg.month_picker(state),
			cfg.year_picker(state),
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
			state.show_select_month_view = !state.show_select_month_view
			state.show_select_year_view = false
			w.view_state.date_picker_state[cfg.id] = state
			e.is_handled = true
		}
	)
}

fn (cfg DatePickerCfg) year_picker(state DatePickerState) View {
	icon := if state.show_select_year_view { icon_arrow_up } else { icon_arrow_down }
	return button(
		color_border: color_transparent
		content:      [text(text: icon, text_style: gui_theme.icon3)]
		on_click:     fn [cfg] (_ &ButtonCfg, mut e Event, mut w Window) {
			mut state := w.view_state.date_picker_state[cfg.id]
			state.show_select_month_view = false
			state.show_select_year_view = !state.show_select_year_view
			w.view_state.date_picker_state[cfg.id] = state
			e.is_handled = true
		}
	)
}

fn (cfg DatePickerCfg) prev_month(state DatePickerState) View {
	return button(
		disabled:     state.show_select_month_view || state.show_select_year_view
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
		disabled:     state.show_select_month_view || state.show_select_year_view
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
	if state.show_select_month_view {
		return select_month(state)
	}
	if state.show_select_year_view {
		return select_year(state)
	}
	return cfg.calendar(state)
}

fn (cfg DatePickerCfg) calendar(state DatePickerState) View {
	return column(
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
		week_days << button(
			color:        color_transparent
			color_border: color_transparent
			min_width:    cfg.cell_size
			max_width:    cfg.cell_size
			padding:      padding_two
			content:      [text(text: week_days_short[i])]
		)
	}
	return row(
		spacing: cfg.cell_spacing
		padding: padding_none
		content: week_days
	)
}

fn (cfg DatePickerCfg) month(state DatePickerState) View {
	mut month := []View{}

	today := time.now()
	v_time := view_time(state)
	days_in_month := time.days_in_month(v_time.month, v_time.year) or { 0 }

	first_day_of_month := time.day_of_week(v_time.year, v_time.month, 1)
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

	for _ in 0 .. 6 {
		mut week := []View{}
		for _ in 0 .. 7 {
			day := if count <= 0 || count > days_in_month { '' } else { count.str() }

			is_today := count == today.day && v_time.month == today.month
				&& v_time.year == today.year
			is_selected_day := count == cfg.time.day && cfg.time.month == v_time.month
				&& cfg.time.year == v_time.year

			color := if is_selected_day { cfg.color_select } else { cfg.color }
			color_border := if is_today { cfg.text_style.color } else { color_transparent }
			color_hover := if is_selected_day { cfg.color_select } else { cfg.color_hover }

			week << button(
				color:          color
				color_border:   color_border
				color_click:    cfg.color_select
				color_hover:    color_hover
				disabled:       day == ''
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
		name:    'date_picker calendar'
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

fn select_month(state DatePickerState) View {
	return column(
		min_width:  state.calendar_width
		max_width:  state.calendar_width
		min_height: state.calendar_height
		max_height: state.calendar_height
		content:    [text(text: 'month select')]
	)
}

fn select_year(state DatePickerState) View {
	return column(
		min_width:  state.calendar_width
		max_width:  state.calendar_width
		min_height: state.calendar_height
		max_height: state.calendar_height
		content:    [text(text: 'year select')]
	)
}
