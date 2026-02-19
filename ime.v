module gui

// ime.v provides window-level IME (Input Method Editor) support.
// A single StandardIMEHandler per window routes composition events
// to whichever input field currently has focus. The native overlay
// is created lazily because the native window handle is not ready
// during init_fn.
// Linux IME: pending vglyph overlay support; overlay stays nil.
import sokol.sapp
import vglyph

// IME holds per-window Input Method Editor state.
// Created lazily because the native window is not ready during
// init_fn.
struct IME {
mut:
	overlay     voidptr = unsafe { nil }
	handler     voidptr = unsafe { nil }
	initialized bool
}

// ime_create_overlay creates the platform-specific IME overlay.
// Returns nil on platforms without IME overlay support.
fn ime_create_overlay() voidptr {
	$if macos {
		ns_window := sapp.macos_get_window()
		if ns_window == unsafe { nil } {
			return unsafe { nil }
		}
		return vglyph.ime_overlay_create_auto(ns_window)
	} $else {
		// Linux: vglyph stubs return nil (no overlay yet).
		return unsafe { nil }
	}
}

// init_ime lazily creates the IME overlay and registers
// callbacks via VGlyph's StandardIMEHandler.
fn (mut w Window) init_ime() {
	if w.ime.initialized {
		return
	}
	w.ime.initialized = true

	overlay := ime_create_overlay()
	if overlay == unsafe { nil } {
		return
	}
	w.ime.overlay = overlay

	handler := &vglyph.StandardIMEHandler{
		ts:               w.text_system
		user_data:        w
		on_commit:        ime_on_commit
		on_update:        ime_on_update
		get_layout:       ime_get_layout
		get_offset:       ime_get_offset
		get_cursor_index: ime_get_cursor_index
	}
	w.ime.handler = handler
	w.text_system.register_ime_callbacks(overlay, handler)

	// Apply focus if already set before overlay was ready.
	if w.view_state.id_focus > 0 {
		w.update_ime_focus(w.view_state.id_focus)
	}
}

// update_ime_focus makes the IME overlay first responder when
// a focusable input field gains focus, or clears it when focus
// is lost (id == 0). Only activates for elements with
// on_ime_commit (input fields), not menus or other focusables.
fn (mut w Window) update_ime_focus(id u32) {
	if w.ime.overlay == unsafe { nil } {
		return
	}
	if id > 0 {
		if w.layout.shape == unsafe { nil } {
			return
		}
		ly := find_layout_by_id_focus(&w.layout, id) or {
			vglyph.ime_overlay_set_focused_field(w.ime.overlay, '')
			return
		}
		if ly.shape.has_events() && ly.shape.events.on_ime_commit != unsafe { nil } {
			vglyph.ime_overlay_set_focused_field(w.ime.overlay, '${id}')
		} else {
			vglyph.ime_overlay_set_focused_field(w.ime.overlay, '')
		}
	} else {
		vglyph.ime_overlay_set_focused_field(w.ime.overlay, '')
	}
}

// ime_on_commit is called when the IME commits final text.
// Finds the focused input's on_ime_commit callback and
// invokes it.
fn ime_on_commit(text string, data voidptr) {
	if data == unsafe { nil } {
		return
	}
	mut w := unsafe { &Window(data) }
	id_focus := w.view_state.id_focus
	if id_focus == 0 {
		return
	}
	ly := find_layout_by_id_focus(&w.layout, id_focus) or { return }
	if ly.shape.has_events() && ly.shape.events.on_ime_commit != unsafe { nil } {
		ly.shape.events.on_ime_commit(&ly, text, mut w)
	}
}

// ime_on_update triggers a window refresh after any IME
// state change (marked text, commit, unmark).
fn ime_on_update(data voidptr) {
	if data == unsafe { nil } {
		return
	}
	mut w := unsafe { &Window(data) }
	w.update_window()
}

// ime_get_layout returns the vglyph Layout of the focused
// text shape for composition bounds calculation.
fn ime_get_layout(data voidptr) &vglyph.Layout {
	if data == unsafe { nil } {
		return unsafe { nil }
	}
	w := unsafe { &Window(data) }
	id_focus := w.view_state.id_focus
	if id_focus == 0 {
		return unsafe { nil }
	}
	ly := find_layout_by_id_focus(&w.layout, id_focus) or { return unsafe { nil } }
	if ly.shape.has_text_layout() {
		return ly.shape.tc.vglyph_layout
	}
	// Input fields nest the text shape inside children.
	// Walk children to find the text shape with matching
	// id_focus.
	child := find_layout_by_id_focus(&ly, id_focus) or { return unsafe { nil } }
	if child.shape.has_text_layout() {
		return child.shape.tc.vglyph_layout
	}
	return unsafe { nil }
}

// ime_get_offset returns the screen position of the focused
// text shape (top-left corner including padding).
fn ime_get_offset(data voidptr) (f32, f32) {
	if data == unsafe { nil } {
		return 0, 0
	}
	w := unsafe { &Window(data) }
	shape := ime_focused_text_shape(w) or { return 0, 0 }
	return shape.x + shape.padding_left(), shape.y + shape.padding_top()
}

// ime_get_cursor_index returns the byte index of the cursor
// in the focused text shape's text.
fn ime_get_cursor_index(data voidptr) int {
	if data == unsafe { nil } {
		return 0
	}
	w := unsafe { &Window(data) }
	id_focus := w.view_state.id_focus
	if id_focus == 0 {
		return 0
	}
	input_state := w.view_state.input_state.get(id_focus) or { InputState{} }
	shape := ime_focused_text_shape(w) or { return 0 }
	return rune_to_byte_index(shape.tc.text, input_state.cursor_pos)
}

// ime_focused_text_shape finds the text Shape that currently
// has focus. Input fields nest a text child; this helper walks
// down to find it.
fn ime_focused_text_shape(w &Window) ?Shape {
	id_focus := w.view_state.id_focus
	if id_focus == 0 {
		return none
	}
	ly := find_layout_by_id_focus(&w.layout, id_focus) or { return none }
	if ly.shape.shape_type == .text {
		return *ly.shape
	}
	// Input column wraps a text child with same id_focus
	child := find_layout_by_id_focus(&ly, id_focus) or { return none }
	if child.shape.shape_type == .text {
		return *child.shape
	}
	return none
}
