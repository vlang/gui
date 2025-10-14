module gui

import sokol.sapp

// Generating views and immediate mode means there is no place to
// store view states. This is gui's solution.
struct ViewState {
mut:
	input_state       map[u32]InputState         // [id_focus] -> InputState
	input_date_state  map[string]bool            // [id] -> visible
	offset_x_state    map[u32]f32                // [id_scroll] -> offset x
	offset_y_state    map[u32]f32                // [id_scroll] -> offset y
	text_widths       map[u32]f32                // [text + hash(text_style)] -> text width
	mouse_cursor      sapp.MouseCursor           // arrow, finger, ibeam, etc.
	menu_state        map[u32]string             // [id_menubar] -> id of menu
	image_map         map[string]int             // [file name] -> context.cache image id
	select_state      map[string]bool            // [id select] -> open/close state
	tree_state        map[string]map[string]bool // [tree id] -> [node id ] -> open/closed
	date_picker_state map[string]DatePickerState // [id date_picker -> DatePickerState
	mouse_lock        MouseLockCfg               // mouse down/move/up methods to call when locked
	id_focus          u32                        // current view that has focus
	cursor_on_sticky  bool                       // keeps the cursor visible during cursor movement
	cursor_on         bool = true // used by cursor blink animation
}

fn (mut vs ViewState) clear(mut w Window) {
	vs.input_state.clear()
	vs.input_date_state.clear()
	vs.offset_x_state.clear()
	vs.offset_y_state.clear()
	vs.text_widths.clear()
	vs.menu_state.clear()
	vs.image_map.clear()
	vs.select_state.clear()
	vs.tree_state.clear()
	vs.date_picker_state.clear()
	w.view_state = ViewState{}
}
