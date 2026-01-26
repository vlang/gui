module gui

// view_range_slider.v implements a range slider UI component that allows users
// to select a value from a continuous range by dragging a thumb along a track.
// The component supports both horizontal and vertical orientations, customizable
// styling, keyboard navigation, mouse wheel input, and configurable value ranges.
//
import math

// RangeSliderCfg defines the configuration options for the range slider component.
// It includes visual styling properties like colors and dimensions, behavioral
// settings like value range and step size, and callbacks for handling user input.
@[heap; minify]
pub struct RangeSliderCfg {
pub:
	id            string @[required]
	sizing        Sizing
	color         Color   = gui_theme.range_slider_style.color
	color_border  Color   = gui_theme.range_slider_style.color_border
	color_thumb   Color   = gui_theme.range_slider_style.color_thumb
	color_focus   Color   = gui_theme.range_slider_style.color_focus
	color_hover   Color   = gui_theme.range_slider_style.color_hover
	color_left    Color   = gui_theme.range_slider_style.color_left
	color_click   Color   = gui_theme.range_slider_style.color_click
	padding       Padding = gui_theme.range_slider_style.padding
	size_border   f32     = gui_theme.range_slider_style.size_border
	on_change     fn (f32, mut Event, mut Window) @[required]
	value         f32
	min           f32
	max           f32 = 100
	step          f32 = 1
	size          f32 = gui_theme.range_slider_style.size
	thumb_size    f32 = gui_theme.range_slider_style.thumb_size
	radius        f32 = gui_theme.range_slider_style.radius
	radius_border f32 = gui_theme.range_slider_style.radius_border
	id_focus      u32
	round_value   bool // round value to nearest int
	vertical      bool
	disabled      bool
	invisible     bool
}

// range_slider creates and returns a range slider View component based on the provided configuration.
// The range slider allows users to select a numeric value within a specified range by dragging
// a thumb along a track or using keyboard/mouse wheel input.
//
// Parameters:
//   cfg RangeSliderCfg - Configuration struct containing all customization options including:
//   - Visual styling (colors, dimensions, etc.)
//   - Value range (min/max)
//   - Step size
//   - Callbacks for input handling
//   - Layout options
//
// Returns:
//   View - A fully configured range slider View component
//
pub fn range_slider(cfg RangeSliderCfg) View {
	if cfg.min >= cfg.max {
		panic('range_slider.min must be less than range_slider.max')
	}
	return container(
		name:         'range_slider'
		id:           cfg.id
		id_focus:     cfg.id_focus
		width:        cfg.size
		height:       cfg.size
		disabled:     cfg.disabled
		invisible:    cfg.invisible
		color:        cfg.color
		color_border: cfg.color_border
		size_border:  cfg.size_border
		radius:       cfg.radius_border
		padding:      padding_none
		sizing:       cfg.sizing
		h_align:      .center
		v_align:      .middle
		axis:         if cfg.vertical { .top_to_bottom } else { .left_to_right }
		on_click:     make_range_slider_on_mouse_down(cfg)
		amend_layout: make_range_slider_amend_layout_slide(cfg)
		on_hover:     make_range_slider_on_hover_slide(cfg)
		on_keydown:   make_range_slider_on_keydown(cfg)
		content:      [
			rectangle(
				name:         'range_slider left-bar'
				sizing:       fill_fill
				color:        cfg.color_left
				color_border: cfg.color_left
			),
			circle(
				name:         'range_slider thumb'
				width:        cfg.thumb_size
				height:       cfg.thumb_size
				color:        cfg.color_thumb
				color_border: cfg.color_border
				size_border:  cfg.size_border
				padding:      padding_none

				amend_layout: make_range_slider_amend_layout_thumb(cfg)
			),
		]
	)
}

// Wrapper functions to capture RangeSliderCfg by value to avoid dangling reference issues.
fn make_range_slider_on_mouse_down(cfg RangeSliderCfg) fn (&Layout, mut Event, mut Window) {
	return fn [cfg] (layout &Layout, mut e Event, mut w Window) {
		mut ev := &Event{
			...e
			touches: e.touches // runtime mem error otherwise
			mouse_x: e.mouse_x + layout.shape.x
			mouse_y: e.mouse_y + layout.shape.y
		}
		cfg.mouse_move(layout, mut ev, mut w)

		// Lock the mouse to the range slider until the mouse button is released
		w.mouse_lock(MouseLockCfg{
			// event mouse coordinates are not adjusted here
			mouse_move: fn [cfg] (layout &Layout, mut e Event, mut w Window) {
				cfg.mouse_move(layout, mut e, mut w)
			}
			mouse_up:   fn (_ &Layout, mut _ Event, mut w Window) {
				w.mouse_unlock()
			}
		})
		e.is_handled = true
	}
}

fn make_range_slider_amend_layout_slide(cfg RangeSliderCfg) fn (mut Layout, mut Window) {
	return fn [cfg] (mut layout Layout, mut w Window) {
		cfg.amend_layout_slide(mut layout, mut w)
	}
}

fn make_range_slider_on_hover_slide(cfg RangeSliderCfg) fn (mut Layout, mut Event, mut Window) {
	return fn [cfg] (mut layout Layout, mut e Event, mut w Window) {
		cfg.on_hover_slide(mut layout, mut e, mut w)
	}
}

fn make_range_slider_on_keydown(cfg RangeSliderCfg) fn (&Layout, mut Event, mut Window) {
	return fn [cfg] (layout &Layout, mut e Event, mut w Window) {
		cfg.on_keydown(layout, mut e, mut w)
	}
}

