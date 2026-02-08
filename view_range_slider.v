module gui

// view_range_slider.v implements a range slider UI component that allows users
// to select a value from a continuous range by dragging a thumb along a track.
// The component supports both horizontal and vertical orientations, customizable
// styling, keyboard navigation, mouse wheel input, and configurable value ranges.
//
import math
import log

// RangeSliderCfg defines the configuration options for the range slider component.
// It includes visual styling properties like colors and dimensions, behavioral
// settings like value range and step size, and callbacks for handling user input.
@[heap; minify]
pub struct RangeSliderCfg {
pub mut:
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
	width         f32
	height        f32
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
	mut c := cfg
	if c.min >= c.max {
		log.warn('range_slider.min (${c.min}) must be less than range_slider.max (${c.max}); adjusting max to ${
			c.min + 1.0}')
		c.max = c.min + 1.0
	}

	// Wrapper dimensions (Main Axis: Config Width/Size, Cross Axis: max(Size, ThumbSize))
	// Track dimensions (Main Axis: Fill, Cross Axis: Config Size)
	mut wrapper_width := c.size
	mut wrapper_height := f32_max(c.size, c.thumb_size)

	mut track_width := f32(0) // 0 = fill
	mut track_height := c.size

	if c.vertical {
		wrapper_width = f32_max(c.size, c.thumb_size)
		wrapper_height = c.size
		track_width = c.size
		track_height = 0 // 0 = fill
	}

	if c.width > 0 {
		wrapper_width = c.width
	}
	if c.height > 0 {
		wrapper_height = c.height
	}

	return container(
		name:      'range_slider_wrapper'
		id:        c.id
		id_focus:  c.id_focus
		width:     wrapper_width
		height:    wrapper_height
		disabled:  c.disabled
		invisible: c.invisible
		padding:   padding_none
		sizing:    c.sizing
		// Center the track within the wrapper
		h_align: .center
		v_align: .middle
		axis:    if c.vertical { .top_to_bottom } else { .left_to_right }
		// Events handled by wrapper for larger hit target
		on_click:     fn [c] (layout &Layout, mut e Event, mut w Window) {
			mut ev := &Event{
				...e
				// touches: e.touches // copy triggers memory error check if not needed
				mouse_x: e.mouse_x + layout.shape.x
				mouse_y: e.mouse_y + layout.shape.y
			}
			c.mouse_move(layout, mut ev, mut w)

			// Lock the mouse to the range slider until the mouse button is released
			w.mouse_lock(MouseLockCfg{
				// event mouse coordinates are not adjusted here
				mouse_move: fn [c] (layout &Layout, mut e Event, mut w Window) {
					c.mouse_move(layout, mut e, mut w)
				}
				mouse_up:   fn (_ &Layout, mut _ Event, mut w Window) {
					w.mouse_unlock()
				}
			})
			e.is_handled = true
		}
		amend_layout: fn [c] (mut layout Layout, mut w Window) {
			c.amend_layout_slide(mut layout, mut w)
		}
		on_hover:     fn [c] (mut layout Layout, mut e Event, mut w Window) {
			c.on_hover_slide(mut layout, mut e, mut w)
		}
		on_keydown:   fn [c] (layout &Layout, mut e Event, mut w Window) {
			c.on_keydown(layout, mut e, mut w)
		}
		content:      [
			// The Track
			container(
				name:         'range_slider_track'
				width:        track_width
				height:       track_height
				sizing:       if c.vertical {
					Sizing{.fixed, .fill}
				} else {
					Sizing{.fill, .fixed}
				} // Fill main axis, Fixed cross axis
				color:        c.color
				color_border: c.color_border
				size_border:  c.size_border
				radius:       c.radius_border
				padding:      padding_none
				axis:         if c.vertical { .top_to_bottom } else { .left_to_right }
				content:      [
					// Left Bar (Fill)
					rectangle(
						name:         'range_slider_fill'
						sizing:       fill_fill
						color:        c.color_left
						color_border: c.color_left
					),
					// Thumb
					circle(
						name:         'range_slider_thumb'
						width:        c.thumb_size
						height:       c.thumb_size
						color:        c.color_thumb
						color_border: c.color_border
						size_border:  c.size_border
						padding:      padding_none
						amend_layout: fn [c] (mut layout Layout, mut w Window) {
							c.amend_layout_thumb(mut layout, mut w)
						}
					),
				]
			),
		]
	)
}

// amend_layout_slide adjusts the layout of the range slider components based on the
// current value and configuration.
//
// Hierarchy:
// Wrapper (layout)
//   -> Track (layout.children[0])
//      -> Left Bar (layout.children[0].children[0])
//      -> Thumb (layout.children[0].children[1])
//
// Parameters:
//   layout Layout - The wrapper layout node
//   w Window      - Window context for focus state handling
fn (cfg &RangeSliderCfg) amend_layout_slide(mut layout Layout, mut w Window) {
	if layout.shape.events == unsafe { nil } {
		layout.shape.events = &EventHandlers{}
	}
	layout.shape.events.on_mouse_scroll = cfg.on_mouse_scroll

	if layout.children.len == 0 {
		return
	}
	mut track := unsafe { &layout.children[0] }
	if track.children.len < 2 {
		return
	}
	mut left_bar := unsafe { &track.children[0] }
	mut thumb := unsafe { &track.children[1] }

	// set positions of left/right or top/bottom rectangles
	value := f32_clamp(cfg.value, cfg.min, cfg.max)
	percent := math.abs(value / (cfg.max - cfg.min))

	if cfg.vertical {
		height := track.shape.height
		y := f32_min(height * percent, height)
		left_bar.shape.height = y
		left_bar.shape.width = cfg.size - (cfg.size_border * 2)
	} else {
		width := track.shape.width
		x := f32_min(width * percent, width)
		left_bar.shape.width = x
		left_bar.shape.height = cfg.size - (cfg.size_border * 2)
	}

	if layout.shape.disabled {
		return
	}

	if w.is_focus(layout.shape.id_focus) {
		thumb.shape.color = cfg.color_focus
		thumb.shape.color_border = cfg.color_focus
	}
}

fn (cfg &RangeSliderCfg) on_hover_slide(mut layout Layout, mut e Event, mut w Window) {
	w.set_mouse_cursor_pointing_hand()
	// Highlight track border on hover (Wrapper is transparent usually, so we target Track)
	if layout.children.len > 0 {
		layout.children[0].shape.color_border = cfg.color_hover
		if e.mouse_button == .left && layout.children[0].children.len > 1 {
			layout.children[0].children[1].shape.color_border = cfg.color_click // Thumb border
		}
	}
}

// amend_layout_thumb positions the slider's thumb element.
// Thumb is a child of Track.
// layout.parent is Track.
fn (cfg &RangeSliderCfg) amend_layout_thumb(mut layout Layout, mut _ Window) {
	// set the thumb position
	value := f32_clamp(cfg.value, cfg.min, cfg.max)
	percent := math.abs(value / (cfg.max - cfg.min))
	radius := cfg.thumb_size / 2

	// Parent is Track
	if cfg.vertical {
		height := layout.parent.shape.height
		y := f32_min(height * percent, height)
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
