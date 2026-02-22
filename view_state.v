module gui

import gg
import sokol.sapp

// ViewState stores the transient state of the GUI views.
// Since views are regenerated every frame in immediate mode, this struct
// persists state like focus, scroll positions, and input selections across
// frames. Per-widget state lives in StateRegistry (see state_registry.v);
// specialized caches (images, SVG, markdown, trees, diagrams) remain as
// dedicated fields for type safety.
struct ViewState {
mut:
	cursor_on_sticky            bool // keeps the cursor visible during cursor movement
	id_focus                    u32  // current view that has focus
	input_cursor_on             bool = true // used by cursor blink animation
	menu_key_nav                bool             // true, menu navigated by keyboard
	mouse_cursor                sapp.MouseCursor // arrow, finger, ibeam, etc.
	mouse_lock                  MouseLockCfg     // mouse down/move/up/scroll/sliders, etc. use this
	rtf_tooltip_rect            gg.Rect          // RTF abbreviation tooltip anchor rect
	rtf_tooltip_text            string           // RTF abbreviation tooltip text
	tooltip                     TooltipState     // State for the active tooltip
	registry                    StateRegistry    // generic per-widget state maps
	image_map                   BoundedImageMap = BoundedImageMap{
		max_size: 100
	}
	svg_cache                   BoundedSvgCache = BoundedSvgCache{
		max_size: 100
	}
	svg_dim_cache               map[string][2]f32
	markdown_cache              BoundedMarkdownCache = BoundedMarkdownCache{
		max_size: 50
	}
	tree_state                  BoundedTreeState = BoundedTreeState{
		max_size: 30
	}
	external_api_warning_logged bool
	diagram_cache               BoundedDiagramCache = BoundedDiagramCache{
		max_size: 200
	}
	diagram_request_seq         u64
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

// DataGridPresentationCache stores cached display rows for a grid id.
struct DataGridPresentationCache {
	signature       u64
	rows            []DataGridDisplayRow
	data_to_display map[int]int
	group_ranges    map[string]int
	group_cols      []string
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

// DataGridCrudState stores staged CRUD state for a grid id.
struct DataGridCrudState {
mut:
	source_signature           u64
	local_rows_len             int = -1
	local_rows_id_signature    u64
	local_rows_signature_valid bool
	committed_rows             []GridRow
	working_rows               []GridRow
	dirty_row_ids              map[string]bool
	draft_row_ids              map[string]bool
	deleted_row_ids            map[string]bool
	next_draft_seq             int
	saving                     bool
	save_error                 string
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
	query_signature  u64
	current_cursor   string
	next_cursor      string
	prev_cursor      string
	offset_start     int
	row_count        ?int
	has_more         bool
	received_count   int // latest page count only (reset per fetch)
	request_count    int
	cancelled_count  int
	stale_drop_count int
	active_abort     &GridAbortController = unsafe { nil }
	pagination_kind  GridPaginationKind   = .cursor
	config_cursor    string
	pending_jump_row int = -1
	cached_caps      GridDataCapabilities
	caps_cached      bool
	rows_dirty       bool = true
	rows_signature   u64
}

// ListBoxSourceState stores async data-source runtime state per list-box id.
struct ListBoxSourceState {
mut:
	data             []ListBoxOption
	loading          bool
	load_error       string
	has_loaded       bool
	request_id       u64
	request_key      string
	request_count    int
	cancelled_count  int
	stale_drop_count int
	received_count   int // cumulative across all requests
	active_abort     &GridAbortController = unsafe { nil }
	data_dirty       bool                 = true
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
	w.view_state.diagram_cache.clear()
	w.view_state.svg_cache.clear()
	w.view_state.markdown_cache.clear()
	w.view_state.registry.clear()
	w.view_state = ViewState{}
}

fn (mut w Window) clear_input_selections() {
	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	for key in imap.keys() {
		if value := imap.get(key) {
			imap.set(key, InputState{
				...value
				select_beg: 0
				select_end: 0
			})
		}
	}
}
