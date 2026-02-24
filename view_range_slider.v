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
@[minify]
pub struct RangeSliderCfg {
	A11yCfg
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

// range_slider creates and returns a range slider View component based on
// the provided configuration. The range slider allows users to select a
// numeric value within a specified range by dragging a thumb along a track
// or using keyboard/mouse wheel input.
pub fn range_slider(cfg RangeSliderCfg) View {
	mut c := cfg
	if c.min >= c.max {
		log.warn('range_slider.min (${c.min}) must be less than range_slider.max (${c.max}); adjusting max to ${
			c.min + 1.0}')
		c.max = c.min + 1.0
	}

	// Wrapper dimensions (Main Axis: Config Width/Size,
	// Cross Axis: max(Size, ThumbSize))
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

	// Extract fields for closure captures to avoid retaining
	// the full @[heap] RangeSliderCfg.
	slider_id := c.id
	on_change := c.on_change
	value := c.value
	min := c.min
	max := c.max
	step := c.step
	vertical := c.vertical
	round_value := c.round_value
	size := c.size
	sz_border := c.size_border
	thumb_size := c.thumb_size
	color_focus := c.color_focus
	color_hover := c.color_hover
	color_click := c.color_click
	disabled := c.disabled
	id_focus := c.id_focus

	return container(
		name:      'range_slider_wrapper'
		id:        c.id
		id_focus:  c.id_focus
		a11y_role: .slider
		a11y:      &AccessInfo{
			label:       a11y_label(c.a11y_label, c.id)
			description: c.a11y_description
			value_num:   c.value
			value_min:   c.min
			value_max:   c.max
		}
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
		on_click:     fn [slider_id, on_change, value, min, max, vertical, round_value] (layout &Layout, mut e Event, mut w Window) {
			mut ev := &Event{
				...e
				mouse_x: e.mouse_x + layout.shape.x
				mouse_y: e.mouse_y + layout.shape.y
			}
			range_slider_mouse_move(layout, mut ev, mut w, slider_id, on_change, value,
				min, max, vertical, round_value)

			w.mouse_lock(MouseLockCfg{
				mouse_move: fn [slider_id, on_change, value, min, max, vertical, round_value] (layout &Layout, mut e Event, mut w Window) {
					range_slider_mouse_move(layout, mut e, mut w, slider_id, on_change,
						value, min, max, vertical, round_value)
				}
				mouse_up:   fn (_ &Layout, mut _ Event, mut w Window) {
					w.mouse_unlock()
				}
			})
			e.is_handled = true
		}
		amend_layout: fn [on_change, value, min, max, size, sz_border, vertical, color_focus, disabled, id_focus, round_value] (mut layout Layout, mut w Window) {
			range_slider_amend_layout_slide(mut layout, mut w, on_change, value, min,
				max, size, sz_border, vertical, color_focus, disabled, id_focus, round_value)
		}
		on_hover:     fn [color_hover, color_click] (mut layout Layout, mut e Event, mut w Window) {
			w.set_mouse_cursor_pointing_hand()
			if layout.children.len > 0 {
				layout.children[0].shape.color_border = color_hover
				if e.mouse_button == .left && layout.children[0].children.len > 1 {
					layout.children[0].children[1].shape.color_border = color_click
				}
			}
		}
		on_keydown:   fn [on_change, value, min, max, step, round_value] (layout &Layout, mut e Event, mut w Window) {
			range_slider_on_keydown(layout, mut e, mut w, on_change, value, min, max,
				step, round_value)
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
						size_border:  1.5
						padding:      padding_none
						amend_layout: fn [value, min, max, thumb_size, vertical] (mut layout Layout, mut w Window) {
							range_slider_amend_layout_thumb(mut layout, mut w, value,
								min, max, thumb_size, vertical)
						}
					),
				]
			),
		]
	)
}

