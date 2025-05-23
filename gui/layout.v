module gui

// Based on Nic Barter's video of how Clay's UI algorithm works.
// https://www.youtube.com/watch?v=by9lQvpvMIc&t=1272s
//
// There's a fair bit of code duplication here. This is intentional.
// I found it much easier to write and debug without generalizing
// up/down vs. left/right. Abstractions here only complicate an
// already hard-to-reason-about problem. -imho

// Layout defines a tree of Layouts. Views generate Layouts
@[heap]
pub struct Layout {
pub mut:
	shape    Shape
	parent   &Layout = unsafe { nil }
	children []Layout
}

// layout_arrange executes a pipeline of functions to arrange and position the layout.
// Multiple layouts are returned, each is used to draw a layer of the final renderering.
fn layout_arrange(mut layout Layout, mut window Window) []Layout {
	mut layouts := [layout]
	// Set the parents of all the nodes. This is used to
	// compute relative floating layout coordinates
	layout_parents(mut layout, unsafe { nil })

	// floating layouts do not affect their parent or sibling elements
	// They also complicate the fuck out of things.
	mut floating_layouts := []Layout{}
	layout_remove_floating_layouts(mut layout, mut floating_layouts)
	fix_float_parents(mut floating_layouts)

	// Dialog is a pop-up dialog.
	// Add last to ensure it is always on top.
	// Dialogs do not support additional floating layouts.
	if window.dialog_cfg.visible {
		dialog_view := dialog_view_generator(window.dialog_cfg)
		mut dialog_layout := generate_layout(dialog_view, mut window)
		layout_parents(mut dialog_layout, layout)
		floating_layouts << dialog_layout
	}

	// Compute the layout without the floating elements.
	layout_pipeline(mut layout, mut window)

	// Compute the floating layouts. Because they are appended to
	// the layout array, they get rendered after the main layout.
	for mut floating_layout in floating_layouts {
		layout_pipeline(mut floating_layout, mut window)
		layouts << floating_layout
	}
	return layouts
}

// layout_pipeline makes multple passes over the layout.
// Multple passes actually simply many of the layout
// calculationsv by only dealing with one axis of
// expansion/contraction at a time. Same for scroll offsets
// and text wrapping. This logic mimics the logic presented
// in Nic Barter's video referenced above.
fn layout_pipeline(mut layout Layout, mut window Window) {
	layout_widths(mut layout)
	layout_fill_widths(mut layout)
	layout_wrap_text(mut layout, mut window)
	layout_heights(mut layout)
	layout_fill_heights(mut layout)
	layout_adjust_scroll_offsets(mut layout, mut window)
	x, y := float_attach_layout(layout)
	layout_positions(mut layout, x, y, window)
	layout_disables(mut layout, false)
	layout_set_draw_clips(mut layout, window.window_rect())
	layout_amend(mut layout, mut window)
}

// layout_parents sets the parent property of layout
fn layout_parents(mut layout Layout, parent &Layout) {
	// Reference is to the same tree so it should be safe
	layout.parent = unsafe { parent }
	for mut child in layout.children {
		layout_parents(mut child, layout)
	}
}

// layout_remove_floating_layouts removes the layouts marked as floating
// and puts an empty Layout node with no axis in its place. The empty
// layout has no axis, height or width so it is effectively ignored by
// the layout logic.
fn layout_remove_floating_layouts(mut layout Layout, mut layouts []Layout) {
	for i, mut child in layout.children {
		if child.shape.float {
			layouts << child
		}

		layout_remove_floating_layouts(mut child, mut layouts)

		if child.shape.float {
			// shape.type == .none does two things.
			// - allows fix_nested_sibling_floats() to indentify this as an empty node.
			// - removes it from the fence-post spacing calculation in layout.spacing()
			layout.children[i] = Layout{
				shape: Shape{}
			}
		}
	}
}

