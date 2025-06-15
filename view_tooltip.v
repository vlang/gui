module gui

import time
import hash.fnv1a

pub struct TooltipCfg {
pub:
	id             string
	delay          time.Duration = gui_theme.tooltip_style.delay
	color          Color         = gui_theme.tooltip_style.color
	color_hover    Color         = gui_theme.tooltip_style.color_hover
	color_border   Color         = gui_theme.tooltip_style.color_border
	fill           bool          = gui_theme.tooltip_style.fill
	fill_border    bool          = gui_theme.tooltip_style.fill_border
	padding        Padding       = gui_theme.tooltip_style.padding
	padding_border Padding       = gui_theme.tooltip_style.padding_border
	radius         f32           = gui_theme.tooltip_style.radius
	radius_border  f32           = gui_theme.tooltip_style.radius_border
	text_style     TextStyle     = gui_theme.tooltip_style.text_style
	anchor         FloatAttach   = .bottom_center
	tie_off        FloatAttach
	offset_x       f32 = -3
	offset_y       f32 = -3
	content        []View
}

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

fn (cfg TooltipCfg) animation_tooltip() AnimationDelay {
	return AnimationDelay{
		id:       '___tooltip___'
		callback: fn [cfg] (mut w Window) {
			if point_in_rectangle(w.ui.mouse_pos_x, w.ui.mouse_pos_y, gui_tooltip.bounds) {
				gui_tooltip.id = cfg.hash()
			}
		}
	}
}

fn (cfg TooltipCfg) hash() u32 {
	lines := cfg.str().split_into_lines()
	clean := lines.filter(!it.contains('cfg:'))
	return fnv1a.sum32_string(clean.join('\n'))
}
