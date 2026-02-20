// Virtualized data grid with sorting, grouping, pagination,
// frozen rows/columns, inline cell editing, CRUD operations,
// row selection, column reordering/resizing/pinning, detail
// row expansion, and CSV/TSV/XLSX/PDF export.
module gui

import hash.fnv1a
import strconv
import time

const data_grid_virtual_buffer_rows = 2
const data_grid_resize_double_click_frames = u64(24) // ~400ms at 60fps
const data_grid_edit_double_click_frames = u64(36) // ~600ms at 60fps
const data_grid_resize_handle_width = f32(6)
const data_grid_autofit_padding = f32(18)
const data_grid_autofit_max_rows = 1000
const data_grid_indicator_alpha = u8(140)
const data_grid_resize_key_step = f32(8)
const data_grid_resize_key_step_large = f32(24)
const data_grid_header_control_width = f32(12)
const data_grid_header_reorder_spacing = f32(1)
const data_grid_header_label_min_width = f32(24)
const data_grid_group_indent_step = f32(14)
const data_grid_detail_indent_gap = f32(4)
const data_grid_pdf_page_width = f32(612)
const data_grid_pdf_page_height = f32(792)
const data_grid_pdf_margin = f32(40)
const data_grid_pdf_font_size = f32(10)
const data_grid_pdf_line_height = f32(12)
const data_grid_record_sep = '\x1e'
const data_grid_unit_sep = '\x1f'
const data_grid_group_sep = '\x1d'

pub enum GridSortDir as u8 {
	asc
	desc
}

pub enum GridColumnPin as u8 {
	none
	left
	right
}

pub enum GridAggregateOp as u8 {
	count
	sum
	avg
	min
	max
}

pub enum GridCellEditorKind as u8 {
	text
	select
	date
	checkbox
}

@[minify]
pub struct GridSort {
pub:
	col_id string
	dir    GridSortDir = .asc
}

@[minify]
pub struct GridFilter {
pub:
	col_id string
	op     string = 'contains'
	value  string
}

@[minify]
pub struct GridQueryState {
pub mut:
	sorts        []GridSort
	filters      []GridFilter
	quick_filter string
}

@[minify]
pub struct GridSelection {
pub:
	anchor_row_id    string
	active_row_id    string
	selected_row_ids map[string]bool
}

@[minify]
pub struct GridColumnCfg {
pub:
	id                 string @[required]
	title              string @[required]
	width              f32  = 120
	min_width          f32  = 60
	max_width          f32  = 600
	resizable          bool = true
	reorderable        bool = true
	sortable           bool = true
	filterable         bool = true
	editable           bool
	editor             GridCellEditorKind = .text
	editor_options     []string
	editor_true_value  string = 'true'
	editor_false_value string = 'false'
	default_value      string
	pin                GridColumnPin   = .none
	align              HorizontalAlign = .start
	text_style         ?TextStyle
}

@[minify]
pub struct GridRow {
pub:
	id    string @[required]
	cells map[string]string
}

@[minify]
pub struct GridAggregateCfg {
pub:
	col_id string
	op     GridAggregateOp = .count
	label  string
}

@[minify]
pub struct GridCellEdit {
pub:
	row_id  string
	row_idx int
	col_id  string
	value   string
}

@[minify]
pub struct GridCsvData {
pub:
	columns []GridColumnCfg
	rows    []GridRow
}

@[minify]
pub struct GridExportCfg {
pub:
	sanitize_spreadsheet_formulas bool = true
	xlsx_auto_type                bool
}

@[minify]
pub struct GridCellFormat {
pub:
	has_bg_color   bool
	bg_color       Color
	has_text_color bool
	text_color     Color
}

enum DataGridDisplayRowKind as u8 {
	data
	group_header
	detail
}

struct DataGridDisplayRow {
	kind            DataGridDisplayRowKind
	data_row_idx    int = -1
	group_col_id    string
	group_value     string
	group_col_title string
	group_depth     int
	group_count     int
	aggregate_text  string
}

struct DataGridPresentation {
	rows            []DataGridDisplayRow
	data_to_display map[int]int
}

