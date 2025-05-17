module gui

import gg
import math

@[heap]
pub struct RangeSliderCfg {
pub:
	id             string @[required]
	id_focus       u32
	min            f32
	max            f32 = 100
	value          f32
	round_value    bool // round values to nearest int
	vertical       bool
	disabled       bool
	invisible      bool
	sizing         Sizing
	size           f32                             = gui_theme.range_slider_style.size
	thumb_size     f32                             = gui_theme.range_slider_style.thumb_size
	fill           bool                            = gui_theme.range_slider_style.fill
	fill_border    bool                            = gui_theme.range_slider_style.fill_border
	color          Color                           = gui_theme.range_slider_style.color
	color_border   Color                           = gui_theme.range_slider_style.color_border
	color_thumb    Color                           = gui_theme.range_slider_style.color_thumb
	color_focus    Color                           = gui_theme.range_slider_style.color_focus
	color_hover    Color                           = gui_theme.range_slider_style.color_hover
	color_left     Color                           = gui_theme.range_slider_style.color_left
	color_click    Color                           = gui_theme.range_slider_style.color_click
	padding        Padding                         = gui_theme.range_slider_style.padding
	padding_border Padding                         = gui_theme.range_slider_style.padding_border
	radius         f32                             = gui_theme.range_slider_style.radius
	radius_border  f32                             = gui_theme.range_slider_style.radius_border
	on_change      fn (f32, mut Event, mut Window) = unsafe { nil }
}

pub fn range_slider(cfg RangeSliderCfg) View {
	if cfg.min >= cfg.max {
		panic('range_slider.min must be less thand range_slider.max')
	}
	return container(
		id:           cfg.id
		width:        cfg.size
		height:       cfg.size
		disabled:     cfg.disabled
		invisible:    cfg.invisible
		color:        cfg.color_border
		radius:       cfg.radius_border
		padding:      cfg.padding_border
		fill:         cfg.fill_border
		sizing:       cfg.sizing
		h_align:      .center
		v_align:      .middle
		axis:         if cfg.vertical { .top_to_bottom } else { .left_to_right }
		amend_layout: cfg.amend_layout_slide
		content:      [
			container(
				color:   cfg.color
				fill:    true
				radius:  cfg.radius
				sizing:  fill_fill
				padding: padding_none
				axis:    if cfg.vertical { .top_to_bottom } else { .left_to_right }
				content: [
					rectangle( // left bar
						fill:   cfg.fill
						sizing: fill_fill
						color:  cfg.color_left
					),
					circle( // thumb
						float:         true
						float_anchor:  if cfg.vertical { .top_center } else { .middle_left }
						float_tie_off: .middle_center
						width:         cfg.thumb_size
						height:        cfg.thumb_size
						fill:          cfg.fill
						color:         cfg.color_border
						padding:       cfg.padding_border
						on_click:      cfg.on_mouse_down
						amend_layout:  cfg.amend_layout_thumb
						content:       [
							circle(
								fill:    cfg.fill
								color:   cfg.color_thumb
								padding: padding_none
								width:   cfg.thumb_size - cfg.padding_border.width()
								height:  cfg.thumb_size - cfg.padding_border.height()
							),
						]
					),
				]
			),
		]
	)
}

fn (cfg &RangeSliderCfg) amend_layout_slide(mut node Layout, mut w Window) {
	node.shape.on_mouse_down_shape = cfg.on_mouse_down_shape

	// set positions of left/right or top/bottom rectangles
	value := clamp_f32(cfg.value, cfg.min, cfg.max)
	percent := math.abs(value / (cfg.max - cfg.min))
	if cfg.vertical {
		height := node.children[0].shape.height
		y := f32_min(height * percent, height)
		node.children[0].children[0].shape.height = y
	} else {
		width := node.children[0].shape.width
		x := f32_min(width * percent, width)
		node.children[0].children[0].shape.width = x
	}

	if node.shape.disabled {
		return
	}
	if w.is_focus(node.shape.id_focus) {
		node.children[0].shape.color = cfg.color_focus
	}
	ctx := w.context()
	if node.shape.point_in_shape(f32(ctx.mouse_pos_x), f32(ctx.mouse_pos_y)) || w.mouse_is_locked() {
		if w.dialog_cfg.visible && !node_in_dialog_layout(node) {
			return
		}
		node.children[0].shape.color = cfg.color_hover
		if ctx.mouse_buttons == gg.MouseButtons.left {
			node.children[0].shape.color = cfg.color_click
		}
	}
}

