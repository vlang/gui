module gui

import gg
import gx

// ButtonConfig configures a clickable button. It won't respond mouse
// interactions if an on_click handler is missing. In that mode, it functions as
// bubble text.
pub struct ButtonCfg {
pub:
	id         string
	id_focus   int
	width      f32
	height     f32
	color      gx.Color = button_background
	fill       bool     = true
	padding    Padding  = button_padding_default
	radius     int      = radius_default
	sizing     Sizing
	text       string
	text_style gx.TextCfg = gx.TextCfg{
		color: text_color_default
		size:  text_size_default
	}
	on_click   fn (string, MouseEvent, &Window) = unsafe { nil }
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
		color:        cfg.color
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
	if c == ` ` {
		cfg.on_click(cfg.id, MouseEvent{}, w)
	}
}

fn (cfg ButtonCfg) amend_layout(mut node ShapeTree, mut w Window) {
	if node.shape.id_focus == w.id_focus() {
		node.shape.color = shade_color(node.shape.color, -20)
	}

	ctx := w.context()
	mouse_over := node.shape.point_in_shape(f32(ctx.mouse_pos_x), f32(ctx.mouse_pos_y))

	if mouse_over {
		w.set_mouse_cursor_pointing_hand()
		if ctx.mouse_buttons == gg.MouseButtons.left {
			node.shape.color = shade_color(node.shape.color, -10)
		}
	}
}
