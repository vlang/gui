module gui

// view_scrollbar.v provides scrollbars as floating overlay elements that sit
// on top of their scrollable containers. It defines scrollbar configuration,
// layout, rendering, and interaction (dragging, hovering, and scrolling) for
// both vertical and horizontal orientations.

// ScrollbarOverflow determines how scrollbars are shown.
// Remember to set id_scroll > 0 or these options have no effect.
//
// - auto shows scrollbar when required
// - hidden hides the scrollbar
// - visible always shows the scroll bar
// - on_hover show only when mouse is over scrollbar
pub enum ScrollbarOverflow as u8 {
	auto
	hidden
	visible
	on_hover
}

// ScrollbarOrientation determines the scrollbar's orientation.
pub enum ScrollbarOrientation as u8 {
	none
	vertical
	horizontal
}

// ScrollMode allows scrolling in one or both directions. Default is both
pub enum ScrollMode as u8 {
	both
	vertical_only
	horizontal_only
}

// ScrollbarCfg configures the style of a scrollbar. Column and Row
// define a default ScrollbarCfgs so most of the time it is only
// needed to define id_scroll in the Column/Row config. Scrollbars are
// optional. Columns/Rows are scrollable without visible scrollbars.
// [ScrollbarOverflow](#ScrollbarOverflow)
@[minify]
pub struct ScrollbarCfg {
pub:
	id               string
	color_thumb      Color = gui_theme.scrollbar_style.color_thumb
	color_background Color = gui_theme.scrollbar_style.color_background
	size             f32   = gui_theme.scrollbar_style.size
	min_thumb_size   f32   = gui_theme.scrollbar_style.min_thumb_size
	radius           f32   = gui_theme.scrollbar_style.radius
	radius_thumb     f32   = gui_theme.scrollbar_style.radius_thumb
	gap_edge         f32   = gui_theme.scrollbar_style.gap_edge
	gap_end          f32   = gui_theme.scrollbar_style.gap_end
	id_scroll        u32
	overflow         ScrollbarOverflow
	orientation      ScrollbarOrientation
}

const scroll_extend = 10 // cushion on scroll range ends
const scroll_snap_min = f32(0.03) // snap to 0% below this threshold
const scroll_snap_max = f32(0.97) // snap to 100% above this threshold
const thumb_index = 0

// scrollbar creates a scrollbar view based on the provided configuration.
// It adapts its layout (row or column) depending on the `orientation`
// specified in `cfg`.
pub fn scrollbar(cfg ScrollbarCfg) View {
	return if cfg.orientation == .horizontal {
		row(
			scrollbar_orientation: .horizontal
			id:                    cfg.id
			a11y_role:             .scroll_bar
			a11y:                  make_a11y_info(gui_locale.str_horizontal_scrollbar,
				'')
			color:                 cfg.color_background
			over_draw:             true
			spacing:               0
			padding:               padding_none
			amend_layout:          make_scrollbar_amend_layout(cfg)
			on_hover:              make_scrollbar_on_hover(cfg)
			on_click:              make_scrollbar_gutter_click(cfg)
			content:               [
				thumb(cfg, '__thumb__${cfg.id_scroll}'),
			]
		)
	} else {
		column(
			scrollbar_orientation: .vertical
			id:                    cfg.id
			a11y_role:             .scroll_bar
			a11y:                  make_a11y_info(gui_locale.str_vertical_scrollbar, '')
			color:                 cfg.color_background
			over_draw:             true
			spacing:               0
			padding:               padding_none
			amend_layout:          make_scrollbar_amend_layout(cfg)
			on_hover:              make_scrollbar_on_hover(cfg)
			on_click:              make_scrollbar_gutter_click(cfg)
			content:               [
				thumb(cfg, '__thumb__${cfg.id_scroll}'),
			]
		)
	}
}

fn thumb(cfg ScrollbarCfg, id string) View {
	return column(
		name:     'scrollbar thumb'
		id:       id
		color:    cfg.color_thumb
		radius:   cfg.radius_thumb
		padding:  padding_none
		spacing:  0
		on_click: make_scrollbar_on_mouse_down(cfg)
	)
}

