module gui

import sokol.sapp

// Generating views and immediate mode means there is no place to
// store view states. The view states GUI needs are minimal but
// necessary.
struct ViewState {
pub mut:
	id_focus       u32
	input_state    map[u32]InputState // [id_focus] -> input state
	offset_x_state map[u32]f32        // [id_scroll] -> offset_x
	offset_y_state map[u32]f32        // [id_scroll] -> offset_y
	text_widths    map[string]int     // [text + hash(text_style)] -> text width
	mouse_cursor   sapp.MouseCursor   // arrow, finger, ibeam, etc.
	mouse_lock     MouseLockCfg
}

fn (mut vs ViewState) clear() {
	vs.id_focus = 0
	vs.input_state.clear()
	vs.offset_x_state.clear()
	vs.offset_y_state.clear()
	vs.text_widths.clear()
	vs.mouse_lock = MouseLockCfg{}
	vs.mouse_cursor = .arrow
}
