module gui

import arrays

// find_shape walks the layout in depth first until predicate is satisfied.
pub fn (layout &Layout) find_shape(predicate fn (n Layout) bool) ?Shape {
	for child in layout.children {
		if found := child.find_shape(predicate) {
			return found
		}
	}
	return if predicate(layout) { layout.shape } else { none }
}

// find_layout walks the layout in dept first until predicate is satisfied.
pub fn (layout &Layout) find_layout(predicate fn (n Layout) bool) ?Layout {
	for child in layout.children {
		if found := child.find_layout(predicate) {
			return found
		}
	}
	return if predicate(layout) { layout } else { none }
}

// previous_focusable gets the previous non-skippable focusable of the current focus.
// Returns the first non-skippable focusable if focus is not set.
pub fn (layout &Layout) previous_focusable(mut w Window) ?Shape {
	ids := layout.get_focus_ids().reverse()
	return layout.find_next_focusable(ids, mut w)
}

// next_focusable gets the next non-skippable focusable of the current focus.
// Returns the first non-skippable focusable if focus is not set.
pub fn (layout &Layout) next_focusable(mut w Window) ?Shape {
	ids := layout.get_focus_ids()
	return layout.find_next_focusable(ids, mut w)
}

// find_next_focusable finds the next focusable that is not disabled.
// If none are found it tries to find the first focusable that
// is not disabled.
fn (layout &Layout) find_next_focusable(ids []u32, mut w Window) ?Shape {
	// ids are sorted either ascending or descending.
	if w.view_state.id_focus > 0 {
		mut found := false
		for id in ids {
			if id == w.view_state.id_focus {
				found = true
				continue
			}
			if !found {
				continue
			}
			shape := layout.find_shape(fn [id] (n Layout) bool {
				return n.shape.id_focus == id && !n.shape.disabled
			}) or { continue }
			return shape
		}
	}
	// did not find anything. Try to return the first non disabled.
	mut first := ?Shape(none)
	for id in ids {
		first = layout.find_shape(fn [id] (n Layout) bool {
			return n.shape.id_focus == id && !n.shape.disabled
		}) or { continue }
		break
	}
	return first
}

// get_focus_ids returns an ordered list of focus ids
fn (layout &Layout) get_focus_ids() []u32 {
	mut focus_ids := []u32{}
	unsafe { focus_ids.flags.set(.noslices) }
	if layout.shape.id_focus > 0 && !layout.shape.focus_skip {
		focus_ids << layout.shape.id_focus
	}
	for child in layout.children {
		focus_ids << child.get_focus_ids()
	}
	return arrays.distinct(focus_ids).sorted()
}

// spacing does the fence-post calculation for spacings
fn (layout &Layout) spacing() f32 {
	count := layout.children.count(!it.shape.float && it.shape.type != .none && !it.shape.over_draw)
	return int_max(0, (count - 1)) * layout.shape.spacing
}

fn content_width(layout &Layout) f32 {
	mut width := f32(0)
	if layout.shape.axis == .left_to_right {
		// along the axis add up all children heights plus spacing
		width += layout.spacing()
		for child in layout.children {
			if child.shape.over_draw {
				continue
			}
			width += child.shape.width
		}
	} else {
		// across the axis need only the height of largest child
		for child in layout.children {
			if child.shape.over_draw {
				continue
			}
			width = f32_max(width, child.shape.width)
		}
	}
	return width
}

fn content_height(layout &Layout) f32 {
	mut height := f32(0)
	if layout.shape.axis == .top_to_bottom {
		// along the axis add up all children heights plus spacing
		height += layout.spacing()
		for child in layout.children {
			if child.shape.over_draw {
				continue
			}
			height += child.shape.height
		}
	} else {
		// across the axis need only the height of largest child
		for child in layout.children {
			if child.shape.over_draw {
				continue
			}
			height = f32_max(height, child.shape.height)
		}
	}
	return height
}

// rect_intersection returns the intersection of two rectangles as an Option<Rect>.
// If there is no intersection, returns none.
fn rect_intersection(a DrawClip, b DrawClip) ?DrawClip {
	x1 := f32_max(a.x, b.x)
	y1 := f32_max(a.y, b.y)
	x2 := f32_min(a.x + a.width, b.x + b.width)
	y2 := f32_min(a.y + a.height, b.y + b.height)

	if x2 > x1 && y2 > y1 {
		return DrawClip{
			x:      x1
			y:      y1
			width:  x2 - x1
			height: y2 - y1
		}
	}
	return none
}

// point_in_rectangle returns true if point is within bounds of rectangle
pub fn point_in_rectangle(x f32, y f32, rect DrawClip) bool {
	return x >= rect.x && y >= rect.y && x < (rect.x + rect.width) && y < (rect.y + rect.height)
}

// clear_layouts recursively clears parent and shape references in a layout tree.
// This breaks reference cycles and clears heap data so the garbage collector
// can properly free the old layout tree.
fn clear_layouts(mut layout Layout) {
	for mut child in layout.children {
		clear_layouts(mut child)
	}
	unsafe {
		layout.parent = nil
		layout.children.reset()
		if layout.shape != nil {
			layout.shape.clear()
			layout.shape = nil
		}
	}
	layout.children.clear()
}
