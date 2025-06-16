module gui

@[params]
pub struct ThrobberCfg {
pub:
	id    string
	color Color  = gui_theme.color_text
	icon1 string = icon_elipsis_h // icon1 used to measure for min_width
	icon2 string = icon_elipsis_v
	size  u32    = u32(gui_theme.size_text_medium)
}

pub fn (window &Window) throbber(cfg ThrobberCfg) View {
	text_style := TextStyle{
		...gui_theme.icon3
		size:  int(cfg.size)
		color: cfg.color
	}
	width := get_text_width_no_cache(icon_elipsis_h, text_style, window)
	txt := if window.view_state.cursor_on { cfg.icon1 } else { cfg.icon2 }

	return column(
		min_width: width
		padding:   padding_none
		content:   [
			text(
				text:       txt
				text_style: text_style
			),
		]
	)
}