// layout_widths arranges a node's children layout horizontally. Only container
// layout with an axis are arranged.
fn layout_widths(mut node Layout) {
	padding := node.shape.padding.width()
	if node.shape.axis == .left_to_right { // along the axis
		spacing := node.spacing()
		if node.shape.sizing.width == .fixed {
			for mut child in node.children {
				layout_widths(mut child)
			}
		} else {
			mut min_widths := padding + spacing
			for mut child in node.children {
				layout_widths(mut child)
				node.shape.width += child.shape.width
				min_widths += child.shape.min_width
			}

			node.shape.min_width = f32_max(min_widths, node.shape.min_width + padding + spacing)
			node.shape.width += padding + spacing

			if node.shape.max_width > 0 {
				node.shape.max_width = node.shape.max_width
				node.shape.width = f32_min(node.shape.max_width, node.shape.width)
				node.shape.min_width = f32_min(node.shape.max_width, node.shape.min_width)
			}
			if node.shape.min_width > 0 {
				node.shape.width = f32_max(node.shape.min_width, node.shape.width)
			}
		}
	} else if node.shape.axis == .top_to_bottom { // across the axis
		for mut child in node.children {
			layout_widths(mut child)
			if node.shape.sizing.width != .fixed {
				node.shape.width = f32_max(node.shape.width, child.shape.width + padding)
				node.shape.min_width = f32_max(node.shape.min_width, child.shape.min_width + padding)
			}
		}
		node.shape.width = f32_max(node.shape.width, node.shape.min_width)
		if node.shape.max_width > 0 {
			node.shape.width = f32_min(node.shape.max_width, node.shape.width)
			node.shape.min_width = f32_min(node.shape.max_width, node.shape.min_width)
		}
	}
}

// layout_heights arranges a node's children layout vertically. Only container
// layout with an axis are arranged.
fn layout_heights(mut node Layout) {
	padding := node.shape.padding.height()
	if node.shape.axis == .top_to_bottom { // along the axis
		spacing := node.spacing()
		if node.shape.sizing.height == .fixed {
			for mut child in node.children {
				layout_heights(mut child)
			}
		} else {
			mut min_heights := padding + spacing
			for mut child in node.children {
				layout_heights(mut child)
				node.shape.height += child.shape.height
				min_heights += child.shape.min_height
			}

			node.shape.min_height = f32_max(min_heights, node.shape.min_height + padding + spacing)
			node.shape.height += padding + spacing

			if node.shape.max_height > 0 {
				node.shape.max_height = node.shape.max_height
				node.shape.height = f32_min(node.shape.max_height, node.shape.height)
				node.shape.min_height = f32_min(node.shape.max_height, node.shape.min_height)
			}
			if node.shape.min_height > 0 {
				node.shape.height = f32_max(node.shape.min_height, node.shape.height)
			}
			if node.shape.sizing.height == .fill && node.shape.id_scroll > 0 {
				node.shape.min_height = spacing_small
			}
		}
	} else if node.shape.axis == .left_to_right { // across the axis
		for mut child in node.children {
			layout_heights(mut child)
			if node.shape.sizing.height != .fixed {
				node.shape.height = f32_max(node.shape.height, child.shape.height + padding)
				node.shape.min_height = f32_max(node.shape.min_height, child.shape.min_height +
					padding)
			}
		}
		node.shape.height = f32_max(node.shape.height, node.shape.min_height)
		if node.shape.max_height > 0 {
			node.shape.height = f32_min(node.shape.max_height, node.shape.height)
			node.shape.min_height = f32_min(node.shape.max_height, node.shape.min_height)
		}
	}
}

// find_first_idx_and_len gets the index of the first element to satisfy the
// predicate and the length of all elements that satisfy the predicate. Iterates
// the array once with no allocations.
fn find_first_idx_and_len(node &Layout, predicate fn (n Layout) bool) (int, int) {
	mut idx := 0
	mut len := 0
	mut set_idx := false
	for i, child in node.children {
		if predicate(child) {
			len += 1
			if !set_idx {
				idx = i
				set_idx = true
			}
		}
	}
	return idx, len
}

