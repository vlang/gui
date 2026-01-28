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

// layout_arrange executes a rendering pipeline to arrange and position the layout.
// It returns a list of layouts, where each layout represents a distinct rendering layer.
// The main layout is the first element, followed by any floating layouts (e.g., popups, tooltips)
// that should be rendered on top.
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

// layout_pipeline performs multiple passes over the layout tree to calculate sizing and positioning.
// Handling one axis of expansion/contraction at a time simplifies the complex constraint solving.
// The logic follows the approach described in the Clay UI layout algorithm.
fn layout_pipeline(mut layout Layout, mut window Window) {
	// 1. Calculate intrinsic widths based on content constraints
	layout_widths(mut layout)
	// 2. Expand widths to fill available space where applicable
	layout_fill_widths(mut layout)
	// 3. Wrap text based on valid widths, which may affect height
	layout_wrap_text(mut layout, mut window)
	// 4. Calculate intrinsic heights based on content
	layout_heights(mut layout)
	// 5. Expand heights to fill available space
	layout_fill_heights(mut layout)
	// 6. Adjust scroll offsets for containers
	layout_adjust_scroll_offsets(mut layout, mut window)
	// 7. Calculate final X, Y positions for all elements
	x, y := float_attach_layout(layout)
	layout_positions(mut layout, x, y, window)
	// 8. Handle disabled states
	layout_disables(mut layout, false)
	// 9. Handle scroll container logic
	layout_scroll_containers(mut layout, 0)
	// 10. Final layout adjustments/amendments
	layout_amend(mut layout, mut window)
	// 11. Apply animation transitions (layout/hero)
	apply_layout_transition(mut layout, window)
	apply_hero_transition(mut layout, window)
	// 12. Calculate clipping rectangles for rendering
	layout_set_shape_clips(mut layout, window.window_rect())
	// 13. Update hover states
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

// layout_remove_floating_layouts extracts floating elements from the main layout tree.
// It replaces them with empty placeholder nodes to preserve the tree structure indices
// while removing them from standard flow layout calculations. The extracted layouts
// are collected into the `layouts` array to be processed as separate layers.
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
