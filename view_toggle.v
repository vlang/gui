module gui

// ToggleCfg a.k.a checkbox. [Toggle](#toggle) in its default mode functions and a checkbox.
// However, there is an option of overriding the `text_select` and `text_unselect` properties.
@[minify]
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
	size_border        f32       = gui_theme.toggle_style.size_border
	radius             f32       = gui_theme.toggle_style.radius
	radius_border      f32       = gui_theme.toggle_style.radius_border
	min_width          f32
	id_focus           u32
	disabled           bool
	invisible          bool
	select             bool
	a11y_label         string // override label for screen readers
	a11y_description   string // extended help text
}

// checkbox is an alias for [toggle](#toggle).
pub fn checkbox(cfg ToggleCfg) View {
	return toggle(cfg)
}

// toggle creates a toggle button (a.k.a checkbox) from the given [ToggleCfg](#ToggleCfg)
pub fn toggle(cfg ToggleCfg) View {
	color := if cfg.select { cfg.color_select } else { cfg.color }
	txt := if cfg.select || cfg.text_unselect == ' ' { cfg.text_select } else { cfg.text_unselect }
	mut txt_style := cfg.text_style
	if !cfg.select && cfg.text_unselect == ' ' {
		txt_style = TextStyle{
			...cfg.text_style
			color: color_transparent
		}
	}
	mut content := []View{cap: 2}

	// Capture values needed for callbacks by copy to avoid dangling reference to cfg
	color_focus := cfg.color_focus
	color_border_focus := cfg.color_border_focus
	color_hover := cfg.color_hover
	color_click := cfg.color_click

	content << row(
		name:         'toggle box'
		color:        color
		color_border: cfg.color_border
		size_border:  cfg.size_border
		padding:      cfg.padding
		radius:       cfg.radius
		disabled:     cfg.disabled
		invisible:    cfg.invisible
		h_align:      .center
		v_align:      .middle
		content:      [
			text(
				text:       txt
				text_style: txt_style
			),
		]
	)

	if cfg.label.len > 0 {
		content << text(
			text:       cfg.label
			text_style: cfg.text_style_label
		)
	}

	return row(
		name:             'toggle'
		id:               cfg.id
		id_focus:         cfg.id_focus
		padding:          padding_none
		v_align:          .middle
		a11y_role:        .checkbox
		a11y_state:       if cfg.select { AccessState.checked } else { AccessState.none }
		a11y_label:       a11y_label(cfg.a11y_label, cfg.label)
		a11y_description: cfg.a11y_description
		on_char:          spacebar_to_click(cfg.on_click)
		on_click:         left_click_only(cfg.on_click)
		on_hover:         fn [color_hover, color_click] (mut layout Layout, mut e Event, mut w Window) {
			w.set_mouse_cursor_pointing_hand()
			if layout.children.len == 0 {
				return
			}
			layout.children[0].shape.color = color_hover
			if e.mouse_button == .left {
				layout.children[0].shape.color = color_click
			}
		}
		min_width:        cfg.min_width
		amend_layout:     fn [color_focus, color_border_focus] (mut layout Layout, mut w Window) {
			if layout.shape.disabled || !layout.shape.has_events()
				|| layout.shape.events.on_click == unsafe { nil } {
				return
			}
			if layout.children.len == 0 {
				return
			}
			if w.is_focus(layout.shape.id_focus) {
				layout.children[0].shape.color = color_focus
				layout.children[0].shape.color_border = color_border_focus
			}
		}
		content:          content
	)
}