@[minify]
pub struct DataGridCfg {
pub:
	id                        string @[required]
	id_focus                  u32
	id_scroll                 u32
	columns                   []GridColumnCfg @[required]
	column_order              []string
	group_by                  []string
	aggregates                []GridAggregateCfg
	rows                      []GridRow
	data_source               ?DataGridDataSource
	pagination_kind           GridPaginationKind = .cursor
	cursor                    string
	page_limit                int = 100
	row_count                 ?int
	loading                   bool
	load_error                string
	show_crud_toolbar         bool
	allow_create              bool = true
	allow_delete              bool = true
	query                     GridQueryState
	selection                 GridSelection
	multi_sort                bool = true
	multi_select              bool = true
	range_select              bool = true
	show_header               bool = true
	freeze_header             bool
	show_filter_row           bool
	show_quick_filter         bool
	show_column_chooser       bool
	show_group_counts         bool = true
	page_size                 int
	page_index                int
	hidden_column_ids         map[string]bool
	frozen_top_row_ids        []string
	detail_expanded_row_ids   map[string]bool
	quick_filter_placeholder  string            = gui_locale.str_search
	quick_filter_debounce     time.Duration     = 200 * time.millisecond
	row_height                f32               = 30
	header_height             f32               = 34
	color_background          Color             = gui_theme.data_grid_style.color_background
	color_header              Color             = gui_theme.data_grid_style.color_header
	color_header_hover        Color             = gui_theme.data_grid_style.color_header_hover
	color_filter              Color             = gui_theme.data_grid_style.color_filter
	color_quick_filter        Color             = gui_theme.data_grid_style.color_quick_filter
	color_row_hover           Color             = gui_theme.data_grid_style.color_row_hover
	color_row_alt             Color             = gui_theme.data_grid_style.color_row_alt
	color_row_selected        Color             = gui_theme.data_grid_style.color_row_selected
	color_border              Color             = gui_theme.data_grid_style.color_border
	color_resize_handle       Color             = gui_theme.data_grid_style.color_resize_handle
	color_resize_active       Color             = gui_theme.data_grid_style.color_resize_active
	padding_cell              Padding           = gui_theme.data_grid_style.padding_cell
	padding_header            Padding           = gui_theme.data_grid_style.padding_header
	padding_filter            Padding           = gui_theme.data_grid_style.padding_filter
	text_style                TextStyle         = gui_theme.data_grid_style.text_style
	text_style_header         TextStyle         = gui_theme.data_grid_style.text_style_header
	text_style_filter         TextStyle         = gui_theme.data_grid_style.text_style_filter
	radius                    f32               = gui_theme.data_grid_style.radius
	size_border               f32               = gui_theme.data_grid_style.size_border
	scrollbar                 ScrollbarOverflow = .auto
	sizing                    Sizing            = fill_fill
	width                     f32
	height                    f32
	min_width                 f32
	max_width                 f32
	min_height                f32
	max_height                f32
	on_query_change           fn (GridQueryState, mut Event, mut Window)                 = unsafe { nil }
	on_selection_change       fn (GridSelection, mut Event, mut Window)                  = unsafe { nil }
	on_column_order_change    fn ([]string, mut Event, mut Window)                       = unsafe { nil }
	on_column_pin_change      fn (string, GridColumnPin, mut Event, mut Window)          = unsafe { nil }
	on_hidden_columns_change  fn (hidden_ids map[string]bool, mut e Event, mut w Window) = unsafe { nil }
	on_page_change            fn (int, mut Event, mut Window) = unsafe { nil }
	on_detail_expanded_change fn (detail_ids map[string]bool, mut e Event, mut w Window)          = unsafe { nil }
	on_cell_edit              fn (GridCellEdit, mut Event, mut Window)                            = unsafe { nil }
	on_rows_change            fn ([]GridRow, mut Event, mut Window)                               = unsafe { nil }
	on_crud_error             fn (string, mut Event, mut Window)                                  = unsafe { nil }
	on_cell_format            fn (GridRow, int, GridColumnCfg, string, mut Window) GridCellFormat = unsafe { nil }
	on_detail_row_view        fn (GridRow, mut Window) View                 = unsafe { nil }
	on_copy_rows              fn ([]GridRow, mut Event, mut Window) ?string = unsafe { nil }
	on_row_activate           fn (GridRow, mut Event, mut Window)           = unsafe { nil }
	a11y_label                string // override label for screen readers
	a11y_description          string // extended help text
}

fn data_grid_indicator_text_style(base TextStyle) TextStyle {
	return TextStyle{
		...base
		color: data_grid_dim_color(base.color)
	}
}

fn data_grid_dim_color(c Color) Color {
	return Color{
		r: c.r
		g: c.g
		b: c.b
		a: data_grid_indicator_alpha
	}
}

