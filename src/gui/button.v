module gui

import gg
import gx

// ButtonConfig configures a clickable button. It won't respond mouse
// interactions if an on_click handler is missing. In that mode, it functions as
// bubble text.
//
pub struct ButtonCfg {
pub:
	id          string
	id_focus    int
	width       f32
	height      f32
	color       gx.Color = color_button
	color_focus gx.Color = shade_color(color_button, 10)
	color_hover gx.Color = shade_color(color_button, 20)
	color_click gx.Color = shade_color(color_button, 30)
	fill        bool     = true
	h_align     HorizontalAlign
	v_align     VerticalAlign
	padding     Padding = padding_button
	radius      int     = radius_medium
	sizing      Sizing
	text        string
	text_style  gx.TextCfg = text_cfg
	on_click    fn (&ButtonCfg, MouseEvent, &Window) = unsafe { nil }
}

// button creates a button. Imagine that.
pub fn button(cfg ButtonCfg) &View {
	return row(
		id:           cfg.id
		id_focus:     cfg.id_focus
		width:        cfg.width
		height:       cfg.height
		padding:      cfg.padding
		sizing:       cfg.sizing
		radius:       cfg.radius
		fill:         cfg.fill
		v_align:      cfg.v_align
		h_align:      cfg.h_align
		color:        cfg.color
		cfg:          &ButtonCfg{ // allocate on heap
			...cfg
		}
		on_click:     cfg.on_click
		on_char:      cfg.on_char
		amend_layout: cfg.amend_layout
		children:     [
			text(
				text:  cfg.text
				style: cfg.text_style
			),
		]
	)
}

fn (cfg ButtonCfg) on_char(c u32, mut w Window) {
	if c == ` ` && cfg.on_click != unsafe { nil } {
		cfg.on_click(&cfg, MouseEvent{}, w)
	}
}

fn (cfg ButtonCfg) amend_layout(mut node ShapeTree, mut w Window) {
	if cfg.on_click == unsafe { nil } {
		return
	}
	if node.shape.id_focus == w.id_focus() {
		node.shape.color = cfg.color_focus
	}
	ctx := w.context()
	if node.shape.point_in_shape(f32(ctx.mouse_pos_x), f32(ctx.mouse_pos_y)) {
		w.set_mouse_cursor_pointing_hand()
		node.shape.color = cfg.color_hover
		if ctx.mouse_buttons == gg.MouseButtons.left {
			node.shape.color = cfg.color_click
			node.children[0].shape.color = shade_color(node.children[0].shape.color, -20)
		}
	}
}
