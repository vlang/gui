module gui

import datatypes
import sokol.sapp

// Generating views and immediate mode means there is no place to
// store view states. This is gui's solution.
struct ViewState {
mut:
	cursor_on      bool                       // used by cursor blink animation
	id_focus       u32                        // current view that has focus
	input_state    map[u32]InputState         // [id_focus] -> InputState
	offset_x_state map[u32]f32                // [id_scroll] -> offset x
	offset_y_state map[u32]f32                // [id_scroll] -> offset y
	text_widths    map[f32]int                // [text + hash(text_style)] -> text width
	mouse_cursor   sapp.MouseCursor           // arrow, finger, ibeam, etc.
	mouse_lock     MouseLockCfg               // mouse down/move/up methods to call when locked
	menu_state     map[u32]string             // [id_menubar] -> id of menu
	image_map      map[string]int             // [file name] -> context.cache image id
	select_state   map[string]bool            // [id select] -> open/close state
	tree_state     map[string]map[string]bool // [tree id] -> [node id ] -> open/closed
}

fn (mut vs ViewState) clear(mut w Window) {
	vs.id_focus = 0
	vs.input_state.clear()
	vs.offset_x_state.clear()
	vs.offset_y_state.clear()
	vs.text_widths.clear()
	vs.mouse_cursor = .arrow
	vs.mouse_lock = MouseLockCfg{}
	vs.menu_state.clear()
	// image cache
	mut ctx := w.context()
	for idx in vs.image_map.values() {
		ctx.remove_cached_image_by_idx(idx)
	}
	vs.image_map.clear()
	vs.select_state.clear()
	vs.tree_state.clear()
}

// The management of focus and input states poses a problem in stateless views
// because...they're stateless. Instead, the window maintains this state in a
// map where the key is the w.view_state.id_focus. This state map is cleared when a new
// view is introduced.
struct InputState {
pub:
	// positions are number of runes relative to start of input text
	cursor_pos int
	select_beg u32
	select_end u32
	undo       datatypes.Stack[InputMemento]
	redo       datatypes.Stack[InputMemento]
}

struct InputMemento {
pub:
	text       string
	cursor_pos int
	select_beg u32
	select_end u32
}
