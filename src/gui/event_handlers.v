module gui

import gg

fn click_handler(node Layout, e &gg.Event, mut w Window) bool {
	for child in node.children {
		if click_handler(child, e, mut w) {
			return true
		}
	}
	if !node.shape.disabled && node.shape.on_click != unsafe { nil } {
		if node.shape.point_in_shape(e.mouse_x, e.mouse_y) {
			if node.shape.id_focus > 0 {
				w.set_id_focus(node.shape.id_focus)
			}
			// give click handler mouse coordinates
			// relative to node.shape
			mouse_x := e.mouse_x - node.shape.x
			mouse_y := e.mouse_y - node.shape.y
			ev := &gg.Event{
				...e
				touches: e.touches // runtime mem error otherwise
				mouse_x: mouse_x
				mouse_y: mouse_y
			}
			if node.shape.on_click(node.shape.cfg, ev, w) {
				return true
			}
		}
	}
	return false
}

fn keydown_handler(node Layout, e &gg.Event, w &Window) bool {
	for child in node.children {
		if keydown_handler(child, e, w) {
			return true
		}
	}
	if node.shape.id_focus > 0 && !node.shape.disabled && node.shape.id_focus == w.id_focus {
		if node.shape.on_keydown != unsafe { nil } && node.shape.on_keydown(node.shape.cfg, e, w) {
			return true
		}
	}
	return false
}

fn mouse_scroll_handler(node Layout, e &gg.Event, mut w Window, parent Shape) {
	for child in node.children {
		mouse_scroll_handler(child, e, mut w, node.shape)
	}

	if !node.shape.disabled && node.shape.v_scroll_id > 0 {
		if node.shape.point_in_shape(e.mouse_x, e.mouse_y) {
			v_id := node.shape.v_scroll_id
			if v_id > 0 {
				max_offset := node.shape.height - node.shape.max_height - size_text_medium
				scroll_state := w.scroll_state[v_id]
				mut v_offset := scroll_state.v_offset + e.scroll_y * gui_theme.scroll_multiplier
				v_offset = f32_max(v_offset, max_offset)
				v_offset = f32_min(0, v_offset)
				w.scroll_state[v_id] = ScrollState{
					...scroll_state
					v_offset: v_offset
				}
			}
		}
	}
}