// Shared button style for pager, CRUD toolbar, column
// chooser, and header controls. Transparent background,
// hover highlight, no border/radius, indicator text.
// When width > 0, uses fixed_fill; otherwise fit_fill.
fn data_grid_indicator_button(label string, text_style TextStyle, hover_color Color, disabled bool, width f32, on_click fn (&Layout, mut Event, mut Window)) View {
	return button(
		width:        width
		sizing:       if width > 0 { fixed_fill } else { fit_fill }
		padding:      padding_none
		size_border:  0
		radius:       0
		color:        color_transparent
		color_hover:  hover_color
		color_focus:  color_transparent
		color_click:  hover_color
		color_border: color_transparent
		disabled:     disabled
		on_click:     on_click
		content:      [
			text(
				text:       label
				mode:       .single_line
				text_style: data_grid_indicator_text_style(text_style)
			),
		]
	)
}

// data_grid renders a controlled, virtualized data grid view.
//
// Orchestration: resolve config → source/CRUD state →
// layout metrics → pagination → frozen rows →
// virtualization → view assembly.
pub fn (mut window Window) data_grid(cfg DataGridCfg) View {
	// Resolve data source (if any) and apply pending
	// jump/selection from a previous page change.
	resolved_cfg0, source_state0, has_source, source_caps := data_grid_resolve_source_cfg(cfg, mut
		window)
	mut resolved_cfg := resolved_cfg0
	mut source_state := source_state0
	if has_source {
		data_grid_source_apply_pending_jump_selection(resolved_cfg, source_state, mut
			window)
	}

	// If CRUD is enabled, overlay working copy of rows onto
	// the resolved config so edits are reflected in the grid.
	mut crud_state := DataGridCrudState{}
	crud_enabled := data_grid_crud_enabled(resolved_cfg)
	if crud_enabled {
		next_cfg, next_crud_state := data_grid_crud_resolve_cfg(resolved_cfg, mut window)
		resolved_cfg = next_cfg
		crud_state = next_crud_state
		if has_source {
			if latest_state := window.view_state.data_grid_source_state.get(resolved_cfg.id) {
				source_state = latest_state
			}
		}
	}

	// Interaction state: focus/scroll IDs, hovered/resizing
	// column, and column chooser visibility.
	row_delete_enabled := data_grid_crud_row_delete_enabled(resolved_cfg, has_source,
		source_caps)
	focus_id := data_grid_focus_id(resolved_cfg)
	scroll_id := data_grid_scroll_id(resolved_cfg)
	hovered_col_id := window.view_state.data_grid_header_hover_col.get(resolved_cfg.id) or { '' }
	resizing_col_id := data_grid_active_resize_col_id(resolved_cfg.id, window)
	chooser_open := window.view_state.data_grid_column_chooser_open.get(resolved_cfg.id) or {
		false
	}

	// Height/layout waterfall: static_top accumulates
	// non-scrolling zone heights (chooser, header, filter);
	// grid_height subtracts pager and toolbar; virtualize
	// requires both positive grid_height and rows; scroll_y
	// is negated because scroll state is stored negative.
	row_height := data_grid_row_height(resolved_cfg, mut window)
	header_in_scroll_body := resolved_cfg.show_header && !resolved_cfg.freeze_header
	static_top := data_grid_static_top_height(resolved_cfg, row_height, chooser_open,
		header_in_scroll_body)
	page_start, page_end, page_index, page_count := data_grid_page_bounds(resolved_cfg.rows.len,
		resolved_cfg.page_size, resolved_cfg.page_index)
	page_indices := data_grid_page_row_indices(page_start, page_end)
	frozen_top_indices, body_page_indices := data_grid_split_frozen_top_indices(resolved_cfg,
		page_indices)
	frozen_top_ids := data_grid_frozen_top_id_set(resolved_cfg)
	pager_enabled := data_grid_pager_enabled(resolved_cfg, page_count)
	source_pager_enabled := has_source
	mut grid_height := data_grid_height(resolved_cfg)
	if (pager_enabled || source_pager_enabled) && grid_height > 0 {
		grid_height = f32_max(0, grid_height - data_grid_pager_height(resolved_cfg))
	}
	if crud_enabled {
		toolbar_height := data_grid_crud_toolbar_height(resolved_cfg)
		if grid_height > 0 {
			grid_height = f32_max(0, grid_height - toolbar_height)
		}
	}
	virtualize := grid_height > 0 && resolved_cfg.rows.len > 0
	scroll_y := if virtualize {
		-(window.view_state.scroll_y.get(scroll_id) or { f32(0) })
	} else {
		f32(0)
	}

	// Build column list and flat display rows (with group
	// headers and detail rows interleaved). Apply any
	// pending jump-to-row scroll from a prior page change.
	columns := data_grid_effective_columns(resolved_cfg.columns, resolved_cfg.column_order,
		resolved_cfg.hidden_column_ids)
	presentation := data_grid_presentation_rows(resolved_cfg, columns, body_page_indices)
	if !has_source {
		data_grid_apply_pending_local_jump_scroll(resolved_cfg, grid_height, row_height,
			static_top, scroll_id, presentation.data_to_display, mut window)
	}

	// Build row ID set for O(1) membership checks and
	// clear stale editing state in the same pass.
	mut editing_row_id := data_grid_editing_row_id(resolved_cfg.id, window)
	mut row_id_set := map[string]bool{}
	mut editing_row_found := editing_row_id.len == 0
	for ri, r in resolved_cfg.rows {
		rid := data_grid_row_id(r, ri)
		row_id_set[rid] = true
		if !editing_row_found && rid == editing_row_id {
			editing_row_found = true
		}
	}
	if !editing_row_found {
		data_grid_clear_editing_row(resolved_cfg.id, mut window)
		editing_row_id = ''
	}
	focused_col_id := data_grid_header_focused_col_id(resolved_cfg, columns, window.id_focus())

	// Pre-build header, frozen top rows, and column widths
	// before entering the row assembly loop.
	mut column_widths := data_grid_column_widths(resolved_cfg.id, resolved_cfg.columns, mut
		window)
	total_width := data_grid_columns_total_width(columns, column_widths)
	header_view := data_grid_header_row(resolved_cfg, columns, column_widths, focus_id,
		hovered_col_id, resizing_col_id, focused_col_id)
	header_height := data_grid_header_height(resolved_cfg)
	frozen_top_views, frozen_top_display_rows := data_grid_frozen_top_views(resolved_cfg,
		frozen_top_indices, columns, column_widths, row_height, focus_id, editing_row_id,
		row_delete_enabled, mut window)
	scroll_x := window.view_state.scroll_x.get(scroll_id) or { f32(0) }
	last_row_idx := presentation.rows.len - 1

	// Virtual windowing: only rows in [first_visible,
	// last_visible] are instantiated. Transparent spacer
	// rectangles above and below fill the remaining height
	// so the scrollbar reflects total content size.
	first_visible, last_visible := if virtualize {
		data_grid_visible_range_for_scroll(scroll_y, grid_height, row_height, presentation.rows.len,
			static_top, data_grid_virtual_buffer_rows)
	} else {
		0, last_row_idx
	}

	// Assemble scroll body rows: optional column chooser,
	// non-frozen header, filter row, then source status
	// placeholders when data is loading or errored.
	mut rows := []View{cap: presentation.rows.len + 8}
	if resolved_cfg.show_column_chooser {
		rows << data_grid_column_chooser_row(resolved_cfg, chooser_open, focus_id)
	}
	if header_in_scroll_body {
		rows << header_view
	}
	if resolved_cfg.show_filter_row {
		rows << data_grid_filter_row(resolved_cfg, columns, column_widths)
	}
	if has_source && resolved_cfg.loading && presentation.rows.len == 0 {
		rows << data_grid_source_status_row(resolved_cfg, gui_locale.str_loading)
	}
	if has_source && resolved_cfg.load_error.len > 0 && presentation.rows.len == 0 {
		rows << data_grid_source_status_row(resolved_cfg, '${gui_locale.str_load_error}: ${resolved_cfg.load_error}')
	}

	if virtualize && first_visible > 0 {
		rows << rectangle(
			name:   'data_grid spacer top'
			color:  color_transparent
			height: f32(first_visible) * row_height
			sizing: fill_fixed
		)
	}

	// Emit visible rows: group headers, detail expansions,
	// or regular data rows depending on entry kind.
	for row_idx in first_visible .. last_visible + 1 {
		if row_idx < 0 || row_idx >= presentation.rows.len {
			continue
		}
		entry := presentation.rows[row_idx]
		if entry.kind == .group_header {
			rows << data_grid_group_header_row_view(resolved_cfg, entry, row_height)
			continue
		}
		if entry.kind == .detail {
			if entry.data_row_idx < 0 || entry.data_row_idx >= resolved_cfg.rows.len {
				continue
			}
			rows << data_grid_detail_row_view(resolved_cfg, resolved_cfg.rows[entry.data_row_idx],
				entry.data_row_idx, columns, column_widths, row_height, focus_id, mut
				window)
			continue
		}
		if entry.data_row_idx < 0 || entry.data_row_idx >= resolved_cfg.rows.len {
			continue
		}
		rows << data_grid_row_view(resolved_cfg, resolved_cfg.rows[entry.data_row_idx],
			entry.data_row_idx, columns, column_widths, row_height, focus_id, editing_row_id,
			row_delete_enabled, mut window)
	}

	if virtualize && last_visible < last_row_idx {
		remaining := last_row_idx - last_visible
		rows << rectangle(
			name:   'data_grid spacer bottom'
			color:  color_transparent
			height: f32(remaining) * row_height
			sizing: fill_fixed
		)
	}

	// Wrap all rows in a scrollable column with both
	// horizontal and vertical scrollbars.
	scrollbar_cfg := ScrollbarCfg{
		overflow: resolved_cfg.scrollbar
	}
	scroll_body := column(
		name:            'data_grid scroll body'
		id:              '${resolved_cfg.id}:scroll'
		id_scroll:       scroll_id
		scrollbar_cfg_x: &scrollbar_cfg
		scrollbar_cfg_y: &scrollbar_cfg
		color:           resolved_cfg.color_background
		padding:         data_grid_scroll_padding(resolved_cfg)
		spacing:         0
		sizing:          fill_fill
		content:         rows
	)

	// Frozen zone stacking order: CRUD toolbar → quick
	// filter → frozen header → frozen top rows → scroll
	// body → pager. Each frozen zone clips its content and
	// offsets by scroll_x to track horizontal scroll.
	mut content := []View{cap: 6}
	if crud_enabled {
		content << data_grid_crud_toolbar_row(resolved_cfg, crud_state, source_caps, has_source,
			focus_id)
	}
	if resolved_cfg.show_quick_filter {
		quick_filter_height := data_grid_quick_filter_height(resolved_cfg)
		content << data_grid_frozen_top_zone(resolved_cfg, [
			data_grid_quick_filter_row(resolved_cfg),
		], quick_filter_height, total_width, scroll_x)
	}
	if resolved_cfg.show_header && resolved_cfg.freeze_header {
		content << data_grid_frozen_top_zone(resolved_cfg, [header_view], header_height,
			total_width, scroll_x)
	}
	if frozen_top_display_rows > 0 {
		frozen_height := f32(frozen_top_display_rows) * row_height
		content << data_grid_frozen_top_zone(resolved_cfg, frozen_top_views, frozen_height,
			total_width, scroll_x)
	}
	content << scroll_body
	if pager_enabled {
		total_rows := if count := resolved_cfg.row_count { count } else { resolved_cfg.rows.len }
		jump_text := window.view_state.data_grid_jump_input.get(resolved_cfg.id) or { '' }
		content << data_grid_pager_row(resolved_cfg, focus_id, page_index, page_count,
			page_start, page_end, total_rows, grid_height, row_height, static_top, scroll_id,
			presentation.data_to_display, jump_text)
	}
	if source_pager_enabled {
		jump_text := window.view_state.data_grid_jump_input.get(resolved_cfg.id) or { '' }
		content << data_grid_source_pager_row(resolved_cfg, focus_id, source_state, source_caps,
			jump_text)
	}

	// Final assembly: outer column with keyboard/mouse
	// handlers wrapping all frozen zones and scroll body.
	return column(
		name:             'data_grid'
		id:               resolved_cfg.id
		id_focus:         focus_id
		a11y_role:        .grid
		a11y_label:       resolved_cfg.a11y_label
		a11y_description: resolved_cfg.a11y_description
		on_keydown:       make_data_grid_on_keydown(resolved_cfg, columns, row_height,
			static_top, scroll_id, page_indices, frozen_top_ids, presentation.data_to_display)
		on_char:          make_data_grid_on_char(resolved_cfg, columns)
		on_mouse_move:    make_data_grid_on_mouse_move(resolved_cfg.id)
		color:            resolved_cfg.color_background
		color_border:     resolved_cfg.color_border
		size_border:      resolved_cfg.size_border
		radius:           resolved_cfg.radius
		padding:          padding_none
		spacing:          0
		sizing:           resolved_cfg.sizing
		width:            resolved_cfg.width
		height:           resolved_cfg.height
		min_width:        resolved_cfg.min_width
		max_width:        resolved_cfg.max_width
		min_height:       resolved_cfg.min_height
		max_height:       resolved_cfg.max_height
		content:          content
	)
}

