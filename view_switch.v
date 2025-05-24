module gui

import gg

// SwitchCfg a.k.a checkbox. [Switch](#toggle) in its default mode functions and a checkbox.
// However, there is an option of overriding the `text_selected` and `text_unselected` properties.
@[heap]
pub struct SwitchCfg {
pub:
	id                 string
	id_focus           u32
	width              f32 = gui_theme.n2.size * f32(1.65)
	height             f32 = gui_theme.n2.size
	disabled           bool
	invisible          bool
	selected           bool
	fill               bool    = gui_theme.switch_style.fill
	fill_border        bool    = gui_theme.switch_style.fill_border
	color              Color   = gui_theme.switch_style.color
	color_focus        Color   = gui_theme.switch_style.color_focus
	color_hover        Color   = gui_theme.switch_style.color_hover
	color_click        Color   = gui_theme.switch_style.color_click
	color_border       Color   = gui_theme.switch_style.color_border
	color_border_focus Color   = gui_theme.switch_style.color_border_focus
	color_selected     Color   = gui_theme.switch_style.color_selected
	color_unselected   Color   = gui_theme.switch_style.color_unselected
	padding            Padding = gui_theme.switch_style.padding
	padding_border     Padding = gui_theme.switch_style.padding_border
	radius             f32     = gui_theme.switch_style.radius
	radius_border      f32     = gui_theme.switch_style.radius_border
	on_click           fn (&SwitchCfg, mut Event, mut Window) = unsafe { nil }
}

// toggle creates a toggle button (a.k.a checkbox) from the given [SwitchCfg](#SwitchCfg)
pub fn switch(cfg SwitchCfg) View {
	color := if cfg.selected { cfg.color_selected } else { cfg.color_unselected }
	circle_size := cfg.height - cfg.padding.height() - cfg.padding_border.height()

	return row(
		id:           cfg.id
		id_focus:     cfg.id_focus
		width:        cfg.width
		height:       cfg.height
		sizing:       fixed_fit
		color:        cfg.color_border
		padding:      cfg.padding_border
		fill:         cfg.fill_border
		radius:       cfg.radius_border
		disabled:     cfg.disabled
		invisible:    cfg.invisible
		cfg:          &cfg
		on_char:      cfg.on_char_button
		on_click:     cfg.on_click
		amend_layout: cfg.amend_layout
		content:      [
			row(
				color:   cfg.color
				fill:    cfg.fill
				sizing:  fill_fill
				padding: cfg.padding
				radius:  cfg.radius
				h_align: if cfg.selected { .end } else { .start }
				v_align: .middle
				content: [
					circle(
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
}

fn (cfg &SwitchCfg) on_char_button(_ &SwitchCfg, mut e Event, mut w Window) {
	if e.char_code == ` ` && cfg.on_click != unsafe { nil } {
		cfg.on_click(cfg, mut e, mut w)
		e.is_handled = true
	}
}

fn (cfg &SwitchCfg) amend_layout(mut node Layout, mut w Window) {
	if node.shape.disabled || cfg.on_click == unsafe { nil } {
		return
	}
	if w.is_focus(node.shape.id_focus) {
		node.children[0].shape.color = cfg.color_focus
		node.shape.color = cfg.color_border_focus
	}
	ctx := w.context()
	if node.shape.point_in_shape(f32(ctx.mouse_pos_x), f32(ctx.mouse_pos_y)) {
		if w.dialog_cfg.visible && !node_in_dialog_layout(node) {
			return
		}
		w.set_mouse_cursor_pointing_hand()
		node.children[0].shape.color = cfg.color_hover
		if ctx.mouse_buttons == gg.MouseButtons.left {
			node.children[0].shape.color = cfg.color_click
		}
	}
}
