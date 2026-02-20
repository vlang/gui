module gui

import encoding.csv
import log

const max_table_warned_size = 1000

// TableBorderStyle controls which borders are drawn in a table
pub enum TableBorderStyle {
	none        // no borders
	all         // full grid (default)
	horizontal  // horizontal lines between rows only
	header_only // single line under header row only
}

// TableCfg configures a table layout. It loosely follows the conventions of HTML tables.
// The `data` member consists of rows ([TableRowCfg](#TableRowCfg)) and cells
// ([TableCellCfg](#TableCellCfg)). Because the formatting of structs can use large amounts
// of vertical space, several helper methods are available:
//
// - `tr(cols []TableCellCfg)` creates a row from the given cells
// - `th(text string)` creates a header cell
// - `td(text string)` creates a data cell
//
// Example:
// ```v
// window.table(
// 	text_style_head: gui.theme().b2
// 	data:   [
// 		gui.tr([gui.th('First'), gui.th('Last'),     gui.th('Email')]),
// 		gui.tr([gui.td('Matt'),  gui.td('Williams'), gui.td('non.egestas.a@protonmail.org')]),
// 		gui.tr([gui.td('Clara'), gui.td('Nelson'),   gui.td('mauris.sagittis@icloud.net')]),
// 		gui.tr([gui.td('Frank'), gui.td('Johnson'),  gui.td('ac.libero.nec@aol.com')]),
// 		gui.tr([gui.td('Elmer'), gui.td('Fudd'),     gui.td('mus@aol.couk')]),
// 		gui.tr([gui.td('Roy'),   gui.td('Rogers'),   gui.td('amet.ultricies@yahoo.com')]),
// 	]
// )
// ```
@[minify]
pub struct TableCfg {
	SizeCfg
pub:
	id                   string
	color_border         Color = gui_theme.color_border
	color_select         Color = gui_theme.color_select
	color_hover          Color = gui_theme.color_hover
	color_row_alt        ?Color
	cell_padding         Padding         = padding_two_five
	text_style           TextStyle       = gui_theme.n3
	text_style_head      TextStyle       = gui_theme.b3
	align_head           HorizontalAlign = HorizontalAlign.center
	column_alignments    []HorizontalAlign // per-column data cell alignment
	column_width_default f32 = 50
	column_width_min     f32 = 20 // minimum column width
	size_border          f32
	size_border_header   f32 // optional header separator override
	border_style         TableBorderStyle = .all
	id_scroll            u32
	scrollbar            ScrollbarOverflow // default .auto shows scrollbar; use .hidden to hide
	multi_select         bool
	selected             map[int]bool // selected row indices (0-based, header is row 0)
	on_select            fn (selected map[int]bool, row_idx int, mut e Event, mut w Window) = unsafe { nil }
pub mut:
	data []TableRowCfg
}

// TableRowCfg configures a table row from the given cells
@[minify]
pub struct TableRowCfg {
pub:
	id       string
	cells    []TableCellCfg
	on_click fn (&Layout, mut Event, mut Window) = unsafe { nil }
}

// TableCellCfg configures a table cell
// Note: @[minify] not used due to V compiler bug with optional fields
pub struct TableCellCfg {
pub:
	id         string
	value      string
	rich_text  ?RichText // for accurate width calculation with mixed fonts
	head_cell  bool
	h_align    ?HorizontalAlign // optional per-cell override
	text_style ?TextStyle
	content    ?View // optional custom cell content (overrides value)
	on_click   fn (&Layout, mut Event, mut Window) = unsafe { nil }
}

