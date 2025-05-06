module gui

pub struct MouseLockCfg {
pub:
	mouse_down ?fn (&Layout, mut Event, mut Window)
	mouse_move ?fn (&Layout, mut Event, mut Window)
	mouse_up   ?fn (&Layout, mut Event, mut Window)
}

fn char_handler(node &Layout, mut e Event, mut w Window) {
	for child in node.children {
		char_handler(child, mut e, mut w)
		if e.is_handled {
			return
		}
	}
	if node.shape.id_focus > 0 && !node.shape.disabled && node.shape.id_focus == w.id_focus {
		if node.shape.on_char_shape != unsafe { nil } {
			node.shape.on_char_shape(node.shape, mut e, mut w)
			if e.is_handled {
				return
			}
		}
		if node.shape.on_char != unsafe { nil } {
			node.shape.on_char(node.shape.cfg, mut e, mut w)
			if e.is_handled {
				return
			}
		}
	}
}

fn keydown_handler(node &Layout, mut e Event, mut w Window) {
	for child in node.children {
		keydown_handler(child, mut e, mut w)
		if e.is_handled {
			return
		}
	}
	if node.shape.disabled {
		return
	}
	if w.is_focus(node.shape.id_focus) || node.shape.id == reserved_dialog_id {
		if node.shape.on_keydown_shape != unsafe { nil } {
			node.shape.on_keydown_shape(node.shape, mut e, mut w)
			if e.is_handled {
				return
			}
		}
		if node.shape.id_scroll > 0 {
			key_down_scroll_handler(node, mut e, mut w)
			if e.is_handled {
				return
			}
		}
		if node.shape.on_keydown != unsafe { nil } {
			node.shape.on_keydown(node.shape.cfg, mut e, mut w)
			if e.is_handled {
				return
			}
		}
	} else {
		if node.shape.id_scroll > 0 {
			key_down_scroll_handler(node, mut e, mut w)
			if e.is_handled {
				return
			}
		}
	}
}

fn key_down_scroll_handler(node &Layout, mut e Event, mut w Window) {
	delta_line := gui_theme.scroll_delta_line
	delta_page := gui_theme.scroll_delta_page
	delta_home := 10000000 // any really big number works
	if e.modifiers == 0 {
		match e.key_code {
			.up { e.is_handled = scroll_vertical(node, delta_line, mut w) }
			.down { e.is_handled = scroll_vertical(node, -delta_line, mut w) }
			.home { e.is_handled = scroll_vertical(node, delta_home, mut w) }
			.end { e.is_handled = scroll_vertical(node, -delta_home, mut w) }
			.page_up { e.is_handled = scroll_vertical(node, delta_page, mut w) }
			.page_down { e.is_handled = scroll_vertical(node, -delta_page, mut w) }
			else {}
		}
	} else if e.modifiers == u32(Modifier.shift) {
		match e.key_code {
			.left { e.is_handled = scroll_horizontal(node, delta_line, mut w) }
			.right { e.is_handled = scroll_horizontal(node, -delta_line, mut w) }
			else {}
		}
	}
}

fn mouse_down_handler(node &Layout, in_handler bool, mut e Event, mut w Window) {
	if !in_handler { // limits checking to once per tree walk.
		if w.mouse_lock.mouse_down != none {
			w.mouse_lock.mouse_down(node, mut e, mut w)
			return
		}
	}
	for child in node.children {
		mouse_down_handler(child, true, mut e, mut w)
		if e.is_handled {
			return
		}
	}
	if !node.shape.disabled {
		if node.shape.point_in_shape(e.mouse_x, e.mouse_y) {
			if node.shape.id_focus > 0 {
				w.set_id_focus(node.shape.id_focus)
			}
			if node.shape.on_mouse_down_shape != unsafe { nil } {
				node.shape.on_mouse_down_shape(node.shape, mut e, mut w)
				if e.is_handled {
					return
				}
			}
			// make click handler mouse coordinates relative to node.shape
			mut ev := event_relative_to(node.shape, e)
			if node.shape.on_click != unsafe { nil } {
				node.shape.on_click(node.shape.cfg, mut ev, mut w)
				if ev.is_handled {
					e.is_handled = true
					return
				}
			}
		}
	}
}

fn mouse_move_handler(node &Layout, mut e Event, mut w Window) {
	if w.mouse_lock.mouse_move != none {
		w.mouse_lock.mouse_move(node, mut e, mut w)
		return
	}
	if !w.pointer_over_app(e) {
		return
	}
	for child in node.children {
		mouse_move_handler(child, mut e, mut w)
		if e.is_handled {
			return
		}
	}
	if !node.shape.disabled {
		if node.shape.point_in_shape(e.mouse_x, e.mouse_y) {
			if node.shape.on_mouse_move_shape != unsafe { nil } {
				node.shape.on_mouse_move_shape(node.shape, mut e, mut w)
				if e.is_handled {
					return
				}
			}
		}
	}
}

fn mouse_up_handler(node &Layout, mut e Event, mut w Window) {
	if w.mouse_lock.mouse_up != none {
		w.mouse_lock.mouse_up(node, mut e, mut w)
		return
	}
	for child in node.children {
		mouse_up_handler(child, mut e, mut w)
		if e.is_handled {
			return
		}
	}
	if !node.shape.disabled {
		if node.shape.point_in_shape(e.mouse_x, e.mouse_y) {
			if node.shape.id_focus > 0 {
				w.set_id_focus(node.shape.id_focus)
			}
			if node.shape.on_mouse_up_shape != unsafe { nil } {
				node.shape.on_mouse_up_shape(node.shape, mut e, mut w)
				if e.is_handled {
					return
				}
			}
			// make up handler mouse coordinates relative to node.shape
			mut ev := event_relative_to(node.shape, e)
			if node.shape.on_mouse_up != unsafe { nil } {
				node.shape.on_mouse_up(node.shape.cfg, mut ev, mut w)
				if ev.is_handled {
					e.is_handled = true
					return
				}
			}
		}
	}
}

fn mouse_scroll_handler(node &Layout, mut e Event, mut w Window) {
	for child in node.children {
		mouse_scroll_handler(child, mut e, mut w)
		if e.is_handled {
			return
		}
	}
	if !node.shape.disabled && node.shape.id_scroll > 0 {
		if node.shape.point_in_shape(e.mouse_x, e.mouse_y) {
			if e.modifiers == u32(Modifier.shift) {
				e.is_handled = scroll_horizontal(node, e.scroll_x, mut w)
			} else {
				e.is_handled = scroll_vertical(node, e.scroll_y, mut w)
			}
		}
	}
}

fn scroll_horizontal(node &Layout, delta f32, mut w Window) bool {
	v_id := node.shape.id_scroll
	if v_id > 0 {
		// scrollable region does not including padding
		max_offset := f32_min(0, node.shape.width - node.shape.padding.width() - content_width(node))
		offset_x := w.offset_x_state[v_id] + delta * gui_theme.scroll_multiplier
		w.offset_x_state[v_id] = clamp_f32(offset_x, max_offset, 0)
		return true
	}
	return false
}

fn scroll_vertical(node &Layout, delta f32, mut w Window) bool {
	v_id := node.shape.id_scroll
	if v_id > 0 {
		// scrollable region does not including padding
		max_offset := f32_min(0, node.shape.height - node.shape.padding.height() - content_height(node))
		offset_y := w.offset_y_state[v_id] + delta * gui_theme.scroll_multiplier
		w.offset_y_state[v_id] = clamp_f32(offset_y, max_offset, 0)
		return true
	}
	return false
}
