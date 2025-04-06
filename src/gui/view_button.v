module gui

import gg
import gx

// ButtonCfgconfigures a clickable button. It won't respond mouse
// interactions if an on_click handler is not provided. In that mode,
// it functions as bubble text.
@[heap]
pub struct ButtonCfg {
pub:
	id                 string
	id_focus           u32
	width              f32
	height             f32
	min_width          f32
	min_height         f32
	max_width          f32
	max_height         f32
	disabled           bool
	h_align            HorizontalAlign = .center
	v_align            VerticalAlign   = .middle
	sizing             Sizing
	content            []View
	fill               bool     = gui_theme.button_style.fill
	fill_border        bool     = gui_theme.button_style.fill_border
	color              gx.Color = gui_theme.button_style.color
	color_focus        gx.Color = gui_theme.button_style.color_focus
	color_hover        gx.Color = gui_theme.button_style.color_hover
	color_click        gx.Color = gui_theme.button_style.color_click
	color_border       gx.Color = gui_theme.button_style.color_border
	color_border_focus gx.Color = gui_theme.button_style.color_border_focus
	padding            Padding  = gui_theme.button_style.padding
	padding_border     Padding  = gui_theme.button_style.padding_border
	radius             f32      = gui_theme.button_style.radius
	radius_border      f32      = gui_theme.button_style.radius_border
	on_click           fn (&ButtonCfg, &gg.Event, &Window) bool = unsafe { nil }
}

// button creates a button.
// Example:
// ```v
// gui.button(
// 	min_width:      90
// 	max_width:      90
// 	padding_border: gui.padding_one
// 	content:        [gui.text(text: '${app.clicks} Clicks')]
// 	on_click:       fn (_ &gui.ButtonCfg, _ &gg.Event, mut w gui.Window) bool {
// 		mut app := w.state[App]()
// 		app.clicks += 1
// 		return true
// 	}
// )
// ```
pub fn button(cfg ButtonCfg) View {
	return row(
		id:         cfg.id
		color:      cfg.color_border
		padding:    cfg.padding_border
		fill:       cfg.fill_border
		radius:     cfg.radius_border
		width:      cfg.width
		height:     cfg.height
		disabled:   cfg.disabled
		min_width:  cfg.min_width
		max_width:  cfg.max_width
		min_height: cfg.min_height
		max_height: cfg.max_height
		sizing:     cfg.sizing
		content:    [
			row(
				id_focus:     cfg.id_focus
				sizing:       fill_fill
				h_align:      cfg.h_align
				v_align:      cfg.v_align
				padding:      cfg.padding
				radius:       cfg.radius
				fill:         cfg.fill
				color:        cfg.color
				cfg:          &cfg
				on_click:     cfg.on_click
				on_char:      on_char_button
				amend_layout: cfg.amend_layout
				content:      cfg.content
			),
		]
	)
}

fn on_char_button(cfg &ButtonCfg, e &gg.Event, mut w Window) bool {
	if e.char_code == ` ` && cfg.on_click != unsafe { nil } {
		cfg.on_click(&cfg, e, w)
		return true
	}
	return false
}

fn (cfg ButtonCfg) amend_layout(mut node Layout, mut w Window) {
	if node.shape.disabled || cfg.on_click == unsafe { nil } {
		return
	}
	if node.shape.id_focus > 0 && node.shape.id_focus == w.id_focus() {
		node.parent.color = cfg.color_border_focus
	}
	ctx := w.context()
	if node.shape.point_in_shape(f32(ctx.mouse_pos_x), f32(ctx.mouse_pos_y)) {
		w.set_mouse_cursor_pointing_hand()
		node.shape.color = cfg.color_hover
		if ctx.mouse_buttons == gg.MouseButtons.left {
			node.shape.color = cfg.color_click
		}
	}
}
