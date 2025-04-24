module gui

// ProgressBarCfg configures a [progress_bar](#progress_bar)
pub struct ProgressBarCfg {
pub:
	id         string
	width      f32
	height     f32
	min_width  f32
	min_height f32
	max_width  f32
	max_height f32
	disabled   bool
	invisible  bool
	sizing     Sizing
	indefinite bool // TODO: not implemented
	vertical   bool // orientation
	percent    f32  // 0.0 <= percent <= 1.0
	color      Color = gui_theme.progress_bar_style.color
	color_bar  Color = gui_theme.progress_bar_style.color_bar
	radius     f32   = gui_theme.progress_bar_style.radius
	text       string
}

// progress_bar creates a progress bar from the given [ProgressBarCfg](#ProgressBarCfg)
pub fn progress_bar(cfg &ProgressBarCfg) View {
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
