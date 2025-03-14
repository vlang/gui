module gui

import gx

// ButtonConfig configures a clickable button.
// It won't respond mouse interactions if an
// on_click handler is missing. In that mode,
// it functions as bubble text.
pub struct ButtonCfg {
pub:
	id         string
	width      f32
	height     f32
	padding    Padding = Padding{5, 10, 7, 10}
	text       string
	color      gx.Color = blue
	fill       bool     = true
	radius     int      = 5
	text_style gx.TextCfg
	on_click   fn (string, MouseEvent, &Window) = unsafe { nil }
}

// button creates a button. Imagine that.
pub fn button(cfg ButtonCfg) &View {
	return canvas(
		id:       cfg.id
		width:    cfg.width
		height:   cfg.height
		padding:  cfg.padding
		radius:   cfg.radius
		fill:     cfg.fill
		color:    cfg.color
		on_click: cfg.on_click
		children: [
			text(
				text:  cfg.text
				style: cfg.text_style
			),
		]
	)
}
