module gui

@[heap]
pub struct RadioCfg {
pub:
	id               string
	id_focus         u32
	disabled         bool
	invisible        bool
	selected         bool
	size             f32     = gui_theme.n3.size
	color            Color   = gui_theme.radio_style.color
	color_focus      Color   = gui_theme.radio_style.color_focus
	color_border     Color   = gui_theme.radio_style.color_border
	color_selected   Color   = gui_theme.radio_style.color_selected
	color_unselected Color   = gui_theme.radio_style.color_unselected
	padding          Padding = gui_theme.radio_style.padding
	on_click         fn (&RadioCfg, mut Event, mut Window) = unsafe { nil }
}

pub fn radio(cfg RadioCfg) View {
	return circle(
		id:           cfg.id
		id_focus:     cfg.id_focus
		width:        cfg.size
		height:       cfg.size
		color:        cfg.color_border
		padding:      cfg.padding
		fill:         false
		disabled:     cfg.disabled
		invisible:    cfg.invisible
		sizing:       fixed_fixed
		h_align:      .center
		v_align:      .middle
		cfg:          &cfg
		on_char:      cfg.on_char_button
		on_click:     cfg.on_click
		amend_layout: cfg.amend_layout
		on_hover:     cfg.on_hover
		content:      [
			circle(
				fill:    true
				color:   if cfg.selected { cfg.color_selected } else { cfg.color_unselected }
				padding: padding_none
				width:   cfg.size - cfg.padding.width()
				height:  cfg.size - cfg.padding.height()
			),
		]
	)
}

fn (cfg &RadioCfg) on_char_button(_ &RadioCfg, mut e Event, mut w Window) {
	if e.char_code == ` ` && cfg.on_click != unsafe { nil } {
		cfg.on_click(cfg, mut e, mut w)
		e.is_handled = true
	}
}

fn (cfg &RadioCfg) amend_layout(mut node Layout, mut w Window) {
	if node.shape.disabled || cfg.on_click == unsafe { nil } {
		return
	}
	if w.is_focus(node.shape.id_focus) {
		node.shape.color = cfg.color_focus
	}
}

fn (cfg &RadioCfg) on_hover(mut node Layout, mut _ Event, mut w Window) {
	w.set_mouse_cursor_pointing_hand()
}
