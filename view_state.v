module gui

import sokol.sapp

// Generating views and immediate mode means there is no place to
// store view states. This is gui's solution.
struct ViewState {
mut:
	input_state            map[u32]InputState         // [id_focus] -> InputState
	input_date_state       map[string]bool            // [id] -> visible
	scroll_x               map[u32]f32                // [id_scroll] -> scroll offset x
	scroll_y               map[u32]f32                // [id_scroll] -> scroll offset y
	text_widths            map[u32]f32                // [text + hash(text_style)] -> text width
	mouse_cursor           sapp.MouseCursor           // arrow, finger, ibeam, etc.
	menu_state             map[u32]string             // [id_menubar] -> id of menu
	menu_key_nav           bool                       // true, menu navigated by keyboard
	image_map              map[string]int             // [file name] -> context.cache image id
	select_state           map[string]bool            // [id select] -> open/close state
	tree_state             map[string]map[string]bool // [tree id] -> [node id ] -> open/closed
	date_picker_state      map[string]DatePickerState // [id date_picker -> DatePickerState
	mouse_lock             MouseLockCfg               // mouse down/move/up methods to call when locked
	id_focus               u32                        // current view that has focus
	input_cursor_on_sticky bool                       // keeps the cursor visible during cursor movement
	input_cursor_on        bool = true // used by cursor blink animation
}

fn (mut vs ViewState) clear(mut w Window) {
	unsafe {
		vs.input_state.free()
		vs.input_date_state.free()
		vs.scroll_x.free()
		vs.scroll_y.free()
		vs.text_widths.free()
		vs.menu_state.free()
		vs.image_map.free()
		vs.select_state.free()
		vs.tree_state.free()
		vs.date_picker_state.free()
	}
	w.view_state = ViewState{}
}
