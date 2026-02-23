module gui

pub enum FloatAttach as u8 {
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

// mirror_float_attach swaps left/right anchors for RTL mirroring.
fn mirror_float_attach(a FloatAttach) FloatAttach {
	return match a {
		.top_left { .top_right }
		.top_right { .top_left }
		.middle_left { .middle_right }
		.middle_right { .middle_left }
		.bottom_left { .bottom_right }
		.bottom_right { .bottom_left }
		else { a }
	}
}

// float_attach_layout computes the position of the float layouts relative
// to their parent.
fn float_attach_layout(layout &Layout) (f32, f32) {
	if layout.parent == unsafe { nil } {
		return f32(0), f32(0)
	}
	parent := layout.parent.shape
	is_rtl := effective_text_dir(parent) == .rtl

	anchor := if is_rtl {
		mirror_float_attach(layout.shape.float_anchor)
	} else {
		layout.shape.float_anchor
	}
	tie_off := if is_rtl {
		mirror_float_attach(layout.shape.float_tie_off)
	} else {
		layout.shape.float_tie_off
	}
	offset_x := if is_rtl { -layout.shape.float_offset_x } else { layout.shape.float_offset_x }

	mut x, mut y := layout.parent.shape.x, layout.parent.shape.y
	x, y = match anchor {
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
	x, y = match tie_off {
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
	x += offset_x
	y += layout.shape.float_offset_y
	return x, y
}

// layout_remove_floating_layouts extracts floating elements from the main layout tree.
// It replaces them with empty placeholder nodes to preserve the tree structure indices
// while removing them from standard flow layout calculations. The extracted layouts
// are collected into the `layouts` array to be processed as separate layers.
fn layout_remove_floating_layouts(mut layout Layout, mut layouts []&Layout) {
	mut scratch := ScratchPools{}
	layout_remove_floating_layouts_with_scratch(mut layout, mut layouts, mut scratch)
}

fn layout_remove_floating_layouts_with_scratch(mut layout Layout, mut layouts []&Layout, mut scratch ScratchPools) {
	for i in 0 .. layout.children.len {
		if layout.children[i].shape.float {
			// Move floating layout to reusable heap node to keep parent pointers stable.
			mut heap_layout := scratch.alloc_floating_layout(layout.children[i])

			// Update direct children to point to the new heap-allocated parent
			for mut child in heap_layout.children {
				child.parent = heap_layout
			}

			layouts << heap_layout

			// Recurse into the floating layout to find nested floats
			layout_remove_floating_layouts_with_scratch(mut *heap_layout, mut layouts, mut
				scratch)

			// Replace in original tree with empty placeholder
			layout.children[i] = layout_placeholder()
		} else {
			layout_remove_floating_layouts_with_scratch(mut layout.children[i], mut layouts, mut
				scratch)
		}
	}
}
