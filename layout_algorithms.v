module gui

import arrays

// layout_widths arranges children horizontally. Only containers with an axis
// are processed.
fn layout_widths(mut layout Layout) {
	padding := layout.shape.padding.width()
	if layout.shape.axis == .left_to_right { // along the axis
		spacing := layout.spacing()
		if layout.shape.sizing.width == .fixed {
			for mut child in layout.children {
				layout_widths(mut child)
			}
		} else {
			mut min_widths := padding + spacing
			for mut child in layout.children {
				layout_widths(mut child)
				layout.shape.width += child.shape.width
				min_widths += child.shape.min_width
			}

			layout.shape.min_width = f32_max(min_widths, layout.shape.min_width + padding + spacing)
			layout.shape.width += padding + spacing

			if layout.shape.max_width > 0 {
				layout.shape.max_width = layout.shape.max_width
				layout.shape.width = f32_min(layout.shape.max_width, layout.shape.width)
				layout.shape.min_width = f32_min(layout.shape.max_width, layout.shape.min_width)
			}
			if layout.shape.min_width > 0 {
				layout.shape.width = f32_max(layout.shape.min_width, layout.shape.width)
			}
		}
	} else if layout.shape.axis == .top_to_bottom { // across the axis
		for mut child in layout.children {
			layout_widths(mut child)
			if layout.shape.sizing.width != .fixed {
				layout.shape.width = f32_max(layout.shape.width, child.shape.width + padding)
				layout.shape.min_width = f32_max(layout.shape.min_width, child.shape.min_width +
					padding)
			}
		}
		if layout.shape.min_width > 0 {
			layout.shape.width = f32_max(layout.shape.width, layout.shape.min_width)
		}
		if layout.shape.max_width > 0 {
			layout.shape.width = f32_min(layout.shape.width, layout.shape.max_width)
		}
	}
}

// layout_heights arranges children vertically. Only containers with an axis
// are processed.
fn layout_heights(mut layout Layout) {
	padding := layout.shape.padding.height()
	if layout.shape.axis == .top_to_bottom { // along the axis
		spacing := layout.spacing()
		if layout.shape.sizing.height == .fixed {
			for mut child in layout.children {
				layout_heights(mut child)
			}
		} else {
			mut min_heights := padding + spacing
			for mut child in layout.children {
				layout_heights(mut child)
				layout.shape.height += child.shape.height
				min_heights += child.shape.min_height
			}

			layout.shape.min_height = f32_max(min_heights, layout.shape.min_height + padding +
				spacing)
			layout.shape.height += padding + spacing

			if layout.shape.max_height > 0 {
				layout.shape.max_height = layout.shape.max_height
				layout.shape.height = f32_min(layout.shape.max_height, layout.shape.height)
				layout.shape.min_height = f32_min(layout.shape.max_height, layout.shape.min_height)
			}
			if layout.shape.min_height > 0 {
				layout.shape.height = f32_max(layout.shape.min_height, layout.shape.height)
			}
			if layout.shape.sizing.height == .fill && layout.shape.id_scroll > 0 {
				layout.shape.min_height = spacing_small
			}
		}
	} else if layout.shape.axis == .left_to_right { // across the axis
		for mut child in layout.children {
			layout_heights(mut child)
			if layout.shape.sizing.height != .fixed {
				layout.shape.height = f32_max(layout.shape.height, child.shape.height + padding)
				layout.shape.min_height = f32_max(layout.shape.min_height, child.shape.min_height +
					padding)
			}
		}
		if layout.shape.min_height > 0 {
			layout.shape.height = f32_max(layout.shape.height, layout.shape.min_height)
		}
		if layout.shape.max_height > 0 {
			layout.shape.height = f32_min(layout.shape.height, layout.shape.max_height)
		}
	}
}

