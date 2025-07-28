module gui

// ToggleCfg a.k.a checkbox. [Toggle](#toggle) in its default mode functions and a checkbox.
// However, there is an option of overriding the `text_select` and `text_unselect` properties.
@[heap]
pub struct ToggleCfg {
pub:
	id                 string
	id_focus           u32
	disabled           bool
	invisible          bool
	label              string
	text_select        string = icon_check
	text_unselect      string = ' '
	select             bool
	fill               bool      = gui_theme.toggle_style.fill
	fill_border        bool      = gui_theme.toggle_style.fill_border
	color              Color     = gui_theme.toggle_style.color
	color_focus        Color     = gui_theme.toggle_style.color_focus
	color_hover        Color     = gui_theme.toggle_style.color_hover
	color_click        Color     = gui_theme.toggle_style.color_click
	color_border       Color     = gui_theme.toggle_style.color_border
	color_border_focus Color     = gui_theme.toggle_style.color_border_focus
	color_select       Color     = gui_theme.toggle_style.color_select
	padding            Padding   = gui_theme.toggle_style.padding
	padding_border     Padding   = gui_theme.toggle_style.padding_border
	radius             f32       = gui_theme.toggle_style.radius
	radius_border      f32       = gui_theme.toggle_style.radius_border
	text_style         TextStyle = gui_theme.toggle_style.text_style
	text_style_label   TextStyle = gui_theme.toggle_style.text_style_label
	on_click           fn (&ToggleCfg, mut Event, mut Window) @[required]
}

// toggle creates a toggle button (a.k.a checkbox) from the given [ToggleCfg](#ToggleCfg)
pub fn toggle(cfg ToggleCfg) View {
	color := if cfg.select { cfg.color_select } else { cfg.color }
	txt := if cfg.select { cfg.text_select } else { cfg.text_unselect }

	mut content := []View{}

	content << row(
		name:         'toggle border'
		id:           cfg.id
		id_focus:     cfg.id_focus
		color:        cfg.color_border
		padding:      cfg.padding_border
		fill:         cfg.fill_border
		radius:       cfg.radius_border
		disabled:     cfg.disabled
		invisible:    cfg.invisible
		min_width:    gui_theme.n3.size + 2
		min_height:   gui_theme.n3.size + 2
		h_align:      .center
		v_align:      .middle
		cfg:          &cfg
		on_char:      cfg.on_char_button
		amend_layout: cfg.amend_layout
		content:      [
			row(
				name:    'toggle interior'
				color:   color
				fill:    cfg.fill
				sizing:  fill_fill
				padding: cfg.padding
				radius:  cfg.radius
				h_align: .center
				v_align: .middle
				content: [
					text(
						text:       txt
						text_style: cfg.text_style
					),
				]
			),
		]
	)

	if cfg.label.len > 0 {
		content << text(text: cfg.label, text_style: cfg.text_style_label)
	}

	return row(
		name:     'toggle'
		padding:  padding_none
		on_click: cfg.left_click()
		on_hover: cfg.on_hover
		h_align:  .center
		v_align:  .middle
		content:  content
	)
}

fn (cfg &ToggleCfg) left_click() fn (&ToggleCfg, mut Event, mut Window) {
	if cfg.on_click == unsafe { nil } {
		return cfg.on_click
	}
	return fn [cfg] (_ &ToggleCfg, mut e Event, mut w Window) {
		if e.mouse_button == .left {
			cfg.on_click(cfg, mut e, mut w)
		}
	}
}

fn (cfg &ToggleCfg) on_char_button(_ &ToggleCfg, mut e Event, mut w Window) {
	if e.char_code == ` ` && cfg.on_click != unsafe { nil } {
		cfg.on_click(cfg, mut e, mut w)
		e.is_handled = true
	}
}

fn (cfg &ToggleCfg) amend_layout(mut node Layout, mut w Window) {
	if node.shape.disabled || cfg.on_click == unsafe { nil } {
		return
	}
	if w.is_focus(node.shape.id_focus) {
		node.children[0].shape.color = cfg.color_focus
		node.shape.color = cfg.color_border_focus
	}
}

fn (cfg &ToggleCfg) on_hover(mut node Layout, mut e Event, mut w Window) {
	w.set_mouse_cursor_pointing_hand()
	node.children[0].children[0].shape.color = cfg.color_hover
	if e.mouse_button == .left {
		node.children[0].children[0].shape.color = cfg.color_click
	}
}
