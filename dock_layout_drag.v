module gui

// dock_layout_drag.v — drag lifecycle, zone detection, ghost
// rendering, and overlay drawing for docking panel drag operations.

const dock_drag_threshold = f32(5.0)
const dock_drag_ghost_opacity = 0.85
const dock_drag_ghost_shadow_color = Color{0, 0, 0, 60}
const dock_drag_ghost_shadow_blur = f32(8.0)
const dock_drag_ghost_shadow_offset_y = f32(2.0)
const dock_drag_window_edge_zone = f32(20.0)
const dock_drag_edge_ratio = f32(0.25)

// DockDropZone identifies where a panel will be inserted on drop.
pub enum DockDropZone as u8 {
	none
	center // add as tab
	top    // split above
	bottom // split below
	left   // split left
	right  // split right
	window_top
	window_bottom
	window_left
	window_right
}

// DockDragState tracks an in-progress dock panel drag.
struct DockDragState {
mut:
	active         bool
	panel_id       string
	source_group   string
	mouse_x        f32
	mouse_y        f32
	start_mouse_x  f32
	start_mouse_y  f32
	ghost_w        f32
	ghost_h        f32
	parent_x       f32
	parent_y       f32
	hover_zone     DockDropZone
	hover_group_id string
}

// dock_drag_get retrieves the current drag state.
fn dock_drag_get(mut w Window, dock_id string) DockDragState {
	mut sm := state_map[string, DockDragState](mut w, ns_dock_drag, cap_few)
	return sm.get(dock_id) or { DockDragState{} }
}

// dock_drag_set stores drag state.
fn dock_drag_set(mut w Window, dock_id string, state DockDragState) {
	mut sm := state_map[string, DockDragState](mut w, ns_dock_drag, cap_few)
	sm.set(dock_id, state)
}

// dock_drag_clear removes drag state.
fn dock_drag_clear(mut w Window, dock_id string) {
	mut sm := state_map[string, DockDragState](mut w, ns_dock_drag, cap_few)
	sm.delete(dock_id)
}

// dock_drag_start initiates a dock panel drag from a tab header click.
fn dock_drag_start(dock_id string, panel_id string, source_group string,
	root &DockNode, on_layout_change fn (&DockNode, mut Window),
	layout &Layout, e &Event, mut w Window) {
	state := DockDragState{
		active:        false
		panel_id:      panel_id
		source_group:  source_group
		mouse_x:       e.mouse_x
		mouse_y:       e.mouse_y
		start_mouse_x: e.mouse_x
		start_mouse_y: e.mouse_y
		ghost_w:       layout.shape.width
		ghost_h:       layout.shape.height
		parent_x:      if layout.parent != unsafe { nil } { layout.parent.shape.x } else { f32(0) }
		parent_y:      if layout.parent != unsafe { nil } { layout.parent.shape.y } else { f32(0) }
	}
	dock_drag_set(mut w, dock_id, state)
	w.mouse_lock(MouseLockCfg{
		mouse_move: fn [dock_id, root] (_ &Layout, mut e Event, mut w Window) {
			dock_drag_on_mouse_move(dock_id, root, e.mouse_x, e.mouse_y, mut w)
		}
		mouse_up:   fn [dock_id, root, on_layout_change] (_ &Layout, mut e Event, mut w Window) {
			dock_drag_on_mouse_up(dock_id, root, on_layout_change, mut w)
		}
	})
}

// dock_drag_on_mouse_move handles threshold detection and zone tracking.
fn dock_drag_on_mouse_move(dock_id string, root &DockNode,
	mouse_x f32, mouse_y f32, mut w Window) {
	mut state := dock_drag_get(mut w, dock_id)
	state.mouse_x = mouse_x
	state.mouse_y = mouse_y

	if !state.active {
		dx := mouse_x - state.start_mouse_x
		dy := mouse_y - state.start_mouse_y
		dist := f32_max(f32_abs(dx), f32_abs(dy))
		if dist < dock_drag_threshold {
			dock_drag_set(mut w, dock_id, state)
			return
		}
		state.active = true
	}

	// Zone detection.
	zone, group_id := dock_drag_detect_zone(dock_id, root, mouse_x, mouse_y, state.source_group,
		state.panel_id, w)
	state.hover_zone = zone
	state.hover_group_id = group_id
	dock_drag_set(mut w, dock_id, state)
	w.update_window()
}

// dock_drag_on_mouse_up handles the drop or cancel.
fn dock_drag_on_mouse_up(dock_id string, root &DockNode,
	on_layout_change fn (&DockNode, mut Window), mut w Window) {
	state := dock_drag_get(mut w, dock_id)
	w.mouse_unlock()

	if state.active && state.hover_zone != .none {
		new_root := dock_tree_move_panel(root, state.panel_id, state.hover_group_id, state.hover_zone)
		on_layout_change(new_root, mut w)
	}

	dock_drag_clear(mut w, dock_id)
	w.update_window()
}

// dock_drag_cancel cancels the drag in progress.
fn dock_drag_cancel(dock_id string, mut w Window) {
	w.mouse_unlock()
	dock_drag_clear(mut w, dock_id)
	w.update_window()
}

