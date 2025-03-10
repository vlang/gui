module gui

// Based on Nic Barter's video of how Clay's UI algorithm works.
// https://www.youtube.com/watch?v=by9lQvpvMIc&t=1272s
//
import arrays

fn layout_do(mut layout ShapeTree, window Window) {
	layout_widths(mut layout, window)
	layout_dynamic_widths(mut layout)
	layout_wrap_text(mut layout, window)
	layout_heights(mut layout, window)
	layout_dynamic_heights(mut layout)
	layout_positions(mut layout, 0, 0)
}

fn layout_widths(mut node ShapeTree, window Window) {
	if node.shape.type == .text {
		node.shape.width = text_width(node.shape, window)
	}

	mut width := node.shape.width

	for mut child in node.children {
		layout_widths(mut child, window)

		match node.shape.direction {
			.left_to_right { width += child.shape.width }
			.top_to_bottom { width = f32_max(width, child.shape.width) }
			.none {}
		}
	}

	if node.shape.sizing.width != .fixed {
		node.shape.width = width + node.shape.padding.left + node.shape.padding.right
		if node.shape.direction == .left_to_right {
			node.shape.width += node.shape.spacing * (node.children.len - 1)
		}
	}
}

fn layout_heights(mut node ShapeTree, window Window) {
	if node.shape.type == .text {
		node.shape.height = text_height(node.shape, window)
	}

	mut height := node.shape.height

	for mut child in node.children {
		layout_heights(mut child, window)
		match node.shape.direction {
			.left_to_right { height = f32_max(height, child.shape.height) }
			.top_to_bottom { height += child.shape.height }
			.none {}
		}
	}

	if node.shape.sizing.height != .fixed {
		node.shape.height = height + node.shape.padding.top + node.shape.padding.bottom
		if node.shape.direction == .top_to_bottom {
			node.shape.height += node.shape.spacing * (node.children.len - 1)
		}
	}
}

fn layout_dynamic_widths(mut node ShapeTree) {
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
		clamp := 100 // avoid infinite loop
		length := node.children.filter(it.shape.sizing.width == .grow).len

		// divide up the remaining dynamic widths by first growing
		// all the all the dynamics to the same size (if possible)
		// and then distributing the remaining width to evenly to
		// each dynamic.
		for i := 0; remaining_width > 0.1 && i < clamp; i++ {
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
	} else {
		for mut child in node.children {
			if child.shape.sizing.width == .grow {
				child.shape.width += (remaining_width - child.shape.width)
			}
		}
	}

	for mut child in node.children {
		layout_dynamic_widths(mut child)
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
