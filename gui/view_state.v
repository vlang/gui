module gui

import sokol.sapp

// Generating views and immediate mode means there is no place to
// store view states. This is gui's solution.
struct ViewState {
pub mut:
	id_focus       u32
	input_state    map[u32]InputState // [id_focus] -> InputState
	offset_x_state map[u32]f32        // [id_scroll] -> offset x
	offset_y_state map[u32]f32        // [id_scroll] -> offset y
	text_widths    map[string]int     // [text + hash(text_style)] -> text width
	mouse_cursor   sapp.MouseCursor   // arrow, finger, ibeam, etc.
	mouse_lock     MouseLockCfg       // mouse down/move/up methods to call when locked
}

fn (mut vs ViewState) clear() {
	vs.id_focus = 0
	vs.input_state.clear()
	vs.offset_x_state.clear()
	vs.offset_y_state.clear()
	vs.text_widths.clear()
	vs.mouse_cursor = .arrow
	vs.mouse_lock = MouseLockCfg{}
}