// table generates a table from the given [TableCfg](#TableCfg)
pub fn (mut window Window) table(cfg TableCfg) View {
	column_widths := window.table_column_widths(cfg)
	last_row_idx := cfg.data.len - 1

	// Determine cell border based on style
	cell_border := match cfg.border_style {
		.all { cfg.size_border }
		else { f32(0) }
	}

	// Row spacing for .all style (negative to overlap borders)
	row_spacing := match cfg.border_style {
		.all { -cfg.size_border }
		else { f32(0) }
	}

	// Virtualization: only render visible rows for scrollable tables with constrained height
	table_height := if cfg.height > 0 { cfg.height } else { cfg.max_height }
	virtualize := cfg.id_scroll > 0 && table_height > 0 && cfg.data.len > 0
	row_height := table_estimate_row_height(cfg, mut window)
	first_visible, last_visible := if virtualize {
		table_visible_range(table_height, row_height, cfg, mut window)
	} else {
		0, last_row_idx
	}

	mut rows := []View{cap: (last_visible - first_visible + 1) * 2 + 2}

	// Add top spacer for virtualized rows
	if virtualize && first_visible > 0 {
		rows << rectangle(
			name:   'table spacer top'
			color:  color_transparent
			height: f32(first_visible) * row_height
			sizing: fill_fixed
		)
	}

	for row_idx in first_visible .. last_visible + 1 {
		if row_idx >= cfg.data.len {
			break
		}
		r := cfg.data[row_idx]
		mut cells := []View{cap: r.cells.len}
		for idx, cell in r.cells {
			cell_text_style := cell.text_style or {
				if cell.head_cell { cfg.text_style_head } else { cfg.text_style }
			}

			column_width := if idx < column_widths.len {
				column_widths[idx]
			} else {
				cfg.column_width_default
			}

			h_align := if align := cell.h_align {
				align
			} else if cell.head_cell {
				cfg.align_head
			} else if idx < cfg.column_alignments.len {
				cfg.column_alignments[idx]
			} else {
				HorizontalAlign.start
			}

			cell_content := if c := cell.content {
				[c]
			} else {
				[text(text: cell.value, text_style: cell_text_style)]
			}
			cells << column(
				name:         'table cell'
				color:        color_transparent
				color_border: cfg.color_border
				size_border:  cell_border
				padding:      cfg.cell_padding
				radius:       0
				spacing:      0
				h_align:      h_align
				sizing:       fixed_fill
				width:        column_width + cfg.cell_padding.width()
				on_click:     cell.on_click
				content:      cell_content
				on_hover:     fn [cell, cfg] (mut layout Layout, mut e Event, mut w Window) {
					if cell.on_click != unsafe { nil } {
						w.set_mouse_cursor_pointing_hand()
						layout.shape.color = cfg.color_hover
					}
				}
			)
		}

		// Determine row background color
		is_selected := cfg.selected[row_idx]
		row_color := if is_selected {
			cfg.color_select
		} else if alt := cfg.color_row_alt {
			if row_idx % 2 == 1 { alt } else { color_transparent }
		} else {
			color_transparent
		}

		// Row click handler - selection or custom
		row_on_click := r.on_click
		on_select := cfg.on_select
		selected := cfg.selected.clone()
		multi_select := cfg.multi_select

		rows << row(
			name:        'table row'
			color:       row_color
			spacing:     -cell_border
			radius:      0
			padding:     padding_none
			size_border: 0
			content:     cells
			on_click:    fn [row_idx, row_on_click, on_select, selected, multi_select] (layout &Layout, mut e Event, mut w Window) {
				if row_on_click != unsafe { nil } {
					row_on_click(layout, mut e, mut w)
				}
				if on_select != unsafe { nil } {
					mut new_selected := if multi_select {
						selected.clone()
					} else {
						map[int]bool{}
					}
					if new_selected[row_idx] {
						new_selected.delete(row_idx)
					} else {
						new_selected[row_idx] = true
					}
					on_select(new_selected, row_idx, mut e, mut w)
				}
			}
			on_hover:    fn [cfg, is_selected] (mut layout Layout, mut e Event, mut w Window) {
				if cfg.on_select != unsafe { nil } {
					w.set_mouse_cursor_pointing_hand()
					if !is_selected {
						layout.shape.color = cfg.color_hover
					}
				}
			}
		)

		// Add separator for horizontal/header_only styles
		separator_height := if row_idx == 0 && cfg.size_border_header > 0 {
			cfg.size_border_header
		} else {
			cfg.size_border
		}

		needs_separator := match cfg.border_style {
			.horizontal { row_idx != last_row_idx }
			.header_only { row_idx == 0 }
			else { false }
		}

		if needs_separator {
			rows << rectangle(
				name:   'table separator'
				color:  cfg.color_border
				height: separator_height
				sizing: fill_fixed
			)
		}
	}

	// Add bottom spacer for virtualized rows
	if virtualize && last_visible < last_row_idx {
		remaining := last_row_idx - last_visible
		rows << rectangle(
			name:   'table spacer bottom'
			color:  color_transparent
			height: f32(remaining) * row_height
			sizing: fill_fixed
		)
	}

	scrollbar_cfg := ScrollbarCfg{
		overflow: cfg.scrollbar
	}
	return column(
		name:            'table'
		id:              cfg.id
		id_scroll:       cfg.id_scroll
		scrollbar_cfg_y: &scrollbar_cfg
		color:           color_transparent
		padding:         padding_none
		radius:          0
		spacing:         row_spacing
		sizing:          cfg.sizing
		width:           cfg.width
		height:          cfg.height
		min_width:       cfg.min_width
		max_width:       cfg.max_width
		min_height:      cfg.min_height
		max_height:      cfg.max_height
		content:         rows
	)
}

