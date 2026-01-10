module gui

// SwitchCfg displays pill shaped box with a sliding toggle. [Switch](#toggle)
@[heap; minify]
pub struct SwitchCfg {
pub:
	id                 string
	label              string
	color              Color     = gui_theme.switch_style.color
	color_focus        Color     = gui_theme.switch_style.color_focus
	color_hover        Color     = gui_theme.switch_style.color_hover
	color_click        Color     = gui_theme.switch_style.color_click
	color_border       Color     = gui_theme.switch_style.color_border
	color_border_focus Color     = gui_theme.switch_style.color_border_focus
	color_select       Color     = gui_theme.switch_style.color_select
	color_unselect     Color     = gui_theme.switch_style.color_unselect
	padding            Padding   = gui_theme.switch_style.padding
	padding_border     Padding   = gui_theme.switch_style.padding_border
	text_style         TextStyle = gui_theme.switch_style.text_style
	on_click           fn (&Layout, mut Event, mut Window) @[required]
	width              f32 = gui_theme.n2.size * f32(1.65)
	height             f32 = gui_theme.n2.size
	radius             f32 = gui_theme.switch_style.radius
	radius_border      f32 = gui_theme.switch_style.radius_border
	id_focus           u32
	disabled           bool
	invisible          bool
	select             bool
	fill               bool = gui_theme.switch_style.fill
	fill_border        bool = gui_theme.switch_style.fill_border
}

// switch creates a pill shaped box with a sliding toggle from the given [SwitchCfg](#SwitchCfg)
pub fn switch(cfg SwitchCfg) View {
	color := if cfg.select { cfg.color_select } else { cfg.color_unselect }
	circle_size := cfg.height - cfg.padding.height() - cfg.padding_border.height()

	mut content := []View{cap: 2}
	content << row(
		name:         'switch border'
		id:           cfg.id
		width:        cfg.width
		height:       cfg.height
		sizing:       fixed_fit
		color:        cfg.color_border
		padding:      cfg.padding_border
		fill:         cfg.fill_border
		radius:       cfg.radius_border
		disabled:     cfg.disabled
		invisible:    cfg.invisible
		amend_layout: cfg.amend_layout
		content:      [
			row(
				name:    'switch interior'
				color:   cfg.color
				fill:    cfg.fill
				sizing:  fill_fill
				padding: cfg.padding
				radius:  cfg.radius
				h_align: if cfg.select { .end } else { .start }
				v_align: .middle
				content: [
					circle(
						name:   'select thumb'
						color:  color
						fill:   true
						width:  circle_size
						height: circle_size
						sizing: fixed_fixed
					),
				]
			),
		]
	)
	if cfg.label.len > 0 {
		content << text(text: cfg.label, text_style: cfg.text_style)
	}
	return row(
		id_focus: cfg.id_focus
		padding:  padding_none
		on_char:  cfg.on_char_button
		on_click: cfg.on_switch_click()
		on_hover: cfg.on_hover
		content:  content
	)
}

fn (cfg &SwitchCfg) on_switch_click() fn (&Layout, mut Event, mut Window) {
	if cfg.on_click == unsafe { nil } {
		return cfg.on_click
	}
	return fn [cfg] (layout &Layout, mut e Event, mut w Window) {
		if e.mouse_button == .left {
			cfg.on_click(layout, mut e, mut w)
		}
	}
}

fn (cfg &SwitchCfg) on_char_button(layout &Layout, mut e Event, mut w Window) {
	if e.char_code == ` ` && cfg.on_click != unsafe { nil } {
		cfg.on_click(layout, mut e, mut w)
		e.is_handled = true
	}
}

fn (cfg &SwitchCfg) amend_layout(mut layout Layout, mut w Window) {
	if layout.shape.disabled || cfg.on_click == unsafe { nil } {
		return
	}
	if w.is_focus(layout.parent.shape.id_focus) {
		layout.children[0].shape.color = cfg.color_focus
		layout.shape.color = cfg.color_border_focus
	}
}

fn (cfg &SwitchCfg) on_hover(mut layout Layout, mut e Event, mut w Window) {
	w.set_mouse_cursor_pointing_hand()
	layout.children[0].children[0].shape.color = cfg.color_hover
	if e.mouse_button == .left {
		layout.children[0].children[0].shape.color = cfg.color_click
	}
}
