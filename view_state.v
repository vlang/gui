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
	cursor_on_sticky              bool // keeps the cursor visible during cursor movement
	id_focus                      u32  // current view that has focus
	input_cursor_on               bool = true // used by cursor blink animation
	menu_key_nav                  bool             // true, menu navigated by keyboard
	mouse_cursor                  sapp.MouseCursor // arrow, finger, ibeam, etc.
	mouse_lock                    MouseLockCfg     // mouse down/move/up/scroll/sliders, etc. use this
	rtf_tooltip_rect              gg.Rect          // RTF abbreviation tooltip anchor rect
	rtf_tooltip_text              string           // RTF abbreviation tooltip text
	tooltip                       TooltipState     // State for the active tooltip
	input_state                   BoundedMap[u32, InputState] = BoundedMap[u32, InputState]{
		max_size: 100
	}
	input_focus_state             BoundedMap[u32, bool] = BoundedMap[u32, bool]{
		max_size: 100
	}
	input_date_state              BoundedMap[string, bool] = BoundedMap[string, bool]{
		max_size: 50
	}
	scroll_x                      BoundedMap[u32, f32] = BoundedMap[u32, f32]{
		max_size: 200
	}
	scroll_y                      BoundedMap[u32, f32] = BoundedMap[u32, f32]{
		max_size: 200
	}
	menu_state                    BoundedMap[u32, string] = BoundedMap[u32, string]{
		max_size: 20
	}
	image_map                     BoundedImageMap = BoundedImageMap{
		max_size: 100
	}
	active_downloads              BoundedMap[string, i64] = BoundedMap[string, i64]{
		max_size: 50
	}
	svg_cache                     BoundedSvgCache = BoundedSvgCache{
		max_size: 100
	}
	markdown_cache                BoundedMarkdownCache = BoundedMarkdownCache{
		max_size: 50
	}
	select_state                  BoundedMap[string, bool] = BoundedMap[string, bool]{
		max_size: 50
	}
	select_highlight              BoundedMap[string, int] = BoundedMap[string, int]{
		max_size: 50
	}
	tree_state                    BoundedTreeState = BoundedTreeState{
		max_size: 30
	}
	date_picker_state             BoundedMap[string, DatePickerState] = BoundedMap[string, DatePickerState]{
		max_size: 20
	}
	date_picker_roller_state      BoundedMap[string, DatePickerRollerState] = BoundedMap[string, DatePickerRollerState]{
		max_size: 20
	}
	table_col_widths              BoundedMap[string, TableColCache] = BoundedMap[string, TableColCache]{
		max_size: 50
	}
	table_warned_no_id            BoundedMap[u64, bool] = BoundedMap[u64, bool]{
		max_size: 100
	}
	diagram_cache                 BoundedDiagramCache = BoundedDiagramCache{
		max_size: 200
	}
	progress_state                BoundedMap[string, f32] = BoundedMap[string, f32]{
		max_size: 50
	}
	color_picker_state            BoundedMap[string, ColorPickerState] = BoundedMap[string, ColorPickerState]{
		max_size: 20
	}
	data_grid_col_widths          BoundedMap[string, &DataGridColWidths] = BoundedMap[string, &DataGridColWidths]{
		max_size: 50
	}
	data_grid_resize_state        BoundedMap[string, DataGridResizeState] = BoundedMap[string, DataGridResizeState]{
		max_size: 20
	}
	data_grid_header_hover_col    BoundedMap[string, string] = BoundedMap[string, string]{
		max_size: 20
	}
	data_grid_range_state         BoundedMap[string, DataGridRangeState] = BoundedMap[string, DataGridRangeState]{
		max_size: 20
	}
	data_grid_column_chooser_open BoundedMap[string, bool] = BoundedMap[string, bool]{
		max_size: 20
	}
	data_grid_edit_state          BoundedMap[string, DataGridEditState] = BoundedMap[string, DataGridEditState]{
		max_size: 20
	}
	data_grid_source_state        BoundedMap[string, DataGridSourceState] = BoundedMap[string, DataGridSourceState]{
		max_size: 20
	}
	splitter_runtime_state        BoundedMap[string, SplitterRuntimeState] = BoundedMap[string, SplitterRuntimeState]{
		max_size: 20
	}
}

// ColorPickerState stores persistent HSV values for ColorPickers.
// This preserves hue even when color becomes grayscale (s=0 or v=0).
pub struct ColorPickerState {
pub:
	h f32
	s f32
	v f32
}

// SplitterRuntimeState stores transient splitter interaction state.
struct SplitterRuntimeState {
mut:
	last_handle_click_frame u64
}

// DataGridResizeState stores transient state for active column resizing.
struct DataGridResizeState {
mut:
	active            bool
	col_id            string
	start_mouse_x     f32
	start_width       f32
	last_click_frame  u64
	last_click_col_id string
}

// DataGridColWidths stores per-column runtime widths for a grid id.
struct DataGridColWidths {
	widths map[string]f32
}

// DataGridRangeState stores transient range-selection anchor state.
struct DataGridRangeState {
mut:
	anchor_row_id string
}

// DataGridEditState stores transient edit mode state for a grid id.
struct DataGridEditState {
mut:
	editing_row_id    string
	last_click_row_id string
	last_click_frame  u64
}

// DataGridSourceState stores async data-source runtime state per grid id.
struct DataGridSourceState {
mut:
	rows             []GridRow
	loading          bool
	load_error       string
	has_loaded       bool
	request_id       u64
	request_key      string
	query_signature  string
	current_cursor   string
	next_cursor      string
	prev_cursor      string
	offset_start     int
	row_count        ?int
	has_more         bool
	received_count   int
	request_count    int
	cancelled_count  int
	stale_drop_count int
	active_abort     &GridAbortController = unsafe { nil }
	pagination_kind  GridPaginationKind   = .cursor
	config_cursor    string
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