// Wrapper functions to capture ScrollbarCfg by value to avoid dangling reference issues.
fn make_scrollbar_amend_layout(cfg ScrollbarCfg) fn (mut Layout, mut Window) {
	return fn [cfg] (mut layout Layout, mut w Window) {
		cfg.amend_layout(mut layout, mut w)
	}
}

fn make_scrollbar_on_hover(cfg ScrollbarCfg) fn (mut Layout, mut Event, mut Window) {
	return fn [cfg] (mut layout Layout, mut e Event, mut w Window) {
		cfg.on_hover(mut layout, mut e, mut w)
	}
}

fn make_scrollbar_gutter_click(cfg ScrollbarCfg) fn (&Layout, mut Event, mut Window) {
	return fn [cfg] (layout &Layout, mut e Event, mut w Window) {
		cfg.gutter_click(layout, mut e, mut w)
	}
}

fn make_scrollbar_on_mouse_down(cfg ScrollbarCfg) fn (voidptr, mut Event, mut Window) {
	return fn [cfg] (ptr voidptr, mut e Event, mut w Window) {
		cfg.on_mouse_down(ptr, mut e, mut w)
	}
}

// scrollbar_mouse_move handles mouse movement during thumb drag.
// Shared by on_mouse_down and gutter_click to avoid code duplication.
fn scrollbar_mouse_move(orientation ScrollbarOrientation, id_scroll u32, layout &Layout, mut e Event, mut w Window) {
	if ly := find_layout_by_id_scroll(layout, id_scroll) {
		match orientation == .horizontal {
			true {
				if e.mouse_x >= (ly.shape.x - scroll_extend)
					&& e.mouse_x <= (ly.shape.x + ly.shape.width + scroll_extend) {
					offset := offset_mouse_change_x(ly, e.mouse_dx, id_scroll, mut w)
					mut sx := state_map[u32, f32](mut w, ns_scroll_x, cap_scroll)
					sx.set(id_scroll, offset)
					if ly.shape.has_events() && ly.shape.events.on_scroll != unsafe { nil } {
						ly.shape.events.on_scroll(ly, mut w)
					}
				}
			}
			else {
				if e.mouse_y >= (ly.shape.y - scroll_extend)
					&& e.mouse_y <= (ly.shape.y + ly.shape.height + scroll_extend) {
					offset := offset_mouse_change_y(ly, e.mouse_dy, id_scroll, mut w)
					mut sy := state_map[u32, f32](mut w, ns_scroll_y, cap_scroll)
					sy.set(id_scroll, offset)
					if ly.shape.has_events() && ly.shape.events.on_scroll != unsafe { nil } {
						ly.shape.events.on_scroll(ly, mut w)
					}
				}
			}
		}
	}
}

// on_mouse_down handles the mouse button press event on the scrollbar thumb.
// It sets focus to the scrollable content (if applicable) and locks the mouse
// to handle the drag operation (scrolling).
fn (cfg &ScrollbarCfg) on_mouse_down(_ voidptr, mut e Event, mut w Window) {
	// Capture values needed for mouse_lock callbacks
	orientation := cfg.orientation
	id_scroll := cfg.id_scroll
	// Lock the mouse to this control to capture all mouse move/up events
	// until the button is released. This ensures smooth dragging even if cursor leaves the thumb.
	w.mouse_lock(MouseLockCfg{
		mouse_move: fn [orientation, id_scroll] (layout &Layout, mut e Event, mut w Window) {
			scrollbar_mouse_move(orientation, id_scroll, layout, mut e, mut w)
		}
		mouse_up:   fn (_ &Layout, mut e Event, mut w Window) {
			w.mouse_unlock()
		}
	})
	e.is_handled = true
}

