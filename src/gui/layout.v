module gui

// Based on Nic Barter's video of how Clay's UI algorithm works.
// https://www.youtube.com/watch?v=by9lQvpvMIc&t=1272s
//
import arrays

// layout_do executes a pipeline of functions to layout and position the Shapes
// of a ShapeTree
fn layout_do(mut layout ShapeTree, window &Window) {
	layout_widths(mut layout)
	layout_flex_widths(mut layout)
	layout_wrap_text(mut layout, window)
	layout_heights(mut layout)
	layout_flex_heights(mut layout)
	layout_positions(mut layout, 0, 0)
	layout_amend(mut layout, window)
}

// layout_widths arranges a node's children Shapes horizontally. Only container
// shapes with an axis are arranged.
fn layout_widths(mut node ShapeTree) {
	padding := node.shape.padding.left + node.shape.padding.right
	if node.shape.axis == .left_to_right { // along the axis
		if node.shape.sizing.width == .fixed {
			for mut child in node.children {
				layout_widths(mut child)
			}
		} else {
			for mut child in node.children {
				layout_widths(mut child)
				node.shape.width += child.shape.width
				node.shape.min_width += match child.shape.min_width > 0 {
					true { child.shape.min_width }
					else { child.shape.width }
				}
				node.shape.max_width += child.shape.max_width
			}
			spacing := int_max(0, (node.children.len - 1)) * node.shape.spacing
			node.shape.width += padding + spacing
			node.shape.min_width += padding + spacing
			node.shape.width = f32_max(node.shape.width, node.shape.min_width)
			if node.shape.max_width != 0 {
				node.shape.width = f32_min(node.shape.max_width + padding + spacing, node.shape.width)
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
		if node.shape.max_width != 0 {
			node.shape.width = f32_min(node.shape.max_width + padding, node.shape.width)
		}
	}
}

// layout_heights arranges a node's children Shapes vertically. Only container
// shapes with an axis are arranged.
fn layout_heights(mut node ShapeTree) {
	padding := node.shape.padding.top + node.shape.padding.bottom
	if node.shape.axis == .top_to_bottom { // along the axis
		if node.shape.sizing.height == .fixed {
			for mut child in node.children {
				layout_heights(mut child)
			}
		} else {
			for mut child in node.children {
				layout_heights(mut child)
				node.shape.height += child.shape.height
				node.shape.min_height += match child.shape.min_height > 0 {
					true { child.shape.min_height }
					else { child.shape.height }
				}
				node.shape.max_height += child.shape.max_height
			}
			spacing := int_max(0, (node.children.len - 1)) * node.shape.spacing
			node.shape.height += padding + spacing
			node.shape.min_height += padding + spacing
			node.shape.height = f32_max(node.shape.height, node.shape.min_height)
			if node.shape.max_height != 0 {
				node.shape.height = f32_min(node.shape.max_height + padding + spacing,
					node.shape.height)
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
		if node.shape.max_height != 0 {
			node.shape.height = f32_min(node.shape.max_height + padding, node.shape.height)
		}
	}
}

// find_first_idx_and_len gets the index of the first element to satisfy the
// predicate and the length of all elements that satisfy the predicate. Iterates
// the array once with no allocations.
fn find_first_idx_and_len(node ShapeTree, predicate fn (n ShapeTree) bool) (int, int) {
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

// layout_flex_widths manages the growing and shrinking of Shapes horizontally
// to satisfy a layout constraint
fn layout_flex_widths(mut node ShapeTree) {
	clamp := 100 // avoid infinite loop
	mut remaining_width := node.shape.width - node.shape.padding.left - node.shape.padding.right

	if node.shape.axis == .left_to_right {
		for mut child in node.children {
			remaining_width -= child.shape.width
		}
		// fence post spacing
		remaining_width -= int_max(0, (node.children.len - 1)) * node.shape.spacing

		// divide up the remaining flex widths by first growing all the
		// all the flex shapes to the same size (if possible) and then
		// distributing the remaining width to evenly.
		//
		mut excluded := []u64{cap: 25}
		for i := 0; remaining_width > 0.1 && i < clamp; i++ {
			// Grow child elements
			idx, len := find_first_idx_and_len(node, fn [excluded] (n ShapeTree) bool {
				return n.shape.sizing.width == .flex && n.shape.uid !in excluded
			})
			if len == 0 {
				break
			}

			mut smallest := node.children[idx].shape.width
			mut second_smallest := f32(1000 * 1000)
			mut width_to_add := remaining_width

			for child in node.children {
				if child.shape.sizing.width == .flex && child.shape.uid !in excluded {
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
				if child.shape.sizing.width == .flex && child.shape.uid !in excluded {
					if child.shape.width == smallest {
						previous_width := child.shape.width
						child.shape.width += width_to_add
						if child.shape.width <= child.shape.min_width {
							child.shape.width = child.shape.min_width
							excluded << child.shape.uid
						} else if child.shape.max_width != 0
							&& child.shape.width >= child.shape.max_width {
							child.shape.width = child.shape.max_width
							excluded << child.shape.uid
						}
						remaining_width -= (child.shape.width - previous_width)
					}
				}
			}
		}

		// Shrink if needed
		excluded.clear()
		for i := 0; remaining_width < -0.1 && i < clamp; i++ {
			shrinkable := node.children.filter(it.shape.uid !in excluded)
			if shrinkable.len == 0 {
				break
			}

			mut largest := shrinkable[0].shape.width
			mut second_largest := f32(0)
			mut width_to_add := remaining_width

			for child in shrinkable {
				if child.shape.width > largest {
					second_largest = largest
					largest = child.shape.width
				}
				if child.shape.width < largest {
					second_largest = f32_max(second_largest, child.shape.width)
					width_to_add = second_largest - largest
				}
			}

			width_to_add = f32_max(width_to_add, remaining_width / shrinkable.len)

			for mut child in node.children {
				if child.shape.sizing.width == .flex && child.shape.uid !in excluded {
					if child.shape.width == largest {
						previous_width := child.shape.width
						child.shape.width += width_to_add
						if child.shape.width <= child.shape.min_width {
							child.shape.width = child.shape.min_width
							excluded << child.shape.uid
						} else if child.shape.max_width != 0
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
		if node.shape.max_width != 0 {
			max_width := node.shape.max_width
			if node.shape.width > max_width {
				node.shape.width = max_width
			}
		}
		for mut child in node.children {
			if child.shape.sizing.width == .flex {
				child.shape.width += (remaining_width - f32_max(child.shape.width, child.shape.min_width))
				child_padding := child.shape.padding.left + child.shape.padding.right
				if child.shape.max_width != 0
					&& child.shape.width > (child.shape.max_width - child_padding) {
					child.shape.width = child.shape.max_width - child_padding
				}
			}
		}
	}

	for mut child in node.children {
		layout_flex_widths(mut child)
	}
}

// layout_flex_heights manages the growing and shrinking of Shapes vertically to
// satisfy a layout constraint
fn layout_flex_heights(mut node ShapeTree) {
	clamp := 100 // avoid infinite loop
	padding := node.shape.padding.top + node.shape.padding.bottom
	mut remaining_height := node.shape.height - padding

	if node.shape.axis == .top_to_bottom {
		for mut child in node.children {
			remaining_height -= child.shape.height
		}
		// fence post spacing
		remaining_height -= int_max(0, (node.children.len - 1)) * node.shape.spacing

		// divide up the remaining flex heights by first growing all the
		// all the flex shapes to the same size (if possible) and then
		// distributing the remaining height to evenly.
		//
		mut excluded := []u64{cap: 25}
		for i := 0; remaining_height > 0.1 && i < clamp; i++ {
			// Grow child elements
			idx, len := find_first_idx_and_len(node, fn [excluded] (n ShapeTree) bool {
				return n.shape.sizing.height == .flex && n.shape.uid !in excluded
			})
			if len == 0 {
				break
			}

			mut smallest := node.children[idx].shape.height
			mut second_smallest := f32(1000 * 1000)
			mut height_to_add := remaining_height

			for child in node.children {
				if child.shape.sizing.height == .flex && child.shape.uid !in excluded {
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
				if child.shape.sizing.height == .flex {
					if child.shape.height == smallest {
						previous_height := child.shape.height
						child.shape.height += height_to_add
						if child.shape.height <= child.shape.min_height {
							child.shape.height = child.shape.min_height
							excluded << child.shape.uid
						} else if child.shape.max_height != 0
							&& child.shape.height >= child.shape.max_height {
							child.shape.height = child.shape.max_height
							excluded << child.shape.uid
						}
						remaining_height -= (child.shape.height - previous_height)
					}
				}
			}
		}

		// Shrink if needed
		excluded.clear()
		for i := 0; remaining_height < -0.1 && i < clamp; i++ {
			shrinkable := node.children.filter(it.shape.uid !in excluded)
			if shrinkable.len == 0 {
				break
			}

			mut largest := shrinkable[0].shape.height
			mut second_largest := f32(0)
			mut height_to_add := remaining_height

			for child in shrinkable {
				if child.shape.height > largest {
					second_largest = largest
					largest = child.shape.height
				}
				if child.shape.height < largest {
					second_largest = f32_max(second_largest, child.shape.height)
					height_to_add = second_largest - largest
				}
			}

			height_to_add = f32_max(height_to_add, remaining_height / shrinkable.len)

			for mut child in node.children {
				if child.shape.sizing.height == .flex && child.shape.uid !in excluded {
					if child.shape.height == largest {
						previous_height := child.shape.height
						child.shape.height += height_to_add
						if child.shape.height <= child.shape.min_height {
							child.shape.height = child.shape.min_height
							excluded << child.shape.uid
						} else if child.shape.max_height != 0
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
		if node.shape.max_height != 0 {
			max_height := node.shape.max_height
			if node.shape.height > max_height {
				node.shape.height = max_height
			}
		}
		for mut child in node.children {
			if child.shape.sizing.height == .flex {
				child.shape.height += (remaining_height - f32_max(child.shape.height,
					child.shape.min_height))
				if child.shape.max_height != 0 && child.shape.height > child.shape.max_height {
					child.shape.height = child.shape.max_height
				}
			}
		}
	}

	for mut child in node.children {
		layout_flex_heights(mut child)
	}
}

// layout_wrap_text is called after all widths in a ShapeTree are determined.
// Wrapping text can change the height of an Shape, which is why it is called
// before computing Shape heights
fn layout_wrap_text(mut node ShapeTree, w &Window) {
	if w.id_focus > 0 && w.id_focus == node.shape.id_focus && node.shape.type == .text {
		// figure out where the dang cursor goes
		node.shape.cursor_x = 0
		node.shape.cursor_y = 0

		input_state := w.input_state[w.id_focus]
		cursor_pos := input_state.cursor_pos

		if cursor_pos >= 0 {
			// place a zero-space char in the string at the cursor pos as
			// a marker to where the cursor should go.
			zero_space := '\xe2\x80\x8b'
			text := node.shape.text[..cursor_pos] + zero_space + node.shape.text[cursor_pos..]

			w.ui.set_text_cfg(node.shape.text_cfg)
			wrapped := match node.shape.wrap {
				true {
					match node.shape.keep_spaces {
						true { text_wrap_text_keep_spaces(text, node.shape.width, w.ui) }
						else { text_wrap_text(text, node.shape.width, w.ui) }
					}
				}
				else {
					[text]
				}
			}

			// After wrapping, find the zero-space cursor_y is the
			// index into the shape.lines array cursor_x is
			// character index of that indexed line
			zero_space_rune := zero_space.runes()[0]
			for idx, ln in wrapped {
				pos := arrays.index_of_first(ln.runes(), fn [zero_space_rune] (idx int, elem rune) bool {
					return elem == zero_space_rune
				})
				if pos >= 0 {
					node.shape.cursor_x = int_min(pos, ln.len - 1)
					node.shape.cursor_y = idx
					break
				}
			}
		}
	}

	// wrap the text for-real
	text_wrap(mut node.shape, w.ui)

	for mut child in node.children {
		layout_wrap_text(mut child, w)
	}
}

// layout_positions sets the positions of all Shapes in the ShapeTreee. It also
// handles alignment (soon)
fn layout_positions(mut node ShapeTree, offset_x f32, offset_y f32) {
	node.shape.x += offset_x
	node.shape.y += offset_y

	axis := node.shape.axis
	padding := node.shape.padding
	spacing := node.shape.spacing

	mut x := node.shape.x + padding.left
	mut y := node.shape.y + padding.top

	// alignment along the axis
	match axis {
		.left_to_right {
			if node.shape.h_align != .left {
				mut remaining := node.shape.width - padding.left - padding.right
				remaining -= int_max(0, (node.children.len - 1)) * node.shape.spacing
				for child in node.children {
					remaining -= child.shape.width
				}
				if node.shape.h_align == .center {
					remaining /= (node.children.len + 1)
				}
				x += remaining
			}
		}
		.top_to_bottom {
			if node.shape.v_align != .top {
				mut remaining := node.shape.height - padding.top - padding.bottom
				remaining -= int_max(0, (node.children.len - 1)) * node.shape.spacing
				for child in node.children {
					remaining -= child.shape.height
				}
				if node.shape.v_align == .middle {
					remaining /= (node.children.len + 1)
				}
				y += remaining
			}
		}
		.none {}
	}

	for mut child in node.children {
		// alignment across the axis
		mut x_extra := f32(0)
		mut y_extra := f32(0)
		match axis {
			.left_to_right {
				remaining := node.shape.height - child.shape.height - padding.top - padding.bottom
				if remaining > 0 {
					match node.shape.v_align {
						.top {}
						.middle { y_extra = remaining / 2 }
						else { y_extra = remaining }
					}
				}
			}
			.top_to_bottom {
				remaining := node.shape.width - child.shape.width - padding.left - padding.right
				if remaining > 0 {
					match node.shape.h_align {
						.left {}
						.center { x_extra = remaining / 2 }
						else { x_extra = remaining }
					}
				}
			}
			.none {}
		}

		layout_positions(mut child, x + x_extra, y + y_extra)

		match axis {
			.left_to_right { x += child.shape.width + spacing }
			.top_to_bottom { y += child.shape.height + spacing }
			.none {}
		}
	}
}

// Handle focus, hover stuff here.
fn layout_amend(mut node ShapeTree, w &Window) {
	for mut child in node.children {
		layout_amend(mut child, w)
	}
	if node.shape.amend_layout != unsafe { nil } {
		node.shape.amend_layout(mut node, w)
	}
}
