module gui

// Based on Nic Barter's video of how Clay's UI algorithm works.
// https://www.youtube.com/watch?v=by9lQvpvMIc&t=1272s
//
import arrays
import gg
// import time

// layout_do executes a pipeline of functions to layout
// and position the Shapes of a ShapeTree
fn layout_do(mut layout ShapeTree, window Window) {
	// mut stop_watch := time.StopWatch{}
	// stop_watch.start()

	layout_widths(mut layout)
	layout_flex_widths(mut layout)
	layout_wrap_text(mut layout, window)
	layout_heights(mut layout)
	layout_flex_heights(mut layout)
	layout_positions(mut layout, 0, 0)

	width, height := window.window_size()
	layout_clipping_bounds(mut layout, width: width, height: height)

	// stop_watch.stop()
	// println(stop_watch.elapsed())
}

// layout_widths arranges a node's children Shapes horizontally. Only container
// nodes with a shape axis are arranged.
fn layout_widths(mut node ShapeTree) {
	if node.shape.axis == .left_to_right && node.shape.sizing.width != .fixed {
		node.shape.width += node.shape.spacing * (node.children.len - 1)
	}
	for mut child in node.children {
		layout_widths(mut child)
		child.shape.width += child.shape.padding.left + child.shape.padding.right
		if node.shape.sizing.width != .fixed {
			match node.shape.axis {
				.left_to_right { node.shape.width += child.shape.width }
				.top_to_bottom { node.shape.width = f32_max(node.shape.width, child.shape.width) }
				.none {}
			}
		}
	}
}

// layout_heights arranges a node's children Shapes vertically. Only container
// Shapes with a axis are arranged.
fn layout_heights(mut node ShapeTree) {
	if node.shape.axis == .top_to_bottom && node.shape.sizing.height != .fixed {
		node.shape.height += node.shape.spacing * (node.children.len - 1)
	}
	for mut child in node.children {
		layout_heights(mut child)
		child.shape.height += child.shape.padding.top + child.shape.padding.bottom
		if node.shape.sizing.height != .fixed {
			match node.shape.axis {
				.top_to_bottom { node.shape.height += child.shape.height }
				.left_to_right { node.shape.height = f32_max(node.shape.height, child.shape.height) }
				.none {}
			}
		}
	}
}

// find_first_idx_and_len gets the index of the first element to satisfy
// the predicate and the length of all elements that satisfy the predicate.
// Only iterates the array once with no allocations
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

