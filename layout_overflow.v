module gui

// layout_overflow hides children that don't fit in an overflow
// container. Called in layout_pipeline after layout_fill_widths
// and layout_wrap. Stores visible_count in ViewState so the
// view generator can build a dropdown with overflow items on
// the next frame.
fn layout_overflow(mut layout Layout, mut window Window) {
	for mut child in layout.children {
		layout_overflow(mut child, mut window)
	}

	if !layout.shape.overflow || layout.shape.axis != .left_to_right || layout.children.len < 2 {
		return
	}

	available := layout.shape.width - layout.shape.padding_width()
	spacing := layout.shape.spacing

	// Find the trigger button (last non-float, non-placeholder child).
	// Floating children (the dropdown menu) are replaced with .none
	// placeholders by layout_remove_floating_layouts before this runs.
	mut trigger_idx := layout.children.len - 1
	for trigger_idx > 0 && (layout.children[trigger_idx].shape.float
		|| layout.children[trigger_idx].shape.shape_type == .none) {
		trigger_idx--
	}
	trigger_w := layout.children[trigger_idx].shape.width

	mut used := f32(0)
	mut visible_count := 0

	for i in 0 .. trigger_idx {
		child := layout.children[i]
		if child.shape.float || child.shape.shape_type == .none {
			continue
		}
		gap := if used > 0 { spacing } else { f32(0) }
		needed := used + gap + child.shape.width
		// Reserve space for trigger + gap
		if needed + spacing + trigger_w > available {
			break
		}
		used = needed
		visible_count++
	}

	if visible_count >= trigger_idx {
		// All items fit — hide trigger
		hide_overflow_child(mut layout.children[trigger_idx])
		visible_count = trigger_idx
	} else {
		// Hide non-fitting items
		for i in visible_count .. trigger_idx {
			hide_overflow_child(mut layout.children[i])
		}
	}

	// Persist for dropdown content generation (visible_count used by
	// view generator to build the dropdown with overflow items).
	mut om := state_map[string, int](mut window, ns_overflow, cap_moderate)
	old := om.get(layout.shape.id) or { -1 }
	if old != visible_count {
		om.set(layout.shape.id, visible_count)
		// Close dropdown — overflow items changed
		mut ss := state_map[string, bool](mut window, ns_select, cap_moderate)
		ss.delete(layout.shape.id)
		window.refresh_layout = true
	}
}

// hide_overflow_child collapses a layout node so it takes no space
// and its descendants are clipped to zero area at render time.
fn hide_overflow_child(mut child Layout) {
	child.shape.shape_type = .none
	child.shape.width = 0
	child.shape.clip = true
}
