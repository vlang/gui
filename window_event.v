module gui

// AI-DOC: window_event.v
// - Scope: Window event intake and dispatch from gg callback.
// - Entry point: event_fn().
// - Focus gate: reject most events while unfocused; allow right-click and
//   focus/scroll flow.
// - Modal behavior: route events to dialog layer when dialog visible.
// - Post-condition: tooltip id cleared and update_window() requested.
import gg
import log

// event_fn handles user events, mostly delegating to child views.
fn event_fn(ev &gg.Event, mut w Window) {
	mut e := from_gg_event(ev)
	if !w.focused && e.typ == .mouse_down && e.mouse_button == MouseButton.right {
		// allow right clicks without focus.
		// motivation: browsers allow this action.
	} else if !w.focused && e.typ !in [.focused, .mouse_scroll] {
		return
	}

	$if !prod {
		if e.typ == .key_down && e.key_code == .f12 {
			inspector_toggle(mut w)
			e.is_handled = true
			return
		}
		if w.inspector_enabled && e.typ == .key_down && e.modifiers == .ctrl {
			if e.key_code == .left {
				inspector_resize(inspector_resize_step, mut w)
				e.is_handled = true
				return
			} else if e.key_code == .right {
				inspector_resize(-inspector_resize_step, mut w)
				e.is_handled = true
				return
			} else if e.key_code == .up {
				inspector_toggle_side(mut w)
				e.is_handled = true
				return
			}
		}
	}

	// Top-level layout children represent z-axis layers:
	// layout -> [main layout, floating layouts..., dialog layout]
	// Dialogs are modal if present. Events process bottom-up (leaf nodes) then
	// top-down (layers). Processing stops when `event.is_handled` is true.
	// No lock needed: layout is immutable on the main thread between frames.
	layout := if w.dialog_cfg.visible && w.layout.children.len > 0 {
		w.layout.children[w.layout.children.len - 1]
	} else {
		w.layout
	}

	match e.typ {
		.char {
			char_handler(layout, mut e, mut w)
		}
		.focused {
			w.focused = true
		}
		.unfocused {
			w.focused = false
		}
		.key_down {
			keydown_handler(layout, mut e, mut w)
			if !e.is_handled && e.key_code == .tab && e.modifiers == .shift {
				if shape := layout.previous_focusable(mut w) {
					w.set_id_focus(shape.id_focus)
				}
			} else if !e.is_handled && e.key_code == .tab {
				if shape := layout.next_focusable(mut w) {
					w.set_id_focus(shape.id_focus)
				}
			}
		}
		.mouse_down {
			w.set_mouse_cursor_arrow()
			$if !prod {
				if w.inspector_enabled {
					ww, _ := w.window_size()
					panel_w := inspector_panel_width(w)
					left := inspector_is_left(w)
					// Click outside inspector panel — pick app node
					in_app := if left {
						e.mouse_x > panel_w + inspector_margin
					} else {
						e.mouse_x < f32(ww) - panel_w - inspector_margin
					}
					if in_app {
						picked := inspector_pick_path(&w.layout, e.mouse_x, e.mouse_y)
						if picked.len > 0 {
							inspector_select(picked, mut w)
						}
						e.is_handled = true
					}
				}
			}
			if !e.is_handled {
				mouse_down_handler(layout, false, mut e, mut w)
			}
			if !e.is_handled {
				mut ss := state_map[string, bool](mut w, ns_select, cap_moderate)
				ss.clear()
				mut cs := state_map[string, bool](mut w, ns_combobox, cap_moderate)
				cs.clear()
			}
		}
		.mouse_move {
			w.set_mouse_cursor_arrow()
			w.view_state.menu_key_nav = false
			w.view_state.rtf_tooltip_text = '' // Clear before checking for new tooltip
			mouse_move_handler(layout, mut e, mut w)
		}
		.mouse_up {
			mouse_up_handler(layout, mut e, mut w)
		}
		.mouse_scroll {
			mouse_scroll_handler(layout, mut e, mut w)
		}
		.resized {
			w.update_window_size()
		}
		else {
			// dump(e)
		}
	}
	if !e.is_handled {
		w.on_event(e, mut w)
	}
	if e.is_handled {
		log.debug('event_fn: ${e.typ} handled: ${e}')
	}
	w.view_state.tooltip.id = ''
	w.update_window()
}
