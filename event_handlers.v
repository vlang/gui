module gui

// Event Handler System
//
// This module defines the event handling system for the GUI library. It traverses
// the widget tree (Layout tree), determines which widget should receive an input
// event (keyboard or mouse), and executes the appropriate callbacks.
//
// Traversal order:
// - Keyboard events: Forward (natural DOM order, depth-first)
// - Mouse events: Reverse (topmost/last child first for z-axis layering)
//
// See event_traversal.v for helper functions used here.
//
import arrays
import log

// char_handler handles character input events (typing).
// Traverses forward and delivers to focused element.
fn char_handler(layout &Layout, mut e Event, mut w Window) {
	// Traverse children forward (depth-first)
	for child in layout.children {
		if !is_child_enabled(child) {
			continue
		}
		char_handler(child, mut e, mut w)
		if e.is_handled {
			return
		}
	}
	// Execute callback if this layout has focus
	on_char := if layout.shape.has_events() { layout.shape.events.on_char } else { unsafe { nil } }
	execute_focus_callback(layout, mut e, mut w, on_char, 'char_handler')
}

// keydown_handler handles key down events (special keys, shortcuts).
// Traverses forward and delivers to focused element.
// Also handles scroll behavior for focusable scroll containers.
fn keydown_handler(layout &Layout, mut e Event, mut w Window) {
	// Traverse children forward (depth-first)
	for child in layout.children {
		if !is_child_enabled(child) {
			continue
		}
		keydown_handler(child, mut e, mut w)
		if e.is_handled {
			return
		}
	}
	// Check focus requirements
	if layout.shape.id_focus == 0 {
		return
	}
	if !w.is_focus(layout.shape.id_focus) && layout.shape.id != reserved_dialog_id {
		return
	}
	// Execute keydown callback before scroll fallback.
	// Custom handlers (e.g. listbox) manage their own scrolling;
	// generic scroll is only for containers without key handling.
	on_keydown := if layout.shape.has_events() {
		layout.shape.events.on_keydown
	} else {
		unsafe { nil }
	}
	execute_focus_callback(layout, mut e, mut w, on_keydown, 'keydown_handler')
	if e.is_handled {
		return
	}
	// Fallback: scroll keys for focusable scroll containers
	if layout.shape.id_scroll > 0 {
		key_down_scroll_handler(layout, mut e, mut w)
		if e.is_handled {
			log.debug('keydown_handler scrolled by ${layout.shape.id}')
		}
	}
}

// key_down_scroll_handler handles keyboard-based scrolling.
// Supports arrow keys, page up/down, and home/end.
fn key_down_scroll_handler(layout &Layout, mut e Event, mut w Window) {
	delta_line := gui_theme.scroll_delta_line
	delta_page := gui_theme.scroll_delta_page
	delta_home := 10000000 // Large number to scroll to start/end

	if e.modifiers == .none {
		match e.key_code {
			.up { e.is_handled = scroll_vertical(layout, delta_line, mut w) }
			.down { e.is_handled = scroll_vertical(layout, -delta_line, mut w) }
			.home { e.is_handled = scroll_vertical(layout, delta_home, mut w) }
			.end { e.is_handled = scroll_vertical(layout, -delta_home, mut w) }
			.page_up { e.is_handled = scroll_vertical(layout, delta_page, mut w) }
			.page_down { e.is_handled = scroll_vertical(layout, -delta_page, mut w) }
			else {}
		}
	} else if e.modifiers == Modifier.shift {
		match e.key_code {
			.left { e.is_handled = scroll_horizontal(layout, delta_line, mut w) }
			.right { e.is_handled = scroll_horizontal(layout, -delta_line, mut w) }
			else {}
		}
	}
}

