module gui

import math

// ProgressBarCfg configures a [progress_bar](#progress_bar)
@[heap]
pub struct ProgressBarCfg {
pub:
	id              string
	text            string
	sizing          Sizing
	text_style      TextStyle = gui_theme.text_style
	color           Color     = gui_theme.progress_bar_style.color
	color_bar       Color     = gui_theme.progress_bar_style.color_bar
	text_background Color     = gui_theme.progress_bar_style.text_background
	text_padding    Padding   = gui_theme.progress_bar_style.text_padding
	width           f32
	height          f32
	min_width       f32
	min_height      f32
	max_width       f32
	max_height      f32
	percent         f32 // 0.0 <= percent <= 1.0
	radius          f32  = gui_theme.progress_bar_style.radius
	text_show       bool = gui_theme.progress_bar_style.text_show
	text_fill       bool = gui_theme.progress_bar_style.text_fill
	disabled        bool
	invisible       bool
	indefinite      bool // TODO: not implemented
	vertical        bool // orientation
}

// progress_bar creates a progress bar from the given [ProgressBarCfg](#ProgressBarCfg)
pub fn progress_bar(cfg ProgressBarCfg) View {
	mut content := []View{cap: 2}
	unsafe { content.flags.set(.noslices) }
	content << row(
		name:    'progress_bar left-bar'
		fill:    true
		padding: padding_none
		radius:  cfg.radius
		color:   cfg.color_bar
	)
	if cfg.text_show {
		mut percent := f64_min(f64_max(cfg.percent, f64(0)), f64(1))
		percent = math.round(percent * 100)
		content << row(
			name:    'progress_bar percent'
			color:   cfg.text_background
			fill:    cfg.text_fill
			padding: cfg.text_padding
			content: [text(text: '${percent:.0}%', text_style: cfg.text_style)]
		)
	}
	size := f32(gui_theme.progress_bar_style.size)
	container_cfg := ContainerCfg{
		name:         'progress_bar'
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

fn (cfg ProgressBarCfg) amend_layout(mut layout Layout, mut w Window) {
	if layout.children.len >= 0 {
		percent := f32_clamp(cfg.percent, 0, 1)
		if cfg.vertical {
			height := f32_min(layout.shape.height * percent, layout.shape.height)
			layout.children[0].shape.x = layout.shape.x
			layout.children[0].shape.y = layout.shape.y
			layout.children[0].shape.height = height
			layout.children[0].shape.width = layout.shape.width
			// center label on bar. Label is row containing text
			if cfg.text_show {
				center := layout.shape.x + layout.shape.width / 2
				half_width := layout.children[1].shape.width / 2
				old_x := layout.children[1].shape.x
				layout.children[1].shape.x = center - half_width
				layout.children[1].children[0].shape.x -= old_x - layout.children[1].shape.x

				middle := layout.shape.y + layout.shape.height / 2
				half_height := layout.children[1].shape.height / 2
				old_y := layout.children[1].shape.y
				layout.children[1].shape.y = middle - half_height
				layout.children[1].children[0].shape.y -= old_y - layout.children[1].shape.y
			}
		} else {
			width := f32_min(layout.shape.width * percent, layout.shape.width)
			layout.children[0].shape.x = layout.shape.x
			layout.children[0].shape.y = layout.shape.y
			layout.children[0].shape.width = width
			layout.children[0].shape.height = layout.shape.height
			// center label on bar. Label is row containing text
			if cfg.text_show {
				middle := layout.shape.y + layout.shape.height / 2
				half_height := layout.children[1].shape.height / 2
				old_y := layout.children[1].shape.y
				layout.children[1].shape.y = middle - half_height
				layout.children[1].children[0].shape.y -= old_y - layout.children[1].shape.y

				center := layout.shape.x + layout.shape.width / 2
				half_width := layout.children[1].shape.width / 2
				old_x := layout.children[1].shape.x
				layout.children[1].shape.x = center - half_width
				layout.children[1].children[0].shape.x -= old_x - layout.children[1].shape.x
			}
		}
	}
}
