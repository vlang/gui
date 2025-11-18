module gui

@[params]
pub struct PulsarCfg {
pub:
	id    string
	icon1 string = icon_elipsis_h
	icon2 string = icon_elipsis_v
	color Color  = gui_theme.text_style.color
	size  u32    = u32(gui_theme.size_text_medium)
	width f32
}

// pulsar creates a blinking icon.
// window.cursor_blink must be true to enable the animation.
pub fn (window &Window) pulsar(cfg PulsarCfg) View {
	text_style := TextStyle{
		...gui_theme.icon3
		size:  int(cfg.size)
		color: cfg.color
	}

	width := match cfg.width > 0 {
		true { cfg.width }
		else { get_text_width_no_cache(cfg.icon1, text_style, window) }
	}
	txt := if window.view_state.input_cursor_on { cfg.icon1 } else { cfg.icon2 }

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
