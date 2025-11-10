module gui

import math

@[heap]
pub struct RangeSliderCfg {
pub:
	id             string @[required]
	sizing         Sizing
	color          Color   = gui_theme.range_slider_style.color
	color_border   Color   = gui_theme.range_slider_style.color_border
	color_thumb    Color   = gui_theme.range_slider_style.color_thumb
	color_focus    Color   = gui_theme.range_slider_style.color_focus
	color_hover    Color   = gui_theme.range_slider_style.color_hover
	color_left     Color   = gui_theme.range_slider_style.color_left
	color_click    Color   = gui_theme.range_slider_style.color_click
	padding        Padding = gui_theme.range_slider_style.padding
	padding_border Padding = gui_theme.range_slider_style.padding_border
	on_change      fn (f32, mut Event, mut Window) @[required]
	value          f32
	min            f32
	max            f32 = 100
	step           f32 = 1
	size           f32 = gui_theme.range_slider_style.size
	thumb_size     f32 = gui_theme.range_slider_style.thumb_size
	radius         f32 = gui_theme.range_slider_style.radius
	radius_border  f32 = gui_theme.range_slider_style.radius_border
	id_focus       u32
	round_value    bool // round value to nearest int
	fill           bool = gui_theme.range_slider_style.fill
	fill_border    bool = gui_theme.range_slider_style.fill_border
	vertical       bool
	disabled       bool
	invisible      bool
}