// table_cfg_from_data takes `[][]string` and creates a table.
// First row is treated as a header row.
pub fn table_cfg_from_data(data [][]string) TableCfg {
	mut row_cfg := []TableRowCfg{cap: data.len}
	for i, r in data {
		mut cells := []TableCellCfg{}
		for cell in r {
			cells << TableCellCfg{
				value:     cell
				head_cell: i == 0
			}
		}
		row_cfg << TableRowCfg{
			cells: cells
		}
	}
	return TableCfg{
		data: row_cfg
	}
}

// table_cfg_from_csv_string converts a string representing a csv format to a TableCfg.
// First row is treated as a header row.
// Returns an error if the CSV data is empty or malformed.
pub fn table_cfg_from_csv_string(data string) !TableCfg {
	// Validate input
	if data.len == 0 {
		return error('cannot parse empty CSV data')
	}

	// Create parser with error context
	mut parser := csv.csv_reader_from_string(data) or {
		return error('failed to create CSV parser: ${err.msg()}')
	}

	// Get row count with validation
	row_count := parser.rows_count() or {
		return error('failed to get CSV row count: ${err.msg()}')
	}

	if row_count == 0 {
		return error('CSV data contains no rows')
	}

	// Parse rows with error context
	mut rows := [][]string{cap: int(row_count)}
	for y in 0 .. int(row_count) {
		row := parser.get_row(y) or { return error('failed to parse CSV row ${y}: ${err.msg()}') }
		rows << row
	}
	return table_cfg_from_data(rows)
}

// table_from_csv_string is a helper function that returns a table from the csv string.
// If there is a parser error, it returns a table with the error message.
pub fn (mut window Window) table_from_csv_string(data string) View {
	csv_table_cfg := table_cfg_from_csv_string(data) or { table_cfg_error(err.msg()) }
	return window.table(csv_table_cfg)
}

// table_cfg_error is a helper method to produce a [TableCfg](#TableCfg) with an error message
pub fn table_cfg_error(message string) TableCfg {
	return TableCfg{
		data: [tr([td(message)])]
	}
}

// tr is a helper method to configure a table row from the given array of [TableCellCfg](#TableCellCfg)
pub fn tr(cols []TableCellCfg) TableRowCfg {
	return TableRowCfg{
		cells: cols
	}
}

// th is a helper method to configure a header cell
pub fn th(value string) TableCellCfg {
	return TableCellCfg{
		value:     value
		head_cell: true
	}
}

