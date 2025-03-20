module gui

import gx

// ButtonConfig configures a clickable button. It won't respond mouse
// interactions if an on_click handler is missing. In that mode, it functions as
// bubble text.
pub struct ButtonCfg {
pub:
	id          string
	focus_id    int @[required] // !0 indicates input is focusable. Value indiciates tabbing order
	color       gx.Color = gx.blue
	color_focus gx.Color = gx.dark_blue
	fill        bool     = true
	height      f32
	padding     Padding = padding(5, 10, 7, 10)
	radius      int     = 5
	text        string
	text_style  gx.TextCfg
	width       f32
	on_click    fn (string, MouseEvent, &Window) bool = unsafe { nil }
}

// button creates a button. Imagine that.
pub fn button(cfg ButtonCfg) &View {
	return row(
		id:           cfg.id
		focus_id:     cfg.focus_id
		width:        cfg.width
		height:       cfg.height
		padding:      cfg.padding
		radius:       cfg.radius
		fill:         cfg.fill
		color:        cfg.color
		on_click:     cfg.on_click
		on_char:      cfg.on_char
		render_focus: cfg.render_focus
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

fn (cfg ButtonCfg) render_focus(mut node ShapeTree, w &Window) {
	node.shape.color = cfg.color_focus
}
