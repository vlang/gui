module gui

import time

@[params]
pub struct DatePickerCfg {
pub:
	id                  string
	id_focus            u32 @[required]
	time                time.Time = time.now()
	first_day_of_week   int
	show_adjacent_month bool
	show_week           bool
	cell_width          f32 = 25
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
	color               Color   = gui_theme.button_style.color
	color_hover         Color   = gui_theme.button_style.color_hover
	color_focus         Color   = gui_theme.button_style.color_focus
	color_click         Color   = gui_theme.button_style.color_click
	color_border        Color   = gui_theme.button_style.color_border
	color_border_focus  Color   = gui_theme.button_style.color_border_focus
	fill                bool    = gui_theme.button_style.fill
	fill_border         bool    = gui_theme.button_style.fill_border
	padding             Padding = gui_theme.button_style.padding
	padding_border      Padding = gui_theme.button_style.padding_border
	radius              f32     = gui_theme.button_style.radius
	radius_border       f32     = gui_theme.button_style.radius_border
	on_select           fn ([]time.Time, mut Event, mut Window) = unsafe { nil }
}

pub fn date_picker(cfg DatePickerCfg) View {
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
					cfg.title(),
					cfg.current(),
					row(
						content: [
							cfg.month_picker(),
							cfg.year_picker(),
						]
					),
					cfg.body(),
				]
			),
		]
	)
}

fn (cfg DatePickerCfg) title() View {
	return text(text: 'SELECT DATE', text_style: gui_theme.m5)
}

fn (cfg DatePickerCfg) current() View {
	return text(text: cfg.time.custom_format('ddd, MMM D'))
}

fn (cfg DatePickerCfg) month_picker() View {
	return button(content: [text(text: 'bla')])
}

fn (cfg DatePickerCfg) year_picker() View {
	return toggle(
		on_click: fn (_ &ToggleCfg, mut e Event, mut w Window) {}
	)
}

// body is either a calendar, month picker or year picker
fn (cfg DatePickerCfg) body() View {
	return cfg.calendar()
}

fn (cfg DatePickerCfg) calendar() View {
	return column(
		padding: padding_none
		content: [
			cfg.week_days(),
			cfg.month(),
		]
	)
}

fn (cfg DatePickerCfg) week_days() View {
	mut week_days := []View{}
	week_days_short := ['S', 'M', 'T', 'W', 'T', 'F', 'S']!
	for i in 0 .. 7 {
		week_days << row(
			h_align:   .center
			min_width: cfg.cell_width
			padding:   padding_none
			content:   [text(text: week_days_short[i])]
		)
	}
	return row(
		spacing: cfg.cell_spacing
		padding: padding_none
		content: week_days
	)
}

fn (cfg DatePickerCfg) month() View {
	mut month := []View{}
	mut offset := time.day_of_week(cfg.time.year, cfg.time.month, 0) * -1
	days_in_month := time.days_in_month(cfg.time.month, cfg.time.year) or { 0 }
	for _ in 0 .. 5 {
		mut week := []View{}
		for _ in 0 .. 7 {
			week << row(
				h_align:   .center
				min_width: cfg.cell_width
				padding:   padding_none
				content:   [
					text(
						text: if offset <= 0 || offset > days_in_month { '' } else { offset.str() }
					),
				]
			)
			offset += 1
		}
		month << row(
			spacing: cfg.cell_spacing
			padding: padding_none
			content: week
		)
	}
	return column(
		padding: padding_none
		spacing: cfg.cell_spacing
		content: month
	)
}
