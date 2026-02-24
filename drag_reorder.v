module gui

// drag_reorder.v provides shared drag-to-reorder infrastructure
// for ListBox, TabControl, and Tree widgets. One active drag at
// a time (mouse_lock exclusivity). Uses existing FLIP animation
// (animate_layout), floating layers, and mouse_lock.

const ns_drag_reorder = 'gui.drag_reorder'
const drag_reorder_threshold = f32(5.0)
const drag_reorder_scroll_zone = f32(40.0)
const drag_reorder_scroll_speed = f32(4.0)

// DragReorderAxis selects the primary drag axis.
pub enum DragReorderAxis as u8 {
	vertical
	horizontal
}

// DragReorderState tracks an in-progress drag-reorder operation.
struct DragReorderState {
mut:
	active        bool
	cancelled     bool
	source_index  int
	current_index int
	item_count    int
	start_mouse_x f32
	start_mouse_y f32
	mouse_x       f32
	mouse_y       f32
	item_x        f32
	item_y        f32
	item_width    f32
	item_height   f32
	parent_x      f32
	parent_y      f32
	item_id       string
}

// drag_reorder_get returns the current drag state for the given
// widget namespace key, or a default if none exists.
fn drag_reorder_get(mut w Window, key string) DragReorderState {
	mut sm := state_map[string, DragReorderState](mut w, ns_drag_reorder, cap_few)
	return sm.get(key) or { DragReorderState{} }
}

// drag_reorder_set stores drag state.
fn drag_reorder_set(mut w Window, key string, state DragReorderState) {
	mut sm := state_map[string, DragReorderState](mut w, ns_drag_reorder, cap_few)
	sm.set(key, state)
}

// drag_reorder_clear removes drag state for the given key.
fn drag_reorder_clear(mut w Window, key string) {
	mut sm := state_map[string, DragReorderState](mut w, ns_drag_reorder, cap_few)
	sm.delete(key)
}

// drag_reorder_read returns drag state without requiring mut Window.
fn drag_reorder_read(w &Window, key string) DragReorderState {
	sm := state_map_read[string, DragReorderState](w, ns_drag_reorder) or {
		return DragReorderState{}
	}
	return sm.get(key) or { DragReorderState{} }
}

// drag_reorder_make_lock builds a MouseLockCfg that implements the
// full drag lifecycle: threshold detection, tracking with FLIP
// animation, and drop/cancel.
fn drag_reorder_make_lock(drag_key string,
	axis DragReorderAxis,
	on_reorder fn (int, int, mut Window)) MouseLockCfg {
	return MouseLockCfg{
		mouse_move: fn [drag_key, axis] (_ &Layout, mut e Event, mut w Window) {
			drag_reorder_on_mouse_move(drag_key, axis, e.mouse_x, e.mouse_y, mut w)
		}
		mouse_up:   fn [drag_key, on_reorder] (_ &Layout, mut e Event, mut w Window) {
			drag_reorder_on_mouse_up(drag_key, on_reorder, mut w)
		}
	}
}

// drag_reorder_on_mouse_move handles threshold detection and
// index tracking during a drag.
fn drag_reorder_on_mouse_move(drag_key string,
	axis DragReorderAxis,
	mouse_x f32,
	mouse_y f32,
	mut w Window) {
	mut state := drag_reorder_get(mut w, drag_key)
	if state.cancelled {
		return
	}

	state.mouse_x = mouse_x
	state.mouse_y = mouse_y

	if !state.active {
		dx := mouse_x - state.start_mouse_x
		dy := mouse_y - state.start_mouse_y
		dist := match axis {
			.vertical { f32_abs(dy) }
			.horizontal { f32_abs(dx) }
		}
		if dist < drag_reorder_threshold {
			drag_reorder_set(mut w, drag_key, state)
			return
		}
		// Threshold crossed — activate drag.
		state.active = true
		w.animate_layout(LayoutTransitionCfg{})
	}

	// Estimate drop target from cursor vs item geometry.
	mouse_main := match axis {
		.vertical { mouse_y }
		.horizontal { mouse_x }
	}
	item_start := match axis {
		.vertical { state.item_y }
		.horizontal { state.item_x }
	}
	item_size := match axis {
		.vertical { state.item_height }
		.horizontal { state.item_width }
	}
	new_index := drag_reorder_calc_index(mouse_main, item_start, item_size, state.source_index,
		state.item_count)

	if new_index != state.current_index {
		w.animate_layout(LayoutTransitionCfg{})
		state.current_index = new_index
	}

	drag_reorder_set(mut w, drag_key, state)
	w.update_window()
}