// layout_fill_widths manages the growing and shrinking of layout horizontally
// to satisfy a layout constraint
fn layout_fill_widths(mut node Layout) {
	mut previous_remaining_width := f32(0)
	mut remaining_width := node.shape.width - node.shape.padding.width()

	if node.shape.axis == .left_to_right {
		for mut child in node.children {
			remaining_width -= child.shape.width
		}
		// fence post spacing
		remaining_width -= node.spacing()

		// divide up the remaining fill widths by first growing all the
		// all the fill layouts to the same size (if possible) and then
		// distributing the remaining width to evenly.
		//
		mut excluded := []u64{cap: node.children.len}
		for remaining_width > tolerance {
			if f32_are_close(remaining_width, previous_remaining_width) {
				break
			}
			previous_remaining_width = remaining_width
			// Grow child elements
			idx, len := find_first_idx_and_len(node, fn [excluded] (n Layout) bool {
				return n.shape.sizing.width == .fill && n.shape.uid !in excluded
			})
			if len == 0 {
				break
			}

			mut smallest := node.children[idx].shape.width
			mut second_smallest := f32(max_u32)
			mut width_to_add := remaining_width

			for child in node.children {
				if child.shape.sizing.width == .fill && child.shape.uid !in excluded {
					if child.shape.width < smallest {
						second_smallest = smallest
						smallest = child.shape.width
					}
					if child.shape.width > smallest {
						second_smallest = f32_min(second_smallest, child.shape.width)
						width_to_add = second_smallest - smallest
					}
				}
			}

			width_to_add = f32_min(width_to_add, remaining_width / len)

			for mut child in node.children {
				if child.shape.sizing.width == .fill && child.shape.uid !in excluded {
					if child.shape.width == smallest {
						previous_width := child.shape.width
						child.shape.width += width_to_add
						if child.shape.width <= child.shape.min_width {
							child.shape.width = child.shape.min_width
							excluded << child.shape.uid
						} else if child.shape.max_width > 0
							&& child.shape.width >= child.shape.max_width {
							child.shape.width = child.shape.max_width
							excluded << child.shape.uid
						}
						remaining_width -= (child.shape.width - previous_width)
					}
				}
			}
		}

		// Shrink if needed using similar algorithm
		excluded.clear()
		previous_remaining_width = 0
		for remaining_width < -tolerance {
			if f32_are_close(remaining_width, previous_remaining_width) {
				break
			}
			previous_remaining_width = remaining_width
			idx, len := find_first_idx_and_len(node, fn [excluded] (n Layout) bool {
				return n.shape.uid !in excluded
			})
			if len == 0 {
				break
			}

			mut largest := node.children[idx].shape.width
			mut second_largest := f32(0)
			mut width_to_add := remaining_width

			for child in node.children {
				if child.shape.uid !in excluded {
					if child.shape.width > largest {
						second_largest = largest
						largest = child.shape.width
					}
					if child.shape.width < largest {
						second_largest = f32_max(second_largest, child.shape.width)
						width_to_add = second_largest - largest
					}
				}
			}

			width_to_add = f32_max(width_to_add, remaining_width / len)

			for mut child in node.children {
				if child.shape.sizing.width == .fill && child.shape.uid !in excluded {
					if child.shape.width == largest {
						previous_width := child.shape.width
						child.shape.width += width_to_add
						if child.shape.width <= child.shape.min_width {
							child.shape.width = child.shape.min_width
							excluded << child.shape.uid
						} else if child.shape.max_width > 0
							&& child.shape.width >= child.shape.max_width {
							child.shape.width = child.shape.max_width
							excluded << child.shape.uid
						}
						remaining_width -= (child.shape.width - previous_width)
					}
				}
			}
		}
	} else if node.shape.axis == .top_to_bottom {
		if node.shape.max_width > 0 && node.shape.width > node.shape.max_width {
			node.shape.width = node.shape.max_width
		}
		for mut child in node.children {
			if child.shape.sizing.width == .fill {
				child.shape.width += (remaining_width - f32_max(child.shape.width, child.shape.min_width))
				child.shape.width = f32_max(child.shape.width, child.shape.min_width)
				child_padding := child.shape.padding.width()
				if child.shape.max_width > 0
					&& child.shape.width > (child.shape.max_width - child_padding) {
					child.shape.width = child.shape.max_width - child_padding
				}
			}
		}
	}

	for mut child in node.children {
		layout_fill_widths(mut child)
	}
}