fn data_grid_presentation(cfg DataGridCfg, columns []GridColumnCfg) DataGridPresentation {
	return data_grid_presentation_rows(cfg, columns, data_grid_visible_row_indices(cfg.rows.len,
		[]int{}))
}

// Builds the flat display list from data rows, inserting
// group headers when grouped column values change. Group
// headers carry depth, count, and aggregate text. Detail
// expansion rows are interleaved after their parent data
// row. data_to_display maps data row index → display index
// for scroll-into-view.
fn data_grid_presentation_rows(cfg DataGridCfg, columns []GridColumnCfg, row_indices []int) DataGridPresentation {
	mut rows := []DataGridDisplayRow{cap: cfg.rows.len + 8}
	mut data_to_display := map[int]int{}
	visible_indices := data_grid_visible_row_indices(cfg.rows.len, row_indices)
	group_cols := data_grid_group_columns(cfg.group_by, columns)
	if group_cols.len == 0 || visible_indices.len == 0 {
		for row_idx in visible_indices {
			row := cfg.rows[row_idx]
			data_to_display[row_idx] = rows.len
			rows << DataGridDisplayRow{
				kind:         .data
				data_row_idx: row_idx
			}
			if cfg.on_detail_row_view != unsafe { nil }
				&& data_grid_detail_row_expanded(cfg, data_grid_row_id(row, row_idx)) {
				rows << DataGridDisplayRow{
					kind:         .detail
					data_row_idx: row_idx
				}
			}
		}
		return DataGridPresentation{
			rows:            rows
			data_to_display: data_to_display
		}
	}

	group_titles := data_grid_group_titles(columns)
	group_ranges := data_grid_group_ranges(cfg.rows, visible_indices, group_cols)
	mut prev_values := []string{len: group_cols.len}
	mut has_prev := false

	for local_idx, row_idx in visible_indices {
		row := cfg.rows[row_idx]
		mut values := []string{cap: group_cols.len}
		for col_id in group_cols {
			values << row.cells[col_id] or { '' }
		}
		mut change_depth := -1
		if !has_prev {
			change_depth = 0
		} else {
			for depth, value in values {
				if value != prev_values[depth] {
					change_depth = depth
					break
				}
			}
		}
		if change_depth >= 0 {
			for depth in change_depth .. group_cols.len {
				col_id := group_cols[depth]
				range_end_local := group_ranges[data_grid_group_range_key(depth, local_idx)] or {
					local_idx
				}
				range_end := visible_indices[range_end_local]
				count := int_max(0, range_end_local - local_idx + 1)
				rows << DataGridDisplayRow{
					kind:            .group_header
					group_col_id:    col_id
					group_value:     values[depth]
					group_col_title: group_titles[col_id] or { col_id }
					group_depth:     depth
					group_count:     count
					aggregate_text:  data_grid_group_aggregate_text(cfg, row_idx, range_end)
				}
			}
		}
		data_to_display[row_idx] = rows.len
		rows << DataGridDisplayRow{
			kind:         .data
			data_row_idx: row_idx
		}
		if cfg.on_detail_row_view != unsafe { nil }
			&& data_grid_detail_row_expanded(cfg, data_grid_row_id(row, row_idx)) {
			rows << DataGridDisplayRow{
				kind:         .detail
				data_row_idx: row_idx
			}
		}
		prev_values = unsafe { values }
		has_prev = true
	}

	return DataGridPresentation{
		rows:            rows
		data_to_display: data_to_display
	}
}

