module gui

import time

// drag_reorder.v provides shared drag-to-reorder infrastructure
// for ListBox, TabControl, and Tree widgets. One active drag at
// a time (mouse_lock exclusivity). Uses existing FLIP animation
// (animate_layout), floating layers, and mouse_lock.

const ns_drag_reorder = 'gui.drag_reorder'
const ns_drag_reorder_ids_meta = 'gui.drag_reorder.ids_meta'
const drag_reorder_threshold = f32(5.0)
const drag_reorder_scroll_zone = f32(40.0)
const drag_reorder_scroll_speed = f32(4.0)
const drag_reorder_scroll_animation_id = 'gui.drag_reorder.scroll'
const drag_reorder_ghost_opacity = 0.85
const drag_reorder_ghost_shadow_color = Color{0, 0, 0, 60}
const drag_reorder_ghost_shadow_blur = f32(8.0)
const drag_reorder_ghost_shadow_offset_y = f32(2.0)

// DragReorderAxis selects the primary drag axis.
pub enum DragReorderAxis as u8 {
	vertical
	horizontal
}

// DragReorderState tracks an in-progress drag-reorder operation.
struct DragReorderState {
mut:
	started             bool
	active              bool
	cancelled           bool
	source_index        int
	current_index       int
	item_count          int
	ids_len             int
	ids_hash            u64
	item_layout_ids     []string
	item_mids           []f32
	start_mouse_x       f32
	start_mouse_y       f32
	mouse_x             f32
	mouse_y             f32
	item_x              f32
	item_y              f32
	item_width          f32
	item_height         f32
	parent_x            f32
	parent_y            f32
	item_id             string
	id_scroll           u32
	container_start     f32
	container_end       f32
	start_scroll_x      f32
	start_scroll_y      f32
	layouts_valid       bool
	mids_offset         int // draggable count before first midpoint entry
	scroll_timer_active bool
}

