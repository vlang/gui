module gui

// ToggleCfg a.k.a checkbox. [Toggle](#toggle) in its default mode functions and a checkbox.
// However, there is an option of overriding the `text_select` and `text_unselect` properties.
@[heap; minify]
pub struct ToggleCfg {
pub:
	id                 string
	label              string
	text_select        string = '✓'
	text_unselect      string = ' '
	on_click           fn (&Layout, mut Event, mut Window) @[required]
	text_style         TextStyle = gui_theme.toggle_style.text_style
	text_style_label   TextStyle = gui_theme.toggle_style.text_style_label
	color              Color     = gui_theme.toggle_style.color
	color_focus        Color     = gui_theme.toggle_style.color_focus
	color_hover        Color     = gui_theme.toggle_style.color_hover
	color_click        Color     = gui_theme.toggle_style.color_click
	color_border       Color     = gui_theme.toggle_style.color_border
	color_border_focus Color     = gui_theme.toggle_style.color_border_focus
	color_select       Color     = gui_theme.toggle_style.color_select
	padding            Padding   = gui_theme.toggle_style.padding
	padding_border     Padding   = gui_theme.toggle_style.padding_border
	border_width       f32       = gui_theme.toggle_style.border_width
	radius             f32       = gui_theme.toggle_style.radius
	radius_border      f32       = gui_theme.toggle_style.radius_border
	id_focus           u32
	disabled           bool
	invisible          bool
	select             bool
	fill               bool = gui_theme.toggle_style.fill
	fill_border        bool = gui_theme.toggle_style.fill_border
}

// toggle creates a toggle button (a.k.a checkbox) from the given [ToggleCfg](#ToggleCfg)
pub fn toggle(cfg ToggleCfg) View {
	color := if cfg.select { cfg.color_select } else { cfg.color }
	txt := if cfg.select { cfg.text_select } else { cfg.text_unselect }

	mut content := []View{cap: 2}

	border_width := if cfg.border_width == 0 && !cfg.padding_border.is_none() {
		cfg.padding_border.width() / 2
	} else {
		cfg.border_width
	}

	content << row(
		name:         'toggle box'
		color:        color
		border_color: cfg.color_border
		border_width: border_width
		padding:      cfg.padding
		fill:         cfg.fill
		radius:       cfg.radius
		disabled:     cfg.disabled
		invisible:    cfg.invisible
		min_width:    gui_theme.n1.size
		min_height:   gui_theme.n1.size
		h_align:      .center
		v_align:      .middle
		content:      [
			text(
				text:       txt
				text_style: cfg.text_style
			),
		]
	)

	if cfg.label.len > 0 {
		content << text(text: cfg.label, text_style: cfg.text_style_label)
	}

	return row(
		name:         'toggle'
		id:           cfg.id
		id_focus:     cfg.id_focus
		h_align:      .center
		v_align:      .middle
		padding:      padding_none
		on_char:      spacebar_to_click(cfg.on_click)
		on_click:     left_click_only(cfg.on_click)
		on_hover:     cfg.on_hover
		amend_layout: cfg.amend_layout
		content:      content
	)
}

fn (cfg &ToggleCfg) amend_layout(mut layout Layout, mut w Window) {
	if layout.shape.disabled || cfg.on_click == unsafe { nil } {
		return
	}
	if w.is_focus(layout.shape.id_focus) {
		layout.children[0].shape.color = cfg.color_focus
		layout.children[0].shape.border_color = cfg.color_border_focus
	}
}

fn (cfg &ToggleCfg) on_hover(mut layout Layout, mut e Event, mut w Window) {
	w.set_mouse_cursor_pointing_hand()
	layout.children[0].shape.color = cfg.color_hover
	if e.mouse_button == .left {
		layout.children[0].shape.color = cfg.color_click
	}
}
