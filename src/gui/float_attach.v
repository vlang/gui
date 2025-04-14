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
	x, y = match layout.shape.float_attach {
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
	return x, y
}

// float_layouts_fix_neseted_floats fixes an edge case. If a float is nested
// immediately in a float it effectively makes the one float a child of the other.
// The logic in layout_remove_floating_layouts() replaces the float layouts in the
// layout tree with empty nodes. This means the second float layout parent is no
// longer pointing at parent float layout. Fortunately, the array has the parent
// float layout in the previous array element.
fn float_layouts_fix_neseted_floats(mut floating_layouts []Layout) {
	for i := 0; i < floating_layouts.len; i++ {
		if floating_layouts[i].parent.shape.axis == .none && i > 0 {
			floating_layouts[i].parent = unsafe { &floating_layouts[i - 1] }
		}
	}
}