// layout_fill_widths manages horizontal growth/shrinkage to satisfy constraints.
//
// Algorithm invariants:
// - Children with sizing.width == .fill participate in space distribution
// - Growth: smallest children grow first until they match the next-smallest
// - Shrink: largest children shrink first until they match the next-largest
// - Termination guarantee: each iteration either reduces |remaining_width| by
//   at least f32_tolerance OR removes at least one candidate from the list
// - The previous_remaining check guards against infinite loops when rounding
//   prevents progress
fn layout_fill_widths(mut layout Layout) {
	mut previous_remaining_width := f32(0)
	mut remaining_width := layout.shape.width - layout.shape.padding.width()

	if layout.shape.axis == .left_to_right {
		for mut child in layout.children {
			remaining_width -= child.shape.width
		}
		// fence post spacing
		remaining_width -= layout.spacing()

		// divide up the remaining fill widths by first growing all the
		// all the fill layouts to the same size (if possible) and then
		// distributing the remaining width to evenly.
		//
		if remaining_width > f32_tolerance {
			mut candidates := []int{cap: layout.children.len}
			for i, child in layout.children {
				if child.shape.sizing.width == .fill {
					candidates << i
				}
			}

			// Invariant: remaining_width decreases or candidates shrinks each iteration
			for remaining_width > f32_tolerance && candidates.len > 0 {
				if f32_are_close(remaining_width, previous_remaining_width) {
					break
				}
				previous_remaining_width = remaining_width

				mut smallest := layout.children[candidates[0]].shape.width
				mut second_smallest := f32(max_u32)

				for idx in candidates {
					child_width := layout.children[idx].shape.width
					if child_width < smallest {
						second_smallest = smallest
						smallest = child_width
					} else if child_width > smallest {
						second_smallest = f32_min(second_smallest, child_width)
					}
				}

				mut width_to_add := f32(0)
				if second_smallest == max_u32 {
					width_to_add = remaining_width
				} else {
					width_to_add = second_smallest - smallest
				}

				width_to_add = f32_min(width_to_add, remaining_width / candidates.len)

				mut keep_idx := 0
				for i in 0 .. candidates.len {
					idx := candidates[i]
					mut child := &layout.children[idx]
					mut kept := true
					if child.shape.width == smallest {
						previous_width := child.shape.width
						child.shape.width += width_to_add

						mut constrained := false
						if child.shape.width <= child.shape.min_width {
							child.shape.width = child.shape.min_width
							constrained = true
						} else if child.shape.max_width > 0
							&& child.shape.width >= child.shape.max_width {
							child.shape.width = child.shape.max_width
							constrained = true
						}
						remaining_width -= (child.shape.width - previous_width)

						if constrained {
							kept = false
						}
					}
					if kept {
						if keep_idx != i {
							candidates[keep_idx] = idx
						}
						keep_idx++
					}
				}
				candidates.trim(keep_idx)
			}
		}

		// Shrink if needed using similar algorithm
		if remaining_width < -f32_tolerance {
			mut candidates := []int{cap: layout.children.len}
			mut fixed_indices := []int{cap: layout.children.len}

			for i, child in layout.children {
				if child.shape.sizing.width == .fill {
					candidates << i
				} else {
					fixed_indices << i
				}
			}

			previous_remaining_width = 0
			for remaining_width < -f32_tolerance && candidates.len > 0 {
				if f32_are_close(remaining_width, previous_remaining_width) {
					break
				}
				previous_remaining_width = remaining_width

				mut largest := f32(0)
				mut second_largest := f32(0)

				for idx in candidates {
					child_width := layout.children[idx].shape.width
					if child_width > largest {
						second_largest = largest
						largest = child_width
					} else if child_width < largest {
						second_largest = f32_max(second_largest, child_width)
					}
				}
				for idx in fixed_indices {
					child_width := layout.children[idx].shape.width
					if child_width > largest {
						second_largest = largest
						largest = child_width
					} else if child_width < largest {
						second_largest = f32_max(second_largest, child_width)
					}
				}

				mut width_to_add := f32(0)
				if largest > 0 {
					if second_largest == 0 {
						width_to_add = remaining_width
					} else {
						width_to_add = second_largest - largest
					}
				} else {
					width_to_add = remaining_width
				}

				total_len := candidates.len + fixed_indices.len
				if total_len > 0 {
					width_to_add = f32_max(width_to_add, remaining_width / f32(total_len))
				}

				mut keep_idx := 0
				for i in 0 .. candidates.len {
					idx := candidates[i]
					mut child := &layout.children[idx]
					mut kept := true
					if child.shape.width == largest {
						previous_width := child.shape.width
						child.shape.width += width_to_add
						mut constrained := false
						if child.shape.width <= child.shape.min_width {
							child.shape.width = child.shape.min_width
							constrained = true
						} else if child.shape.max_width > 0
							&& child.shape.width >= child.shape.max_width {
							child.shape.width = child.shape.max_width
							constrained = true
						}
						remaining_width -= (child.shape.width - previous_width)
						if constrained {
							kept = false
						}
					}
					if kept {
						if keep_idx != i {
							candidates[keep_idx] = idx
						}
						keep_idx++
					}
				}
				candidates.trim(keep_idx)
			}
		}
	} else if layout.shape.axis == .top_to_bottom {
		if layout.shape.id_scroll > 0 && layout.shape.sizing.width == .fill
			&& layout.shape.scroll_mode != .vertical_only
			&& layout.parent.shape.axis == .left_to_right {
			mut sibling_width_sum := f32(0)
			for sibling in layout.parent.children {
				if sibling.shape.uid != layout.shape.uid {
					sibling_width_sum += sibling.shape.width
				}
			}
			layout.shape.width = layout.parent.shape.width - sibling_width_sum
			layout.shape.width -= layout.parent.spacing()
			layout.shape.width -= layout.parent.shape.padding.width()
			layout.shape.width += 1 // round-off?
		}
		if layout.shape.max_width > 0 && layout.shape.width > layout.shape.max_width {
			layout.shape.width = layout.shape.max_width
		}
		for mut child in layout.children {
			if child.shape.sizing.width == .fill {
				child.shape.width = remaining_width
				if child.shape.min_width > 0 {
					child.shape.width = f32_max(child.shape.width, child.shape.min_width)
				}
				if child.shape.max_width > 0 {
					child.shape.width = f32_min(child.shape.width, child.shape.max_width)
				}
			}
		}
	}

	for mut child in layout.children {
		layout_fill_widths(mut child)
	}
}

