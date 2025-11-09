module gui

pub struct MouseLockCfg {
pub:
	mouse_down ?fn (&Layout, mut Event, mut Window)
	mouse_move ?fn (&Layout, mut Event, mut Window)
	mouse_up   ?fn (&Layout, mut Event, mut Window)
}

fn char_handler(layout &Layout, mut e Event, mut w Window) {
	for child in layout.children {
		char_handler(child, mut e, mut w)
		if e.is_handled {
			return
		}
	}
	if e.is_handled || layout.shape.disabled || layout.shape.id_focus == 0 {
		return
	}
	if layout.shape.id_focus == w.view_state.id_focus {
		if layout.shape.on_char != unsafe { nil } {
			layout.shape.on_char(layout, mut e, mut w)
			if e.is_handled {
				return
			}
		}
	}
}

fn keydown_handler(layout &Layout, mut e Event, mut w Window) {
	for child in layout.children {
		keydown_handler(child, mut e, mut w)
		if e.is_handled {
			return
		}
	}
	if e.is_handled || layout.shape.disabled {
		return
	}
	if w.is_focus(layout.shape.id_focus) || layout.shape.id == reserved_dialog_id {
		if layout.shape.id_scroll > 0 {
			key_down_scroll_handler(layout, mut e, mut w)
			if e.is_handled {
				return
			}
		}
		if layout.shape.on_keydown != unsafe { nil } {
			layout.shape.on_keydown(layout, mut e, mut w)
			if e.is_handled {
				return
			}
		}
	} else {
		if layout.shape.id_scroll > 0 {
			key_down_scroll_handler(layout, mut e, mut w)
			if e.is_handled {
				return
			}
		}
	}
}

fn key_down_scroll_handler(layout &Layout, mut e Event, mut w Window) {
	delta_line := gui_theme.scroll_delta_line
	delta_page := gui_theme.scroll_delta_page
	delta_home := 10000000 // any really big number works
	if e.modifiers == 0 {
		match e.key_code {
			.up { e.is_handled = scroll_vertical(layout, delta_line, mut w) }
			.down { e.is_handled = scroll_vertical(layout, -delta_line, mut w) }
			.home { e.is_handled = scroll_vertical(layout, delta_home, mut w) }
			.end { e.is_handled = scroll_vertical(layout, -delta_home, mut w) }
			.page_up { e.is_handled = scroll_vertical(layout, delta_page, mut w) }
			.page_down { e.is_handled = scroll_vertical(layout, -delta_page, mut w) }
			else {}
		}
	} else if e.modifiers == u32(Modifier.shift) {
		match e.key_code {
			.left { e.is_handled = scroll_horizontal(layout, delta_line, mut w) }
			.right { e.is_handled = scroll_horizontal(layout, -delta_line, mut w) }
			else {}
		}
	}
}

fn mouse_down_handler(layout &Layout, in_handler bool, mut e Event, mut w Window) {
	if !in_handler { // limits checking to once per tree walk.
		if w.view_state.mouse_lock.mouse_down != none {
			w.view_state.mouse_lock.mouse_down(layout, mut e, mut w)
			return
		}
	}
	for i := layout.children.len - 1; layout.children.len > 0 && i >= 0; i-- {
		child := unsafe { &layout.children[i] }
		mouse_down_handler(child, true, mut e, mut w)
		if e.is_handled {
			return
		}
	}
	if e.is_handled || layout.shape.disabled {
		return
	}
	if layout.shape.point_in_shape(e.mouse_x, e.mouse_y) {
		if layout.shape.id_focus > 0 {
			w.set_id_focus(layout.shape.id_focus)
		}
		if layout.shape.on_click != unsafe { nil } {
			// make click handler mouse coordinates relative to layout.shape
			mut ev := event_relative_to(layout.shape, e)
			layout.shape.on_click(layout, mut ev, mut w)
			if ev.is_handled {
				e.is_handled = true
				return
			}
		}
	}
}

