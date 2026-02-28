module gui

pub enum BadgeVariant as u8 {
	default_
	info
	success
	warning
	error
}

@[minify]
pub struct BadgeCfg {
	A11yCfg
pub:
	label      string
	variant    BadgeVariant
	max        int  // 0=no cap; shows "max+" when exceeded
	dot        bool // dot-only mode, no label
	color      Color     = gui_theme.badge_style.color
	padding    Padding   = gui_theme.badge_style.padding
	radius     f32       = gui_theme.badge_style.radius
	text_style TextStyle = gui_theme.badge_style.text_style
	dot_size   f32       = gui_theme.badge_style.dot_size
}

pub fn badge(cfg BadgeCfg) View {
	style := gui_theme.badge_style
	bg := match cfg.variant {
		.default_ { cfg.color }
		.info { style.color_info }
		.success { style.color_success }
		.warning { style.color_warning }
		.error { style.color_error }
	}

	if cfg.dot {
		sz := cfg.dot_size
		return row(
			a11y_label: a11y_label(cfg.a11y_label, 'status')
			color:      bg
			radius:     sz / 2
			width:      sz
			height:     sz
			sizing:     fixed_fixed
			padding:    padding_none
		)
	}

	label := badge_label(cfg.label, cfg.max)
	return row(
		a11y_label: a11y_label(cfg.a11y_label, label)
		color:      bg
		radius:     cfg.radius
		sizing:     fit_fit
		padding:    cfg.padding
		h_align:    .center
		v_align:    .middle
		content:    [
			text(text: label, text_style: cfg.text_style),
		]
	)
}

fn badge_label(label string, max int) string {
	if max <= 0 {
		return label
	}
	n := label.int()
	if n > max {
		return '${max}+'
	}
	return label
}