// layout_fill_heights manages vertical growth/shrinkage to satisfy constraints.\n// See layout_fill_widths for algorithm invariants (same logic, vertical axis).
fn layout_fill_heights(mut layout Layout) {
	mut previous_remaining_height := f32(0)
	mut remaining_height := layout.shape.height - layout.shape.padding.height()

	if layout.shape.axis == .top_to_bottom {
		for mut child in layout.children {
			remaining_height -= child.shape.height
		}
		// fence post spacing
		remaining_height -= layout.spacing()

		// divide up the remaining fill heights by first growing all the
		// all the fill layouts to the same size (if possible) and then
		// distributing the remaining height to evenly.
		//
		if remaining_height > f32_tolerance {
			mut candidates := []int{cap: layout.children.len}
			for i, child in layout.children {
				if child.shape.sizing.height == .fill {
					candidates << i
				}
			}

			for remaining_height > f32_tolerance && candidates.len > 0 {
				if f32_are_close(remaining_height, previous_remaining_height) {
					break
				}
				previous_remaining_height = remaining_height

				mut smallest := layout.children[candidates[0]].shape.height
				mut second_smallest := f32(max_u32)

				for idx in candidates {
					child_height := layout.children[idx].shape.height
					if child_height < smallest {
						second_smallest = smallest
						smallest = child_height
					} else if child_height > smallest {
						second_smallest = f32_min(second_smallest, child_height)
					}
				}

				mut height_to_add := f32(0)
				if second_smallest == max_u32 {
					height_to_add = remaining_height
				} else {
					height_to_add = second_smallest - smallest
				}

				height_to_add = f32_min(height_to_add, remaining_height / candidates.len)

				mut keep_idx := 0
				for i in 0 .. candidates.len {
					idx := candidates[i]
					mut child := &layout.children[idx]
					mut kept := true
					if child.shape.height == smallest {
						previous_height := child.shape.height
						child.shape.height += height_to_add

						mut constrained := false
						if child.shape.height <= child.shape.min_height {
							child.shape.height = child.shape.min_height
							constrained = true
						} else if child.shape.max_height > 0
							&& child.shape.height >= child.shape.max_height {
							child.shape.height = child.shape.max_height
							constrained = true
						}
						remaining_height -= (child.shape.height - previous_height)

						if constrained {
							kept = false
						}
					}
					if kept {
						if keep_idx != i {
							candidates[keep_idx] = idx
						}
						keep_idx++
					}
				}
				candidates.trim(keep_idx)
			}
		}

		// Shrink if needed using similar algorithm
		if remaining_height < -f32_tolerance {
			mut candidates := []int{cap: layout.children.len}
			mut fixed_indices := []int{cap: layout.children.len}

			for i, child in layout.children {
				if child.shape.sizing.height == .fill {
					candidates << i
				} else {
					fixed_indices << i
				}
			}

			previous_remaining_height = 0
			for remaining_height < -f32_tolerance && candidates.len > 0 {
				if f32_are_close(remaining_height, previous_remaining_height) {
					break
				}
				previous_remaining_height = remaining_height

				mut largest := f32(0)
				mut second_largest := f32(0)

				for idx in candidates {
					child_height := layout.children[idx].shape.height
					if child_height > largest {
						second_largest = largest
						largest = child_height
					} else if child_height < largest {
						second_largest = f32_max(second_largest, child_height)
					}
				}
				for idx in fixed_indices {
					child_height := layout.children[idx].shape.height
					if child_height > largest {
						second_largest = largest
						largest = child_height
					} else if child_height < largest {
						second_largest = f32_max(second_largest, child_height)
					}
				}

				mut height_to_add := f32(0)
				if largest > 0 {
					if second_largest == 0 {
						height_to_add = remaining_height
					} else {
						height_to_add = second_largest - largest
					}
				} else {
					height_to_add = remaining_height
				}

				total_len := candidates.len + fixed_indices.len
				if total_len > 0 {
					height_to_add = f32_max(height_to_add, remaining_height / f32(total_len))
				}

				mut keep_idx := 0
				for i in 0 .. candidates.len {
					idx := candidates[i]
					mut child := &layout.children[idx]
					mut kept := true
					if child.shape.height == largest {
						previous_height := child.shape.height
						child.shape.height += height_to_add
						mut constrained := false
						if child.shape.height <= child.shape.min_height {
							child.shape.height = child.shape.min_height
							constrained = true
						} else if child.shape.max_height > 0
							&& child.shape.height >= child.shape.max_height {
							child.shape.height = child.shape.max_height
							constrained = true
						}
						remaining_height -= (child.shape.height - previous_height)
						if constrained {
							kept = false
						}
					}
					if kept {
						if keep_idx != i {
							candidates[keep_idx] = idx
						}
						keep_idx++
					}
				}
				candidates.trim(keep_idx)
			}
		}
	} else if layout.shape.axis == .left_to_right {
		if layout.shape.id_scroll > 0 && layout.shape.sizing.height == .fill
			&& layout.shape.scroll_mode != .horizontal_only
			&& layout.parent.shape.axis == .top_to_bottom {
			mut sibling_height_sum := f32(0)
			for sibling in layout.parent.children {
				if sibling.shape.uid != layout.shape.uid {
					sibling_height_sum += sibling.shape.height
				}
			}
			layout.shape.height = layout.parent.shape.height - sibling_height_sum
			layout.shape.height -= layout.parent.spacing()
			layout.shape.height -= layout.parent.shape.padding.height()
			layout.shape.height += 1 // round-off?
		}
		if layout.shape.max_height > 0 && layout.shape.height > layout.shape.max_height {
			layout.shape.height = layout.shape.max_height
		}
		for mut child in layout.children {
			if child.shape.sizing.height == .fill {
				child.shape.height = remaining_height
				if child.shape.min_height > 0 {
					child.shape.height = f32_max(child.shape.height, child.shape.min_height)
				}
				if child.shape.max_height > 0 {
					child.shape.height = f32_min(child.shape.height, child.shape.max_height)
				}
			}
		}
	}

	for mut child in layout.children {
		layout_fill_heights(mut child)
	}
}

