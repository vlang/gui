module gui

import gx

// ButtonConfig configures a clickable button. It won't respond mouse
// interactions if an on_click handler is missing. In that mode, it functions as
// bubble text.
pub struct ButtonCfg {
pub:
	id          string
	id_focus    int @[required] // !0 indicates input is focusable. Value indiciates tabbing order
	width       f32
	height      f32
	color       gx.Color = gx.blue
	color_focus gx.Color = gx.dark_blue
	color_hover gx.Color = gx.indigo
	fill        bool     = true
	padding     Padding  = padding(5, 10, 7, 10)
	radius      int      = 5
	text        string
	text_style  gx.TextCfg
	on_click    fn (string, MouseEvent, &Window) bool = unsafe { nil }
}

// button creates a button. Imagine that.
pub fn button(cfg ButtonCfg) &View {
	return row(
		id:           cfg.id
		id_focus:     cfg.id_focus
		width:        cfg.width
		height:       cfg.height
		padding:      cfg.padding
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

fn (cfg ButtonCfg) on_char(c u32, mut w Window) bool {
	if c == ` ` {
		cfg.on_click(cfg.id, MouseEvent{}, w)
		return true
	}
	return false
}

fn (cfg ButtonCfg) amend_layout(mut node ShapeTree, w &Window) {
	if node.shape.point_in_shape(w.mouse_x, w.mouse_y) {
		node.shape.color = cfg.color_hover
	} else if node.shape.id_focus == w.id_focus {
		node.shape.color = cfg.color_focus
	}
}
