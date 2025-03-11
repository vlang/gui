module gui

// Based on Nic Barter's video of how Clay's UI algorithm works.
// https://www.youtube.com/watch?v=by9lQvpvMIc&t=1272s
//
import arrays

fn layout_do(mut layout ShapeTree, window Window) {
	layout_widths(mut layout)
	layout_dynamic_widths(mut layout, window)
	layout_wrap_text(mut layout, window)
	layout_heights(mut layout)
	layout_dynamic_heights(mut layout)
	layout_positions(mut layout, 0, 0)
}

fn layout_widths(mut node ShapeTree) {
	for mut child in node.children {
		layout_widths(mut child)
		if node.shape.sizing.width != .fixed {
			if node.shape.direction == .left_to_right {
				node.shape.width += node.shape.spacing * (node.children.len - 1)
			}
			match node.shape.direction {
				.left_to_right { node.shape.width += child.shape.width }
				.top_to_bottom { node.shape.width = f32_max(node.shape.width, child.shape.width) }
				.none {}
			}
			node.shape.width += node.shape.padding.left + node.shape.padding.right
		}
	}
}

fn layout_heights(mut node ShapeTree) {
	for mut child in node.children {
		layout_heights(mut child)
		if node.shape.sizing.height != .fixed {
			if node.shape.direction == .top_to_bottom {
				node.shape.height += node.shape.spacing * (node.children.len - 1)
			}
			match node.shape.direction {
				.left_to_right { node.shape.height = f32_max(node.shape.height, child.shape.height) }
				.top_to_bottom { node.shape.height += child.shape.height }
				.none {}
			}
			node.shape.height += node.shape.padding.top + node.shape.padding.bottom
		}
	}
}

fn layout_dynamic_widths(mut node ShapeTree, window Window) {
	clamp := 100 // avoid infinite loop
	mut remaining_width := node.shape.width - node.shape.padding.left - node.shape.padding.right

	if node.shape.direction == .left_to_right {
		for mut child in node.children {
			remaining_width -= child.shape.width
		}
		// fence post spacing
		remaining_width -= (node.children.len - 1) * node.shape.spacing

		// Grow child elements
		idx := arrays.index_of_first(node.children, fn (_ int, n ShapeTree) bool {
			return n.shape.sizing.width == .grow
		})
		if idx < 0 {
			return
		}
		length := node.children.filter(it.shape.sizing.width == .grow).len

		// divide up the remaining dynamic widths by first growing
		// all the all the dynamics to the same size (if possible)
		// and then distributing the remaining width to evenly to
		// each dynamic.
		for i := 0; remaining_width > 0 && i < clamp; i++ {
			// mut smallest := node.children[idx].shape.width
			mut smallest := node.children[idx].shape.width
			mut second_smallest := f32(1000 * 1000)
			mut width_to_add := remaining_width

			for child in node.children {
				if child.shape.sizing.width == .grow {
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

			width_to_add = f32_min(width_to_add, remaining_width / length)

			for mut child in node.children {
				if child.shape.sizing.width == .grow {
					if child.shape.width == smallest {
						child.shape.width += width_to_add
						remaining_width -= width_to_add
					}
				}
			}
		}

		// Shrink if needed
		mut excluded := []string{}

		for i := 0; remaining_width < 0 && i < clamp; i++ {
			shrinkable := node.children.filter(it.shape.sizing.width == .grow
				&& it.shape.uid !in excluded)

			if shrinkable.len == 0 {
				return
			}

			mut largest := shrinkable[0].shape.width
			mut second_largest := f32(0)
			mut width_to_add := remaining_width

			for child in shrinkable {
				if child.shape.sizing.width == .grow && child.shape.uid !in excluded {
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

			width_to_add = f32_max(width_to_add, remaining_width / shrinkable.len)

			for mut child in node.children {
				if child.shape.sizing.width == .grow {
					previous_width := child.shape.width
					if child.shape.width == largest {
						child.shape.width += width_to_add
						if child.shape.width <= child.shape.min_width {
							child.shape.width = child.shape.min_width
							excluded << child.shape.uid
						}
					}
					remaining_width -= (width_to_add - previous_width)
				}
			}
		}
	} else {
		for mut child in node.children {
			if child.shape.sizing.width == .grow {
				child.shape.width += (remaining_width - child.shape.width)
			}
		}
	}

	for mut child in node.children {
		layout_dynamic_widths(mut child, window)
	}
}

fn layout_dynamic_heights(mut node ShapeTree) {
	mut remaining_height := node.shape.height - node.shape.padding.top - node.shape.padding.bottom

	if node.shape.direction == .top_to_bottom {
		for mut child in node.children {
			layout_dynamic_heights(mut child)
			remaining_height -= child.shape.height
		}

		// fence post spacing
		remaining_height -= (node.children.len - 1) * node.shape.spacing

		// Grow child elements
		idx := arrays.index_of_first(node.children, fn (_ int, n ShapeTree) bool {
			return n.shape.sizing.height == .grow
		})
		if idx < 0 {
			return
		}
		clamp := 100 // avoid infinite loop
		length := node.children.filter(it.shape.sizing.height == .grow).len

		// divide up the remaining dynamic hieghts by first growing
		// all the all the dynamics to the same size (if possible)
		// and then distributing the remaining height to evenly to
		// each dynamic.
		for i := 0; remaining_height > 0.1 && i < clamp; i++ {
			mut smallest := node.children[idx].shape.height
			mut second_smallest := f32(1000 * 1000)
			mut height_to_add := remaining_height

			for child in node.children {
				if child.shape.sizing.height == .grow {
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

			height_to_add = f32_min(height_to_add, remaining_height / length)

			for mut child in node.children {
				if child.shape.sizing.height == .grow {
					if child.shape.height == smallest {
						child.shape.height += height_to_add
						remaining_height -= height_to_add
					}
				}
			}
		}
	} else {
		for mut child in node.children {
			if child.shape.sizing.height == .grow {
				child.shape.height += (remaining_height - child.shape.height)
			}
		}
	}

	for mut child in node.children {
		layout_dynamic_heights(mut child)
	}
}

fn layout_wrap_text(mut node ShapeTree, window &Window) {
	// this space for rent
}

fn layout_positions(mut node ShapeTree, offset_x f32, offset_y f32) {
	node.shape.x += offset_x
	node.shape.y += offset_y

	spacing := node.shape.spacing
	direction := node.shape.direction

	mut x := node.shape.x + node.shape.padding.left
	mut y := node.shape.y + node.shape.padding.top

	for mut child in node.children {
		layout_positions(mut child, x, y)
		match direction {
			.left_to_right { x += child.shape.width + spacing }
			.top_to_bottom { y += child.shape.height + spacing }
			.none {}
		}
	}
}