// layout_wrap_text runs after widths are set. Wrapping changes min-height,
// so this runs before height calculation.
fn layout_wrap_text(mut layout Layout, mut w Window) {
	text_wrap(mut layout.shape, mut w)
	for mut child in layout.children {
		layout_wrap_text(mut child, mut w)
	}
}

// layout_adjust_scroll_offsets ensures scroll offsets are in range.
// Scroll offsets can go out of range during window resizing.
fn layout_adjust_scroll_offsets(mut layout Layout, mut w Window) {
	id_scroll := layout.shape.id_scroll
	if id_scroll > 0 {
		max_offset_x := f32_min(0, layout.shape.width - layout.shape.padding.width() - content_width(layout))
		offset_x := w.view_state.scroll_x[id_scroll]
		w.view_state.scroll_x[id_scroll] = f32_clamp(offset_x, max_offset_x, 0)

		max_offset_y := f32_min(0, layout.shape.height - layout.shape.padding.height() - content_height(layout))
		offset_y := w.view_state.scroll_y[id_scroll]
		w.view_state.scroll_y[id_scroll] = f32_clamp(offset_y, max_offset_y, 0)
	}
	for mut child in layout.children {
		layout_adjust_scroll_offsets(mut child, mut w)
	}
}

// layout_positions sets positions and handles alignment. Alignment only
// affects x/y positions, not sizes.
fn layout_positions(mut layout Layout, offset_x f32, offset_y f32, w &Window) {
	layout.shape.x += offset_x
	layout.shape.y += offset_y

	axis := layout.shape.axis
	padding := layout.shape.padding
	spacing := layout.shape.spacing

	if layout.shape.id_scroll > 0 {
		layout.shape.clip = true
	}

	mut x := layout.shape.x + padding.left
	mut y := layout.shape.y + padding.top

	if layout.shape.id_scroll > 0 {
		x += w.view_state.scroll_x[layout.shape.id_scroll]
		y += w.view_state.scroll_y[layout.shape.id_scroll]
	}

	// Eventually start/end will be culture dependent
	h_align := match layout.shape.h_align {
		.start { HorizontalAlign.left }
		.left { HorizontalAlign.left }
		.center { HorizontalAlign.center }
		.end { HorizontalAlign.right }
		.right { HorizontalAlign.right }
	}

	// alignment along the axis
	match axis {
		.left_to_right {
			if h_align != .left {
				mut remaining := layout.shape.width - padding.width()
				remaining -= layout.spacing()
				for child in layout.children {
					remaining -= child.shape.width
				}
				if h_align == .center {
					remaining /= 2
				}
				x += remaining
			}
		}
		.top_to_bottom {
			if layout.shape.v_align != .top {
				mut remaining := layout.shape.height - padding.height()
				remaining -= layout.spacing()
				for child in layout.children {
					remaining -= child.shape.height
				}
				if layout.shape.v_align == .middle {
					remaining /= 2
				}
				y += remaining
			}
		}
		.none {}
	}

	for mut child in layout.children {
		// alignment across the axis
		mut x_align := f32(0)
		mut y_align := f32(0)
		match axis {
			.left_to_right {
				remaining := layout.shape.height - child.shape.height - padding.height()
				if remaining > 0 {
					match layout.shape.v_align {
						.top {}
						.middle { y_align = remaining / 2 }
						else { y_align = remaining }
					}
				}
			}
			.top_to_bottom {
				remaining := layout.shape.width - child.shape.width - padding.width()
				if remaining > 0 {
					match h_align {
						.left {}
						.center { x_align = remaining / 2 }
						else { x_align = remaining }
					}
				}
			}
			.none {}
		}

		layout_positions(mut child, x + x_align, y + y_align, w)

		if child.shape.shape_type != .none {
			match axis {
				.left_to_right { x += child.shape.width + spacing }
				.top_to_bottom { y += child.shape.height + spacing }
				.none {}
			}
		}
	}
}