// range_slider_amend_layout_slide adjusts the layout of the range slider
// components based on the current value.
fn range_slider_amend_layout_slide(mut layout Layout, mut w Window, on_change fn (f32, mut Event, mut Window), value f32, min f32, max f32, size f32, size_border f32, vertical bool, color_focus Color, disabled bool, id_focus u32, round_value bool) {
	if layout.shape.events == unsafe { nil } {
		layout.shape.events = &EventHandlers{}
	}
	layout.shape.events.on_mouse_scroll = fn [on_change, value, min, max, round_value] (_ &Layout, mut e Event, mut w Window) {
		range_slider_on_mouse_scroll(mut e, mut w, on_change, value, min, max, round_value)
	}

	if layout.children.len == 0 {
		return
	}
	mut track := unsafe { &layout.children[0] }
	if track.children.len < 2 {
		return
	}
	mut left_bar := unsafe { &track.children[0] }
	mut thumb := unsafe { &track.children[1] }

	clamped := f32_clamp(value, min, max)
	percent := math.abs(clamped / (max - min))

	if vertical {
		height := track.shape.height
		y := f32_min(height * percent, height)
		left_bar.shape.height = y
		left_bar.shape.width = size - (size_border * 2)
	} else {
		width := track.shape.width
		x := f32_min(width * percent, width)
		left_bar.shape.width = x
		left_bar.shape.height = size - (size_border * 2)
	}

	if disabled {
		return
	}

	if w.is_focus(id_focus) {
		thumb.shape.color = color_focus
		thumb.shape.color_border = color_focus
	}
}

// range_slider_amend_layout_thumb positions the slider's thumb element.
fn range_slider_amend_layout_thumb(mut layout Layout, mut _ Window, value f32, min f32, max f32, thumb_size f32, vertical bool) {
	clamped := f32_clamp(value, min, max)
	percent := math.abs(clamped / (max - min))
	radius := thumb_size / 2

	if vertical {
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

// range_slider_mouse_move handles mouse move during drag.
fn range_slider_mouse_move(layout &Layout, mut e Event, mut w Window, slider_id string, on_change fn (f32, mut Event, mut Window), cur_value f32, min f32, max f32, vertical bool, round_value bool) {
	if on_change != unsafe { nil } {
		range_slider := layout.find_layout(fn [slider_id] (n Layout) bool {
			return n.shape.id == slider_id
		})
		if range_slider != none {
			w.set_mouse_cursor_pointing_hand()
			shape := range_slider.shape
			if vertical {
				height := shape.height
				percent := f32_clamp((e.mouse_y - shape.y) / height, 0, 1)
				val := (max - min) * percent
				mut value := f32_clamp(val, min, max)
				if round_value {
					value = f32(math.round(f64(value)))
				}
				on_change(value, mut e, mut w)
			} else {
				width := shape.width
				percent := f32_clamp((e.mouse_x - shape.x) / width, 0, 1)
				val := (max - min) * percent
				mut value := f32_clamp(val, min, max)
				if round_value {
					value = f32(math.round(f64(value)))
				}
				if value != cur_value {
					on_change(value, mut e, mut w)
				}
			}
		}
	}
}

fn range_slider_on_keydown(_ &Layout, mut e Event, mut w Window, on_change fn (f32, mut Event, mut Window), cur_value f32, min f32, max f32, step f32, round_value bool) {
	if on_change != unsafe { nil } && e.modifiers == .none {
		mut value := cur_value
		match e.key_code {
			.home { value = min }
			.end { value = max }
			.left, .up { value = f32_clamp(value - step, min, max) }
			.right, .down { value = f32_clamp(value + step, min, max) }
			else { return }
		}
		if round_value {
			value = f32(math.round(f64(value)))
		}
		if value != cur_value {
			on_change(value, mut e, mut w)
		}
	}
}

fn range_slider_on_mouse_scroll(mut e Event, mut w Window, on_change fn (f32, mut Event, mut Window), cur_value f32, min f32, max f32, round_value bool) {
	e.is_handled = true
	if on_change != unsafe { nil } && e.modifiers == .none {
		mut value := f32_clamp(cur_value + e.scroll_y, min, max)
		if round_value {
			value = f32(math.round(f64(value)))
		}
		if value != cur_value {
			on_change(value, mut e, mut w)
		}
	}
}
