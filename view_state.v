module gui

import gg
import sokol.sapp

// ViewState stores the transient state of the GUI views.
// Since views are regenerated every frame in immediate mode, this struct
// persists state like focus, scroll positions, and input selections across frames.
struct ViewState {
mut:
	input_state              map[u32]InputState               // [id_focus] -> InputState
	input_date_state         map[string]bool                  // [id] -> visible
	scroll_x                 map[u32]f32                      // [id_scroll] -> scroll offset x
	scroll_y                 map[u32]f32                      // [id_scroll] -> scroll offset y
	mouse_cursor             sapp.MouseCursor                 // arrow, finger, ibeam, etc.
	menu_state               map[u32]string                   // [id_menubar] -> id of menu
	menu_key_nav             bool                             // true, menu navigated by keyboard
	image_map                map[string]int                   // [file name] -> context.cache image id
	svg_cache                map[string]&CachedSvg            // [cache key] -> cached SVG data
	markdown_cache           map[int][]MarkdownBlock          // [source hash] -> parsed blocks
	select_state             map[string]bool                  // [id select] -> open/close state
	select_highlight         map[string]int                   // [id select] -> highlighted index
	tree_state               map[string]map[string]bool       // [tree id] -> [node id ] -> open/closed
	date_picker_state        map[string]DatePickerState       // [id date_picker -> DatePickerState
	date_picker_roller_state map[string]DatePickerRollerState // [id] -> DatePickerRollerState
	mouse_lock               MouseLockCfg                     // mouse down/move/up/scroll/sliders, etc. use this
	id_focus                 u32  // current view that has focus
	cursor_on_sticky         bool // keeps the cursor visible during cursor movement
	input_cursor_on          bool = true // used by cursor blink animation
	tooltip                  TooltipState // State for the active tooltip
	rtf_tooltip_text         string       // RTF abbreviation tooltip text
	rtf_tooltip_rect         gg.Rect      // RTF abbreviation tooltip anchor rect
}

// MouseLockCfg stores callback functions for mouse event handling in a locked state.
// When mouse is locked, these callbacks intercept normal mouse event processing.
// Used for implementing drag operations and modal behaviors.
pub struct MouseLockCfg {
pub:
	cursor_pos int
	mouse_down ?fn (&Layout, mut Event, mut Window)
	mouse_move ?fn (&Layout, mut Event, mut Window)
	mouse_up   ?fn (&Layout, mut Event, mut Window)
}

// clear releases all stored view state maps and resets the window's ViewState.
// Call this when a window is destroyed or needs its GUI state fully reinitialized.
fn (mut vs ViewState) clear(mut w Window) {
	w.view_state = ViewState{}
}

fn (mut vs ViewState) clear_input_selections() {
	for key, value in vs.input_state {
		vs.input_state[key] = InputState{
			...value
			select_beg: 0
			select_end: 0
		}
	}
}