// layout_disables walks the Layout and disables any children
// that have a disabled ancestor.
fn layout_disables(mut layout Layout, disabled bool) {
	mut is_disabled := disabled || layout.shape.disabled
	layout.shape.disabled = is_disabled
	for mut child in layout.children {
		layout_disables(mut child, is_disabled)
	}
}

// layout_scroll_containers identifies which text views are in a
// scrollable container (row, column).
fn layout_scroll_containers(mut layout Layout, id_scroll_container u32) {
	for mut ly in layout.children {
		id := match ly.shape.id_scroll > 0 {
			true { ly.shape.id_scroll }
			else { id_scroll_container }
		}
		layout_scroll_containers(mut ly, id)
		// Motivation: `text` views are not directly scrollable but must live inside
		// a scrollable container. Selecting text can push selection outside the
		// visible region. Use `id_scroll_container` to track the parent.
		if ly.shape.shape_type == .text {
			ly.shape.id_scroll_container = id_scroll_container
		}
	}
}

// layout_set_shape_clips - shape_clips are used for hit testing.
fn layout_set_shape_clips(mut layout Layout, clip DrawClip) {
	shape_clip := DrawClip{
		x:      layout.shape.x
		y:      layout.shape.y
		width:  layout.shape.width
		height: layout.shape.height
	}

	layout.shape.shape_clip = rect_intersection(shape_clip, clip) or { DrawClip{} }

	for mut child in layout.children {
		layout_set_shape_clips(mut child, layout.shape.shape_clip)
	}
}