fn (cfg &RangeSliderCfg) amend_layout_thumb(mut node Layout, mut w Window) {
	// set the thumb position
	value := clamp_f32(cfg.value, cfg.min, cfg.max)
	percent := math.abs(value / (cfg.max - cfg.min))
	if cfg.vertical {
		height := node.parent.shape.height
		y := f32_min(height * percent, height)
		node.move_shape_positions(0, y - cfg.padding_border.height())
	} else {
		width := node.parent.shape.width
		x := f32_min(width * percent, width)
		node.move_shape_positions(x - cfg.padding_border.width(), 0)
	}
	// set mouse cursor
	ctx := w.context()
	if node.shape.point_in_shape(f32(ctx.mouse_pos_x), f32(ctx.mouse_pos_y)) {
		if w.dialog_cfg.visible && !node_in_dialog_layout(node) {
			return
		}
		w.set_mouse_cursor_pointing_hand()
	}
}

fn (cfg &RangeSliderCfg) on_mouse_down(node &Layout, mut e Event, mut w Window) {
	w.mouse_lock(MouseLockCfg{
		mouse_move: cfg.mouse_move
		mouse_up:   fn (node &Layout, mut e Event, mut w Window) {
			w.mouse_unlock()
		}
	})
}

// pass cfg by value more reliable here
fn (cfg RangeSliderCfg) mouse_move(node &Layout, mut e Event, mut w Window) {
	if cfg.on_change != unsafe { nil } {
		if node_circle := node.find_node(fn [cfg] (n Layout) bool {
			return n.shape.id == cfg.id
		})
		{
			shape := node_circle.parent.shape
			if cfg.vertical {
				height := shape.height
				percent := clamp_f32((e.mouse_y - shape.y) / height, 0, 1)
				val := (cfg.max - cfg.min) * percent
				mut value := clamp_f32(val, cfg.min, cfg.max)
				if cfg.round_value {
					value = f32(math.round(f64(value)))
				}
				cfg.on_change(value, mut e, mut w)
			} else {
				width := shape.width
				percent := clamp_f32((e.mouse_x - shape.x) / width, 0, 1)
				val := (cfg.max - cfg.min) * percent
				mut value := clamp_f32(val, cfg.min, cfg.max)
				if cfg.round_value {
					value = f32(math.round(f64(value)))
				}
				cfg.on_change(value, mut e, mut w)
			}
		}
	}
}

fn (cfg &RangeSliderCfg) on_mouse_down_shape(shape &Shape, mut e Event, mut w Window) {
	if cfg.on_change != unsafe { nil } {
		forgiveness := 10
		len := if cfg.vertical { shape.height } else { shape.width }
		mouse := if cfg.vertical { e.mouse_y } else { e.mouse_x }
		pos := if cfg.vertical { shape.y } else { shape.x }
		percent := match true {
			mouse <= pos + forgiveness { 0 }
			mouse >= pos + len - forgiveness { 1 }
			else { clamp_f32((mouse - pos) / len, 0, 1) }
		}
		val := (cfg.max - cfg.min) * percent
		mut value := clamp_f32(val, cfg.min, cfg.max)
		if cfg.round_value {
			value = f32(math.round(f64(value)))
		}
		cfg.on_change(value, mut e, mut w)
	}
}
