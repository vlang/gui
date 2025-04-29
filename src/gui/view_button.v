module gui

import gg

// ButtonCfg configures a clickable [button](#button). It won't respond mouse
// interactions if an on_click handler is not provided. In that mode,
// it functions as bubble text.
@[heap]
pub struct ButtonCfg {
pub:
	id                 string
	width              f32
	height             f32
	min_width          f32
	min_height         f32
	max_width          f32
	max_height         f32
	disabled           bool
	invisible          bool
	sizing             Sizing
	id_focus           u32
	h_align            HorizontalAlign = .center
	v_align            VerticalAlign   = .middle
	content            []View
	fill               bool    = gui_theme.button_style.fill
	fill_border        bool    = gui_theme.button_style.fill_border
	color              Color   = gui_theme.button_style.color
	color_focus        Color   = gui_theme.button_style.color_focus
	color_hover        Color   = gui_theme.button_style.color_hover
	color_click        Color   = gui_theme.button_style.color_click
	color_border       Color   = gui_theme.button_style.color_border
	color_border_focus Color   = gui_theme.button_style.color_border_focus
	padding            Padding = gui_theme.button_style.padding
	padding_border     Padding = gui_theme.button_style.padding_border
	radius             f32     = gui_theme.button_style.radius
	radius_border      f32     = gui_theme.button_style.radius_border
	on_click           fn (&ButtonCfg, mut Event, mut Window) = unsafe { nil }
}

// button creates a clickable button. Buttons can contain content other than text.
// See [ButtonCfg](#ButtonCfg)
// Example:
// ```v
// gui.button(
// 	min_width:      90
// 	max_width:      90
// 	padding_border: gui.padding_one
// 	content:        [gui.text(text: '${app.clicks} Clicks')]
// 	on_click:       fn (_ &gui.ButtonCfg, _ &gui.Event, mut w gui.Window) bool {
// 		mut app := w.state[App]()
// 		app.clicks += 1
// 		return true
// 	}
// )
// ```
pub fn button(cfg ButtonCfg) View {
	return row(
		id:           cfg.id
		id_focus:     cfg.id_focus
		color:        cfg.color_border
		padding:      cfg.padding_border
		fill:         cfg.fill_border
		radius:       cfg.radius_border
		width:        cfg.width
		height:       cfg.height
		disabled:     cfg.disabled
		invisible:    cfg.invisible
		min_width:    cfg.min_width
		max_width:    cfg.max_width
		min_height:   cfg.min_height
		max_height:   cfg.max_height
		sizing:       cfg.sizing
		cfg:          &cfg
		on_click:     cfg.on_click
		on_char:      cfg.on_char_button
		amend_layout: cfg.amend_layout
		content:      [
			row(
				sizing:  fill_fill
				h_align: cfg.h_align
				v_align: cfg.v_align
				padding: cfg.padding
				radius:  cfg.radius
				fill:    cfg.fill
				color:   cfg.color
				content: cfg.content
			),
		]
	)
}

fn (cfg &ButtonCfg) on_char_button(_ &ButtonCfg, mut e Event, mut w Window) {
	if e.char_code == ` ` && cfg.on_click != unsafe { nil } {
		cfg.on_click(cfg, mut e, mut w)
		e.is_handled = true
	}
}

fn (cfg &ButtonCfg) amend_layout(mut node Layout, mut w Window) {
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
