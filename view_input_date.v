module gui

import time

@[minify]
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
	on_enter                 fn (&Layout, mut Event, mut Window)     = unsafe { nil }
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
	border_width             f32       = gui_theme.date_picker_style.border_width
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
	disabled                 bool
	invisible                bool
	select_multiple          bool
	hide_today_indicator     bool = gui_theme.date_picker_style.hide_today_indicator
	monday_first_day_of_week bool = gui_theme.date_picker_style.monday_first_day_of_week
	show_adjacent_months     bool = gui_theme.date_picker_style.show_adjacent_months
}

// input_date creates an input field with an integrated date picker that allows
// users to select a date through a calendar interface. The input displays the
// selected date in M/D/YYYY format and shows a calendar icon. Clicking the
// icon toggles a dropdown date picker below the input field. The date picker
// supports various customization options including allowed dates, weekdays,
// months, and years, as well as styling options for colors, padding, and text.
// Multiple date selection is supported when configured.
//
// Parameters:
//   cfg - InputDateCfg struct containing all configuration options including:
//         - id: unique identifier (required)
//         - date: initial date (defaults to current date)
//         - placeholder: placeholder text when no date is selected
//         - allowed_weekdays, allowed_months, allowed_years, allowed_dates:
//           restrictions on selectable dates
//         - on_select: callback when date is selected
//         - on_enter: callback when Enter key is pressed
//         - styling options: colors, padding, text styles, radius, etc.
//         - behavior flags: disabled, invisible, select_multiple, etc.
//
// Returns:
//   View - A column layout containing the input field and floating date picker
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
				on_enter:          cfg.on_enter
				on_click_icon:     fn [cfg] (_ &Layout, mut e Event, mut w Window) {
					visible := w.view_state.input_date_state[cfg.id]
					w.view_state.input_date_state.clear() // close all other date_pickers
					w.view_state.input_date_state[cfg.id] = !visible
					e.is_handled = true
				}
				sizing:            cfg.sizing
				text_style:        cfg.text_style
				placeholder_style: cfg.placeholder_style
				width:             cfg.width
				height:            cfg.height
				min_width:         cfg.min_width
				min_height:        cfg.min_height
				max_width:         cfg.max_width
				max_height:        cfg.max_height
				radius:            cfg.radius
				radius_border:     cfg.radius_border
				id_focus:          cfg.id_focus
				padding:           cfg.padding
				border_width:      cfg.border_width

				color:              cfg.color
				color_hover:        cfg.color_hover
				color_border:       cfg.color_border
				color_border_focus: cfg.color_border_focus
				disabled:           cfg.disabled
				invisible:          cfg.invisible
			),
			row(
				float:          true
				float_anchor:   .bottom_left
				float_offset_y: -cfg.border_width

				invisible: !window.view_state.input_date_state[cfg.id]
				padding:   padding_none
				content:   [
					window.date_picker(DatePickerCfg{
						id:                 cfg.id
						dates:              [cfg.date]
						allowed_weekdays:   cfg.allowed_weekdays
						allowed_months:     cfg.allowed_months
						allowed_years:      cfg.allowed_years
						allowed_dates:      cfg.allowed_dates
						on_select:          cfg.on_select
						weekdays_len:       cfg.weekdays_len
						text_style:         cfg.text_style
						color:              cfg.color
						color_hover:        cfg.color_hover
						color_focus:        cfg.color_focus
						color_click:        cfg.color_click
						color_border:       cfg.color_border
						color_border_focus: cfg.color_border_focus
						color_select:       cfg.color_select
						padding:            cfg.padding
						border_width:       cfg.border_width

						cell_spacing:             cfg.cell_spacing
						radius:                   cfg.radius
						radius_border:            cfg.radius_border
						disabled:                 cfg.disabled
						invisible:                cfg.invisible
						select_multiple:          cfg.select_multiple
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