// gutter_click handles clicks on the scrollbar track (background).
// It moves the scroll position directly to the clicked location and
// initiates a mouse lock to allow immediate dragging from that new position.
fn (cfg &ScrollbarCfg) gutter_click(_ &Layout, mut e Event, mut w Window) {
	// Only proceed if the mouse is not already locked by another operation
	if !w.mouse_is_locked() {
		// Calculate and apply the new scroll offset based on the click coordinates
		match cfg.orientation == .horizontal {
			true { offset_from_mouse_x(w.layout, e.mouse_x, cfg.id_scroll, mut w) }
			else { offset_from_mouse_y(w.layout, e.mouse_y, cfg.id_scroll, mut w) }
		}

		// Capture values needed for mouse_lock callbacks
		orientation := cfg.orientation
		id_scroll := cfg.id_scroll
		// Lock the mouse to continue scrolling if the user holds and drags
		w.mouse_lock(MouseLockCfg{
			mouse_move: fn [orientation, id_scroll] (layout &Layout, mut e Event, mut w Window) {
				scrollbar_mouse_move(orientation, id_scroll, layout, mut e, mut w)
			}
			mouse_up:   fn (_ &Layout, mut e Event, mut w Window) {
				w.mouse_unlock()
			}
		})
		e.is_handled = true
	}
}

// amend_layout Don't know what the sizes and positions of the scrollbar elements should
// be until after the layout is almost done requiring manual layout here.
// Scrollbars are hard.
fn (cfg &ScrollbarCfg) amend_layout(mut layout Layout, mut w Window) {
	min_thumb_size := cfg.min_thumb_size
	mut parent := layout.parent

	match cfg.orientation == .horizontal {
		true {
			layout.shape.x = if effective_text_dir(parent.shape) == .rtl {
				parent.shape.x + parent.shape.padding.right + parent.shape.size_border
			} else {
				parent.shape.x + parent.shape.padding_left()
			}
			layout.shape.y = parent.shape.y + parent.shape.height - cfg.size
			layout.shape.width = parent.shape.width - parent.shape.padding_width()
			layout.shape.height = cfg.size

			c_width := content_width(parent)
			if c_width == 0 {
				return
			}
			t_width := layout.shape.width * (layout.shape.width / c_width)
			thumb_width := f32_clamp(t_width, min_thumb_size, layout.shape.width)

			available_width := layout.shape.width - thumb_width
			mut sx := state_map[u32, f32](mut w, ns_scroll_x, cap_scroll)
			scroll_offset := -(sx.get(cfg.id_scroll) or { f32(0) })

			layout.shape.x -= cfg.gap_end
			layout.shape.y -= cfg.gap_edge
			layout.shape.width -= cfg.gap_end + cfg.gap_end
			offset := if available_width == 0 {
				0
			} else {
				f32_clamp((scroll_offset / (c_width - layout.shape.width)) * available_width,
					0, available_width)
			}
			layout.children[thumb_index].shape.x = layout.shape.x + offset
			layout.children[thumb_index].shape.y = layout.shape.y
			layout.children[thumb_index].shape.width = thumb_width - cfg.gap_end - cfg.gap_end
			layout.children[thumb_index].shape.height = cfg.size

			if (cfg.overflow != .visible && available_width < 0.1) || cfg.overflow == .on_hover {
				layout.children[thumb_index].shape.color = color_transparent
			}
		}
		else {
			if effective_text_dir(parent.shape) == .rtl {
				layout.shape.x = parent.shape.x + cfg.gap_edge
			} else {
				layout.shape.x = parent.shape.x + parent.shape.width - cfg.size
			}
			layout.shape.y = parent.shape.y + parent.shape.padding_top()
			layout.shape.width = cfg.size
			layout.shape.height = parent.shape.height - parent.shape.padding_height()

			c_height := content_height(parent)
			if c_height == 0 {
				return
			}
			t_height := layout.shape.height * (layout.shape.height / c_height)
			thumb_height := f32_clamp(t_height, min_thumb_size, layout.shape.height)

			available_height := layout.shape.height - thumb_height
			mut sy := state_map[u32, f32](mut w, ns_scroll_y, cap_scroll)
			scroll_offset := -(sy.get(cfg.id_scroll) or { f32(0) })

			if effective_text_dir(parent.shape) != .rtl {
				layout.shape.x -= cfg.gap_edge
			}
			layout.shape.y += cfg.gap_end
			layout.shape.height -= cfg.gap_end + cfg.gap_end
			layout.children[thumb_index].shape.x = layout.shape.x
			offset := if available_height == 0 {
				0
			} else {
				f32_clamp((scroll_offset / (c_height - layout.shape.height)) * available_height,
					0, available_height)
			}
			layout.children[thumb_index].shape.y = layout.shape.y + offset
			layout.children[thumb_index].shape.height = thumb_height - cfg.gap_end - cfg.gap_end
			layout.children[thumb_index].shape.width = cfg.size

			if (cfg.overflow != .visible && available_height < 0.1) || cfg.overflow == .on_hover {
				layout.children[thumb_index].shape.color = color_transparent
			}
		}
	}
}

