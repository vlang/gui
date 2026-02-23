module gui

// Layout defines a tree of Layouts. Views generate Layouts
@[heap]
pub struct Layout {
pub mut:
	shape    &Shape  = unsafe { nil }
	parent   &Layout = unsafe { nil }
	children []Layout
}

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
	mut floating_layouts := window.scratch.take_floating_layouts(layout.children.len + 1)
	defer {
		window.scratch.put_floating_layouts(mut floating_layouts)
	}
	layout_remove_floating_layouts_with_scratch(mut layout, mut floating_layouts, mut
		window.scratch)

	// Inspector overlay — injected as floating layout like dialogs.
	$if !prod {
		if window.inspector_enabled {
			mut inspector_view := inspector_floating_panel(mut window)
			mut inspector_layout := generate_layout(mut inspector_view, mut window)
			layout_parents(mut inspector_layout, &layout)
			floating_layouts << window.scratch.alloc_floating_layout(inspector_layout)
		}
	}

	// Dialog is a pop-up dialog.
	// Add last to ensure it is always on top.
	// Dialogs do not support additional floating layouts.
	if window.dialog_cfg.visible {
		mut dialog_view := dialog_view_generator(window.dialog_cfg)
		mut dialog_layout := generate_layout(mut dialog_view, mut window)
		layout_parents(mut dialog_layout, &layout)
		floating_layouts << window.scratch.alloc_floating_layout(dialog_layout)
	}

	// Compute the layout without the floating elements.
	layout_pipeline(mut layout, mut window)
	mut layouts := [layout]

	// Compute the floating layouts. Because they are appended to
	// the layout array, they get rendered after the main layout.
	for mut floating_layout in floating_layouts {
		shape_clip := floating_layout.parent.shape.shape_clip
		if shape_clip.width <= 0 || shape_clip.height <= 0 {
			continue
		}
		layout_pipeline(mut floating_layout, mut window)
		layouts << *floating_layout
	}
	return layouts
}

// layout_pipeline performs multiple passes over the layout tree to calculate sizing and positioning.
// Handling one axis of expansion/contraction at a time simplifies the complex constraint solving.
// The logic follows the approach described in the Clay UI layout algorithm.
fn layout_pipeline(mut layout Layout, mut window Window) {
	layout_widths(mut layout)
	layout_fill_widths_with_scratch(mut layout, mut window.scratch.distribute)
	layout_wrap_containers_with_scratch(mut layout, mut window.scratch)
	layout_overflow(mut layout, mut window)
	layout_wrap_text(mut layout, mut window)

	layout_heights(mut layout)
	layout_fill_heights_with_scratch(mut layout, mut window.scratch.distribute)

	layout_adjust_scroll_offsets(mut layout, mut window)
	x, y := float_attach_layout(layout)
	layout_positions(mut layout, x, y, mut window)
	layout_disables(mut layout, false)
	layout_scroll_containers(mut layout, 0)

	layout_amend(mut layout, mut window)
	apply_layout_transition(mut layout, window)
	apply_hero_transition(mut layout, window)
	layout_set_shape_clips(mut layout, window.window_rect())
	layout_hover(mut layout, mut window)
}

// layout_amend handles layout problems resolvable only after sizing/positioning,
// such as mouse-over events affecting appearance. Avoid altering sizes here.
fn layout_amend(mut layout Layout, mut w Window) {
	for mut child in layout.children {
		layout_amend(mut child, mut w)
	}
	if layout.shape.has_events() && layout.shape.events.amend_layout != unsafe { nil } {
		layout.shape.events.amend_layout(mut layout, mut w)
	}
}

// layout_hover encapsulates hover handling logic.
fn layout_hover(mut layout Layout, mut w Window) bool {
	if w.mouse_is_locked() {
		return false
	}
	for mut child in layout.children {
		is_handled := layout_hover(mut child, mut w)
		if is_handled {
			return true
		}
	}
	if layout.shape.has_events() && layout.shape.events.on_hover != unsafe { nil } {
		if layout.shape.disabled {
			return false
		}
		if w.dialog_cfg.visible && !layout_in_dialog_layout(layout) {
			return false
		}
		ctx := w.context()
		if layout.shape.point_in_shape(ctx.mouse_pos_x, ctx.mouse_pos_y) {
			// fake an event to get mouse button states.
			mouse_button := match true {
				ctx.mbtn_mask & 0x01 > 0 { MouseButton.left }
				ctx.mbtn_mask & 0x02 > 0 { MouseButton.right }
				ctx.mbtn_mask & 0x04 > 0 { MouseButton.middle }
				else { MouseButton.invalid }
			}
			mut ev := Event{
				frame_count:   ctx.frame
				typ:           .invalid
				modifiers:     unsafe { Modifier(ctx.key_modifiers) }
				mouse_button:  mouse_button
				mouse_x:       ctx.mouse_pos_x
				mouse_y:       ctx.mouse_pos_y
				mouse_dx:      ctx.mouse_dx
				mouse_dy:      ctx.mouse_dy
				scroll_x:      ctx.scroll_x
				scroll_y:      ctx.scroll_y
				window_width:  ctx.width
				window_height: ctx.height
			}
			layout.shape.events.on_hover(mut layout, mut ev, mut w)
			return ev.is_handled
		}
	}
	return false
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

// layout_disables walks the Layout and disables any children
// that have a disabled ancestor.
fn layout_disables(mut layout Layout, disabled bool) {
	mut is_disabled := disabled || layout.shape.disabled
	layout.shape.disabled = is_disabled
	for mut child in layout.children {
		layout_disables(mut child, is_disabled)
	}
}

fn layout_placeholder() Layout {
	return Layout{
		shape: &Shape{
			shape_type: .none
		}
	}
}
