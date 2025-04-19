module gui

fn char_handler(node Layout, mut e Event, w &Window) {
	for child in node.children {
		char_handler(child, mut e, w)
		if e.is_handled {
			return
		}
	}
	if node.shape.id_focus > 0 && !node.shape.disabled && node.shape.id_focus == w.id_focus {
		if node.shape.on_char != unsafe { nil } {
			node.shape.on_char(node.shape.cfg, mut e, w)
			if e.is_handled {
				return
			}
		}
	}
}

fn keydown_handler(node Layout, mut e Event, mut w Window) {
	for child in node.children {
		keydown_handler(child, mut e, mut w)
		if e.is_handled {
			return
		}
	}
	if !node.shape.disabled && w.is_focus(node.shape.id_focus) {
		if node.shape.on_keydown_shape != unsafe { nil } {
			node.shape.on_keydown_shape(node.shape, mut e, w)
			if e.is_handled {
				return
			}
		}
		if node.shape.id_scroll_v > 0 {
			key_down_scroll_handler(node, mut e, mut w)
			if e.is_handled {
				return
			}
		}
		if node.shape.on_keydown != unsafe { nil } {
			node.shape.on_keydown(node.shape.cfg, mut e, w)
			if e.is_handled {
				return
			}
		}
	}
}

fn key_down_scroll_handler(node Layout, mut e Event, mut w Window) {
	delta_line := gui_theme.scroll_delta_line
	delta_page := gui_theme.scroll_delta_page
	delta_home := 10000000 // any really big number works
	match e.key_code {
		.up { e.is_handled = scroll_vertical(node, delta_line, mut w) }
		.down { e.is_handled = scroll_vertical(node, -delta_line, mut w) }
		.home { e.is_handled = scroll_vertical(node, delta_home, mut w) }
		.end { e.is_handled = scroll_vertical(node, -delta_home, mut w) }
		.page_up { e.is_handled = scroll_vertical(node, delta_page, mut w) }
		.page_down { e.is_handled = scroll_vertical(node, -delta_page, mut w) }
		else {}
	}
}

fn mouse_down_handler(node Layout, mut e Event, mut w Window) {
	for child in node.children {
		mouse_down_handler(child, mut e, mut w)
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
				node.shape.on_mouse_down_shape(node.shape, mut e, w)
				if e.is_handled {
					return
				}
			}
			// make click handler mouse coordinates relative to node.shape
			mut ev := event_relative_to(node.shape, e)
			if node.shape.on_click != unsafe { nil } {
				node.shape.on_click(node.shape.cfg, mut ev, w)
				if ev.is_handled {
					e.is_handled = true
					return
				}
			}
		}
	}
}

fn mouse_move_handler(node Layout, mut e Event, mut w Window) {
	if !w.pointer_over_app(e) {
		return
	}
	w.set_mouse_cursor_arrow()
	for child in node.children {
		mouse_move_handler(child, mut e, mut w)
		if e.is_handled {
			return
		}
	}
	if !node.shape.disabled {
		if node.shape.point_in_shape(e.mouse_x, e.mouse_y) {
			if node.shape.on_mouse_move_shape != unsafe { nil } {
				node.shape.on_mouse_move_shape(node.shape, mut e, w)
				if e.is_handled {
					return
				}
			}
		}
	}
}

fn mouse_scroll_handler(node Layout, mut e Event, mut w Window) {
	for child in node.children {
		mouse_scroll_handler(child, mut e, mut w)
		if e.is_handled {
			return
		}
	}

	if !node.shape.disabled && node.shape.id_scroll_v > 0 {
		if node.shape.point_in_shape(e.mouse_x, e.mouse_y) {
			e.is_handled = scroll_vertical(node, e.scroll_y, mut w)
		}
	}
}

fn scroll_vertical(node Layout, delta f32, mut w Window) bool {
	v_id := node.shape.id_scroll_v
	if v_id > 0 {
		ch := content_height(node)
		mut max_offset := node.shape.height - node.shape.padding.height() - ch
		scroll_offset_v := w.scroll_state_vertical[v_id]
		mut offset_v := scroll_offset_v + delta * gui_theme.scroll_multiplier
		offset_v = f32_max(offset_v, max_offset)
		offset_v = f32_min(0, offset_v)
		w.scroll_state_vertical[v_id] = offset_v
		return true
	}
	return false
}

fn content_height(node Layout) f32 {
	mut height := f32(0)
	if node.shape.axis == .top_to_bottom {
		height += node.spacing()
		for child in node.children {
			height += child.shape.height + child.shape.padding.height()
		}
	} else {
		for child in node.children {
			height = f32_max(height, child.shape.height + child.shape.padding.height())
		}
	}
	return height
}
