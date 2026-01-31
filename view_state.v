module gui

import gg
import sokol.sapp

const max_svg_cache_size = 100
const max_markdown_cache_size = 50

// ViewState stores the transient state of the GUI views.
// Since views are regenerated every frame in immediate mode, this struct
// persists state like focus, scroll positions, and input selections across frames.
struct ViewState {
mut:
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
	mouse_cursor             sapp.MouseCursor        // arrow, finger, ibeam, etc.
	menu_state               map[u32]string          // [id_menubar] -> id of menu
	menu_key_nav             bool                    // true, menu navigated by keyboard
	image_map                BoundedImageMap         // [file name] -> context.cache image id (max 100)
	svg_cache                map[string]&CachedSvg   // [cache key] -> cached SVG data
	svg_cache_order          []string                // LRU order for svg_cache eviction
	markdown_cache           map[int][]MarkdownBlock // [source hash] -> parsed blocks
	markdown_cache_order     []int                   // FIFO order for markdown_cache eviction
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
	mouse_lock               MouseLockCfg // mouse down/move/up/scroll/sliders, etc. use this
	tooltip                  TooltipState // State for the active tooltip
	rtf_tooltip_rect         gg.Rect      // RTF abbreviation tooltip anchor rect
	id_focus                 u32          // current view that has focus
	cursor_on_sticky         bool         // keeps the cursor visible during cursor movement
	rtf_tooltip_text         string       // RTF abbreviation tooltip text
	input_cursor_on          bool = true // used by cursor blink animation
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

// clear releases all stored view state maps and resets the window's ViewState.
// Call this when a window is destroyed or needs its GUI state fully reinitialized.
fn (mut vs ViewState) clear(mut w Window) {
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
