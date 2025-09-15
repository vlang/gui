module gui

import time

struct TooltipState {
mut:
	bounds DrawClip
	id     string
}

// TooltipCfg configures a [tooltip](#tooltip)
pub struct TooltipCfg {
pub:
	id             string @[required] // unique id to tooltips
	color          Color     = gui_theme.tooltip_style.color
	color_hover    Color     = gui_theme.tooltip_style.color_hover
	color_border   Color     = gui_theme.tooltip_style.color_border
	padding        Padding   = gui_theme.tooltip_style.padding
	padding_border Padding   = gui_theme.tooltip_style.padding_border
	text_style     TextStyle = gui_theme.tooltip_style.text_style
	content        []View
	delay          time.Duration = gui_theme.tooltip_style.delay
	radius         f32           = gui_theme.tooltip_style.radius
	radius_border  f32           = gui_theme.tooltip_style.radius_border
	offset_x       f32           = -3
	offset_y       f32           = -3
	anchor         FloatAttach   = .bottom_center
	tie_off        FloatAttach
	fill           bool = gui_theme.tooltip_style.fill
	fill_border    bool = gui_theme.tooltip_style.fill_border
}

// tooltip creates a tooltip from the given [TooltipCfg](#TooltipCfg)
pub fn tooltip(cfg TooltipCfg) View {
	return row(
		name:           'tooltip border'
		color:          cfg.color_border
		fill:           cfg.fill_border
		padding:        cfg.padding_border
		radius:         cfg.radius_border
		float:          true
		float_anchor:   cfg.anchor
		float_tie_off:  cfg.tie_off
		float_offset_x: cfg.offset_x
		float_offset_y: cfg.offset_y
		content:        [
			row(
				name:    'tooltip interior'
				color:   cfg.color
				fill:    cfg.fill
				padding: cfg.padding
				radius:  cfg.radius
				content: cfg.content
			),
		]
	)
}

fn (cfg TooltipCfg) animation_tooltip() Animate {
	id := cfg.id
	return Animate{
		id:       '___tooltip___'
		callback: fn [id] (mut w Window) {
			if point_in_rectangle(w.ui.mouse_pos_x, w.ui.mouse_pos_y, gui_tooltip.bounds) {
				gui_tooltip.id = id
			}
		}
	}
}