fn data_grid_group_columns(group_by []string, columns []GridColumnCfg) []string {
	if group_by.len == 0 {
		return []
	}
	mut available := map[string]bool{}
	for col in columns {
		if col.id.len > 0 {
			available[col.id] = true
		}
	}
	mut seen := map[string]bool{}
	mut cols := []string{cap: group_by.len}
	for col_id in group_by {
		if col_id.len == 0 || seen[col_id] || !available[col_id] {
			continue
		}
		seen[col_id] = true
		cols << col_id
	}
	return cols
}

fn data_grid_group_titles(columns []GridColumnCfg) map[string]string {
	mut titles := map[string]string{}
	for col in columns {
		if col.id.len == 0 {
			continue
		}
		titles[col.id] = col.title
	}
	return titles
}

fn data_grid_group_range_key(depth int, start_idx int) string {
	return '${depth}:${start_idx}'
}

// Pre-computes the contiguous range [start, end] for each
// group at each nesting depth. Walks rows sequentially;
// when a group value changes at depth D, closes ranges for
// depths D..max, then opens new ranges. Key format is
// "depth:start_idx". Accepts full rows array + indices to
// avoid copying row structs.
fn data_grid_group_ranges(rows []GridRow, indices []int, group_cols []string) map[string]int {
	mut ranges := map[string]int{}
	if indices.len == 0 || group_cols.len == 0 {
		return ranges
	}

	mut starts := []int{len: group_cols.len, init: 0}
	mut values := []string{len: group_cols.len}
	for depth, col_id in group_cols {
		values[depth] = rows[indices[0]].cells[col_id] or { '' }
	}

	for i in 1 .. indices.len {
		row := rows[indices[i]]
		mut change_depth := -1
		for depth, col_id in group_cols {
			value := row.cells[col_id] or { '' }
			if value != values[depth] {
				change_depth = depth
				break
			}
		}
		if change_depth < 0 {
			continue
		}

		mut depth := group_cols.len - 1
		for depth >= change_depth {
			ranges[data_grid_group_range_key(depth, starts[depth])] = i - 1
			if depth == 0 {
				break
			}
			depth--
		}

		for dep in change_depth .. group_cols.len {
			col_id := group_cols[dep]
			starts[dep] = i
			values[dep] = row.cells[col_id] or { '' }
		}
	}

	last := indices.len - 1
	mut depth := group_cols.len - 1
	for {
		ranges[data_grid_group_range_key(depth, starts[depth])] = last
		if depth == 0 {
			break
		}
		depth--
	}
	return ranges
}