// mouse_down_handler handles mouse button press events.
// Traverses reverse (topmost first) and delivers to element under cursor.
// Also handles focus changes on click.
fn mouse_down_handler(layout &Layout, in_handler bool, mut e Event, mut w Window) {
	// Check mouse lock (only at top level to avoid repeated checks)
	if !in_handler {
		if w.view_state.mouse_lock.mouse_down != none {
			w.view_state.mouse_lock.mouse_down(layout, mut e, mut w)
			return
		}
	}
	// Traverse children in reverse (topmost/last child first)
	for child in arrays.reverse_iterator(layout.children) {
		if !is_child_enabled(child) {
			continue
		}
		mouse_down_handler(child, true, mut e, mut w)
		if e.is_handled {
			return
		}
	}
	// Check if click is within this layout's bounds
	if layout.shape.point_in_shape(e.mouse_x, e.mouse_y) {
		// Set focus if this layout is focusable
		if layout.shape.id_focus > 0 {
			w.set_id_focus(layout.shape.id_focus)
		}
		// Execute click callback with relative coordinates
		on_click := if layout.shape.has_events() {
			layout.shape.events.on_click
		} else {
			unsafe { nil }
		}
		execute_mouse_callback(layout, mut e, mut w, on_click, 'mouse_down_handler')
	}
}

// mouse_move_handler handles mouse movement events.
// Traverses reverse (topmost first) and delivers to element under cursor.
fn mouse_move_handler(layout &Layout, mut e Event, mut w Window) {
	// Check mouse lock
	if w.view_state.mouse_lock.mouse_move != none {
		w.view_state.mouse_lock.mouse_move(layout, mut e, mut w)
		return
	}
	// Skip if mouse is outside application window
	if !w.pointer_over_app(e) {
		return
	}
	// Traverse children in reverse (topmost/last child first)
	for child in arrays.reverse_iterator(layout.children) {
		if !is_child_enabled(child) {
			continue
		}
		mouse_move_handler(child, mut e, mut w)
		if e.is_handled {
			return
		}
	}
	// Execute mouse move callback with relative coordinates
	on_mouse_move := if layout.shape.has_events() {
		layout.shape.events.on_mouse_move
	} else {
		unsafe { nil }
	}
	execute_mouse_callback(layout, mut e, mut w, on_mouse_move, 'mouse_move_handler')
}

// mouse_up_handler handles mouse button release events.
// Traverses reverse (topmost first) and delivers to element under cursor.
fn mouse_up_handler(layout &Layout, mut e Event, mut w Window) {
	// Check mouse lock
	if w.view_state.mouse_lock.mouse_up != none {
		w.view_state.mouse_lock.mouse_up(layout, mut e, mut w)
		return
	}
	// Traverse children in reverse (topmost/last child first)
	for child in arrays.reverse_iterator(layout.children) {
		if !is_child_enabled(child) {
			continue
		}
		mouse_up_handler(child, mut e, mut w)
		if e.is_handled {
			return
		}
	}
	// Execute mouse up callback with relative coordinates
	on_mouse_up := if layout.shape.has_events() {
		layout.shape.events.on_mouse_up
	} else {
		unsafe { nil }
	}
	execute_mouse_callback(layout, mut e, mut w, on_mouse_up, 'mouse_up_handler')
}

// mouse_scroll_handler handles mouse wheel scroll events.
// Traverses reverse (topmost first). Delivers to focused element's scroll handler
// first, then falls back to scroll container under cursor.
fn mouse_scroll_handler(layout &Layout, mut e Event, mut w Window) {
	// Traverse children in reverse (topmost/last child first)
	for child in arrays.reverse_iterator(layout.children) {
		if !is_child_enabled(child) {
			continue
		}
		mouse_scroll_handler(child, mut e, mut w)
		if e.is_handled {
			return
		}
	}
	// Check if focused element has a scroll handler
	id_focus := w.id_focus()
	if id_focus != 0 {
		if ly := layout.find_layout(fn [id_focus] (l Layout) bool {
			return l.shape.id_focus == id_focus
		})
		{
			if ly.shape.has_events() && ly.shape.events.on_mouse_scroll != unsafe { nil } {
				ly.shape.events.on_mouse_scroll(ly, mut e, mut w)
				return
			}
		}
	}
	// Handle scroll on scroll container under cursor
	if !layout.shape.disabled && layout.shape.id_scroll > 0 {
		if layout.shape.point_in_shape(e.mouse_x, e.mouse_y) {
			if e.modifiers == Modifier.shift {
				e.is_handled = scroll_horizontal(layout, e.scroll_x, mut w)
			} else if e.modifiers == Modifier.none {
				e.is_handled = scroll_vertical(layout, e.scroll_y, mut w)
			}
		}
	}
}
