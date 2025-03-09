module gui

// Based on Nic Barter's video of how Clay's UI algorithm works.
// https://www.youtube.com/watch?v=by9lQvpvMIc&t=1272s
//
import arrays

pub fn do_layout(mut layout ShapeTree) {
	layout_widths(mut layout)
	layout_dynamic_widths(mut layout)
	layout_wrap_text(mut layout)
	layout_heights(mut layout)
	layout_dynamic_heights(mut layout)
	layout_positions(mut layout, 0, 0)
}

fn layout_widths(mut node ShapeTree) {
	sizing := node.shape.sizing
	padding := node.shape.padding
	spacing := node.shape.spacing
	direction := node.shape.direction

	mut width := f32(0)

	if sizing.width == .fixed {
		node.shape.width
	}

	for mut child in node.children {
		layout_widths(mut child)
		match direction {
			.none {}
			.left_to_right { width += child.shape.width }
			.top_to_bottom { width = f32_max(width, child.shape.width) }
		}
	}

	if sizing.width == .dynamic && node.shape.direction == .left_to_right {
		total_spacing := spacing * (node.children.len - 1)
		node.shape.width = width + padding.left + padding.right
		node.shape.width += total_spacing
	}
}

fn layout_heights(mut node ShapeTree) {
	sizing := node.shape.sizing
	padding := node.shape.padding
	spacing := node.shape.spacing
	direction := node.shape.direction

	mut height := f32(0)

	if sizing.height == .fixed {
		node.shape.height
	}

	for mut child in node.children {
		layout_heights(mut child)
		match direction {
			.none {}
			.left_to_right { height = f32_max(height, child.shape.height) }
			.top_to_bottom { height += child.shape.height }
		}
	}

	if sizing.height == .dynamic && node.shape.direction == .top_to_bottom {
		total_spacing := spacing * (node.children.len - 1)
		node.shape.height = height + padding.top + padding.bottom
		node.shape.height += total_spacing
	}
}

fn layout_dynamic_widths(mut node ShapeTree) {
	padding := node.shape.padding

	mut remaining_width := node.shape.width
	remaining_width -= padding.left + padding.right

	if node.shape.direction == .left_to_right {
		for mut child in node.children {
			remaining_width -= child.shape.width
		}

		// fence post spacing
		remaining_width -= (node.children.len - 1) * node.shape.spacing

		// Grow child elements
		idx := arrays.index_of_first(node.children, fn (_ int, n ShapeTree) bool {
			return n.shape.sizing.width == .dynamic
		})
		if idx < 0 {
			return
		}
		clamp := 100 // avoid infinite loop
		length := node.children.filter(it.shape.sizing.width == .dynamic).len

		// divide up the remaining dynamic widths by first growing
		// all the all the dynamics to the same size (if possible)
		// and then distributing the remaining width to evenly to
		// each dynamic.
		for i := 0; remaining_width > 0.1 && i < clamp; i++ {
			mut smallest := node.children[idx].shape.width
			mut second_smallest := f32(1000 * 1000)
			mut width_to_add := remaining_width

			for child in node.children {
				if child.shape.sizing.width == .dynamic {
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
				if child.shape.sizing.width == .dynamic {
					if child.shape.width == smallest {
						child.shape.width += width_to_add
						remaining_width -= width_to_add
					}
				}
			}
		}
	} else {
		for mut child in node.children {
			if child.shape.sizing.width == .dynamic {
				child.shape.width += (remaining_width - child.shape.width)
			}
		}
	}

	for mut child in node.children {
		layout_dynamic_widths(mut child)
	}
}

fn layout_wrap_text(mut node ShapeTree) {
}

fn layout_dynamic_heights(mut node ShapeTree) {
	mut remaining_height := node.shape.height
	padding := node.shape.padding
	remaining_height -= padding.top + padding.bottom

	if node.shape.direction == .top_to_bottom {
		for mut child in node.children {
			layout_dynamic_heights(mut child)
			remaining_height -= child.shape.height
		}

		// fence post spacing
		remaining_height -= (node.children.len - 1) * node.shape.spacing

		// Grow child elements
		idx := arrays.index_of_first(node.children, fn (_ int, n ShapeTree) bool {
			return n.shape.sizing.height == .dynamic
		})
		if idx < 0 {
			return
		}
		clamp := 100 // avoid infinite loop
		length := node.children.filter(it.shape.sizing.height == .dynamic).len

		// divide up the remaining dynamic hieghts by first growing
		// all the all the dynamics to the same size (if possible)
		// and then distributing the remaining height to evenly to
		// each dynamic.
		for i := 0; remaining_height > 0.1 && i < clamp; i++ {
			mut smallest := node.children[idx].shape.height
			mut second_smallest := f32(1000 * 1000)
			mut height_to_add := remaining_height

			for child in node.children {
				if child.shape.sizing.height == .dynamic {
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
				if child.shape.sizing.height == .dynamic {
					if child.shape.height == smallest {
						child.shape.height += height_to_add
						remaining_height -= height_to_add
					}
				}
			}
		}
	} else {
		for mut child in node.children {
			if child.shape.sizing.height == .dynamic {
				child.shape.height += (remaining_height - child.shape.height)
			}
		}
	}

	for mut child in node.children {
		layout_dynamic_heights(mut child)
	}
}

fn layout_positions(mut node ShapeTree, offset_x f32, offset_y f32) {
	node.shape.x += offset_x
	node.shape.y += offset_y

	padding := node.shape.padding
	spacing := node.shape.spacing
	direction := node.shape.direction

	mut x := node.shape.x + padding.left
	mut y := node.shape.y + padding.top

	for mut child in node.children {
		layout_positions(mut child, x, y)
		match direction {
			.none {}
			.left_to_right { x += child.shape.width + spacing }
			.top_to_bottom { y += child.shape.height + spacing }
		}
	}
}
