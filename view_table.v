module gui

import encoding.csv

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
// - `tr(tr(cols []TableCellCfg))` creates a row from the given cells
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
	column_width_default f32             = 50
	size_border          f32
	size_border_header   f32 // optional header separator override
	border_style         TableBorderStyle = .all
	width                f32
	height               f32
	min_width            f32
	max_width            f32
	min_height           f32
	max_height           f32
	sizing               Sizing
	id_scroll            u32
	multi_select         bool
	selected             []int // selected row indices (0-based, header is row 0)
	on_select            fn (selected []int, row_idx int, mut e Event, mut w Window) = unsafe { nil }
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
@[minify]
pub struct TableCellCfg {
pub:
	id         string
	value      string
	head_cell  bool
	text_style ?TextStyle
	content    ?View // optional custom cell content (overrides value)
	on_click   fn (&Layout, mut Event, mut Window) = unsafe { nil }
}

// table generates a table from the given [TableCfg](#TableCfg)
pub fn (mut window Window) table(cfg TableCfg) View {
	mut rows := []View{cap: cfg.data.len * 2} // extra capacity for separators
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

	for row_idx, r in cfg.data {
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

			h_align := if cell.head_cell { cfg.align_head } else { HorizontalAlign.start }

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
		is_selected := row_idx in cfg.selected
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
		selected := cfg.selected
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
					mut new_selected := if multi_select { selected.clone() } else { []int{} }
					if row_idx in new_selected {
						new_selected = new_selected.filter(it != row_idx)
					} else {
						new_selected << row_idx
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
	return column(
		name:       'table'
		id:         cfg.id
		id_scroll:  cfg.id_scroll
		color:      color_transparent
		padding:    padding_none
		radius:     0
		spacing:    row_spacing
		sizing:     cfg.sizing
		width:      cfg.width
		height:     cfg.height
		min_width:  cfg.min_width
		max_width:  cfg.max_width
		min_height: cfg.min_height
		max_height: cfg.max_height
		content:    rows
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

// th is a helper method to configure a table cell from the given of [TableCellCfg](#TableCellCfg)
pub fn th(value string) TableCellCfg {
	return TableCellCfg{
		value:     value
		head_cell: true
	}
}

// td is a helper method to configure a table cell from the given of [TableCellCfg](#TableCellCfg)
pub fn td(value string) TableCellCfg {
	return TableCellCfg{
		value: value
	}
}

// table_column_widths calculates max width per column
fn (mut window Window) table_column_widths(cfg &TableCfg) []f32 {
	if cfg.data.len == 0 || cfg.data[0].cells.len == 0 {
		return []
	}
	mut column_widths := []f32{cap: cfg.data[0].cells.len}
	for idx, _ in cfg.data[0].cells {
		mut longest := f32(0)
		for row in cfg.data {
			if idx >= row.cells.len {
				continue
			}
			cell := row.cells[idx]
			text_style := cell.text_style or {
				if cell.head_cell { cfg.text_style_head } else { cfg.text_style }
			}

			width := text_width(cell.value, text_style, mut window)
			longest = f32_max(width, longest)
		}
		column_widths << longest
	}
	return column_widths
}