fn mouse_move_handler(layout &Layout, mut e Event, mut w Window) {
	if w.view_state.mouse_lock.mouse_move != none {
		w.view_state.mouse_lock.mouse_move(layout, mut e, mut w)
		return
	}
	if !w.pointer_over_app(e) {
		return
	}
	for i := layout.children.len - 1; layout.children.len > 0 && i >= 0; i-- {
		child := unsafe { &layout.children[i] }
		mouse_move_handler(child, mut e, mut w)
		if e.is_handled {
			return
		}
	}
	if layout.shape.point_in_shape(e.mouse_x, e.mouse_y) {
		if layout.shape.on_mouse_move != unsafe { nil } {
			// make move handler mouse coordinates relative to layout.shape
			mut ev := event_relative_to(layout.shape, e)
			layout.shape.on_mouse_move(layout, mut ev, mut w)
			if ev.is_handled {
				e.is_handled = true
				return
			}
		}
	}
	if e.is_handled || layout.shape.disabled {
		return
	}
}

fn mouse_up_handler(layout &Layout, mut e Event, mut w Window) {
	if w.view_state.mouse_lock.mouse_up != none {
		w.view_state.mouse_lock.mouse_up(layout, mut e, mut w)
		return
	}
	for i := layout.children.len - 1; layout.children.len > 0 && i >= 0; i-- {
		child := unsafe { &layout.children[i] }
		mouse_up_handler(child, mut e, mut w)
		if e.is_handled {
			return
		}
	}
	if e.is_handled || layout.shape.disabled {
		return
	}
	if layout.shape.point_in_shape(e.mouse_x, e.mouse_y) {
		if layout.shape.id_focus > 0 {
			w.set_id_focus(layout.shape.id_focus)
		}
		if layout.shape.on_mouse_up != unsafe { nil } {
			// make up handler mouse coordinates relative to layout.shape
			mut ev := event_relative_to(layout.shape, e)
			layout.shape.on_mouse_up(layout, mut ev, mut w)
			if ev.is_handled {
				e.is_handled = true
				return
			}
		}
	}
}

fn mouse_scroll_handler(layout &Layout, mut e Event, mut w Window) {
	for i := layout.children.len - 1; layout.children.len > 0 && i >= 0; i-- {
		child := unsafe { &layout.children[i] }
		mouse_scroll_handler(child, mut e, mut w)
		if e.is_handled {
			return
		}
	}
	id_focus := w.id_focus()
	if id_focus != 0 {
		if shape := layout.find_shape(fn [id_focus] (n Layout) bool {
			return n.shape.id_focus == id_focus
		})
		{
			if shape.on_mouse_scroll_shape != unsafe { nil } {
				shape.on_mouse_scroll_shape(shape, mut e, mut w)
				return
			}
		}
	}
	if !layout.shape.disabled && layout.shape.id_scroll > 0 {
		if layout.shape.point_in_shape(e.mouse_x, e.mouse_y) {
			if e.modifiers == u32(Modifier.shift) {
				e.is_handled = scroll_horizontal(layout, e.scroll_x, mut w)
			} else {
				e.is_handled = scroll_vertical(layout, e.scroll_y, mut w)
			}
		}
	}
}

fn scroll_horizontal(layout &Layout, delta f32, mut w Window) bool {
	v_id := layout.shape.id_scroll
	if v_id > 0 {
		// scrollable region does not including padding
		max_offset := f32_min(0, layout.shape.width - layout.shape.padding.width() - content_width(layout))
		offset_x := w.view_state.offset_x_state[v_id] + delta * gui_theme.scroll_multiplier
		w.view_state.offset_x_state[v_id] = f32_clamp(offset_x, max_offset, 0)
		return true
	}
	return false
}

fn scroll_vertical(layout &Layout, delta f32, mut w Window) bool {
	v_id := layout.shape.id_scroll
	if v_id > 0 {
		// scrollable region does not including padding
		max_offset := f32_min(0, layout.shape.height - layout.shape.padding.height() - content_height(layout))
		offset_y := w.view_state.offset_y_state[v_id] + delta * gui_theme.scroll_multiplier
		w.view_state.offset_y_state[v_id] = f32_clamp(offset_y, max_offset, 0)
		return true
	}
	return false
}
