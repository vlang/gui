module gui

// The layout module implements a tree-based UI layout system inspired by Clay's UI algorithm.
// It handles arranging and positioning UI elements in both horizontal and vertical layouts,
// with support for nested containers, scrolling, floating elements, alignment, padding and spacing.
// The layout engine uses a multi-pass pipeline to calculate sizes and positions efficiently.
//
// Based on Nic Barter's video of how Clay's UI algorithm works.
// https://www.youtube.com/watch?v=by9lQvpvMIc&t=1272s
//
// There's a fair bit of code duplication here. This is intentional.
// I found it much easier to write and debug without generalizing
// up/down vs. left/right. Abstractions here only complicate an
// already hard-to-reason-about problem. -imho
//
import arrays

// ==================================================
// Note to me: Adding @[heap] to struct Layout causes
// flickering in the scrollbars. Test this by running
// v run fonts.v
// ==================================================

// Layout defines a tree of Layouts. Views generate Layouts
pub struct Layout {
pub mut:
	shape    &Shape  = unsafe { nil }
	parent   &Layout = unsafe { nil }
	children []Layout
}

// layout_arrange executes a pipeline of functions to arrange and position the layout.
// Multiple layouts are returned, each is used to draw a layer of the final rendering.
fn layout_arrange(mut layout Layout, mut window Window) []Layout {
	// stopwatch := time.new_stopwatch()
	// defer { println(stopwatch.elapsed()) }

	// Set the parents of all the nodes. This is used to
	// compute relative floating layout coordinates
	layout_parents(mut layout, unsafe { nil })

	// floating layouts do not affect their parent or sibling elements
	// They also complicate the fuck out of things.
	mut floating_layouts := []Layout{}
	unsafe { floating_layouts.flags.set(.noslices) }
	layout_remove_floating_layouts(mut layout, mut floating_layouts)
	fix_float_parents(mut floating_layouts)

	// Dialog is a pop-up dialog.
	// Add last to ensure it is always on top.
	// Dialogs do not support additional floating layouts.
	if window.dialog_cfg.visible {
		mut dialog_view := dialog_view_generator(window.dialog_cfg)
		mut dialog_layout := generate_layout(mut dialog_view, mut window)
		layout_parents(mut dialog_layout, layout)
		floating_layouts << dialog_layout
	}

	// Compute the layout without the floating elements.
	layout_pipeline(mut layout, mut window)
	mut layouts := [layout]
	unsafe { layouts.flags.set(.noslices) }

	// Compute the floating layouts. Because they are appended to
	// the layout array, they get rendered after the main layout.
	for mut floating_layout in floating_layouts {
		shape_clip := floating_layout.parent.shape.shape_clip
		if shape_clip.width == 0 && shape_clip.height == 0 {
			continue
		}
		layout_pipeline(mut floating_layout, mut window)
		layouts << floating_layout
	}
	return layouts
}

// layout_pipeline makes multiple passes over the layout.
// Multiple passes actually simplify many of the layout
// calculations by only dealing with one axis of
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
	layout_scroll_containers(mut layout, 0)
	layout_amend(mut layout, mut window)
	layout_set_shape_clips(mut layout, window.window_rect())
	layout_hover(mut layout, mut window)
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
				shape: &Shape{}
			}
		}
	}
}

// layout_widths arranges a node's children layout horizontally. Only container
// layout with an axis are arranged.
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

// layout_heights arranges a node's children layout vertically. Only container
// layout with an axis are arranged.
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