// layout_fill_heights manages the growing and shrinking of layout vertically to
// satisfy a layout constraint
fn layout_fill_heights(mut node Layout) {
	mut previous_remaining_height := f32(0)
	mut remaining_height := node.shape.height - node.shape.padding.height()

	if node.shape.axis == .top_to_bottom {
		for mut child in node.children {
			remaining_height -= child.shape.height
		}
		// fence post spacing
		remaining_height -= node.spacing()

		// divide up the remaining fill heights by first growing all the
		// all the fill layouts to the same size (if possible) and then
		// distributing the remaining height to evenly.
		//
		mut excluded := []u64{cap: node.children.len}
		for remaining_height > tolerance {
			if f32_are_close(remaining_height, previous_remaining_height) {
				break
			}
			previous_remaining_height = remaining_height
			// Grow child elements
			idx, len := find_first_idx_and_len(node, fn [excluded] (n Layout) bool {
				return n.shape.sizing.height == .fill && n.shape.uid !in excluded
			})
			if len == 0 {
				break
			}

			mut smallest := node.children[idx].shape.height
			mut second_smallest := f32(max_u32)
			mut height_to_add := remaining_height

			for child in node.children {
				if child.shape.sizing.height == .fill && child.shape.uid !in excluded {
					if child.shape.height < smallest {
						second_smallest = smallest
						smallest = child.shape.height
					}
					if child.shape.height > smallest {
						second_smallest = f32_min(second_smallest, child.shape.height)
						height_to_add = second_smallest - smallest
					}
				}
			}

			height_to_add = f32_min(height_to_add, remaining_height / len)

			for mut child in node.children {
				if child.shape.sizing.height == .fill && child.shape.uid !in excluded {
					if child.shape.height == smallest {
						previous_height := child.shape.height
						child.shape.height += height_to_add

						if child.shape.height <= child.shape.min_height {
							child.shape.height = child.shape.min_height
							excluded << child.shape.uid
						} else if child.shape.max_height > 0
							&& child.shape.height >= child.shape.max_height {
							child.shape.height = child.shape.max_height
							excluded << child.shape.uid
						}
						remaining_height -= (child.shape.height - previous_height)
					}
				}
			}
		}

		// Shrink if needed using similar algorithm
		excluded.clear()
		previous_remaining_height = 0
		for remaining_height < -tolerance {
			if f32_are_close(remaining_height, previous_remaining_height) {
				break
			}
			previous_remaining_height = remaining_height
			idx, len := find_first_idx_and_len(node, fn [excluded] (n Layout) bool {
				return n.shape.uid !in excluded
			})
			if len == 0 {
				break
			}

			mut largest := node.children[idx].shape.height
			mut second_largest := f32(0)
			mut height_to_add := remaining_height

			for child in node.children {
				if child.shape.uid !in excluded {
					if child.shape.height > largest {
						second_largest = largest
						largest = child.shape.height
					}
					if child.shape.height < largest {
						second_largest = f32_max(second_largest, child.shape.height)
						height_to_add = second_largest - largest
					}
				}
			}

			height_to_add = f32_max(height_to_add, remaining_height / len)

			for mut child in node.children {
				if child.shape.sizing.height == .fill && child.shape.uid !in excluded {
					if child.shape.height == largest {
						previous_height := child.shape.height
						child.shape.height += height_to_add
						if child.shape.height <= child.shape.min_height {
							child.shape.height = child.shape.min_height
							excluded << child.shape.uid
						} else if child.shape.max_height > 0
							&& child.shape.height >= child.shape.max_height {
							child.shape.height = child.shape.max_height
							excluded << child.shape.uid
						}
						remaining_height -= (child.shape.height - previous_height)
					}
				}
			}
		}
	} else if node.shape.axis == .left_to_right {
		if node.shape.max_height > 0 && node.shape.height > node.shape.max_height {
			node.shape.height = node.shape.max_height
		}
		for mut child in node.children {
			if child.shape.sizing.height == .fill {
				child.shape.height += (remaining_height - f32_max(child.shape.height,
					child.shape.min_height))
				child.shape.height = f32_max(child.shape.height, child.shape.min_height)
				child_padding := child.shape.padding.height()
				if child.shape.max_height > 0
					&& child.shape.height > (child.shape.max_height - child_padding) {
					child.shape.height = child.shape.max_height - child_padding
				}
			}
		}
	}

	for mut child in node.children {
		layout_fill_heights(mut child)
	}
}

// layout_wrap_text is called after all widths in a Layout are determined.
// Wrapping text changes the min-height of a Shape, which is why it is called
// before computing Shape heights.
fn layout_wrap_text(mut node Layout, mut w Window) {
	text_wrap(mut node.shape, mut w)
	for mut child in node.children {
		layout_wrap_text(mut child, mut w)
	}
}

