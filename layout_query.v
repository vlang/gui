module gui

// find_shape walks the layout in depth first until predicate is satisfied.
pub fn (layout &Layout) find_shape(predicate fn (n Layout) bool) ?Shape {
	for child in layout.children {
		if found := child.find_shape(predicate) {
			return found
		}
	}
	return if predicate(layout) { layout.shape } else { none }
}

// find_layout walks the layout in depth first until predicate is satisfied.
pub fn (layout &Layout) find_layout(predicate fn (n Layout) bool) ?Layout {
	for child in layout.children {
		if found := child.find_layout(predicate) {
			return found
		}
	}
	return if predicate(layout) { layout } else { none }
}

// find_layout_by_id_focus recursively searches for a layout with a matching `id_focus`
// within the given layout and its children. It returns the found Layout if a match is made,
// otherwise it returns `none`.
pub fn find_layout_by_id_focus(layout &Layout, id_focus u32) ?Layout {
	if layout.shape.id_focus == id_focus {
		return *layout
	}
	for child in layout.children {
		if ly := find_layout_by_id_focus(child, id_focus) {
			return ly
		}
	}
	return none
}

// find_layout_by_id_scroll recursively searches for a layout with a matching `id_scroll`
// within the given layout and its children. It returns the found Layout if a match is made,
// otherwise it returns `none`.
pub fn find_layout_by_id_scroll(layout &Layout, id_scroll u32) ?Layout {
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

// previous_focusable gets the previous non-skippable focusable of the current focus.
// Returns the first non-skippable focusable if focus is not set.
pub fn (layout &Layout) previous_focusable(mut w Window) ?Shape {
	mut candidates := w.scratch.take_focus_candidates()
	collect_focus_candidates(layout, mut candidates, 0)
	if candidates.len == 0 {
		w.scratch.put_focus_candidates(mut candidates)
		return none
	}
	focus_sort_and_dedupe(mut candidates)
	result := focus_find_previous(candidates, w.view_state.id_focus)
	w.scratch.put_focus_candidates(mut candidates)
	return result
}

// next_focusable gets the next non-skippable focusable of the current focus.
// Returns the first non-skippable focusable if focus is not set.
pub fn (layout &Layout) next_focusable(mut w Window) ?Shape {
	mut candidates := w.scratch.take_focus_candidates()
	collect_focus_candidates(layout, mut candidates, 0)
	if candidates.len == 0 {
		w.scratch.put_focus_candidates(mut candidates)
		return none
	}
	focus_sort_and_dedupe(mut candidates)
	result := focus_find_next(candidates, w.view_state.id_focus)
	w.scratch.put_focus_candidates(mut candidates)
	return result
}

struct FocusCandidate {
	id    u32
	order int
	shape &Shape = unsafe { nil }
}

fn collect_focus_candidates(layout &Layout, mut candidates []FocusCandidate, order int) int {
	mut next_order := order
	if layout.shape.id_focus > 0 && !layout.shape.focus_skip {
		if !layout.shape.disabled {
			candidates << FocusCandidate{
				id:    layout.shape.id_focus
				order: next_order
				shape: layout.shape
			}
		}
		next_order++
	}
	for child in layout.children {
		next_order = collect_focus_candidates(child, mut candidates, next_order)
	}
	return next_order
}

fn focus_sort_and_dedupe(mut candidates []FocusCandidate) {
	candidates.sort_with_compare(fn (a &FocusCandidate, b &FocusCandidate) int {
		if a.id < b.id {
			return -1
		}
		if a.id > b.id {
			return 1
		}
		if a.order < b.order {
			return -1
		}
		if a.order > b.order {
			return 1
		}
		return 0
	})
	mut keep_idx := 0
	mut last_id := u32(0)
	for i, candidate in candidates {
		if i > 0 && candidate.id == last_id {
			continue
		}
		if keep_idx != i {
			candidates[keep_idx] = candidate
		}
		keep_idx++
		last_id = candidate.id
	}
	candidates.trim(keep_idx)
}

fn focus_find_next(candidates []FocusCandidate, id_focus u32) ?Shape {
	if id_focus > 0 {
		for candidate in candidates {
			if candidate.id > id_focus {
				return *candidate.shape
			}
		}
	}
	return *candidates[0].shape
}

fn focus_find_previous(candidates []FocusCandidate, id_focus u32) ?Shape {
	if id_focus > 0 {
		for i := candidates.len - 1; i >= 0; i-- {
			candidate := candidates[i]
			if candidate.id < id_focus {
				return *candidate.shape
			}
		}
	}
	return *candidates[candidates.len - 1].shape
}

// spacing does the fence-post calculation for spacings
fn (layout &Layout) spacing() f32 {
	mut count := 0
	for child in layout.children {
		if child.shape.float || child.shape.shape_type == .none || child.shape.over_draw {
			continue
		}
		count++
	}
	return int_max(0, (count - 1)) * layout.shape.spacing
}

fn content_width(layout &Layout) f32 {
	mut width := f32(0)
	if layout.shape.axis == .left_to_right {
		// along the axis add up all children widths plus spacing
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

// find_by_id searches the layout tree for a layout with the given ID.
pub fn (layout &Layout) find_by_id(id string) ?Layout {
	if layout.shape.id == id {
		return *layout
	}
	for i in 0 .. layout.children.len {
		if res := layout.children[i].find_by_id(id) {
			return res
		}
	}
	return none
}