pub fn range_slider(cfg RangeSliderCfg) View {
	if cfg.min >= cfg.max {
		panic('range_slider.min must be less than range_slider.max')
	}
	return container(
		name:         'range_slider border'
		id:           cfg.id
		id_focus:     cfg.id_focus
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
		on_hover:     cfg.on_hover_slide
		on_keydown:   cfg.on_keydown
		content:      [
			container(
				name:    'range_slider interior'
				color:   cfg.color
				fill:    true
				radius:  cfg.radius
				sizing:  fill_fill
				padding: padding_none
				axis:    if cfg.vertical { .top_to_bottom } else { .left_to_right }
				content: [
					rectangle(
						name:   'range_slider left-bar'
						fill:   cfg.fill
						sizing: fill_fill
						color:  cfg.color_left
					),
					circle(
						name:         'range_slider thumb border'
						width:        cfg.thumb_size
						height:       cfg.thumb_size
						fill:         cfg.fill
						color:        cfg.color_border
						padding:      cfg.padding_border
						on_click:     cfg.on_mouse_down
						amend_layout: cfg.amend_layout_thumb
						on_hover:     cfg.on_hover_thumb
						content:      [
							circle(
								name:    'range_slider thumb'
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

fn (cfg &RangeSliderCfg) amend_layout_slide(mut layout Layout, mut w Window) {
	layout.shape.on_click = cfg.on_click
	layout.shape.on_mouse_scroll = cfg.on_mouse_scroll

	// set positions of left/right or top/bottom rectangles
	value := f32_clamp(cfg.value, cfg.min, cfg.max)
	percent := math.abs(value / (cfg.max - cfg.min))
	if cfg.vertical {
		height := layout.children[0].shape.height
		y := f32_min(height * percent, height)
		layout.children[0].children[0].shape.height = y
		// resize bars so the specified width and center
		// horizontally on the thumb.
		offset := (cfg.thumb_size - cfg.size) / 2 + 0.5
		// border
		layout.shape.x += offset
		layout.shape.width = cfg.size
		// interior
		layout.children[0].shape.x += offset
		layout.children[0].shape.width = cfg.size - cfg.padding_border.width()
		// left of thumb bar
		layout.children[0].children[0].shape.x += offset
		layout.children[0].children[0].shape.width = cfg.size
	} else {
		width := layout.children[0].shape.width
		x := f32_min(width * percent, width)
		layout.children[0].children[0].shape.width = x
		// resize bars so the specified height and center
		// vertically on the thumb.
		offset := (cfg.thumb_size - cfg.size) / 2 + 0.5
		// border
		layout.shape.y += offset
		layout.shape.height = cfg.size
		// interior
		layout.children[0].shape.y += offset
		layout.children[0].shape.height = cfg.size - cfg.padding_border.height()
		// left of thumb bar
		layout.children[0].children[0].shape.y += offset
		layout.children[0].children[0].shape.height = cfg.size
	}
	if layout.shape.disabled {
		return
	}
	if w.is_focus(layout.shape.id_focus) {
		layout.children[0].shape.color = cfg.color_focus
	}
}

fn (cfg &RangeSliderCfg) on_hover_slide(mut layout Layout, mut e Event, mut _ Window) {
	layout.children[0].shape.color = cfg.color_hover
	if e.mouse_button == .left {
		layout.children[0].shape.color = cfg.color_click
	}
}

fn (cfg &RangeSliderCfg) amend_layout_thumb(mut layout Layout, mut _ Window) {
	// set the thumb position
	value := f32_clamp(cfg.value, cfg.min, cfg.max)
	percent := math.abs(value / (cfg.max - cfg.min))
	if cfg.vertical {
		height := layout.parent.shape.height
		y := f32_min(height * percent, height)
		layout.shape.y = layout.parent.shape.y + y - cfg.padding_border.height()
		layout.children[0].shape.y = layout.shape.y + cfg.padding_border.top
	} else {
		width := layout.parent.shape.width
		x := f32_min(width * percent, width)
		layout.shape.x = layout.parent.shape.x + x - cfg.padding_border.width()
		layout.children[0].shape.x = layout.shape.x + cfg.padding_border.top
	}
}

fn (_ &RangeSliderCfg) on_hover_thumb(mut _ Layout, mut _ Event, mut w Window) {
	w.set_mouse_cursor_pointing_hand()
}

fn (cfg &RangeSliderCfg) on_mouse_down(_ &Layout, mut e Event, mut w Window) {
	w.mouse_lock(MouseLockCfg{
		mouse_move: cfg.mouse_move
		mouse_up:   fn (_ &Layout, mut _ Event, mut w Window) {
			w.mouse_unlock()
		}
	})
	e.is_handled = true
}

// mouse_move pass cfg by value more reliable here
fn (cfg RangeSliderCfg) mouse_move(layout &Layout, mut e Event, mut w Window) {
	id := cfg.id

	if cfg.on_change != unsafe { nil } {
		if node_circle := layout.find_layout(fn [id] (n Layout) bool {
			return n.shape.id == id
		})
		{
			shape := node_circle.parent.shape
			if cfg.vertical {
				height := shape.height
				percent := f32_clamp((e.mouse_y - shape.y) / height, 0, 1)
				val := (cfg.max - cfg.min) * percent
				mut value := f32_clamp(val, cfg.min, cfg.max)
				if cfg.round_value {
					value = f32(math.round(f64(value)))
				}
				cfg.on_change(value, mut e, mut w)
			} else {
				width := shape.width
				percent := f32_clamp((e.mouse_x - shape.x) / width, 0, 1)
				val := (cfg.max - cfg.min) * percent
				mut value := f32_clamp(val, cfg.min, cfg.max)
				if cfg.round_value {
					value = f32(math.round(f64(value)))
				}
				if value != cfg.value {
					cfg.on_change(value, mut e, mut w)
				}
			}
		}
	}
}

fn (cfg &RangeSliderCfg) on_click(layout &Layout, mut e Event, mut w Window) {
	if cfg.on_change != unsafe { nil } {
		forgiveness := 10
		len := if cfg.vertical { layout.shape.height } else { layout.shape.width }
		mouse := if cfg.vertical { e.mouse_y } else { e.mouse_x }
		pos := if cfg.vertical { layout.shape.y } else { layout.shape.x }
		percent := match true {
			mouse <= pos + forgiveness { 0 }
			mouse >= pos + len - forgiveness { 1 }
			else { f32_clamp((mouse - pos) / len, 0, 1) }
		}
		val := (cfg.max - cfg.min) * percent
		mut value := f32_clamp(val, cfg.min, cfg.max)
		if cfg.round_value {
			value = f32(math.round(f64(value)))
		}
		cfg.on_change(value, mut e, mut w)
	}
}

fn (cfg &RangeSliderCfg) on_keydown(_ &Layout, mut e Event, mut w Window) {
	if cfg.on_change != unsafe { nil } && e.modifiers == 0 {
		mut value := cfg.value
		match e.key_code {
			.home { value = cfg.min }
			.end { value = cfg.max }
			.left, .up { value = f32_clamp(value - cfg.step, cfg.min, cfg.max) }
			.right, .down { value = f32_clamp(value + cfg.step, cfg.min, cfg.max) }
			else { return }
		}
		if cfg.round_value {
			value = f32(math.round(f64(value)))
		}
		if value != cfg.value {
			cfg.on_change(value, mut e, mut w)
		}
	}
}

fn (cfg &RangeSliderCfg) on_mouse_scroll(_ &Layout, mut e Event, mut w Window) {
	e.is_handled = true
	if cfg.on_change != unsafe { nil } && e.modifiers == 0 {
		mut value := f32_clamp(cfg.value + e.scroll_y, cfg.min, cfg.max)
		if cfg.round_value {
			value = f32(math.round(f64(value)))
		}
		if value != cfg.value {
			cfg.on_change(value, mut e, mut w)
		}
	}
}