fn data_grid_group_aggregate_text(cfg DataGridCfg, start_idx int, end_idx int) string {
	if cfg.aggregates.len == 0 || start_idx < 0 || end_idx < start_idx || end_idx >= cfg.rows.len {
		return ''
	}
	mut parts := []string{cap: cfg.aggregates.len}
	for agg in cfg.aggregates {
		value := data_grid_aggregate_value(cfg.rows, start_idx, end_idx, agg) or { continue }
		parts << '${data_grid_aggregate_label(agg)}: ${value}'
	}
	return parts.join('  ')
}

fn data_grid_aggregate_label(agg GridAggregateCfg) string {
	if agg.label.len > 0 {
		return agg.label
	}
	if agg.op == .count {
		return 'count'
	}
	if agg.col_id.len == 0 {
		return agg.op.str()
	}
	return '${agg.op.str()} ${agg.col_id}'
}

fn data_grid_aggregate_value(rows []GridRow, start_idx int, end_idx int, agg GridAggregateCfg) ?string {
	if agg.op == .count {
		return (end_idx - start_idx + 1).str()
	}
	if agg.col_id.len == 0 {
		return none
	}

	mut values := []f64{}
	for idx in start_idx .. end_idx + 1 {
		raw := rows[idx].cells[agg.col_id] or { continue }
		number := data_grid_parse_number(raw) or { continue }
		values << number
	}
	if values.len == 0 {
		return none
	}

	mut result := f64(0)
	match agg.op {
		.sum, .avg {
			for value in values {
				result += value
			}
			if agg.op == .avg {
				result = result / values.len
			}
		}
		.min {
			result = values[0]
			for value in values[1..] {
				if value < result {
					result = value
				}
			}
		}
		.max {
			result = values[0]
			for value in values[1..] {
				if value > result {
					result = value
				}
			}
		}
		else {}
	}

	return data_grid_format_number(result)
}

