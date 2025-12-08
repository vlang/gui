module gui

// ScrollbarOverflow determines how scrollbars are shown.
// Remember that to set id_scroll > 0 or these options
// have no effect.
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
// Default is vertical.
pub enum ScrollbarOrientation as u8 {
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
@[heap; minify]
pub struct ScrollbarCfg {
pub:
	id               string
	color_thumb      Color = gui_theme.scrollbar_style.color_thumb
	color_background Color = gui_theme.scrollbar_style.color_background
	size             f32   = gui_theme.scrollbar_style.size
	radius           f32   = gui_theme.scrollbar_style.radius
	radius_thumb     f32   = gui_theme.scrollbar_style.radius_thumb
	offset_x         f32   = gui_theme.scrollbar_style.offset_x // x and y are swapped in
	offset_y         f32   = gui_theme.scrollbar_style.offset_y // horizontal orientation
	id_track         u32
	overflow         ScrollbarOverflow
	orientation      ScrollbarOrientation
	fill_thumb       bool = gui_theme.scrollbar_style.fill_thumb
	fill_background  bool = gui_theme.scrollbar_style.fill_background
}

const scrollbar_vertical_name = 'scrollbar vertical'
const scrollbar_horizontal_name = 'scrollbar horizontal'

// scrollbar creates a scrollbar view based on the provided configuration.
// It adapts its layout (row or column) depending on the `orientation`
// specified in `cfg`.
pub fn scrollbar(cfg ScrollbarCfg) View {
	return if cfg.orientation == .horizontal {
		row(
			name:         scrollbar_horizontal_name
			id:           cfg.id
			fill:         cfg.fill_background
			color:        cfg.color_background
			over_draw:    true
			spacing:      0
			padding:      padding_none
			amend_layout: cfg.amend_layout
			on_hover:     cfg.on_hover
			on_click:     cfg.gutter_click
			content:      [
				thumb(cfg, '__thumb__${cfg.id_track}'),
			]
		)
	} else {
		column(
			name:         scrollbar_vertical_name
			id:           cfg.id
			fill:         cfg.fill_background
			color:        cfg.color_background
			over_draw:    true
			spacing:      0
			padding:      padding_none
			amend_layout: cfg.amend_layout
			on_hover:     cfg.on_hover
			on_click:     cfg.gutter_click
			content:      [
				thumb(cfg, '__thumb__${cfg.id_track}'),
			]
		)
	}
}

fn thumb(cfg &ScrollbarCfg, id string) View {
	return column(
		name:     'scrollbar thumb'
		id:       id
		color:    cfg.color_thumb
		fill:     cfg.fill_thumb
		radius:   cfg.radius_thumb
		padding:  padding_none
		spacing:  0
		on_click: cfg.on_mouse_down
	)
}

// on_mouse_down handles the mouse button press event on the scrollbar thumb.
// It sets focus to the scrollable content (if applicable) and locks the mouse
// to handle the drag operation (scrolling).
fn (cfg &ScrollbarCfg) on_mouse_down(_ voidptr, mut e Event, mut w Window) {
	// Clicking on the scrollbar gives focus to the shape it is tracking
	// if the tracked shape is not disabled.
	id_track := cfg.id_track

	// Find the layout/shape being scrolled by this scrollbar
	shape := w.layout.find_shape(fn [id_track] (n Layout) bool {
		return n.shape.id_scroll == id_track
	})

	// Set focus to the scrolled content if found and enabled
	if shape != none {
		if !shape.disabled {
			w.set_id_focus(shape.id_focus)
		}
	}

	// Lock the mouse to this control to capture all mouse move/up events
	// until the button is released. This ensures smooth dragging even if cursor leaves the thumb.
	w.mouse_lock(MouseLockCfg{
		mouse_move: cfg.mouse_move
		mouse_up:   cfg.mouse_up
	})
	e.is_handled = true
}

// gutter_click handles clicks on the scrollbar track (background).
// It moves the scroll position directly to the clicked location and
// initiates a mouse lock to allow immediate dragging from that new position.
fn (cfg &ScrollbarCfg) gutter_click(_ &Layout, mut e Event, mut w Window) {
	// Only proceed if the mouse is not already locked by another operation
	if !w.mouse_is_locked() {
		id_track := cfg.id_track

		// Find the scrolled content to set focus
		shape := w.layout.find_shape(fn [id_track] (n Layout) bool {
			return n.shape.id_scroll == id_track
		})
		if shape != none {
			if !shape.disabled {
				w.set_id_focus(shape.id_focus)
			}
		}

		// Calculate and apply the new scroll offset based on the click coordinates
		match cfg.orientation == .horizontal {
			true { offset_from_mouse_x(w.layout, e.mouse_x, cfg.id_track, mut w) }
			else { offset_from_mouse_y(w.layout, e.mouse_y, cfg.id_track, mut w) }
		}

		// Lock the mouse to continue scrolling if the user holds and drags
		w.mouse_lock(MouseLockCfg{
			mouse_move: cfg.mouse_move
			mouse_up:   cfg.mouse_up
		})
		e.is_handled = true
	}
}

// mouse_move handles the mouse movement event when the scrollbar thumb is being dragged.
// It calculates the new scroll offset based on the mouse's delta movement and updates
// the view state for the tracked scrollable content, ensuring the scroll position
// stays within the bounds of the scrollable area.
fn (cfg &ScrollbarCfg) mouse_move(layout &Layout, mut e Event, mut w Window) {
	extend := 10 // give some cushion on the ends of the scroll range
	if ly := find_layout_by_id_scroll(layout, cfg.id_track) {
		match cfg.orientation == .horizontal {
			true {
				if e.mouse_x >= (ly.shape.x - extend)
					&& e.mouse_x <= (ly.shape.x + ly.shape.width + extend) {
					offset := offset_mouse_change_x(ly, e.mouse_dx, cfg.id_track, w)
					w.view_state.offset_x_state[cfg.id_track] = offset
				}
			}
			else {
				if e.mouse_y >= (ly.shape.y - extend)
					&& e.mouse_y <= (ly.shape.y + ly.shape.height + extend) {
					offset := offset_mouse_change_y(ly, e.mouse_dy, cfg.id_track, w)
					w.view_state.offset_y_state[cfg.id_track] = offset
				}
			}
		}
	}
}

fn (_ &ScrollbarCfg) mouse_up(_ &Layout, mut e Event, mut w Window) {
	w.mouse_unlock()
}

// amend_layout Don't know what the sizes and positions of the scrollbar elements should
// be until after the layout is almost done requiring manual layout here.
// Scrollbars are hard.
fn (cfg &ScrollbarCfg) amend_layout(mut layout Layout, mut w Window) {
	thumb := 0
	min_thumb_size := 20
	mut parent := layout.parent

	match cfg.orientation == .horizontal {
		true {
			layout.shape.x = parent.shape.x + parent.shape.padding.left
			layout.shape.y = parent.shape.y + parent.shape.height - cfg.size + cfg.offset_y
			layout.shape.width = parent.shape.width - parent.shape.padding.width()
			layout.shape.height = cfg.size

			total_width := content_width(parent)
			t_width := layout.shape.width * (layout.shape.width / total_width)
			thumb_width := f32_clamp(t_width, min_thumb_size, layout.shape.width)

			available_width := layout.shape.width - thumb_width
			scroll_offset := -w.view_state.offset_x_state[cfg.id_track]
			offset := if available_width == 0 {
				0
			} else {
				f32_clamp((scroll_offset / (total_width - layout.shape.width)) * available_width,
					0, available_width)
			}
			layout.children[thumb].shape.x = layout.shape.x + offset
			layout.children[thumb].shape.y = layout.shape.y
			layout.children[thumb].shape.width = thumb_width
			layout.children[thumb].shape.height = cfg.size

			if (cfg.overflow != .visible && layout.shape.width - thumb_width < 0.1)
				|| cfg.overflow == .on_hover {
				layout.children[thumb].shape.color = color_transparent
			}
		}
		else {
			layout.shape.x = parent.shape.x + parent.shape.width - cfg.size + cfg.offset_x
			layout.shape.y = parent.shape.y + parent.shape.padding.top
			layout.shape.width = cfg.size
			layout.shape.height = parent.shape.height - parent.shape.padding.height()

			total_height := content_height(parent)
			t_height := layout.shape.height * (layout.shape.height / total_height)
			thumb_height := f32_clamp(t_height, min_thumb_size, layout.shape.height)

			available_height := layout.shape.height - thumb_height
			scroll_offset := -w.view_state.offset_y_state[cfg.id_track]
			offset := if available_height == 0 {
				0
			} else {
				f32_clamp((scroll_offset / (total_height - layout.shape.height)) * available_height,
					0, available_height)
			}
			layout.children[thumb].shape.x = layout.shape.x
			layout.children[thumb].shape.y = layout.shape.y + offset
			layout.children[thumb].shape.height = thumb_height
			layout.children[thumb].shape.width = cfg.size

			if (cfg.overflow != .visible && layout.shape.height - thumb_height < 0.1)
				|| cfg.overflow == .on_hover {
				layout.children[thumb].shape.color = color_transparent
			}
		}
	}
}

// on_hover handles the mouse hover event on the scrollbar.
// It changes the thumb's color to a hover state if it's not transparent
// or if the overflow mode is set to `on_hover`.
fn (cfg &ScrollbarCfg) on_hover(mut layout Layout, mut _ Event, mut w Window) {
	// on hover dim color of thumb
	thumb := 0
	if layout.children[thumb].shape.color != color_transparent || cfg.overflow == .on_hover {
		layout.children[thumb].shape.color = gui_theme.button_style.color_hover
	}
}

// find_layout_by_id_scroll recursively searches for a layout with a matching `id_scroll`
// within the given layout and its children. It returns the found Layout if a match is made,
// otherwise it returns `none`.
fn find_layout_by_id_scroll(layout &Layout, id_scroll u32) ?Layout {
	if layout.shape.id_scroll == id_scroll {
		return *layout
	}
	for child in layout.children {
		if ly := find_layout_by_id_scroll(child, id_scroll) {
			return ly
		}
	}
	return none
}

// offset_mouse_change_x calculates the new horizontal offset for a scrollable layout
// based on mouse movement.
//
// Parameters:
//   layout:    The layout for which the offset is being calculated.
//   mouse_x:   The current x-coordinate of the mouse.
//   id_scroll: The ID of the scrollable area.
//   w:         The window context.
//
// Returns:
//   The new calculated horizontal offset, clamped within valid bounds.
fn offset_mouse_change_x(layout &Layout, mouse_x f32, id_scroll u32, w &Window) f32 {
	total_width := content_width(layout)
	shape_width := layout.shape.width - layout.shape.padding.width()
	old_offset := w.view_state.offset_x_state[id_scroll]
	new_offset := mouse_x * (total_width / shape_width)
	offset := old_offset - new_offset
	return f32_min(0, f32_max(offset, shape_width - total_width))
}

// offset_mouse_change_y calculates the new vertical offset for a scrollable layout
// based on mouse movement.
//
// Parameters:
//   layout:    The layout for which the offset is being calculated.
//   mouse_y:   The current y-coordinate of the mouse.
//   id_scroll: The ID of the scrollable area.
//   w:         The window context.
//
// Returns:
//   The new calculated vertical offset, clamped within valid bounds.
fn offset_mouse_change_y(layout &Layout, mouse_y f32, id_scroll u32, w &Window) f32 {
	total_height := content_height(layout)
	shape_height := layout.shape.height - layout.shape.padding.height()
	old_offset := w.view_state.offset_y_state[id_scroll]
	new_offset := mouse_y * (total_height / shape_height)
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
		if percent <= 0.03 {
			percent = 0
		}
		if percent >= 0.97 {
			percent = 1
		}
		w.view_state.offset_x_state[id_scroll] = -percent * (total_width - sb.shape.width)
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
		if percent <= 0.03 {
			percent = 0
		}
		if percent >= 0.97 {
			percent = 1
		}
		w.view_state.offset_y_state[id_scroll] = -percent * (total_height - sb.shape.height)
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
		max_offset := f32_min(0, layout.shape.width - layout.shape.padding.width() - content_width(layout))
		offset_x := w.view_state.offset_x_state[v_id] + delta * gui_theme.scroll_multiplier
		w.view_state.offset_x_state[v_id] = f32_clamp(offset_x, max_offset, 0)
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
		max_offset := f32_min(0, layout.shape.height - layout.shape.padding.height() - content_height(layout))
		offset_y := w.view_state.offset_y_state[v_id] + delta * gui_theme.scroll_multiplier
		w.view_state.offset_y_state[v_id] = f32_clamp(offset_y, max_offset, 0)
		return true
	}
	return false
}
