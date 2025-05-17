module gui

import arrays

// find_shape walks the layout in depth first until predicate is satisfied.
pub fn (node &Layout) find_shape(predicate fn (n Layout) bool) ?Shape {
	for child in node.children {
		if found := child.find_shape(predicate) {
			return found
		}
	}
	return if predicate(node) { node.shape } else { none }
}

// find_node walks the layout in dept first until predicate is satisfied.
pub fn (node &Layout) find_node(predicate fn (n Layout) bool) ?Layout {
	for child in node.children {
		if found := child.find_node(predicate) {
			return found
		}
	}
	return if predicate(node) { node } else { none }
}

// previous_focusable gets the previous non-skippable focusable of the current focus.
// Returns the first non-skippable focusable if focus is not set.
pub fn (node &Layout) previous_focusable(mut w Window) ?Shape {
	ids := node.get_focus_ids().reverse()
	return node.find_next_focusable(ids, mut w)
}

// next_focusable gets the next non-skippable focusable of the current focus.
// Returns the first non-skippable focusable if focus is not set.
pub fn (node &Layout) next_focusable(mut w Window) ?Shape {
	ids := node.get_focus_ids()
	return node.find_next_focusable(ids, mut w)
}

// next_focusable finds the next focusable that is not disabled.
// If none are found it tries to find the first focusable that
// is not disabled.
fn (node &Layout) find_next_focusable(ids []u32, mut w Window) ?Shape {
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
			shape := node.find_shape(fn [id] (n Layout) bool {
				return n.shape.id_focus == id && !n.shape.disabled
			}) or { continue }
			return shape
		}
	}
	// did not find anything. Try to return the first non disabled.
	mut first := ?Shape(none)
	for id in ids {
		first = node.find_shape(fn [id] (n Layout) bool {
			return n.shape.id_focus == id && !n.shape.disabled
		}) or { continue }
		break
	}
	return first
}

// get_focus_ids returns an ordered list of focus ids
fn (node &Layout) get_focus_ids() []u32 {
	mut focus_ids := []u32{}
	if node.shape.id_focus > 0 && !node.shape.focus_skip {
		focus_ids << node.shape.id_focus
	}
	for child in node.children {
		focus_ids << child.get_focus_ids()
	}
	return arrays.distinct(focus_ids).sorted()
}

// spacing does the fence-post calculation for spacings
fn (node &Layout) spacing() f32 {
	count := node.children.count(!(it.shape.float || it.shape.type == .none))
	return int_max(0, (count - 1)) * node.shape.spacing
}

// f32 values equal if within tolerance
const tolerance = f32(0.01)

// f32_are_close tests if the differnce of a and b is less than tol
@[inline]
fn f32_are_close(a f32, b f32) bool {
	d := if a >= b { a - b } else { b - a }
	return d <= tolerance
}

// clamp_f32 returns x between  a and b
@[inline]
fn clamp_f32(x f32, a f32, b f32) f32 {
	if x < a {
		return a
	}
	if x > b {
		return b
	}
	return x
}

fn content_width(node &Layout) f32 {
	mut width := f32(0)
	if node.shape.axis == .left_to_right {
		// along the axis add up all children heights plus spacing
		width += node.spacing()
		for child in node.children {
			width += child.shape.width
		}
	} else {
		// across the axis need only the height of largest child
		for child in node.children {
			width = f32_max(width, child.shape.width)
		}
	}
	return width
}

fn content_height(node &Layout) f32 {
	mut height := f32(0)
	if node.shape.axis == .top_to_bottom {
		// along the axis add up all children heights plus spacing
		height += node.spacing()
		for child in node.children {
			height += child.shape.height
		}
	} else {
		// across the axis need only the height of largest child
		for child in node.children {
			height = f32_max(height, child.shape.height)
		}
	}
	return height
}