fn make_range_slider_amend_layout_thumb(cfg RangeSliderCfg) fn (mut Layout, mut Window) {
	return fn [cfg] (mut layout Layout, mut w Window) {
		cfg.amend_layout_thumb(mut layout, mut w)
	}
}

// amend_layout_slide adjusts the layout of the range slider components based on the
// current value and configuration.
//
// The slider consists of two main visual elements:
// 1. A main container (track) with native border
// 2. A "filled" portion showing the selected value (left bar)
// 3. A thumb
//
// For vertical sliders:
// - Adjusts the height of the left bar based on current value percentage
// - Centers the track horizontally relative to the thumb
// - Applies padding and sizing to maintain proper visual alignment
//
// For horizontal sliders:
// - Adjusts the width of the left bar based on current value percentage
// - Centers the track vertically relative to the thumb
// - Applies padding and sizing to maintain proper visual alignment
//
// Parameters:
//   layout Layout - The root layout node for the range slider
//   w Window      - Window context for focus state handling
fn (cfg &RangeSliderCfg) amend_layout_slide(mut layout Layout, mut w Window) {
	layout.shape.on_mouse_scroll = cfg.on_mouse_scroll

	// set positions of left/right or top/bottom rectangles
	value := f32_clamp(cfg.value, cfg.min, cfg.max)
	percent := math.abs(value / (cfg.max - cfg.min))
	if cfg.vertical {
		height := layout.shape.height
		y := f32_min(height * percent, height)
		layout.children[0].shape.height = y
		// resize bars so the specified width and center
		// horizontally on the thumb.
		offset := (cfg.thumb_size - cfg.size) / 1.5
		// track
		layout.shape.x += offset
		layout.shape.width = cfg.size

		// left of thumb bar
		layout.children[0].shape.x += offset
		layout.children[0].shape.width = cfg.size - (cfg.size_border * 2)
	} else {
		width := layout.shape.width
		x := f32_min(width * percent, width)
		layout.children[0].shape.width = x
		// resize bars so the specified height and center
		// vertically on the thumb.
		offset := (cfg.thumb_size - cfg.size) / 1.5
		// track
		layout.shape.y += offset
		layout.shape.height = cfg.size

		// left of thumb bar
		layout.children[0].shape.y += offset
		layout.children[0].shape.height = cfg.size - (cfg.size_border * 2)
	}
	if layout.shape.disabled {
		return
	}
	if w.is_focus(layout.shape.id_focus) {
		layout.children[1].shape.color = cfg.color_focus // Thumb border
		layout.children[1].shape.color_border = cfg.color_focus // Thumb border
	}
}

fn (cfg &RangeSliderCfg) on_hover_slide(mut layout Layout, mut e Event, mut w Window) {
	w.set_mouse_cursor_pointing_hand()
	layout.shape.color_border = cfg.color_hover
	if e.mouse_button == .left {
		layout.children[1].shape.color_border = cfg.color_click // Thumb border
	}
}

// amend_layout_thumb positions the slider's thumb element based on the current value.
// This function is called as an amend layout callback after the main layout is composed
// because the thumb position depends on the final dimensions of the slider track.
//
// The thumb position is calculated as follows:
// 1. Converts the current value to a percentage within the min/max range
// 2. For vertical sliders:
//    - Maps percentage to y-coordinate along the track height
//    - Centers thumb horizontally using padding
// 3. For horizontal sliders:
//    - Maps percentage to x-coordinate along the track width
//    - Centers thumb vertically using padding
//
// Parameters:
//   layout Layout - The thumb element's layout node to position
//   _ Window      - Window context (unused)
fn (cfg &RangeSliderCfg) amend_layout_thumb(mut layout Layout, mut _ Window) {
	// set the thumb position
	value := f32_clamp(cfg.value, cfg.min, cfg.max)
	percent := math.abs(value / (cfg.max - cfg.min))
	radius := cfg.thumb_size / 2
	if cfg.vertical {
		height := layout.parent.shape.height
		y := f32_min(height * percent, height)
		// layout.parent.shape.y includes offset?
		layout.shape.y = layout.parent.shape.y + y - radius
		layout.shape.x = layout.parent.shape.x + (layout.parent.shape.width / 2) - radius
	} else {
		width := layout.parent.shape.width
		x := f32_min(width * percent, width)
		layout.shape.x = layout.parent.shape.x + x - radius
		layout.shape.y = layout.parent.shape.y + (layout.parent.shape.height / 2) - radius
	}
}

// mouse_move expects the events mouse coordinates to NOT be adjusted (see on_mouse_down)
fn (cfg &RangeSliderCfg) mouse_move(layout &Layout, mut e Event, mut w Window) {
	id := cfg.id

	if cfg.on_change != unsafe { nil } {
		range_slider := layout.find_layout(fn [id] (n Layout) bool {
			return n.shape.id == id
		})
		if range_slider != none {
			w.set_mouse_cursor_pointing_hand()
			shape := range_slider.shape
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

fn (cfg &RangeSliderCfg) on_keydown(_ &Layout, mut e Event, mut w Window) {
	if cfg.on_change != unsafe { nil } && e.modifiers == .none {
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
	if cfg.on_change != unsafe { nil } && e.modifiers == .none {
		mut value := f32_clamp(cfg.value + e.scroll_y, cfg.min, cfg.max)
		if cfg.round_value {
			value = f32(math.round(f64(value)))
		}
		if value != cfg.value {
			cfg.on_change(value, mut e, mut w)
		}
	}
}