// on_hover handles the mouse hover event on the scrollbar.
// It changes the thumb's color to a hover state if it's not transparent
// or if the overflow mode is set to `on_hover`.
fn (cfg &ScrollbarCfg) on_hover(mut layout Layout, mut e Event, mut w Window) {
	if layout.children[thumb_index].shape.color != color_transparent || cfg.overflow == .on_hover {
		layout.children[thumb_index].shape.color = cfg.color_thumb
		w.set_mouse_cursor_arrow()
		e.is_handled = true
	}
}

// offset_mouse_change_x calculates the new horizontal offset for a scrollable layout
// based on mouse movement delta.
//
// Parameters:
//   layout:    The layout for which the offset is being calculated.
//   mouse_dx:  The mouse movement delta in x direction.
//   id_scroll: The ID of the scrollable area.
//   w:         The window context.
//
// Returns:
//   The new calculated horizontal offset, clamped within valid bounds.
fn offset_mouse_change_x(layout &Layout, mouse_dx f32, id_scroll u32, mut w Window) f32 {
	total_width := content_width(layout)
	shape_width := layout.shape.width - layout.shape.padding_width()
	mut sx := state_map[u32, f32](mut w, ns_scroll_x, cap_scroll)
	old_offset := sx.get(id_scroll) or { f32(0) }
	new_offset := mouse_dx * (total_width / shape_width)
	offset := old_offset - new_offset
	return f32_min(0, f32_max(offset, shape_width - total_width))
}

// offset_mouse_change_y calculates the new vertical offset for a scrollable layout
// based on mouse movement delta.
//
// Parameters:
//   layout:    The layout for which the offset is being calculated.
//   mouse_dy:  The mouse movement delta in y direction.
//   id_scroll: The ID of the scrollable area.
//   w:         The window context.
//
// Returns:
//   The new calculated vertical offset, clamped within valid bounds.
fn offset_mouse_change_y(layout &Layout, mouse_dy f32, id_scroll u32, mut w Window) f32 {
	total_height := content_height(layout)
	shape_height := layout.shape.height - layout.shape.padding_height()
	mut sy := state_map[u32, f32](mut w, ns_scroll_y, cap_scroll)
	old_offset := sy.get(id_scroll) or { f32(0) }
	new_offset := mouse_dy * (total_height / shape_height)
	offset := old_offset - new_offset
	return f32_min(0, f32_max(offset, shape_height - total_height))
}

