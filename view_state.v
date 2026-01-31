module gui

import gg
import sokol.sapp

// ViewState stores the transient state of the GUI views.
// Since views are regenerated every frame in immediate mode, this struct
// persists state like focus, scroll positions, and input selections across frames.
//
// Key type rationale:
// - u32: widget IDs (hash-based) - input_state, scroll, menu_state, id_focus
// - string: user-provided identifiers - tree_state, date_picker_state, select_state
// - int: content hashes - markdown_cache
// - u64: data hashes - table_warned_no_id
struct ViewState {
mut:
	cursor_on_sticky         bool // keeps the cursor visible during cursor movement
	id_focus                 u32  // current view that has focus
	input_cursor_on          bool = true // used by cursor blink animation
	menu_key_nav             bool             // true, menu navigated by keyboard
	mouse_cursor             sapp.MouseCursor // arrow, finger, ibeam, etc.
	mouse_lock               MouseLockCfg     // mouse down/move/up/scroll/sliders, etc. use this
	rtf_tooltip_rect         gg.Rect          // RTF abbreviation tooltip anchor rect
	rtf_tooltip_text         string           // RTF abbreviation tooltip text
	tooltip                  TooltipState     // State for the active tooltip
	input_state              BoundedMap[u32, InputState] = BoundedMap[u32, InputState]{
		max_size: 100
	}
	input_date_state         BoundedMap[string, bool] = BoundedMap[string, bool]{
		max_size: 50
	}
	scroll_x                 BoundedMap[u32, f32] = BoundedMap[u32, f32]{
		max_size: 200
	}
	scroll_y                 BoundedMap[u32, f32] = BoundedMap[u32, f32]{
		max_size: 200
	}
	menu_state               BoundedMap[u32, string] = BoundedMap[u32, string]{
		max_size: 20
	}
	image_map                BoundedImageMap = BoundedImageMap{
		max_size: 100
	}
	svg_cache                BoundedSvgCache = BoundedSvgCache{
		max_size: 100
	}
	markdown_cache           BoundedMarkdownCache = BoundedMarkdownCache{
		max_size: 50
	}
	select_state             BoundedMap[string, bool] = BoundedMap[string, bool]{
		max_size: 50
	}
	select_highlight         BoundedMap[string, int] = BoundedMap[string, int]{
		max_size: 50
	}
	tree_state               BoundedTreeState = BoundedTreeState{
		max_size: 30
	}
	date_picker_state        BoundedMap[string, DatePickerState] = BoundedMap[string, DatePickerState]{
		max_size: 20
	}
	date_picker_roller_state BoundedMap[string, DatePickerRollerState] = BoundedMap[string, DatePickerRollerState]{
		max_size: 20
	}
	table_col_widths         BoundedMap[string, TableColCache] = BoundedMap[string, TableColCache]{
		max_size: 50
	}
	table_warned_no_id       BoundedMap[u64, bool] = BoundedMap[u64, bool]{
		max_size: 100
	}
}

// TableColCache stores cached column widths and hash for invalidation
struct TableColCache {
	hash   u64   // hash of table data for cache invalidation
	widths []f32 // cached column widths
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

// clear_view_state resets all GUI state for this window.
// Call when window destroyed or needs full GUI state reinitialization.
fn (mut w Window) clear_view_state() {
	mut ctx := w.context()
	w.view_state.image_map.clear(mut ctx)
	w.view_state = ViewState{}
}

fn (mut vs ViewState) clear_input_selections() {
	for key in vs.input_state.keys() {
		if value := vs.input_state.get(key) {
			vs.input_state.set(key, InputState{
				...value
				select_beg: 0
				select_end: 0
			})
		}
	}
}