// dock_drag_detect_zone determines which drop zone the cursor is over.
fn dock_drag_detect_zone(dock_id string, root &DockNode,
	mouse_x f32, mouse_y f32, source_group string, panel_id string,
	w &Window) (DockDropZone, string) {
	// 1. Check window-edge zones first.
	dock_layout := w.find_layout_by_id(dock_id) or { return DockDropZone.none, '' }
	clip := dock_layout.shape.shape_clip
	if clip.width <= 0 || clip.height <= 0 {
		return DockDropZone.none, ''
	}

	edge := dock_drag_window_edge_zone
	if mouse_x >= clip.x && mouse_x < clip.x + edge && mouse_y >= clip.y
		&& mouse_y < clip.y + clip.height {
		return DockDropZone.window_left, ''
	}
	if mouse_x >= clip.x + clip.width - edge && mouse_x < clip.x + clip.width && mouse_y >= clip.y
		&& mouse_y < clip.y + clip.height {
		return DockDropZone.window_right, ''
	}
	if mouse_y >= clip.y && mouse_y < clip.y + edge && mouse_x >= clip.x
		&& mouse_x < clip.x + clip.width {
		return DockDropZone.window_top, ''
	}
	if mouse_y >= clip.y + clip.height - edge && mouse_y < clip.y + clip.height && mouse_x >= clip.x
		&& mouse_x < clip.x + clip.width {
		return DockDropZone.window_bottom, ''
	}

	// 2. Check each panel group's zone.
	groups := dock_tree_collect_panel_nodes(root)
	for group in groups {
		group_layout := w.find_layout_by_id(group.id) or { continue }
		gc := group_layout.shape.shape_clip
		if gc.width <= 0 || gc.height <= 0 {
			continue
		}
		if mouse_x < gc.x || mouse_x >= gc.x + gc.width || mouse_y < gc.y
			|| mouse_y >= gc.y + gc.height {
			continue
		}
		// Skip dropping onto source group if it only has this one panel.
		if group.id == source_group && group.panel_ids.len <= 1 {
			continue
		}
		// Compute relative position.
		rel_x := (mouse_x - gc.x) / gc.width
		rel_y := (mouse_y - gc.y) / gc.height
		zone := dock_classify_zone(rel_x, rel_y)
		// Skip center drop on same group (already a tab there).
		if zone == .center && group.id == source_group {
			continue
		}
		return zone, group.id
	}

	return DockDropZone.none, ''
}

// dock_classify_zone classifies a relative position (0..1) within
// a group rectangle into a drop zone.
fn dock_classify_zone(rel_x f32, rel_y f32) DockDropZone {
	edge := dock_drag_edge_ratio
	if rel_y < edge {
		return .top
	}
	if rel_y > 1.0 - edge {
		return .bottom
	}
	if rel_x < edge {
		return .left
	}
	if rel_x > 1.0 - edge {
		return .right
	}
	return .center
}

// dock_drag_ghost_view returns a floating ghost of the dragged tab.
fn dock_drag_ghost_view(state DockDragState, label string) View {
	ghost_x := state.mouse_x - (state.start_mouse_x - state.parent_x)
	ghost_y := state.mouse_y - (state.start_mouse_y - state.parent_y)

	return column(
		name:           'dock_drag_ghost'
		float:          true
		float_offset_x: ghost_x - state.parent_x
		float_offset_y: ghost_y - state.parent_y
		width:          state.ghost_w
		height:         state.ghost_h
		opacity:        dock_drag_ghost_opacity
		sizing:         fixed_fixed
		clip:           true
		padding:        padding(6, 12, 6, 12)
		color:          gui_theme.color_panel
		shadow:         &BoxShadow{
			color:       dock_drag_ghost_shadow_color
			offset_y:    dock_drag_ghost_shadow_offset_y
			blur_radius: dock_drag_ghost_shadow_blur
		}
		content:        [text(text: label)]
	)
}

// dock_drag_zone_overlay_view returns a semi-transparent overlay
// showing the drop zone preview. Positioned via amend_layout.
fn dock_drag_zone_overlay_view(color_zone Color) View {
	return column(
		name:    'dock_zone_overlay'
		id:      'dock_zone_overlay'
		sizing:  fixed_fixed
		width:   0
		height:  0
		padding: padding_none
		color:   color_zone
	)
}

// dock_drag_amend_overlay positions the zone overlay based on the
// current drag state and target group layout.
fn dock_drag_amend_overlay(dock_id string, color_zone Color, mut layout Layout, mut w Window) {
	state := dock_drag_get(mut w, dock_id)
	if !state.active || state.hover_zone == .none {
		return
	}

	// The overlay is the second child of the dock canvas (index 1).
	if layout.children.len < 2 {
		return
	}

	// Determine target rect.
	mut tx, mut ty, mut tw, mut th := f32(0), f32(0), f32(0), f32(0)

	if state.hover_zone == .window_top || state.hover_zone == .window_bottom
		|| state.hover_zone == .window_left || state.hover_zone == .window_right {
		tx = layout.shape.x
		ty = layout.shape.y
		tw = layout.shape.width
		th = layout.shape.height
	} else if state.hover_group_id.len > 0 {
		group_layout := layout.find_by_id(state.hover_group_id) or { return }
		tx = group_layout.shape.x
		ty = group_layout.shape.y
		tw = group_layout.shape.width
		th = group_layout.shape.height
	} else {
		return
	}

	// Subdivide based on zone.
	match state.hover_zone {
		.top, .window_top {
			th = th * 0.5
		}
		.bottom, .window_bottom {
			ty = ty + th * 0.5
			th = th * 0.5
		}
		.left, .window_left {
			tw = tw * 0.5
		}
		.right, .window_right {
			tx = tx + tw * 0.5
			tw = tw * 0.5
		}
		.center {}
		.none {}
	}

	// children[1] is the drop-zone overlay; index coupled to child order in view_dock_layout.v
	layout.children[1].shape.x = tx
	layout.children[1].shape.y = ty
	layout.children[1].shape.width = tw
	layout.children[1].shape.height = th
	layout.children[1].shape.color = color_zone
}
