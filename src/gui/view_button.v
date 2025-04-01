module gui

import gg
import gx

// ButtonCfgconfigures a clickable button. It won't respond mouse
// interactions if an on_click handler is not provided. In that mode,
// it functions as bubble text.
//
@[heap]
pub struct ButtonCfg {
pub:
	id             string
	id_focus       u32
	width          f32
	height         f32
	min_width      f32
	min_height     f32
	max_width      f32
	max_height     f32
	h_align        HorizontalAlign
	v_align        VerticalAlign
	sizing         Sizing
	content        []View
	fill           bool     = gui_theme.button_style.fill_button
	fill_border    bool     = gui_theme.button_style.fill_button_border
	color          gx.Color = gui_theme.button_style.color_button
	color_focus    gx.Color = gui_theme.button_style.color_button_focus
	color_hover    gx.Color = gui_theme.button_style.color_button_hover
	color_click    gx.Color = gui_theme.button_style.color_button_click
	color_border   gx.Color = gui_theme.button_style.color_button_border
	padding_border Padding  = gui_theme.button_style.padding_button_border
	padding        Padding  = gui_theme.button_style.padding_button
	radius         f32      = gui_theme.button_style.radius_button
	on_click       fn (&ButtonCfg, &gg.Event, &Window) bool = unsafe { nil }
}

// button creates a button. Imagine that.
pub fn button(cfg ButtonCfg) View {
	return row(
		color:      cfg.color_border
		padding:    cfg.padding_border
		fill:       cfg.fill_border
		width:      cfg.width
		height:     cfg.height
		min_width:  cfg.min_width - cfg.padding_border.left - cfg.padding_border.right
		min_height: cfg.min_height - cfg.padding_border.top - cfg.padding_border.bottom
		max_width:  cfg.max_width - cfg.padding_border.left - cfg.padding_border.right
		max_height: cfg.max_height - cfg.padding_border.top - cfg.padding_border.bottom
		sizing:     cfg.sizing
		children:   [
			row(
				id:           cfg.id
				id_focus:     cfg.id_focus
				sizing:       flex_flex
				h_align:      .center
				v_align:      .middle
				padding:      cfg.padding
				radius:       cfg.radius
				fill:         cfg.fill
				color:        cfg.color
				cfg:          &cfg
				on_click:     cfg.on_click
				on_char:      on_char_button
				amend_layout: cfg.amend_layout
				children:     cfg.content
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

fn (cfg ButtonCfg) amend_layout(mut node ShapeTree, mut w Window) {
	if cfg.on_click == unsafe { nil } {
		return
	}
	if node.shape.id_focus > 0 && node.shape.id_focus == w.id_focus() {
		node.shape.color = cfg.color_focus
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
