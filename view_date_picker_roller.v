module gui

import time

// DatePickerRollerDisplayMode controls which drums are visible in the picker.
pub enum DatePickerRollerDisplayMode as u8 {
	day_month_year // DD MMM YYYY (default)
	month_day_year // MMM DD YYYY
	month_year     // MMM YYYY
	year_only      // YYYY
}

// DatePickerRollerState persists scroll animation offsets across frames.
pub struct DatePickerRollerState {
pub mut:
	scroll_offset_day   f32
	scroll_offset_month f32
	scroll_offset_year  f32
}

// DatePickerRollerCfg configures a [date_picker_roller](#date_picker_roller)
@[minify]
pub struct DatePickerRollerCfg {
pub:
	id            string @[required]
	id_focus      u32
	selected_date time.Time @[required]
	display_mode  DatePickerRollerDisplayMode
	min_year      int = 1900
	max_year      int = 2100
	item_height   f32 = 32
	visible_items int = 5 // must be odd
	min_width     f32  // 0 = auto-calculate from font size
	max_width     f32  // 0 = no maximum
	long_months   bool // true = "January", false = "Jan"
	color         Color                      = gui_theme.color_background
	text_style    TextStyle                  = gui_theme.text_style
	on_change     fn (time.Time, mut Window) = unsafe { nil }
}

// date_picker_roller creates a date picker using a drum/roller mechanism.
// Each drum (day, month, year) scrolls independently. Use mouse scroll over
// individual drums or keyboard shortcuts:
//   - Shift + Up/Down: day
//   - Alt + Up/Down: month
//   - Up/Down (no modifier): year
pub fn date_picker_roller(cfg DatePickerRollerCfg) View {
	mut drums := []View{cap: 3}

	// Track drum order for scroll hit detection
	mut drum_order := []string{cap: 3}

	// Calculate drum width based on font size.
	// Month names are longest ("September" = 9 chars), years are 4 digits.
	// Approximate char width as 0.6 * font_size.
	font_size := cfg.text_style.size
	month_drum_width := if cfg.long_months { font_size * 8.0 } else { font_size * 4.0 }
	day_drum_width := font_size * 2.5 // 2 digits + padding
	year_drum_width := font_size * 4.0 // 4 digits + padding

	// Calculate total min_width if not specified
	spacing := f32(4)
	padding := f32(10) // padding_small
	calculated_min_width := match cfg.display_mode {
		.day_month_year, .month_day_year {
			day_drum_width + month_drum_width + year_drum_width + spacing * 2 + padding * 2
		}
		.month_year {
			month_drum_width + year_drum_width + spacing + padding * 2
		}
		.year_only {
			year_drum_width + padding * 2
		}
	}
	min_width := if cfg.min_width > 0 { cfg.min_width } else { calculated_min_width }
	month_format := if cfg.long_months { month_format_long } else { month_format_short }

	match cfg.display_mode {
		.day_month_year {
			drums << cfg.make_drum('day_drum', cfg.selected_date.day, 1, time.days_in_month(cfg.selected_date.month,
				cfg.selected_date.year) or { 31 }, day_format, day_drum_width)
			drums << cfg.make_drum('month_drum', cfg.selected_date.month, 1, 12, month_format,
				month_drum_width)
			drums << cfg.make_drum('year_drum', cfg.selected_date.year, cfg.min_year,
				cfg.max_year, year_format, year_drum_width)
			drum_order = ['day_drum', 'month_drum', 'year_drum']
		}
		.month_day_year {
			drums << cfg.make_drum('month_drum', cfg.selected_date.month, 1, 12, month_format,
				month_drum_width)
			drums << cfg.make_drum('day_drum', cfg.selected_date.day, 1, time.days_in_month(cfg.selected_date.month,
				cfg.selected_date.year) or { 31 }, day_format, day_drum_width)
			drums << cfg.make_drum('year_drum', cfg.selected_date.year, cfg.min_year,
				cfg.max_year, year_format, year_drum_width)
			drum_order = ['month_drum', 'day_drum', 'year_drum']
		}
		.month_year {
			drums << cfg.make_drum('month_drum', cfg.selected_date.month, 1, 12, month_format,
				month_drum_width)
			drums << cfg.make_drum('year_drum', cfg.selected_date.year, cfg.min_year,
				cfg.max_year, year_format, year_drum_width)
			drum_order = ['month_drum', 'year_drum']
		}
		.year_only {
			drums << cfg.make_drum('year_drum', cfg.selected_date.year, cfg.min_year,
				cfg.max_year, year_format, year_drum_width)
			drum_order = ['year_drum']
		}
	}

	on_change := cfg.on_change
	selected_date := cfg.selected_date
	min_year := cfg.min_year
	max_year := cfg.max_year

	return row(
		name:         'date_picker_roller'
		id:           cfg.id
		id_focus:     cfg.id_focus
		min_width:    min_width
		max_width:    cfg.max_width
		color:        cfg.color
		padding:      padding_small
		spacing:      4
		h_align:      .center
		v_align:      .middle
		on_keydown:   fn [on_change, selected_date, min_year, max_year] (_ &Layout, mut e Event, mut w Window) {
			date_picker_on_keydown(on_change, selected_date, min_year, max_year, mut e, mut
				w)
		}
		content:      drums
		amend_layout: fn [on_change, selected_date, min_year, max_year, drum_order] (mut layout Layout, mut w Window) {
			if layout.shape.events == unsafe { nil } {
				layout.shape.events = &EventHandlers{}
			}
			layout.shape.events.on_mouse_scroll = fn [on_change, selected_date, min_year, max_year, drum_order] (ly &Layout, mut e Event, mut w Window) {
				date_picker_on_scroll(ly, drum_order, on_change, selected_date, min_year,
					max_year, mut e, mut w)
			}
		}
	)
}