// layout_amend handles layout problems resolvable only after sizing/positioning,
// such as mouse-over events affecting appearance. Avoid altering sizes here.
fn layout_amend(mut layout Layout, mut w Window) {
	for mut child in layout.children {
		layout_amend(mut child, mut w)
	}
	if layout.shape.amend_layout != unsafe { nil } {
		layout.shape.amend_layout(mut layout, mut w)
	}
}

// layout_hover encapsulates hover handling logic.
fn layout_hover(mut layout Layout, mut w Window) bool {
	if w.mouse_is_locked() {
		return false
	}
	for mut child in layout.children {
		is_handled := layout_hover(mut child, mut w)
		if is_handled {
			return true
		}
	}
	if layout.shape.on_hover != unsafe { nil } {
		if layout.shape.disabled {
			return false
		}
		if w.dialog_cfg.visible && !layout_in_dialog_layout(layout) {
			return false
		}
		ctx := w.context()
		if layout.shape.point_in_shape(ctx.mouse_pos_x, ctx.mouse_pos_y) {
			// fake an event to get mouse button states.
			mouse_button := match true {
				ctx.mbtn_mask & 0x01 > 0 { MouseButton.left }
				ctx.mbtn_mask & 0x02 > 0 { MouseButton.right }
				ctx.mbtn_mask & 0x04 > 0 { MouseButton.middle }
				else { MouseButton.invalid }
			}
			mut ev := Event{
				frame_count:   ctx.frame
				typ:           .invalid
				modifiers:     unsafe { Modifier(ctx.key_modifiers) }
				mouse_button:  mouse_button
				mouse_x:       ctx.mouse_pos_x
				mouse_y:       ctx.mouse_pos_y
				mouse_dx:      ctx.mouse_dx
				mouse_dy:      ctx.mouse_dy
				scroll_x:      ctx.scroll_x
				scroll_y:      ctx.scroll_y
				window_width:  ctx.width
				window_height: ctx.height
			}
			layout.shape.on_hover(mut layout, mut ev, mut w)
			return ev.is_handled
		}
	}
	return false
}

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
	count := layout.children.count(!it.shape.float && it.shape.shape_type != .none
		&& !it.shape.over_draw)
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