fn data_grid_parse_number(value string) ?f64 {
	trimmed := value.trim_space()
	if trimmed.len == 0 {
		return none
	}
	number := strconv.atof64(trimmed) or { return none }
	return number
}

fn data_grid_format_number(value f64) string {
	mut text := '${value:.4f}'
	for text.contains('.') && text.ends_with('0') {
		text = text[..text.len - 1]
	}
	if text.ends_with('.') {
		text = text[..text.len - 1]
	}
	return text
}

fn data_grid_row_id(row GridRow, idx int) string {
	if row.id.len > 0 {
		return row.id
	}
	auto_id := data_grid_row_auto_id(row)
	if auto_id.len > 0 {
		return auto_id
	}
	return idx.str()
}

// Generates deterministic row ID from cell content when no
// explicit ID is provided. Sorts cell keys for stability,
// joins as "key=value" pairs, hashes with FNV-1a. Prefixed
// with `__auto_` to avoid collisions with user IDs.
fn data_grid_row_auto_id(row GridRow) string {
	if row.cells.len == 0 {
		return ''
	}
	mut keys := row.cells.keys()
	keys.sort()
	mut parts := []string{cap: keys.len}
	for key in keys {
		value := row.cells[key] or { '' }
		parts << '${key}=${value}'
	}
	serialized := parts.join(data_grid_unit_sep)
	if serialized.len == 0 {
		return ''
	}
	hash := fnv1a.sum64_string(serialized)
	return '__auto_${hash:016x}'
}

