module gui

// Event Traversal Utilities
//
// This module provides helper functions to reduce code duplication in event handlers.
// The GUI event system uses tree traversal patterns that were previously duplicated
// across 7+ event handlers. These utilities extract the common patterns.
//
// Traversal patterns:
// - Forward: For keyboard events (natural DOM order)
// - Reverse: For mouse events (respects z-axis layering, topmost first)
//
// Execution patterns:
// - Focus-based: Execute callback if layout has focus
// - Mouse-based: Execute callback if mouse is within shape bounds
//
import log

// ShapeCallback is the type used for shape event callbacks.
type ShapeCallback = fn (&Layout, mut Event, mut Window)

// execute_focus_callback executes a callback if the layout has focus.
// Returns true if the callback was executed and handled the event.
//
// This handles the common pattern:
// 1. Check if layout can receive focus (id_focus > 0)
// 2. Check if layout currently has focus or is a dialog
// 3. Execute callback if conditions met
// 4. Log debug info if handled
//
@[inline]
fn execute_focus_callback(layout &Layout, mut e Event, mut w Window, callback ShapeCallback, handler_name string) bool {
	if layout.shape.id_focus == 0 {
		return false
	}
	if !w.is_focus(layout.shape.id_focus) && layout.shape.id != reserved_dialog_id {
		return false
	}
	if callback == unsafe { nil } {
		return false
	}
	callback(layout, mut e, mut w)
	if e.is_handled {
		log.debug('${handler_name} handled by ${layout.shape.id}')
		return true
	}
	return false
}

// execute_mouse_callback executes a callback if the mouse is within the shape bounds.
// Mouse coordinates are made relative to the layout shape before calling.
// Returns true if the callback was executed and handled the event.
//
// This handles the common pattern:
// 1. Check if mouse is within shape bounds
// 2. Make coordinates relative to layout
// 3. Execute callback
// 4. Propagate handled state back to original event
//
@[inline]
fn execute_mouse_callback(layout &Layout, mut e Event, mut w Window, callback ShapeCallback, handler_name string) bool {
	if !layout.shape.point_in_shape(e.mouse_x, e.mouse_y) {
		return false
	}
	if callback == unsafe { nil } {
		return false
	}
	// Make mouse coordinates relative to layout.shape
	mut ev := event_relative_to(layout.shape, e)
	callback(layout, mut ev, mut w)
	if ev.is_handled {
		e.is_handled = true
		log.debug('${handler_name} handled by ${layout.shape.id}')
		return true
	}
	return false
}

// is_child_enabled checks if a child layout should receive events.
// Disabled children are skipped during event traversal.
//
@[inline]
fn is_child_enabled(child &Layout) bool {
	return !child.shape.disabled
}
