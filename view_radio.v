module gui

@[heap]
pub struct RadioCfg {
pub:
	id             string
	id_focus       u32
	disabled       bool
	invisible      bool
	label          string
	select         bool
	size           f32       = gui_theme.n3.size
	color          Color     = gui_theme.radio_style.color
	color_hover    Color     = gui_theme.radio_style.color_hover
	color_focus    Color     = gui_theme.radio_style.color_focus
	color_border   Color     = gui_theme.radio_style.color_border
	color_select   Color     = gui_theme.radio_style.color_select
	color_unselect Color     = gui_theme.radio_style.color_unselect
	padding        Padding   = gui_theme.radio_style.padding
	text_style     TextStyle = gui_theme.radio_style.text_style
	on_click       fn (&RadioCfg, mut Event, mut Window) @[required]
}

pub fn radio(cfg RadioCfg) &View {
	mut content := []&View{}
	content << circle(
		name:      'radio border'
		width:     cfg.size
		height:    cfg.size
		color:     cfg.color_border
		padding:   cfg.padding
		fill:      false
		disabled:  cfg.disabled
		invisible: cfg.invisible
		sizing:    fixed_fixed
		h_align:   .center
		v_align:   .middle
		cfg:       &cfg
		on_char:   cfg.on_char_button
		content:   [
			circle(
				name:    'radio interior'
				fill:    true
				color:   if cfg.select { cfg.color_select } else { cfg.color_unselect }
				padding: padding_none
				width:   cfg.size - cfg.padding.width()
				height:  cfg.size - cfg.padding.height()
			),
		]
	)

	if cfg.label.len > 0 {
		content << row(
			name: 'radio label'
			// pad the label to the right so hover color is past
			// end of text slightly.
			padding: padding(0, pad_x_small, 0, 0)
			content: [text(text: cfg.label, text_style: cfg.text_style)]
		)
	}

	return row(
		name:         'radio'
		id:           cfg.id
		id_focus:     cfg.id_focus
		padding:      padding_none
		on_click:     cfg.on_click
		amend_layout: cfg.amend_layout
		on_hover:     cfg.on_hover
		content:      content
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
		node.children[0].shape.color = cfg.color_focus
	}
}

fn (cfg &RadioCfg) on_hover(mut node Layout, mut _ Event, mut w Window) {
	w.set_mouse_cursor_pointing_hand()
	if !w.is_focus(node.shape.id_focus) {
		node.children[0].shape.color = cfg.color_hover
		node.children[0].shape.fill = true
	}
}
