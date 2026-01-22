module gui

import time

// RollerDatePickerCfg configures a [roller_date_picker](#roller_date_picker)
pub struct RollerDatePickerCfg {
pub:
	id            string
	id_focus      u32
	min_width     f32
	selected_date time.Time @[required]
	min_year      int                        = 1900
	max_year      int                        = 2100
	color         Color                      = gui_theme.color_background
	text_style    TextStyle                  = gui_theme.text_style
	on_change     fn (time.Time, mut Window) = unsafe { nil }
}

// roller_date_picker creates a date picker that uses a rolling/scrolling mechanism
// to select dates, similar to iOS date pickers.
pub fn roller_date_picker(cfg RollerDatePickerCfg) View {
	return column(
		id:        cfg.id
		id_focus:  cfg.id_focus
		min_width: cfg.min_width
		spacing:   0
		padding:   padding_none
		v_align:   .middle
		content:   cfg.make_rows()

		amend_layout: fn [cfg] (mut layout Layout, mut w Window) {
			layout.shape.on_mouse_scroll = fn [cfg] (layout &Layout, mut e Event, mut w Window) {
				if cfg.on_change == unsafe { nil } {
					return
				}

				new_date := match e.scroll_y > 0 {
					true { cfg.selected_date.add(time.hour * -24) }
					else { cfg.selected_date.add(time.hour * 24) }
				}

				e.is_handled = true
				cfg.on_change(new_date, mut w)
			}
		}
	)
}

fn (cfg &RollerDatePickerCfg) make_rows() []View {
	mut rows := []View{}

	// Format dates: -1 to +1 days
	for i in -1 .. 2 {
		// Calculate date offset (approx adding hours)
		t := cfg.selected_date.add(time.hour * 24 * i)

		// Styling
		mut style := cfg.text_style
		if i == 0 {
			// Center item: Highlight
			style = TextStyle{
				...style
				size: style.size + 2
			}
		} else {
			// Off-center: Fade
			style = TextStyle{
				...style
				color: Color{
					...style.color
					a: 100 // Faded
				}
			}
		}

		rows << row(
			h_align: .center
			padding: padding_small
			sizing:  fill_fit
			content: [
				text(text: t.custom_format('D'), min_width: 20, text_style: style),
				rectangle(sizing: fill_fit),
				text(text: t.custom_format('MMM'), text_style: style),
				rectangle(sizing: fill_fit),
				text(text: t.custom_format('YYYY'), text_style: style),
			]
		)
	}

	return rows
}
