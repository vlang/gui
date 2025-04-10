module gui

import gg

fn char_handler(node Layout, e &gg.Event, w &Window) bool {
	for child in node.children {
		if char_handler(child, e, w) {
			return true
		}
	}
	if node.shape.id_focus > 0 && !node.shape.disabled && node.shape.id_focus == w.id_focus {
		if node.shape.on_char != unsafe { nil } && node.shape.on_char(node.shape.cfg, e, w) {
			return true
		}
	}
	return false
}

fn click_handler(node Layout, e &gg.Event, mut w Window) bool {
	for child in node.children {
		if click_handler(child, e, mut w) {
			return true
		}
	}
	if !node.shape.disabled {
		if node.shape.point_in_shape(e.mouse_x, e.mouse_y) {
			if node.shape.id_focus > 0 {
				w.set_id_focus(node.shape.id_focus)
			}
			// make click handler mouse coordinates
			// relative to node.shape
			mouse_x := e.mouse_x - node.shape.x
			mouse_y := e.mouse_y - node.shape.y
			ev := &gg.Event{
				...e
				touches: e.touches // runtime mem error otherwise
				mouse_x: mouse_x
				mouse_y: mouse_y
			}
			if node.shape.on_click != unsafe { nil } {
				if node.shape.on_click(node.shape.cfg, ev, w) {
					return true
				}
			}
		}
	}
	return false
}

fn keydown_handler(node Layout, e &gg.Event, mut w Window) bool {
	for child in node.children {
		if keydown_handler(child, e, mut w) {
			return true
		}
	}
	if !node.shape.disabled && w.is_focus(node.shape.id_focus) {
		if node.shape.on_keydown != unsafe { nil } {
			if node.shape.on_keydown(node.shape.cfg, e, w) {
				return true
			}
		}
		if node.shape.id_scroll_v > 0 {
			return key_down_scroll_handler(node, e, mut w)
		}
	}
	return false
}

fn key_down_scroll_handler(node Layout, e &gg.Event, mut w Window) bool {
	delta_line := gui_theme.scroll_delta_line
	delta_page := gui_theme.scroll_delta_page
	delta_home := 10000000 // any really big number works
	return match e.key_code {
		.up { scroll_vertical(node, delta_line, mut w) }
		.down { scroll_vertical(node, -delta_line, mut w) }
		.home { scroll_vertical(node, delta_home, mut w) }
		.end { scroll_vertical(node, -delta_home, mut w) }
		.page_up { scroll_vertical(node, delta_page, mut w) }
		.page_down { scroll_vertical(node, -delta_page, mut w) }
		else { false }
	}
}

fn mouse_scroll_handler(node Layout, e &gg.Event, mut w Window, parent Shape) {
	for child in node.children {
		mouse_scroll_handler(child, e, mut w, node.shape)
	}

	if !node.shape.disabled && node.shape.id_scroll_v > 0 {
		if node.shape.point_in_shape(e.mouse_x, e.mouse_y) {
			scroll_vertical(node, e.scroll_y, mut w)
		}
	}
}

fn scroll_vertical(node Layout, delta f32, mut w Window) bool {
	v_id := node.shape.id_scroll_v
	if v_id > 0 {
		scroll_state := w.scroll_state[v_id]
		max_offset := node.shape.height - node.shape.max_height - size_text_medium
		mut offset_v := scroll_state.offset_v + delta * gui_theme.scroll_multiplier
		offset_v = f32_max(offset_v, max_offset)
		offset_v = f32_min(0, offset_v)
		w.scroll_state[v_id] = ScrollState{
			...scroll_state
			offset_v: offset_v
		}
		return true
	}
	return false
}
