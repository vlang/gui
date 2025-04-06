module gui

import gx

pub struct ProgressBarCfg {
pub:
	id         string
	width      f32
	height     f32
	indefinite bool // TODO: not implemented
	vertical   bool // orientation
	percent    f32  // 0.0 <= percent <= 1.0
	color      gx.Color = gui_theme.progress_bar_style.color
	color_bar  gx.Color = gui_theme.progress_bar_style.color_bar
	radius     f32      = gui_theme.progress_bar_style.radius
	sizing     Sizing
	text       string
	disabled   bool
}

pub fn progress_bar(cfg ProgressBarCfg) View {
	size := f32(gui_theme.progress_bar_style.size)
	container_cfg := ContainerCfg{
		id:           cfg.id
		width:        if cfg.width == 0 { size } else { cfg.width }
		height:       if cfg.height == 0 { size } else { cfg.height }
		color:        cfg.color
		radius:       cfg.radius
		sizing:       cfg.sizing
		padding:      padding_none
		fill:         true
		disabled:     cfg.disabled
		amend_layout: cfg.amend_layout
		content:      [
			rectangle(
				fill:   true
				radius: cfg.radius
				color:  cfg.color_bar
				sizing: fill_fill
			),
		]
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
			node.children[0].shape.height = height
		} else {
			width := f32_min(node.shape.width * percent, node.shape.width)
			node.children[0].shape.width = width
		}
	}
}
