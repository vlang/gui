module gui

pub enum FloatAttach {
	top_left
	top_center
	top_right
	middle_left
	middle_center
	middle_right
	bottom_left
	bottom_center
	bottom_right
}

// float_attach_layout computes the position of the float layouts relative
// to their parent.
fn float_attach_layout(layout &Layout) (f32, f32) {
	if layout.parent == unsafe { nil } {
		return f32(0), f32(0)
	}
	parent := layout.parent.shape
	mut x, mut y := layout.parent.shape.x, layout.parent.shape.y
	x, y = match layout.shape.float_anchor {
		.top_left { x, y }
		.top_center { x + parent.width / 2, y }
		.top_right { x + parent.width, y }
		.middle_left { x, y + parent.height / 2 }
		.middle_center { x + parent.width / 2, y + parent.height / 2 }
		.middle_right { x + parent.width, y + parent.height / 2 }
		.bottom_left { x, y + parent.height }
		.bottom_center { x + parent.width / 2, y + parent.height }
		.bottom_right { x + parent.width, y + parent.height }
	}
	shape := layout.shape
	x, y = match layout.shape.float_tie_off {
		.top_left { x, y }
		.top_center { x - shape.width / 2, y }
		.top_right { x - shape.width, y }
		.middle_left { x, y - shape.height / 2 }
		.middle_center { x - shape.width / 2, y - shape.height / 2 }
		.middle_right { x - shape.width, y - shape.height / 2 }
		.bottom_left { x, y - shape.height }
		.bottom_center { x - shape.width / 2, y - shape.height }
		.bottom_right { x - shape.width, y - shape.height }
	}
	x += layout.shape.float_offset_x
	y += layout.shape.float_offset_y
	return x, y
}

// fix_float_parents fixes an edge case when floats are nested immediately with floats.
// When layout_remove_floating_layouts() removes nodes from the layout it replaces them
// with an .none node. If floats have child floats, the child float parents will often
// times point at these .none nodes. The actual parent node is earlier in the
// floating_layouts array. Find it and use it as the use it as the parent.
fn fix_float_parents(mut floating_layouts []Layout) {
	for i := floating_layouts.len - 1; i > 0; i-- {
		if floating_layouts[i].parent.shape.type == .none && i > 0 {
			mut j := i
			for ; j > 0; j-- {
				if floating_layouts[j].parent.shape.type != .none {
					break
				}
			}
			floating_layouts[i].parent = unsafe { &floating_layouts[j] }
		}
	}
}