// drag_reorder_on_mouse_up finalizes the drag: fires on_reorder
// if indices differ, then cleans up.
fn drag_reorder_on_mouse_up(drag_key string,
	on_reorder fn (int, int, mut Window),
	mut w Window) {
	state := drag_reorder_get(mut w, drag_key)
	was_active := state.active
	src := state.source_index
	dst := state.current_index

	drag_reorder_clear(mut w, drag_key)
	w.mouse_unlock()

	if was_active && !state.cancelled && src != dst {
		if on_reorder != unsafe { nil } {
			w.animate_layout(LayoutTransitionCfg{})
			on_reorder(src, dst, mut w)
		}
	}
	w.update_window()
}

// drag_reorder_cancel cancels an active drag without firing the
// callback. Called from escape-key handlers.
fn drag_reorder_cancel(drag_key string, mut w Window) {
	mut state := drag_reorder_get(mut w, drag_key)
	if !state.active && !state.cancelled {
		// Not yet activated — just clear.
		drag_reorder_clear(mut w, drag_key)
		w.mouse_unlock()
		return
	}
	state.cancelled = true
	drag_reorder_set(mut w, drag_key, state)
	w.mouse_unlock()
	w.update_window()
}

// drag_reorder_start initiates a drag-reorder from an on_click
// handler. Captures initial mouse/item positions and locks the
// mouse.
fn drag_reorder_start(drag_key string,
	index int,
	item_id string,
	axis DragReorderAxis,
	item_count int,
	on_reorder fn (int, int, mut Window),
	layout &Layout,
	e &Event,
	mut w Window) {
	parent_x := if layout.parent != unsafe { nil } {
		layout.parent.shape.x
	} else {
		f32(0)
	}
	parent_y := if layout.parent != unsafe { nil } {
		layout.parent.shape.y
	} else {
		f32(0)
	}
	state := DragReorderState{
		source_index:  index
		current_index: index
		item_count:    item_count
		start_mouse_x: e.mouse_x + layout.shape.x
		start_mouse_y: e.mouse_y + layout.shape.y
		mouse_x:       e.mouse_x + layout.shape.x
		mouse_y:       e.mouse_y + layout.shape.y
		item_x:        layout.shape.x
		item_y:        layout.shape.y
		item_width:    layout.shape.width
		item_height:   layout.shape.height
		parent_x:      parent_x
		parent_y:      parent_y
		item_id:       item_id
	}
	drag_reorder_set(mut w, drag_key, state)
	w.mouse_lock(drag_reorder_make_lock(drag_key, axis, on_reorder))
}

// drag_reorder_calc_index estimates the drop target index from
// cursor position, using the source item's origin and size to
// infer uniform item spacing.
fn drag_reorder_calc_index(mouse_main f32, item_start f32,
	item_size f32, source_index int, item_count int) int {
	if item_count <= 1 || item_size <= 0 {
		return 0
	}
	// Infer the list start from source item position.
	list_start := item_start - f32(source_index) * item_size
	rel := mouse_main - list_start
	idx := int(rel / item_size)
	return int_clamp(idx, 0, item_count - 1)
}

