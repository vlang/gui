module gui

import time

@[heap]
pub struct InputDateCfg {
pub:
	id                       string @[required] // unique only to other date_pickers
	date                     time.Time = time.now()
	placeholder              string
	allowed_weekdays         []DatePickerWeekdays // [link](#DatePickerWeekdays)
	allowed_months           []DatePickerMonths   // [link](#DatePickerMonths)
	allowed_years            []int
	allowed_dates            []time.Time
	on_select                fn ([]time.Time, mut Event, mut Window) = unsafe { nil }
	on_enter                 fn (&Layout, mut Event, &Window)        = unsafe { nil }
	weekdays_len             DatePickerWeekdayLen                    = gui_theme.date_picker_style.weekdays_len // [link](#DatePickerWeekdayLen)
	text_style               TextStyle = gui_theme.date_picker_style.text_style
	placeholder_style        TextStyle = gui_theme.input_style.placeholder_style
	color                    Color     = gui_theme.date_picker_style.color
	color_hover              Color     = gui_theme.date_picker_style.color_hover
	color_focus              Color     = gui_theme.date_picker_style.color_focus
	color_click              Color     = gui_theme.date_picker_style.color_click
	color_border             Color     = gui_theme.date_picker_style.color_border
	color_border_focus       Color     = gui_theme.date_picker_style.color_border_focus
	color_select             Color     = gui_theme.date_picker_style.color_select
	padding                  Padding   = gui_theme.date_picker_style.padding
	padding_border           Padding   = gui_theme.date_picker_style.padding_border
	sizing                   Sizing
	width                    f32
	height                   f32
	min_width                f32
	min_height               f32
	max_width                f32
	max_height               f32
	cell_spacing             f32 = gui_theme.date_picker_style.cell_spacing
	radius                   f32 = gui_theme.date_picker_style.radius
	radius_border            f32 = gui_theme.date_picker_style.radius_border
	id_focus                 u32
	id_scroll                u32 = u32(459342148) // used in year-month picker
	disabled                 bool
	invisible                bool
	select_multiple          bool
	fill                     bool = gui_theme.date_picker_style.fill
	fill_border              bool = gui_theme.date_picker_style.fill_border
	hide_today_indicator     bool = gui_theme.date_picker_style.hide_today_indicator
	monday_first_day_of_week bool = gui_theme.date_picker_style.monday_first_day_of_week
	show_adjacent_months     bool = gui_theme.date_picker_style.show_adjacent_months
}

pub fn (mut window Window) input_date(cfg InputDateCfg) View {
	return column(
		padding: padding_none
		content: [
			input(
				id:          cfg.id
				text:        cfg.date_format()
				icon:        icon_calendar
				placeholder: cfg.placeholder
				// on_text_changed:    cfg.on_text_changed
				on_enter:           cfg.on_enter
				on_click_icon:      fn (ly &Layout, mut e Event, mut w Window) {
					visible := w.view_state.input_date_state[ly.shape.id]
					w.view_state.input_date_state.clear() // close all other date_pickers
					w.view_state.input_date_state[ly.shape.id] = !visible
					e.is_handled = true
				}
				sizing:             cfg.sizing
				text_style:         cfg.text_style
				placeholder_style:  cfg.placeholder_style
				width:              cfg.width
				height:             cfg.height
				min_width:          cfg.min_width
				min_height:         cfg.min_height
				max_width:          cfg.max_width
				max_height:         cfg.max_height
				radius:             cfg.radius
				radius_border:      cfg.radius_border
				id_focus:           cfg.id_focus
				padding:            cfg.padding
				padding_border:     cfg.padding_border
				color:              cfg.color
				color_hover:        cfg.color_hover
				color_border:       cfg.color_border
				color_border_focus: cfg.color_border_focus
				disabled:           cfg.disabled
				invisible:          cfg.invisible
				fill:               cfg.fill
				fill_border:        cfg.fill_border
			),
			row(
				float:          true
				float_anchor:   .bottom_left
				float_offset_y: -cfg.padding_border.bottom
				invisible:      !window.view_state.input_date_state[cfg.id]
				padding:        padding_none
				content:        [
					window.date_picker(DatePickerCfg{
						id:                       cfg.id
						dates:                    [cfg.date]
						allowed_weekdays:         cfg.allowed_weekdays
						allowed_months:           cfg.allowed_months
						allowed_years:            cfg.allowed_years
						allowed_dates:            cfg.allowed_dates
						on_select:                cfg.on_select
						weekdays_len:             cfg.weekdays_len
						text_style:               cfg.text_style
						color:                    cfg.color
						color_hover:              cfg.color_hover
						color_focus:              cfg.color_focus
						color_click:              cfg.color_click
						color_border:             cfg.color_border
						color_border_focus:       cfg.color_border_focus
						color_select:             cfg.color_select
						padding:                  cfg.padding
						padding_border:           cfg.padding_border
						cell_spacing:             cfg.cell_spacing
						radius:                   cfg.radius
						radius_border:            cfg.radius_border
						id_scroll:                cfg.id_scroll
						disabled:                 cfg.disabled
						invisible:                cfg.invisible
						select_multiple:          cfg.select_multiple
						fill:                     cfg.fill
						fill_border:              cfg.fill_border
						hide_today_indicator:     cfg.hide_today_indicator
						monday_first_day_of_week: cfg.monday_first_day_of_week
						show_adjacent_months:     cfg.show_adjacent_months
					}),
				]
			),
		]
	)
}

fn (cfg InputDateCfg) date_format() string {
	return cfg.date.custom_format('M/D/YYYY')
}
