module gui

import math

// ProgressBarCfg configures a [progress_bar](#progress_bar)
pub struct ProgressBarCfg {
pub:
	id              string
	width           f32
	height          f32
	min_width       f32
	min_height      f32
	max_width       f32
	max_height      f32
	disabled        bool
	invisible       bool
	sizing          Sizing
	indefinite      bool // TODO: not implemented
	vertical        bool // orientation
	percent         f32  // 0.0 <= percent <= 1.0
	color           Color   = gui_theme.progress_bar_style.color
	color_bar       Color   = gui_theme.progress_bar_style.color_bar
	text_show       bool    = gui_theme.progress_bar_style.text_show
	text_background Color   = gui_theme.progress_bar_style.text_background
	text_fill       bool    = gui_theme.progress_bar_style.text_fill
	text_padding    Padding = gui_theme.progress_bar_style.text_padding
	radius          f32     = gui_theme.progress_bar_style.radius
	text            string
}

// progress_bar creates a progress bar from the given [ProgressBarCfg](#ProgressBarCfg)
pub fn progress_bar(cfg &ProgressBarCfg) View {
	mut content := []View{cap: 2}
	content << rectangle(
		fill:   true
		radius: cfg.radius
		color:  cfg.color_bar
	)
	if cfg.text_show {
		mut percent := f64_min(f64_max(cfg.percent, f64(0)), f64(1))
		percent = math.round(percent * 100)
		content << row(
			color:         cfg.text_background
			fill:          cfg.text_fill
			padding:       cfg.text_padding
			float:         true
			float_anchor:  .middle_center
			float_tie_off: .middle_center
			content:       [text(text: '${percent:.0}%')]
		)
	}
	size := f32(gui_theme.progress_bar_style.size)
	container_cfg := ContainerCfg{
		id:           cfg.id
		width:        if cfg.width == 0 { size } else { cfg.width }
		height:       if cfg.height == 0 { size } else { cfg.height }
		min_width:    cfg.min_width
		max_width:    cfg.max_width
		min_height:   cfg.min_height
		max_height:   cfg.max_height
		disabled:     cfg.disabled
		invisible:    cfg.invisible
		color:        cfg.color
		radius:       cfg.radius
		sizing:       cfg.sizing
		padding:      padding_none
		fill:         true
		h_align:      .center
		v_align:      .middle
		amend_layout: cfg.amend_layout
		content:      content
	}
	return match cfg.vertical {
		true { column(container_cfg) }
		else { row(container_cfg) }
	}
}

fn (cfg ProgressBarCfg) amend_layout(mut node Layout, mut w Window) {
	if node.children.len >= 0 {
		percent := f32_min(f32_max(cfg.percent, f32(0)), f32(1))
		if cfg.vertical {
			height := f32_min(node.shape.height * percent, node.shape.height)
			node.children[0].shape.x = node.shape.x
			node.children[0].shape.y = node.shape.y
			node.children[0].shape.height = height
			node.children[0].shape.width = node.shape.width
		} else {
			width := f32_min(node.shape.width * percent, node.shape.width)
			node.children[0].shape.x = node.shape.x
			node.children[0].shape.y = node.shape.y
			node.children[0].shape.width = width
			node.children[0].shape.height = node.shape.height
		}
	}
}
