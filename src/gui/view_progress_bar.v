module gui

import gx

pub struct ProgressBarCfg {
pub:
	id         string
	width      f32
	height     f32
	indefinite bool
	vertical   bool
	percent    f32
	color      gx.Color = color_progress
	color_bar  gx.Color = color_progress_bar
	radius     int      = radius_small
	sizing     Sizing
	text       string
	text_style gx.TextCfg = text_cfg
}

pub fn progress_bar(cfg ProgressBarCfg) View {
	container_cfg := ContainerCfg{
		id:           cfg.id
		width:        if cfg.width == 0 { size_progress_bar } else { cfg.width }
		height:       if cfg.height == 0 { size_progress_bar } else { cfg.height }
		color:        cfg.color
		radius:       cfg.radius
		sizing:       cfg.sizing
		padding:      padding_none
		fill:         true
		amend_layout: cfg.amend_layout
		children:     [
			rectangle(
				fill:   true
				radius: cfg.radius
				color:  cfg.color_bar
				sizing: flex_flex
			),
		]
	}
	return match cfg.vertical {
		true { column(container_cfg) }
		else { row(container_cfg) }
	}
}

fn (cfg ProgressBarCfg) amend_layout(mut node ShapeTree, mut w Window) {
	if node.children.len == 0 {
		return
	}
	percent := f32_min(f32_max(cfg.percent, f32(0)), f32(1))
	if cfg.vertical {
		height := f32_min(node.shape.height * percent, node.shape.height)
		node.children[0].shape.height = height
	} else {
		width := f32_min(node.shape.width * percent, node.shape.width)
		node.children[0].shape.width = width
	}
}