fn data_grid_height(cfg DataGridCfg) f32 {
	if cfg.height > 0 {
		return cfg.height
	}
	if cfg.max_height > 0 {
		return cfg.max_height
	}
	return f32(0)
}

fn data_grid_pager_enabled(cfg DataGridCfg, page_count int) bool {
	return cfg.page_size > 0 && page_count > 1
}

fn data_grid_pager_height(cfg DataGridCfg) f32 {
	if cfg.row_height > 0 {
		return cfg.row_height
	}
	return data_grid_header_height(cfg)
}

fn data_grid_pager_padding(cfg DataGridCfg) Padding {
	left := f32_max(cfg.padding_filter.left, cfg.padding_cell.left)
	right := f32_max(cfg.padding_filter.right, cfg.padding_cell.right)
	return padding(cfg.padding_filter.top, right, cfg.padding_filter.bottom, left)
}

fn data_grid_header_height(cfg DataGridCfg) f32 {
	if cfg.header_height > 0 {
		return cfg.header_height
	}
	return cfg.row_height
}

fn data_grid_filter_height(cfg DataGridCfg) f32 {
	return data_grid_header_height(cfg)
}

fn data_grid_quick_filter_height(cfg DataGridCfg) f32 {
	return data_grid_header_height(cfg)
}

fn data_grid_row_height(cfg DataGridCfg, mut window Window) f32 {
	if cfg.row_height > 0 {
		return cfg.row_height
	}
	font_h := window.text_system.font_height(cfg.text_style.to_vglyph_cfg()) or {
		cfg.text_style.size
	}
	return font_h + cfg.padding_cell.height() + cfg.size_border
}

fn data_grid_static_top_height(cfg DataGridCfg, row_height f32, chooser_open bool, include_header bool) f32 {
	mut top := f32(0)
	if cfg.show_column_chooser {
		top += data_grid_column_chooser_height(cfg, chooser_open)
	}
	if include_header {
		top += data_grid_header_height(cfg)
	}
	if cfg.show_filter_row {
		top += data_grid_filter_height(cfg)
	}
	return top
}

fn data_grid_focus_id(cfg DataGridCfg) u32 {
	if cfg.id_focus > 0 {
		return cfg.id_focus
	}
	return fnv1a.sum32_string(cfg.id + ':focus')
}

fn data_grid_scroll_id(cfg DataGridCfg) u32 {
	if cfg.id_scroll > 0 {
		return cfg.id_scroll
	}
	return fnv1a.sum32_string(cfg.id + ':scroll')
}

// Converts scroll position to range of row indices to
// render. Subtracts static_top (non-scrolling header area)
// from scroll_y to get body-relative offset. Adds buffer
// rows above and below for smooth scrolling. Clamps to
// [0, row_count-1].
fn data_grid_visible_range_for_scroll(scroll_y f32, viewport_height f32, row_height f32, row_count int, static_top f32, buffer int) (int, int) {
	if row_count == 0 || row_height <= 0 || viewport_height <= 0 {
		return 0, -1
	}
	mut body_scroll := scroll_y - static_top
	if body_scroll < 0 {
		body_scroll = 0
	}
	first := int(body_scroll / row_height)
	visible_rows := int(viewport_height / row_height) + 1
	mut first_visible := first - buffer
	if first_visible < 0 {
		first_visible = 0
	}
	mut last_visible := first + visible_rows + buffer
	if last_visible > row_count - 1 {
		last_visible = row_count - 1
	}
	if first_visible > last_visible {
		first_visible = last_visible
	}
	return first_visible, last_visible
}