// drag_reorder_ghost_view returns a floating container at the
// cursor position containing the dragged item content.
// float_offset is computed relative to the parent captured at
// drag start so that float_attach_layout positions the ghost
// at the correct absolute coordinates.
fn drag_reorder_ghost_view(state DragReorderState, content View) View {
	// Desired absolute position of the ghost.
	ghost_x := state.mouse_x - (state.start_mouse_x - state.item_x)
	ghost_y := state.mouse_y - (state.start_mouse_y - state.item_y)

	return column(
		name:           'drag_reorder_ghost'
		float:          true
		float_offset_x: ghost_x - state.parent_x
		float_offset_y: ghost_y - state.parent_y
		width:          state.item_width
		height:         state.item_height
		opacity:        0.85
		sizing:         fixed_fixed
		clip:           true
		padding:        padding_none
		size_border:    0
		v_align:        .middle
		color:          gui_theme.color_background
		shadow:         &BoxShadow{
			color:       Color{0, 0, 0, 60}
			offset_y:    2
			blur_radius: 8
		}
		content:        [content]
	)
}

// drag_reorder_gap_view returns a transparent spacer the same
// size as the dragged item.
fn drag_reorder_gap_view(state DragReorderState, axis DragReorderAxis) View {
	return rectangle(
		name:   'drag_reorder_gap'
		color:  color_transparent
		width:  state.item_width
		height: state.item_height
		sizing: if axis == .horizontal { fixed_fit } else { fill_fixed }
	)
}

// drag_reorder_keyboard_move handles Alt+Arrow keyboard reorder.
// Returns true if the event was handled.
fn drag_reorder_keyboard_move(key_code KeyCode,
	modifiers Modifier,
	axis DragReorderAxis,
	current_index int,
	item_count int,
	on_reorder fn (int, int, mut Window),
	mut w Window) bool {
	if on_reorder == unsafe { nil } || item_count <= 1 {
		return false
	}
	if !modifiers.has(.alt) {
		return false
	}

	mut new_index := -1
	match axis {
		.vertical {
			match key_code {
				.up {
					if current_index > 0 {
						new_index = current_index - 1
					}
				}
				.down {
					if current_index < item_count - 1 {
						new_index = current_index + 1
					}
				}
				else {}
			}
		}
		.horizontal {
			match key_code {
				.left {
					if current_index > 0 {
						new_index = current_index - 1
					}
				}
				.right {
					if current_index < item_count - 1 {
						new_index = current_index + 1
					}
				}
				else {}
			}
		}
	}

	if new_index < 0 {
		return false
	}

	w.animate_layout(LayoutTransitionCfg{})
	on_reorder(current_index, new_index, mut w)
	return true
}

// drag_reorder_escape checks for escape key during an active drag
// and cancels it. Returns true if handled.
fn drag_reorder_escape(drag_key string, key_code KeyCode, mut w Window) bool {
	if key_code != .escape {
		return false
	}
	state := drag_reorder_get(mut w, drag_key)
	if !state.active && state.source_index == 0 && state.item_id.len == 0 {
		return false
	}
	drag_reorder_cancel(drag_key, mut w)
	return true
}

// drag_reorder_auto_scroll checks if the cursor is near the edge
// of a scrollable container and scrolls accordingly. Call from
// mouse_move during an active drag.
fn drag_reorder_auto_scroll(mouse_main f32,
	container_start f32,
	container_end f32,
	id_scroll u32,
	axis DragReorderAxis,
	mut w Window) {
	if id_scroll == 0 {
		return
	}
	near_start := mouse_main - container_start
	near_end := container_end - mouse_main

	if near_start < drag_reorder_scroll_zone && near_start >= 0 {
		ratio := 1.0 - (near_start / drag_reorder_scroll_zone)
		delta := drag_reorder_scroll_speed * ratio
		match axis {
			.vertical { w.scroll_vertical_by(id_scroll, delta) }
			.horizontal { w.scroll_horizontal_by(id_scroll, delta) }
		}
	} else if near_end < drag_reorder_scroll_zone && near_end >= 0 {
		ratio := 1.0 - (near_end / drag_reorder_scroll_zone)
		delta := -drag_reorder_scroll_speed * ratio
		match axis {
			.vertical { w.scroll_vertical_by(id_scroll, delta) }
			.horizontal { w.scroll_horizontal_by(id_scroll, delta) }
		}
	}
}