fn day_format(v int) string {
	return '${v:02}'
}

fn month_format_short(v int) string {
	return gui_locale.months_short[v - 1]
}

fn month_format_long(v int) string {
	return gui_locale.months_full[v - 1]
}

fn year_format(v int) string {
	return v.str()
}

// date_picker_on_scroll handles scroll events, dispatching to correct drum.
fn date_picker_on_scroll(layout &Layout, drum_order []string, on_change fn (time.Time, mut Window), selected_date time.Time, min_year int, max_year int, mut e Event, mut w Window) {
	if on_change == unsafe { nil } {
		return
	}

	for i, child in layout.children {
		if child.shape.point_in_shape(e.mouse_x, e.mouse_y) {
			if i < drum_order.len {
				drum_name := drum_order[i]
				delta := if e.scroll_y > 0 { -1 } else { 1 }

				match drum_name {
					'day_drum' {
						date_picker_adjust_day(delta, selected_date, on_change, mut w)
					}
					'month_drum' {
						date_picker_adjust_month(delta, selected_date, on_change, mut
							w)
					}
					'year_drum' {
						date_picker_adjust_year(delta, selected_date, min_year, max_year,
							on_change, mut w)
					}
					else {}
				}
				e.is_handled = true
				return
			}
		}
	}
}

// make_drum creates a drum column with the given parameters.
fn (cfg &DatePickerRollerCfg) make_drum(name string, value int, min int, max int, format fn (int) string, drum_width f32) View {
	half := cfg.visible_items / 2
	mut items := []View{cap: cfg.visible_items}

	for i in -half .. half + 1 {
		offset_value := value + i
		// Wrap value for display
		display_value := if offset_value < min {
			max - (min - offset_value - 1)
		} else if offset_value > max {
			min + (offset_value - max - 1)
		} else {
			offset_value
		}

		// Calculate fade based on distance from center
		distance := if i < 0 { -i } else { i }
		alpha := match distance {
			0 { u8(255) }
			1 { u8(150) }
			else { u8(80) }
		}

		mut style := cfg.text_style
		if i == 0 {
			// Center item: larger and fully visible
			style = TextStyle{
				...style
				size: style.size + 4
			}
		} else {
			// Faded items
			style = TextStyle{
				...style
				color: Color{
					...style.color
					a: alpha
				}
			}
		}

		items << row(
			h_align: .center
			v_align: .middle
			height:  cfg.item_height
			width:   drum_width
			sizing:  fixed_fixed
			content: [
				text(text: format(display_value), text_style: style),
			]
		)
	}

	return column(
		name:    name
		width:   drum_width
		sizing:  fixed_fit
		padding: padding_none
		spacing: 0
		h_align: .center
		content: items
	)
}

// date_picker_on_keydown handles keyboard navigation with modifier keys.
fn date_picker_on_keydown(on_change fn (time.Time, mut Window), selected_date time.Time, min_year int, max_year int, mut e Event, mut w Window) {
	if on_change == unsafe { nil } {
		return
	}

	delta := match e.key_code {
		.up { -1 }
		.down { 1 }
		else { return }
	}

	match true {
		e.modifiers.has(.shift) {
			date_picker_adjust_day(delta, selected_date, on_change, mut w)
			e.is_handled = true
		}
		e.modifiers.has(.alt) {
			date_picker_adjust_month(delta, selected_date, on_change, mut w)
			e.is_handled = true
		}
		e.modifiers == .none {
			date_picker_adjust_year(delta, selected_date, min_year, max_year, on_change, mut
				w)
			e.is_handled = true
		}
		else {}
	}
}

fn date_picker_adjust_day(delta int, selected_date time.Time, on_change fn (time.Time, mut Window), mut w Window) {
	max_days := time.days_in_month(selected_date.month, selected_date.year) or { 31 }
	mut new_day := selected_date.day + delta

	if new_day < 1 {
		new_day = max_days
	} else if new_day > max_days {
		new_day = 1
	}

	new_date := time.new(
		year:  selected_date.year
		month: selected_date.month
		day:   new_day
	)
	on_change(new_date, mut w)
}

fn date_picker_adjust_month(delta int, selected_date time.Time, on_change fn (time.Time, mut Window), mut w Window) {
	mut new_month := selected_date.month + delta

	if new_month < 1 {
		new_month = 12
	} else if new_month > 12 {
		new_month = 1
	}

	max_days := time.days_in_month(new_month, selected_date.year) or { 31 }
	new_day := if selected_date.day > max_days { max_days } else { selected_date.day }

	new_date := time.new(
		year:  selected_date.year
		month: new_month
		day:   new_day
	)
	on_change(new_date, mut w)
}

fn date_picker_adjust_year(delta int, selected_date time.Time, min_year int, max_year int, on_change fn (time.Time, mut Window), mut w Window) {
	mut new_year := selected_date.year + delta

	if new_year < min_year {
		new_year = min_year
	} else if new_year > max_year {
		new_year = max_year
	}

	max_days := time.days_in_month(selected_date.month, new_year) or { 31 }
	new_day := if selected_date.day > max_days { max_days } else { selected_date.day }

	new_date := time.new(
		year:  new_year
		month: selected_date.month
		day:   new_day
	)
	on_change(new_date, mut w)
}