// td is a helper method to configure a data cell
pub fn td(value string) TableCellCfg {
	return TableCellCfg{
		value: value
	}
}

// clear_table_cache clears cached column widths for a specific table
pub fn (mut w Window) clear_table_cache(id string) {
	w.view_state.table_col_widths.delete(id)
}

// clear_all_table_caches clears all cached table column widths
pub fn (mut w Window) clear_all_table_caches() {
	w.view_state.table_col_widths.clear()
}

// table_column_widths calculates max width per column (cached)
fn (mut window Window) table_column_widths(cfg &TableCfg) []f32 {
	if cfg.data.len == 0 || cfg.data[0].cells.len == 0 {
		return []
	}

	data_hash := table_data_hash(cfg)

	// Check cache if table has id
	if cfg.id.len > 0 {
		if cached := window.view_state.table_col_widths.get(cfg.id) {
			if cached.hash == data_hash {
				return cached.widths
			}
		}
		widths := table_compute_column_widths(cfg, mut window)
		window.view_state.table_col_widths.set(cfg.id, TableColCache{
			hash:   data_hash
			widths: widths
		})
		return widths
	}

	// Warn once for tables without id that have many rows
	if cfg.data.len > 20 && !(window.view_state.table_warned_no_id.get(data_hash) or { false }) {
		window.view_state.table_warned_no_id.set(data_hash, true)
		log.warn('table with ${cfg.data.len} rows has no id; column widths not cached')
	}

	return table_compute_column_widths(cfg, mut window)
}

// table_data_hash computes hash for cache invalidation
fn table_data_hash(cfg &TableCfg) u64 {
	mut h := u64(cfg.data.len)
	h = h * 31 + u64(cfg.data[0].cells.len)
	// Sample first, middle, last rows for change detection
	sample_indices := [0, cfg.data.len / 2, cfg.data.len - 1]
	for idx in sample_indices {
		if idx >= 0 && idx < cfg.data.len {
			row := cfg.data[idx]
			for cell in row.cells {
				for c in cell.value {
					h = h * 31 + u64(c)
				}
			}
		}
	}
	return h
}

// table_compute_column_widths calculates max width per column
fn table_compute_column_widths(cfg &TableCfg, mut window Window) []f32 {
	mut column_widths := []f32{cap: cfg.data[0].cells.len}
	for idx, _ in cfg.data[0].cells {
		mut longest := f32(0)
		for row in cfg.data {
			if idx >= row.cells.len {
				continue
			}
			cell := row.cells[idx]
			width := if rt := cell.rich_text {
				rich_text_width(rt, mut window)
			} else {
				text_style := cell.text_style or {
					if cell.head_cell { cfg.text_style_head } else { cfg.text_style }
				}

				text_width(cell.value, text_style, mut window)
			}
			longest = f32_max(width, longest)
		}
		column_widths << f32_max(longest, cfg.column_width_min)
	}
	return column_widths
}

// table_estimate_row_height estimates row height for virtualization
fn table_estimate_row_height(cfg &TableCfg, mut window Window) f32 {
	vg_cfg := cfg.text_style.to_vglyph_cfg()
	font_h := window.text_system.font_height(vg_cfg) or { 0 }
	border := match cfg.border_style {
		.all { cfg.size_border }
		else { f32(0) }
	}
	return font_h + cfg.cell_padding.height() + border
}

// table_visible_range calculates first/last visible row indices for virtualization
fn table_visible_range(table_height f32, row_height f32, cfg &TableCfg, mut window Window) (int, int) {
	scroll_y := -(window.view_state.scroll_y.get(cfg.id_scroll) or { f32(0) }) // scroll_y is negative
	first := int(scroll_y / row_height)
	visible_rows := int(table_height / row_height) + 1
	buffer := 2
	first_visible := int_max(0, first - buffer)
	last_visible := int_min(cfg.data.len - 1, first + visible_rows + buffer)
	return first_visible, last_visible
}
