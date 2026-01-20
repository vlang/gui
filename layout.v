module gui

// The layout module implements a tree-based UI layout system. It handles
// arranging and positioning UI elements in horizontal and vertical layouts,
// supporting nested containers, scrolling, floating elements, alignment,
// padding, and spacing. The engine uses a multi-pass pipeline for efficient
// calculation.
//
// Based on Clay's UI algorithm:
// https://www.youtube.com/watch?v=by9lQvpvMIc&t=1272s
//

// layout_arrange executes a pipeline to arrange and position the layout.
// Returns multiple layouts, each representing a layer for rendering.
fn layout_arrange(mut layout Layout, mut window Window) []Layout {
	// stopwatch := time.new_stopwatch()
	// defer { println(stopwatch.elapsed()) }

	// Set the parents of all the nodes. This is used to
	// compute relative floating layout coordinates
	layout_parents(mut layout, unsafe { nil })

	// Floating layouts do not affect parent or sibling elements.
	mut floating_layouts := []Layout{}
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

// layout_pipeline performs multiple passes over the layout. Dealing with one
// axis of expansion/contraction at a time simplifies calculations. Matches
// logic in the referenced Clay UI video.
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
	// Array .nogrow to protect layout.parent reference
	// If it grows after this, it's a logic error.
	unsafe { layout.children.flags.set(.nogrow) }
	layout.parent = unsafe { parent }

	for mut child in layout.children {
		layout_parents(mut child, layout)
	}
}

// layout_remove_floating_layouts replaces floating layouts with an empty
// Layout node (no axis/height/width) so they are effectively ignored by
// layout logic. The removed layouts are collected in the layouts array.
fn layout_remove_floating_layouts(mut layout Layout, mut layouts []Layout) {
	for i, mut child in layout.children {
		if child.shape.float {
			layouts << child
		}

		layout_remove_floating_layouts(mut child, mut layouts)

		if child.shape.float {
			// shape.type == .none enables identification as empty node by
			// fix_nested_sibling_floats() and removes it from spacing calculations.
			layout.children[i] = empty_layout
		}
	}
}
