module gui

import arrays

// find_shape walks the ShapeGTree in reverse until predicate is satisfied.
// shape_uid limits the depth of the search into tree. Used in event bubbling. 0
// is not a valid shape_uid and is used to search the entire tree
fn (node Layout) find_shape(predicate fn (n Layout) bool) ?Shape {
	for child in node.children {
		if found := child.find_shape(predicate) {
			return found
		}
	}
	return if predicate(node) { node.shape } else { none }
}

fn (node Layout) previous_focusable(mut w Window) ?Shape {
	ids := node.get_focus_ids().reverse()
	return node.find_next_focusable(ids, mut w)
}

fn (node Layout) next_focusable(mut w Window) ?Shape {
	ids := node.get_focus_ids()
	return node.find_next_focusable(ids, mut w)
}

// next_focusable finds the next focusable that is not disabled.
// If none are found it tries to find the first focusable that
// is not disabled.
fn (node Layout) find_next_focusable(ids []u32, mut w Window) ?Shape {
	// ids are sorted either ascending or descending.
	if w.id_focus > 0 {
		mut found := false
		for id in ids {
			if id == w.id_focus {
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
fn (node Layout) get_focus_ids() []u32 {
	mut focus_ids := []u32{}
	if node.shape.id_focus > 0 {
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

// f32_are_equal tests if a and b are with tol
fn f32_are_equal(a f32, b f32, diff f32) bool {
	assert diff > 0
	d := a - b
	return if d < 0 { -d <= diff } else { d <= diff }
}