struct DragReorderIdsMeta {
	ids_len  int
	ids_hash u64
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

fn drag_reorder_ids_meta_set(mut w Window, key string, ids []string) {
	mut sm := state_map[string, DragReorderIdsMeta](mut w, ns_drag_reorder_ids_meta, cap_few)
	sm.set(key, DragReorderIdsMeta{
		ids_len:  ids.len
		ids_hash: drag_reorder_ids_signature(ids)
	})
}

fn drag_reorder_ids_meta_get(w &Window, key string) ?DragReorderIdsMeta {
	if sm := state_map_read[string, DragReorderIdsMeta](w, ns_drag_reorder_ids_meta) {
		return sm.get(key)
	}
	return none
}

fn drag_reorder_ids_changed(state DragReorderState, meta DragReorderIdsMeta) bool {
	return state.ids_len != meta.ids_len || state.ids_hash != meta.ids_hash
}

// drag_reorder_make_lock builds a MouseLockCfg that implements the
// full drag lifecycle: threshold detection, tracking with FLIP
// animation, and drop/cancel.
fn drag_reorder_make_lock(drag_key string,
	axis DragReorderAxis,
	item_ids []string,
	on_reorder fn (string, string, mut Window)) MouseLockCfg {
	return MouseLockCfg{
		mouse_move: fn [drag_key, axis] (_ &Layout, mut e Event, mut w Window) {
			drag_reorder_on_mouse_move(drag_key, axis, e.mouse_x, e.mouse_y, mut w)
		}
		mouse_up:   fn [drag_key, item_ids, on_reorder] (_ &Layout, mut e Event, mut w Window) {
			drag_reorder_on_mouse_up(drag_key, item_ids, on_reorder, mut w)
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
	if meta := drag_reorder_ids_meta_get(w, drag_key) {
		if drag_reorder_ids_changed(state, meta) {
			drag_reorder_cancel(drag_key, mut w)
			return
		}
	}

	mouse_changed := mouse_x != state.mouse_x || mouse_y != state.mouse_y
	state.mouse_x = mouse_x
	state.mouse_y = mouse_y
	mut activated := false

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
		activated = true
		w.animate_layout(LayoutTransitionCfg{})
	}

	// Determine drop target from cursor vs item geometry.
	// Prefer precomputed midpoints (fastest hit testing).
	// Adjust mouse coordinate by scroll delta so lookups remain relative
	// to the item list as the container auto-scrolls.
	mouse_orig := match axis {
		.vertical { mouse_y }
		.horizontal { mouse_x }
	}
	mut mouse_main := mouse_orig
	mut scrolled_since_start := false
	if state.id_scroll > 0 {
		scroll_val := if axis == .vertical {
			state_read_or[u32, f32](w, ns_scroll_y, state.id_scroll, 0)
		} else {
			state_read_or[u32, f32](w, ns_scroll_x, state.id_scroll, 0)
		}
		start_scroll := if axis == .vertical { state.start_scroll_y } else { state.start_scroll_x }
		scrolled_since_start = scroll_val != start_scroll
		mouse_main -= (scroll_val - start_scroll)
	}

	mut new_index := -1
	if !scrolled_since_start && state.layouts_valid {
		if idx := drag_reorder_calc_index_from_mids(mouse_main, state.item_mids) {
			new_index = idx + state.mids_offset
		}
	}

	if new_index < 0 {
		// Fallback to uniform estimation if geometry is unavailable.
		item_start := match axis {
			.vertical { state.item_y }
			.horizontal { state.item_x }
		}
		item_size := match axis {
			.vertical { state.item_height }
			.horizontal { state.item_width }
		}
		new_index = drag_reorder_calc_index(mouse_main, item_start, item_size, state.source_index,
			state.item_count)
	}

	// Scroll check uses original mouse coordinate.
	did_scroll := drag_reorder_auto_scroll(mouse_orig, state.container_start, state.container_end,
		state.id_scroll, axis, mut w)

	// If scrolling happened, we want to continue scrolling even if mouse doesn't move.
	if did_scroll && !state.scroll_timer_active {
		state.scroll_timer_active = true
		w.animation_add(mut Animate{
			id:       drag_reorder_scroll_animation_id
			repeat:   true
			delay:    16 * time.millisecond
			callback: fn [drag_key, axis] (mut an Animate, mut w Window) {
				mut st := drag_reorder_get(mut w, drag_key)
				if !st.active || st.cancelled {
					an.stopped = true
					return
				}
				// Call mouse_move with current (captured) mouse position to trigger next scroll step.
				drag_reorder_on_mouse_move(drag_key, axis, st.mouse_x, st.mouse_y, mut
					w)
			}
		})
	} else if !did_scroll && state.scroll_timer_active {
		state.scroll_timer_active = false
		w.remove_animation(drag_reorder_scroll_animation_id)
	}

	mut index_changed := false
	if new_index != state.current_index {
		w.animate_layout(LayoutTransitionCfg{})
		state.current_index = new_index
		index_changed = true
	}

	drag_reorder_set(mut w, drag_key, state)
	if activated || index_changed || did_scroll || (state.active && mouse_changed) {
		w.update_window()
	}
}

// drag_reorder_on_mouse_up finalizes the drag: fires on_reorder
// with (moved_id, before_id) if the gap index differs from the
// source position. before_id is "" when dropping at the end.
fn drag_reorder_on_mouse_up(drag_key string,
	item_ids []string,
	on_reorder fn (string, string, mut Window),
	mut w Window) {
	state := drag_reorder_get(mut w, drag_key)
	was_active := state.active
	src := state.source_index
	gap := state.current_index

	// If the backing list changed during the drag, cancel without reorder.
	if meta := drag_reorder_ids_meta_get(w, drag_key) {
		if drag_reorder_ids_changed(state, meta) {
			drag_reorder_clear(mut w, drag_key)
			w.mouse_unlock()
			w.remove_animation(drag_reorder_scroll_animation_id)
			w.update_window()
			return
		}
	}
	if state.ids_len != item_ids.len || state.ids_hash != drag_reorder_ids_signature(item_ids) {
		drag_reorder_clear(mut w, drag_key)
		w.mouse_unlock()
		w.remove_animation(drag_reorder_scroll_animation_id)
		w.update_window()
		return
	}

	drag_reorder_clear(mut w, drag_key)
	w.mouse_unlock()
	w.remove_animation(drag_reorder_scroll_animation_id)

	// drop at gap index (src) or the gap immediately following it (src+1)
	// is a no-op since the item is already between those positions.
	if was_active && !state.cancelled && gap != src && gap != src + 1 {
		if on_reorder != unsafe { nil } && src >= 0 && src < item_ids.len {
			moved_id := item_ids[src]
			before_id := if gap < item_ids.len {
				item_ids[gap]
			} else {
				''
			}
			w.animate_layout(LayoutTransitionCfg{})
			on_reorder(moved_id, before_id, mut w)
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
	// Set cancelled so the frame rebuild (update_window) sees it and hides
	// ghost/gap. mouse_unlock releases the lock without firing mouse_up,
	// so drag_reorder_on_mouse_up is not re-entered. Clear state last so
	// the rebuild can still read the cancelled flag.
	state.cancelled = true
	drag_reorder_set(mut w, drag_key, state)
	w.mouse_unlock()
	w.remove_animation(drag_reorder_scroll_animation_id)
	w.update_window()
	drag_reorder_clear(mut w, drag_key)
}

// drag_reorder_start initiates a drag-reorder from an on_click
// handler. Captures initial mouse/item positions and locks the
// mouse.
fn drag_reorder_start(drag_key string,
	index int,
	item_id string,
	axis DragReorderAxis,
	item_ids []string,
	on_reorder fn (string, string, mut Window),
	item_layout_ids []string,
	mids_offset int,
	id_scroll u32,
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
	mut container_start := f32(0)
	mut container_end := f32(0)
	if id_scroll > 0 && layout.parent != unsafe { nil } {
		match axis {
			.vertical {
				container_start = layout.parent.shape.y
				container_end = layout.parent.shape.y + layout.parent.shape.height
			}
			.horizontal {
				container_start = layout.parent.shape.x
				container_end = layout.parent.shape.x + layout.parent.shape.width
			}
		}
	}
	mut start_scroll_x := f32(0)
	mut start_scroll_y := f32(0)
	if id_scroll > 0 {
		if smx := state_map_read[u32, f32](w, ns_scroll_x) {
			start_scroll_x = smx.get(id_scroll) or { 0 }
		}
		if smy := state_map_read[u32, f32](w, ns_scroll_y) {
			start_scroll_y = smy.get(id_scroll) or { 0 }
		}
	}
	item_mids := drag_reorder_item_mids_from_layouts(axis, item_layout_ids, w) or { []f32{} }
	layouts_valid := item_mids.len > 0 && item_mids.len == item_layout_ids.len
	state := DragReorderState{
		started:         true
		source_index:    index
		current_index:   index
		item_count:      item_ids.len
		ids_len:         item_ids.len
		ids_hash:        drag_reorder_ids_signature(item_ids)
		item_layout_ids: item_layout_ids.clone()
		item_mids:       item_mids
		start_mouse_x:   e.mouse_x + layout.shape.x
		start_mouse_y:   e.mouse_y + layout.shape.y
		mouse_x:         e.mouse_x + layout.shape.x
		mouse_y:         e.mouse_y + layout.shape.y
		item_x:          layout.shape.x
		item_y:          layout.shape.y
		item_width:      layout.shape.width
		item_height:     layout.shape.height
		parent_x:        parent_x
		parent_y:        parent_y
		item_id:         item_id
		id_scroll:       id_scroll
		container_start: container_start
		container_end:   container_end
		start_scroll_x:  start_scroll_x
		start_scroll_y:  start_scroll_y
		layouts_valid:   layouts_valid
		mids_offset:     mids_offset
	}
	drag_reorder_set(mut w, drag_key, state)
	w.mouse_lock(drag_reorder_make_lock(drag_key, axis, item_ids, on_reorder))
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
	return int_clamp(idx, 0, item_count)
}

// drag_reorder_calc_index_from_mids estimates the drop target index
// from precomputed item midpoint coordinates.
fn drag_reorder_calc_index_from_mids(mouse_main f32, item_mids []f32) ?int {
	if item_mids.len == 0 {
		return none
	}
	mut lo := 0
	mut hi := item_mids.len
	for lo < hi {
		mid_idx := (lo + hi) / 2
		if item_mids[mid_idx] <= mouse_main {
			lo = mid_idx + 1
		} else {
			hi = mid_idx
		}
	}
	return lo
}

// drag_reorder_item_mids_from_layouts resolves draggable layout IDs once
// at drag start and stores axis midpoints for fast per-move hit testing.
fn drag_reorder_item_mids_from_layouts(axis DragReorderAxis, item_layout_ids []string, w &Window) ?[]f32 {
	if item_layout_ids.len == 0 {
		return none
	}
	mut mids := []f32{cap: item_layout_ids.len}
	for id in item_layout_ids {
		ly := w.layout.find_by_id(id) or { return none }
		mids << match axis {
			.vertical { ly.shape.y + (ly.shape.height / 2) }
			.horizontal { ly.shape.x + (ly.shape.width / 2) }
		}
	}
	return mids
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
		opacity:        drag_reorder_ghost_opacity
		sizing:         fixed_fixed
		clip:           true
		padding:        padding_none
		size_border:    0
		v_align:        .middle
		color:          gui_theme.color_background
		shadow:         &BoxShadow{
			color:       drag_reorder_ghost_shadow_color
			offset_y:    drag_reorder_ghost_shadow_offset_y
			blur_radius: drag_reorder_ghost_shadow_blur
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
// Converts gap indices to (moved_id, before_id) and calls
// on_reorder directly. Returns true if the event was handled.
fn drag_reorder_keyboard_move(key_code KeyCode,
	modifiers Modifier,
	axis DragReorderAxis,
	current_index int,
	item_ids []string,
	on_reorder fn (string, string, mut Window),
	mut w Window) bool {
	item_count := item_ids.len
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
						// Moving down one slot means dropping before the item
						// at current_index + 2.
						new_index = int_min(current_index + 2, item_count)
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
						// Moving right one slot means dropping before the item
						// at current_index + 2.
						new_index = int_min(current_index + 2, item_count)
					}
				}
				else {}
			}
		}
	}

	if new_index < 0 {
		return false
	}

	moved_id := item_ids[current_index]
	before_id := if new_index < item_count {
		item_ids[new_index]
	} else {
		''
	}
	w.animate_layout(LayoutTransitionCfg{})
	on_reorder(moved_id, before_id, mut w)
	return true
}

// drag_reorder_escape checks for escape key during an active drag
// and cancels it. Returns true if handled.
fn drag_reorder_escape(drag_key string, key_code KeyCode, mut w Window) bool {
	if key_code != .escape {
		return false
	}
	state := drag_reorder_get(mut w, drag_key)
	if !state.started && !state.active {
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
	mut w Window) bool {
	if id_scroll == 0 {
		return false
	}
	near_start := mouse_main - container_start
	near_end := container_end - mouse_main

	if near_start < drag_reorder_scroll_zone && near_start >= 0 {
		ratio := 1.0 - (near_start / drag_reorder_scroll_zone)
		delta := drag_reorder_scroll_speed * ratio
		if delta != 0 {
			match axis {
				.vertical { w.scroll_vertical_by(id_scroll, delta) }
				.horizontal { w.scroll_horizontal_by(id_scroll, delta) }
			}
			return true
		}
	} else if near_end < drag_reorder_scroll_zone && near_end >= 0 {
		ratio := 1.0 - (near_end / drag_reorder_scroll_zone)
		delta := -drag_reorder_scroll_speed * ratio
		if delta != 0 {
			match axis {
				.vertical { w.scroll_vertical_by(id_scroll, delta) }
				.horizontal { w.scroll_horizontal_by(id_scroll, delta) }
			}
			return true
		}
	}
	return false
}

// reorder_indices computes (from, to) indices for a
// delete(from) + insert(to, item) reorder operation.
// moved_id is the ID of the moved item. before_id is
// the ID of the item it should appear before, or ""
// for end of list. Returns (-1, -1) on no-op or
// not-found (including missing before_id).
pub fn reorder_indices(ids []string, moved_id string, before_id string) (int, int) {
	mut from := -1
	mut bi := ids.len
	mut before_found := false
	for i, id in ids {
		if id == moved_id {
			from = i
		}
		if before_id.len > 0 && id == before_id {
			bi = i
			before_found = true
		}
	}
	if from < 0 {
		return -1, -1
	}
	if before_id.len > 0 && !before_found {
		return -1, -1
	}
	to := if from < bi { bi - 1 } else { bi }
	if from == to {
		return -1, -1
	}
	return from, to
}

// drag_reorder_ids_signature computes a stable FNV-1a signature
// of the item IDs to detect mid-drag list mutations.
fn drag_reorder_ids_signature(ids []string) u64 {
	mut h := data_grid_fnv64_offset
	for id in ids {
		h = data_grid_fnv64_str(h, id)
		h = data_grid_fnv64_byte(h, 0x1f)
	}
	return h
}
