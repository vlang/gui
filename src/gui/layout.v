module gui

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

	mut width := 0

	if sizing.across == .fixed {
		node.shape.width
	}

	for mut child in node.children {
		layout_widths(mut child)
		match direction {
			.none {}
			.left_to_right { width += child.shape.width }
			.top_to_bottom { width = int_max(width, child.shape.width) }
		}
	}

	if sizing.across == .dynamic && node.shape.direction == .left_to_right {
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

	mut height := 0

	if sizing.down == .fixed {
		node.shape.height
	}

	for mut child in node.children {
		layout_heights(mut child)
		match direction {
			.none {}
			.left_to_right { height = int_max(height, child.shape.height) }
			.top_to_bottom { height += child.shape.height }
		}
	}

	if sizing.down == .dynamic && node.shape.direction == .top_to_bottom {
		total_spacing := spacing * (node.children.len - 1)
		node.shape.height = height + padding.top + padding.bottom
		node.shape.height += total_spacing
	}
}

fn layout_dynamic_widths(mut node ShapeTree) {
	padding := node.shape.padding
	// spacing := node.shape.spacing
	// direction := node.shape.direction

	mut remaining_width := node.shape.width
	remaining_width -= padding.left + padding.right
	for child in node.children {
		remaining_width -= child.shape.width
	}
	remaining_width -= (node.children.len - 1) * node.shape.spacing

	for mut child in node.children {
		if child.shape.sizing.across == .dynamic {
			child.shape.width += remaining_width
		}
	}
}

fn layout_wrap_text(mut node ShapeTree) {
}

fn layout_dynamic_heights(mut node ShapeTree) {
}

fn layout_positions(mut node ShapeTree, offset_x int, offset_y int) {
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