// offset_from_mouse_x calculates and applies a new horizontal offset for a scrollable layout
// based on the mouse's x-coordinate.
//
// Parameters:
//   layout:    The layout for which the offset is being calculated.
//   mouse_x:   The current x-coordinate of the mouse.
//   id_scroll: The ID of the scrollable area.
//   w:         The window context, which will be updated with the new offset.
fn offset_from_mouse_x(layout &Layout, mouse_x f32, id_scroll u32, mut w Window) {
	if sb := find_layout_by_id_scroll(layout, id_scroll) {
		total_width := content_width(sb)
		mut percent := mouse_x / sb.shape.width
		percent = f32_clamp(percent, 0, 1)
		if percent <= scroll_snap_min {
			percent = 0
		}
		if percent >= scroll_snap_max {
			percent = 1
		}
		mut sx := state_map[u32, f32](mut w, ns_scroll_x, cap_scroll)
		sx.set(id_scroll, -percent * (total_width - sb.shape.width))
		if sb.shape.has_events() && sb.shape.events.on_scroll != unsafe { nil } {
			sb.shape.events.on_scroll(sb, mut w)
		}
	}
}

// offset_from_mouse_y calculates and applies a new vertical offset for a scrollable layout
// based on the mouse's y-coordinate.
//
// Parameters:
//   layout:    The layout for which the offset is being calculated.
//   mouse_y:   The current y-coordinate of the mouse.
//   id_scroll: The ID of the scrollable area.
//   w:         The window context, which will be updated with the new offset.
fn offset_from_mouse_y(layout &Layout, mouse_y f32, id_scroll u32, mut w Window) {
	if sb := find_layout_by_id_scroll(layout, id_scroll) {
		total_height := content_height(sb)
		mut percent := mouse_y / sb.shape.height
		percent = f32_clamp(percent, 0, 1)
		if percent <= scroll_snap_min {
			percent = 0
		}
		if percent >= scroll_snap_max {
			percent = 1
		}
		mut sy := state_map[u32, f32](mut w, ns_scroll_y, cap_scroll)
		sy.set(id_scroll, -percent * (total_height - sb.shape.height))
		if sb.shape.has_events() && sb.shape.events.on_scroll != unsafe { nil } {
			sb.shape.events.on_scroll(sb, mut w)
		}
	}
}

// scroll_horizontal adjusts the horizontal scroll offset of a scrollable layout.
//
// Parameters:
//   layout: The layout to be scrolled.
//   delta:  The amount by which to change the scroll offset.
//   w:      The window context, which will be updated with the new offset.
//
// Returns:
//   `true` if the layout is scrollable and the offset was adjusted, `false` otherwise.
fn scroll_horizontal(layout &Layout, delta f32, mut w Window) bool {
	v_id := layout.shape.id_scroll
	if v_id > 0 {
		// scrollable region does not including padding
		max_offset := f32_min(0, layout.shape.width - layout.shape.padding_width() - content_width(layout))
		mut sx := state_map[u32, f32](mut w, ns_scroll_x, cap_scroll)
		offset_x := (sx.get(v_id) or { f32(0) }) + delta * gui_theme.scroll_multiplier
		sx.set(v_id, f32_clamp(offset_x, max_offset, 0))
		if layout.shape.has_events() && layout.shape.events.on_scroll != unsafe { nil } {
			layout.shape.events.on_scroll(layout, mut w)
		}
		return true
	}
	return false
}

// scroll_vertical adjusts the vertical scroll offset of a scrollable layout.
//
// Parameters:
//   layout: The layout to be scrolled.
//   delta:  The amount by which to change the scroll offset.
//   w:      The window context, which will be updated with the new offset.
//
// Returns:
//   `true` if the layout is scrollable and the offset was adjusted, `false` otherwise.
fn scroll_vertical(layout &Layout, delta f32, mut w Window) bool {
	v_id := layout.shape.id_scroll
	if v_id > 0 {
		// scrollable region does not including padding
		max_offset := f32_min(0, layout.shape.height - layout.shape.padding_height() - content_height(layout))
		mut sy := state_map[u32, f32](mut w, ns_scroll_y, cap_scroll)
		offset_y := (sy.get(v_id) or { f32(0) }) + delta * gui_theme.scroll_multiplier
		sy.set(v_id, f32_clamp(offset_y, max_offset, 0))
		if layout.shape.has_events() && layout.shape.events.on_scroll != unsafe { nil } {
			layout.shape.events.on_scroll(layout, mut w)
		}
		return true
	}
	return false
}