// layout_flex_widths manages the growing and shrinking of Shapes horizontally to satisfy
// a layout constraint
fn layout_flex_widths(mut node ShapeTree) {
	clamp := 100 // avoid infinite loop
	mut remaining_width := node.shape.width - node.shape.padding.left - node.shape.padding.right

	if node.shape.axis == .left_to_right {
		for mut child in node.children {
			remaining_width -= child.shape.width
		}
		// fence post spacing
		remaining_width -= (node.children.len - 1) * node.shape.spacing

		// Grow child elements
		idx, len := find_first_idx_and_len(node, fn (n ShapeTree) bool {
			return n.shape.sizing.width == .flex
		})
		if len == 0 {
			return
		}

		// divide up the remaining flex widths by first growing
		// all the all the flex shapes to the same size (if possible)
		// and then distributing the remaining width to evenly.
		for i := 0; remaining_width > 0.1 && i < clamp; i++ {
			mut smallest := node.children[idx].shape.width
			mut second_smallest := f32(1000 * 1000)
			mut width_to_add := remaining_width

			for child in node.children {
				if child.shape.sizing.width == .flex {
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
				if child.shape.sizing.width == .flex {
					if child.shape.width == smallest {
						child.shape.width += width_to_add
						remaining_width -= width_to_add
					}
				}
			}
		}

		// Shrink if needed
		mut excluded := []u64{cap: 50}
		for i := 0; remaining_width < -0.1 && i < clamp; i++ {
			shrinkable := node.children.filter(it.shape.uid !in excluded)
			if shrinkable.len == 0 {
				return
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
				if child.shape.sizing.width == .flex {
					previous_width := child.shape.width
					if child.shape.width == largest {
						child.shape.width += width_to_add
						if child.shape.width <= child.shape.min_width {
							child.shape.width = child.shape.min_width
							excluded << child.shape.uid
						}
						remaining_width -= (child.shape.width - previous_width)
					}
				}
			}
		}
	} else if node.shape.axis == .top_to_bottom {
		for mut child in node.children {
			if child.shape.sizing.width == .flex {
				child.shape.width += (remaining_width - child.shape.width)
			}
		}
	}

	for mut child in node.children {
		layout_flex_widths(mut child)
	}
}

// layout_flex_heights manages the growing and shrinking of Shapes vertically to satisfy
// a layout constraint
fn layout_flex_heights(mut node ShapeTree) {
	clamp := 100 // avoid infinite loop
	mut remaining_height := node.shape.height - node.shape.padding.top - node.shape.padding.bottom

	if node.shape.axis == .top_to_bottom {
		for mut child in node.children {
			layout_flex_heights(mut child)
			remaining_height -= child.shape.height
		}

		// fence post spacing
		remaining_height -= (node.children.len - 1) * node.shape.spacing

		// Grow child elements
		idx, len := find_first_idx_and_len(node, fn (n ShapeTree) bool {
			return n.shape.sizing.height == .flex
		})
		if len == 0 {
			return
		}

		// divide up the remaining flex hieghts by first growing
		// all the all the flex shape to the same size (if possible)
		// and then distributing the remaining height to evenly to
		// each
		for i := 0; remaining_height > 0.1 && i < clamp; i++ {
			mut smallest := node.children[idx].shape.height
			mut second_smallest := f32(1000 * 1000)
			mut height_to_add := remaining_height

			for child in node.children {
				if child.shape.sizing.height == .flex {
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
						child.shape.height += height_to_add
						remaining_height -= height_to_add
					}
				}
			}
		}
	} else if node.shape.axis == .left_to_right {
		for mut child in node.children {
			if child.shape.sizing.height == .flex {
				child.shape.height += (remaining_height - child.shape.height)
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
	if w.focus_id > 0 && w.focus_id == node.shape.focus_id && node.shape.type == .text {
		// figure out where the dang cursor goes
		node.shape.cursor_x = 0
		node.shape.cursor_y = 0
		if w.cursor_offset >= 0 {
			// place a zero-space char in the string at the cursor pos as
			// a marker to where the cursor should go.
			zero_space := '\xe2\x80\x8b'
			text := node.shape.text[..w.cursor_offset] + zero_space +
				node.shape.text[w.cursor_offset..]

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

			// After wrapping, find the zero-space
			// cursor_y is the index into the shape.lines array
			// cursor_x is character index of that indexed line
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

// layout_positions sets the positions of all Shapes in the ShapeTreee.
// It also handles alignment (soon)
fn layout_positions(mut node ShapeTree, offset_x f32, offset_y f32) {
	node.shape.x += offset_x
	node.shape.y += offset_y

	spacing := node.shape.spacing
	axis := node.shape.axis

	mut x := node.shape.x + node.shape.padding.left
	mut y := node.shape.y + node.shape.padding.top

	for mut child in node.children {
		layout_positions(mut child, x, y)
		match axis {
			.left_to_right { x += child.shape.width + spacing }
			.top_to_bottom { y += child.shape.height + spacing }
			.none {}
		}
	}
}

// layout_clipping_bounds ensures that Shapes do not draw outside the parent
// Shape container.
fn layout_clipping_bounds(mut node ShapeTree, bounds gg.Rect) {
	nb := match node.shape.type == .container {
		true {
			padding := node.shape.padding
			bw := bounds.x + bounds.width
			nw := node.shape.x + node.shape.width - padding.right
			bh := bounds.y + bounds.height
			nh := node.shape.y + node.shape.height - padding.bottom

			gg.Rect{
				x:      if bw < nw { bounds.x } else { node.shape.x }
				y:      if bh < nh { bounds.y } else { node.shape.y }
				width:  if bw < nw { bounds.width } else { node.shape.width - padding.right }
				height: if bh < nh { bounds.height } else { node.shape.height - padding.bottom }
			}
		}
		else {
			bounds
		}
	}
	for mut child in node.children {
		child.shape.bounds = nb
		layout_clipping_bounds(mut child, nb)
	}
}
