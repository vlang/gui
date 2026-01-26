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
	size_border        f32       = gui_theme.switch_style.size_border
	text_style         TextStyle = gui_theme.switch_style.text_style
	on_click           fn (&Layout, mut Event, mut Window) @[required]
	width              f32 = gui_theme.switch_style.size_width
	height             f32 = gui_theme.switch_style.size_height
	radius             f32 = gui_theme.switch_style.radius
	radius_border      f32 = gui_theme.switch_style.radius_border
	id_focus           u32
	disabled           bool
	invisible          bool
	select             bool
}

// switch creates a pill shaped box with a sliding toggle from the given [SwitchCfg](#SwitchCfg)
pub fn switch(cfg SwitchCfg) View {
	color := if cfg.select { cfg.color_select } else { cfg.color_unselect }
	circle_size := cfg.height - cfg.padding.height() - (cfg.size_border * 2)

	// Capture values needed for callbacks by copy to avoid dangling reference to cfg
	color_focus := cfg.color_focus
	color_border_focus := cfg.color_border_focus
	color_hover := cfg.color_hover
	color_click := cfg.color_click

	mut content := []View{cap: 2}
	content << row(
		name:         'switch'
		id:           cfg.id
		width:        cfg.width
		height:       cfg.height
		sizing:       fixed_fit
		color:        cfg.color
		color_border: cfg.color_border
		size_border:  cfg.size_border
		radius:       cfg.radius
		disabled:     cfg.disabled
		invisible:    cfg.invisible
		padding:      cfg.padding
		h_align:      if cfg.select { .end } else { .start }
		v_align:      .middle
		content:      [
			circle(
				name:   'select thumb'
				color:  color
				width:  circle_size
				height: circle_size
				sizing: fixed_fixed
			),
		]
	)
	if cfg.label.len > 0 {
		content << text(text: cfg.label, text_style: cfg.text_style)
	}
	return row(
		id_focus:     cfg.id_focus
		padding:      padding_none
		on_char:      spacebar_to_click(cfg.on_click)
		on_click:     left_click_only(cfg.on_click)
		on_hover:     fn [color_hover, color_click] (mut layout Layout, mut e Event, mut w Window) {
			w.set_mouse_cursor_pointing_hand()
			layout.children[0].shape.color = color_hover
			if e.mouse_button == .left {
				layout.children[0].shape.color = color_click
			}
		}
		amend_layout: fn [color_focus, color_border_focus] (mut layout Layout, mut w Window) {
			if layout.shape.disabled || layout.shape.on_click == unsafe { nil } {
				return
			}
			if w.is_focus(layout.shape.id_focus) {
				layout.shape.color = color_focus
				layout.shape.color_border = color_border_focus
			}
		}
		content:      content
	)
}