// layout_adjust_scroll_offsets ensures scroll offsets are in range.
// Scroll offsets can go out of range during window resizing.
fn layout_adjust_scroll_offsets(mut node Layout, mut w Window) {
	id_scroll := node.shape.id_scroll
	if id_scroll > 0 {
		max_offset_x := f32_min(0, node.shape.width - node.shape.padding.width() - content_width(node))
		offset_x := w.view_state.offset_x_state[id_scroll]
		w.view_state.offset_x_state[id_scroll] = clamp_f32(offset_x, max_offset_x, 0)

		max_offset_y := f32_min(0, node.shape.height - node.shape.padding.height() - content_height(node))
		offset_y := w.view_state.offset_y_state[id_scroll]
		w.view_state.offset_y_state[id_scroll] = clamp_f32(offset_y, max_offset_y, 0)
	}
	for mut child in node.children {
		layout_adjust_scroll_offsets(mut child, mut w)
	}
}

// layout_positions sets the positions of all layout in the Layoute. It also
// handles alignment. Alignment only augments x and y positions. Alignment
// does not effect sizes.
fn layout_positions(mut node Layout, offset_x f32, offset_y f32, w &Window) {
	node.shape.x += offset_x
	node.shape.y += offset_y

	axis := node.shape.axis
	padding := node.shape.padding
	spacing := node.shape.spacing

	if node.shape.id_scroll > 0 {
		node.shape.clip = true
	}

	mut x := node.shape.x + padding.left
	mut y := node.shape.y + padding.top

	if node.shape.id_scroll > 0 {
		x += w.view_state.offset_x_state[node.shape.id_scroll]
		y += w.view_state.offset_y_state[node.shape.id_scroll]
	}

	// alignment along the axis
	match axis {
		.left_to_right {
			if node.shape.h_align != .start {
				mut remaining := node.shape.width - padding.width()
				remaining -= node.spacing()
				for child in node.children {
					remaining -= child.shape.width
				}
				if node.shape.h_align == .center {
					remaining /= 2
				}
				x += remaining
			}
		}
		.top_to_bottom {
			if node.shape.v_align != .top {
				mut remaining := node.shape.height - padding.height()
				remaining -= node.spacing()
				for child in node.children {
					remaining -= child.shape.height
				}
				if node.shape.v_align == .middle {
					remaining /= 2
				}
				y += remaining
			}
		}
		.none {}
	}

	for mut child in node.children {
		// alignment across the axis
		mut x_align := f32(0)
		mut y_align := f32(0)
		match axis {
			.left_to_right {
				remaining := node.shape.height - child.shape.height - padding.height()
				if remaining > 0 {
					match node.shape.v_align {
						.top {}
						.middle { y_align = remaining / 2 }
						else { y_align = remaining }
					}
				}
			}
			.top_to_bottom {
				remaining := node.shape.width - child.shape.width - padding.width()
				if remaining > 0 {
					match node.shape.h_align {
						.start {}
						.center { x_align = remaining / 2 }
						else { x_align = remaining }
					}
				}
			}
			.none {}
		}

		layout_positions(mut child, x + x_align, y + y_align, w)

		if child.shape.type != .none {
			match axis {
				.left_to_right { x += child.shape.width + spacing }
				.top_to_bottom { y += child.shape.height + spacing }
				.none {}
			}
		}
	}
}

// layout_disables walks the Layout and disables any children
// that have a diabled ancestor.
fn layout_disables(mut node Layout, disabled bool) {
	mut is_disabled := disabled || node.shape.disabled
	node.shape.disabled = is_disabled
	for mut child in node.children {
		layout_disables(mut child, is_disabled)
	}
}

fn layout_set_draw_clips(mut node Layout, clip DrawClip) {
	mut node_clip := clip
	draw_clip := shape_clip_rect(node.shape)
	node.shape.draw_clip = rect_intersection(draw_clip, node_clip) or { DrawClip{} }

	if node.shape.clip {
		node_clip = draw_clip
	}

	for mut child in node.children {
		layout_set_draw_clips(mut child, node_clip)
	}
}

// layout_amend is the secret sauce to handling layout problems
// that can't be solved until all the positions and sizes are
// known. In general, one should not alter sizes and positions,
// (exception: scrollbars) it is the right place to handle
// mouse-over events that typically change a color or opacity.
fn layout_amend(mut node Layout, mut w Window) {
	for mut child in node.children {
		layout_amend(mut child, mut w)
	}
	if node.shape.amend_layout != unsafe { nil } {
		node.shape.amend_layout(mut node, mut w)
	}
}
