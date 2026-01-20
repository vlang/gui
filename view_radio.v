module gui

@[heap; minify]
pub struct RadioCfg {
pub:
	id             string
	label          string
	color          Color     = gui_theme.radio_style.color
	color_hover    Color     = gui_theme.radio_style.color_hover
	color_focus    Color     = gui_theme.radio_style.color_focus
	color_border   Color     = gui_theme.radio_style.color_border
	color_select   Color     = gui_theme.radio_style.color_select
	color_unselect Color     = gui_theme.radio_style.color_unselect
	padding        Padding   = gui_theme.radio_style.padding
	text_style     TextStyle = gui_theme.radio_style.text_style
	on_click       fn (&Layout, mut Event, mut Window) @[required]
	size           f32 = gui_theme.n3.size
	id_focus       u32
	disabled       bool
	select         bool
	invisible      bool
}

// radio creates a radio button UI component that allows users to select a
// single option from a group. The component consists of a circular button that
// can be selected or unselected, with an optional text label. The radio button
// supports hover and focus states, keyboard interaction (Space key), and can be
// disabled or made invisible. Visual customization includes colors for various
// states (normal, hover, focus, selected/unselected), padding, size, and text
// styling.
pub fn radio(cfg RadioCfg) View {
	mut content := []View{cap: 2}
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
		on_click:     left_click_only(cfg.on_click)
		on_char:      spacebar_to_click(cfg.on_click)
		amend_layout: cfg.amend_layout
		on_hover:     cfg.on_hover
		content:      content
	)
}

fn (cfg &RadioCfg) amend_layout(mut layout Layout, mut w Window) {
	if layout.shape.disabled || cfg.on_click == unsafe { nil } {
		return
	}
	if w.is_focus(layout.shape.id_focus) {
		layout.children[0].shape.color = cfg.color_focus
	}
}

fn (cfg &RadioCfg) on_hover(mut layout Layout, mut _ Event, mut w Window) {
	w.set_mouse_cursor_pointing_hand()
	if !w.is_focus(layout.shape.id_focus) {
		layout.children[0].shape.color = cfg.color_hover
		layout.children[0].shape.fill = true
	}
}
