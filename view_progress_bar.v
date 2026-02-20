module gui

import math
import time

// ProgressBarCfg configures a [progress_bar](#progress_bar)
@[minify]
pub struct ProgressBarCfg {
	A11yCfg
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
	disabled        bool
	invisible       bool
	indefinite      bool // indicates indeterminate progress state
	vertical        bool // orientation
}

// progress_bar creates a progress bar from the given [ProgressBarCfg](#ProgressBarCfg)
pub fn progress_bar(cfg ProgressBarCfg) View {
	mut content := []View{cap: 2}
	content << row(
		name:    'progress_bar left-bar'
		padding: padding_none
		radius:  cfg.radius
		color:   cfg.color_bar
	)
	if cfg.text_show && !cfg.indefinite {
		mut percent := f64_min(f64_max(cfg.percent, f64(0)), f64(1))
		percent = math.round(percent * 100)
		content << row(
			name:         'progress_bar percent'
			color_border: cfg.text_background
			padding:      cfg.text_padding
			content:      [text(text: '${percent:.0}%', text_style: cfg.text_style)]
		)
	}

	// Capture values needed for callbacks by copy to avoid dangling reference to cfg
	bar_percent := cfg.percent
	text_show := cfg.text_show
	vertical := cfg.vertical
	indefinite := cfg.indefinite
	id := cfg.id

	size := f32(gui_theme.progress_bar_style.size)
	container_cfg := ContainerCfg{
		name:         'progress_bar'
		id:           cfg.id
		a11y_role:    .progress_bar
		a11y_state:   if cfg.indefinite {
			unsafe { AccessState(int(AccessState.busy) | int(AccessState.live)) }
		} else {
			AccessState.live
		}
		a11y:         &AccessInfo{
			label:       a11y_label(cfg.a11y_label, cfg.text)
			description: cfg.a11y_description
			value_num:   cfg.percent
			value_min:   0.0
			value_max:   1.0
		}
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
		h_align:      .center
		v_align:      .middle
		amend_layout: fn [bar_percent, text_show, vertical, indefinite, id] (mut layout Layout, mut w Window) {
			if layout.children.len >= 0 {
				mut percent := f32_clamp(bar_percent, 0, 1)
				mut offset := f32(0)

				if indefinite {
					// 30% width bar for indefinite mode
					percent = 0.3

					// Register animation if missing
					anim_id := '${id}_indefinite'
					if anim_id !in w.animations {
						mut anim := KeyframeAnimation{
							id:        anim_id
							repeat:    true
							duration:  1500 * time.millisecond
							keyframes: [
								Keyframe{
									at:    0.0
									value: 0.0
								},
								Keyframe{
									at:     0.5
									value:  1.0
									easing: ease_in_out_quad
								},
								Keyframe{
									at:     1.0
									value:  0.0
									easing: ease_in_out_quad
								},
							]
							on_value:  fn [id] (v f32, mut w Window) {
								if w.view_state.progress_state.contains(id) {
									w.view_state.progress_state.set(id, v)
								} else {
									// ensure entry exists
									w.view_state.progress_state.set(id, v)
								}
							}
						}
						anim.start = time.now()
						w.animation_add(mut anim)
					}

					// Read current animation progress
					if progress := w.view_state.progress_state.get(id) {
						// Calculate offset based on available space (1.0 - bar_width_percent) * progress
						offset = (1.0 - percent) * progress
					}
				}

				if vertical {
					height := f32_min(layout.shape.height * percent, layout.shape.height)
					layout.children[0].shape.x = layout.shape.x
					layout.children[0].shape.y = layout.shape.y + (layout.shape.height * offset)
					layout.children[0].shape.height = height
					layout.children[0].shape.width = layout.shape.width
					// center label on bar. Label is row containing text
					if text_show && !indefinite {
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
					layout.children[0].shape.x = layout.shape.x + (layout.shape.width * offset)
					layout.children[0].shape.y = layout.shape.y
					layout.children[0].shape.width = width
					layout.children[0].shape.height = layout.shape.height
					// center label on bar. Label is row containing text
					if text_show && !indefinite {
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
		content:      content
	}
	return match cfg.vertical {
		true { column(container_cfg) }
		else { row(container_cfg) }
	}
}