// find_first_idx_and_len gets the index of the first element to satisfy the
// predicate and the length of all elements that satisfy the predicate. Iterates
// the array once with no allocations.
fn find_first_idx_and_len(layout &Layout, predicate fn (n Layout) bool) (int, int) {
	mut idx := 0
	mut len := 0
	mut set_idx := false
	for i, child in layout.children {
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
		mut excluded := []u64{cap: layout.children.len}
		for remaining_width > f32_tolerance {
			if f32_are_close(remaining_width, previous_remaining_width) {
				break
			}
			previous_remaining_width = remaining_width
			// Grow child elements
			idx, len := find_first_idx_and_len(layout, fn [excluded] (n Layout) bool {
				return n.shape.sizing.width == .fill && n.shape.uid !in excluded
			})
			if len == 0 {
				break
			}

			mut smallest := layout.children[idx].shape.width
			mut second_smallest := f32(max_u32)
			mut width_to_add := remaining_width

			for child in layout.children {
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

			for mut child in layout.children {
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
		for remaining_width < -f32_tolerance {
			if f32_are_close(remaining_width, previous_remaining_width) {
				break
			}
			previous_remaining_width = remaining_width
			idx, len := find_first_idx_and_len(layout, fn [excluded] (n Layout) bool {
				return n.shape.uid !in excluded
			})
			if len == 0 {
				break
			}

			mut largest := layout.children[idx].shape.width
			mut second_largest := f32(0)
			mut width_to_add := remaining_width

			for child in layout.children {
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

			for mut child in layout.children {
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
	} else if layout.shape.axis == .top_to_bottom {
		if layout.shape.id_scroll > 0 && layout.shape.sizing.width == .fill
			&& layout.shape.scroll_mode != .vertical_only
			&& layout.parent.shape.axis != .top_to_bottom {
			sibling_widths := layout.parent.children.filter(it.shape.uid != layout.shape.uid).map(it.shape.width)
			layout.shape.width = layout.parent.shape.width - arrays.sum(sibling_widths) or { 0 }
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

// layout_fill_heights manages the growing and shrinking of layout vertically to
// satisfy a layout constraint
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
		mut excluded := []u64{cap: layout.children.len}
		for remaining_height > f32_tolerance {
			if f32_are_close(remaining_height, previous_remaining_height) {
				break
			}
			previous_remaining_height = remaining_height
			// Grow child elements
			idx, len := find_first_idx_and_len(layout, fn [excluded] (n Layout) bool {
				return n.shape.sizing.height == .fill && n.shape.uid !in excluded
			})
			if len == 0 {
				break
			}

			mut smallest := layout.children[idx].shape.height
			mut second_smallest := f32(max_u32)
			mut height_to_add := remaining_height

			for child in layout.children {
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

			for mut child in layout.children {
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
		for remaining_height < -f32_tolerance {
			if f32_are_close(remaining_height, previous_remaining_height) {
				break
			}
			previous_remaining_height = remaining_height
			idx, len := find_first_idx_and_len(layout, fn [excluded] (n Layout) bool {
				return n.shape.uid !in excluded
			})
			if len == 0 {
				break
			}

			mut largest := layout.children[idx].shape.height
			mut second_largest := f32(0)
			mut height_to_add := remaining_height

			for child in layout.children {
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

			for mut child in layout.children {
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
	} else if layout.shape.axis == .left_to_right {
		if layout.shape.id_scroll > 0 && layout.shape.sizing.height == .fill
			&& layout.shape.scroll_mode != .horizontal_only
			&& layout.parent.shape.axis != .left_to_right {
			sibling_heights := layout.parent.children.filter(it.shape.uid != layout.shape.uid).map(it.shape.height)
			layout.shape.height = layout.parent.shape.height - arrays.sum(sibling_heights) or { 0 }
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

// layout_wrap_text is called after all widths in a Layout are determined.
// Wrapping text changes the min-height of a Shape, which is why it is called
// before computing Shape heights.
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

// layout_positions sets the positions of all layout in the Layout. It also
// handles alignment. Alignment only augments x and y positions. Alignment
// does not effect sizes.
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
		// Motivation: `text` views are not directly scrollable but instead
		// must live inside a scrollable container (one with a non-zero id_scroll)
		// Selecting text in a text view can push the selection outside the visible
		// region of the text view (e.g. mouse selection). The event handler does
		// no have enough information to walk up the visible tree to find the
		// scrollable container. Instead, it is bookmarked in the text shape
		// (and maybe other shapes in the future).
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

// layout_amend is the secret sauce to handling layout problems
// that can't be solved until all the positions and sizes are
// known. In general, one should not alter sizes and positions.
// (exception: scrollbars) It is the right place to handle
// mouse-over events that typically change a color or opacity.
fn layout_amend(mut layout Layout, mut w Window) {
	for mut child in layout.children {
		layout_amend(mut child, mut w)
	}
	if layout.shape.amend_layout != unsafe { nil } {
		layout.shape.amend_layout(mut layout, mut w)
	}
}

// layout_hover is a convenience callback for clients to do hover things.
// Originally, it was done in layout_amend but it's a fair bit of boiler
// plate that this callback encapsulates.
fn layout_hover(mut layout Layout, mut w Window) {
	if w.mouse_is_locked() {
		return
	}
	for mut child in layout.children {
		layout_hover(mut child, mut w)
	}
	if layout.shape.on_hover != unsafe { nil } {
		if layout.shape.disabled {
			return
		}
		if w.dialog_cfg.visible && !layout_in_dialog_layout(layout) {
			return
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
		}
	}
}
