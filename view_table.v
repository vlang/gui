module gui

import encoding.csv

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
// gui.table(
// 	text_style_head: gui.theme().b2
// 	window: window
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
@[heap]
pub struct TableCfg {
pub:
	id                   string
	window               &Window @[required]
	color_border         Color     = gui_theme.color_border
	cell_padding         Padding   = padding_two_five
	column_width_default f32       = 50
	text_style           TextStyle = gui_theme.n3
	text_style_head      TextStyle = gui_theme.b3
	on_click             fn (&TableCellCfg, mut Event, mut Window) = unsafe { nil }
	data                 []TableRowCfg
}

// TableRowCfg configures a table row from the given cells
pub struct TableRowCfg {
pub:
	id    string
	cells []TableCellCfg
}

// TableCellCfg configures a table cell
pub struct TableCellCfg {
pub:
	id         string
	value      string
	head_cell  bool
	text_style ?TextStyle
}

// table generates a table from the given [TableCfg](#TableCfg)
pub fn table(cfg &TableCfg) View {
	mut rows := []View{}
	column_widths := table_column_widths(cfg)
	for r in cfg.data {
		mut cols := []View{}
		for idx, col in r.cells {
			cell_text_style := col.text_style or {
				if col.head_cell { cfg.text_style_head } else { cfg.text_style }
			}

			column_width := match idx < column_widths.len {
				true { column_widths[idx] }
				else { cfg.column_width_default }
			}

			h_align := match col.head_cell {
				true { HorizontalAlign.center }
				else { HorizontalAlign.start }
			}

			cols << column(
				color:   cfg.color_border
				h_align: h_align
				padding: cfg.cell_padding
				radius:  0
				spacing: 0
				sizing:  fixed_fill
				width:   column_width + cfg.cell_padding.width()
				content: [text(text: col.value, text_style: cell_text_style)]
			)
		}
		rows << row(
			spacing: 0
			radius:  0
			padding: padding_none
			content: cols
		)
	}
	return column(
		id:      cfg.id
		color:   cfg.color_border
		padding: padding_none
		radius:  0
		spacing: 0
		content: rows
	)
}

// table from data takes `[][]string` and creates a table. The first row
// is treated as a header row.
pub fn table_from_data(data [][]string, mut window Window) View {
	mut row_cfg := []TableRowCfg{}
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
	table_cfg := TableCfg{
		window: window
		data:   row_cfg
	}
	return table(table_cfg)
}

// table_from_csv converts a string representing a csv format to a table.
// First row is treated as a header row.
pub fn table_from_csv_string(data string, mut window Window) !View {
	mut parser := csv.csv_reader_from_string(data)!
	mut rows := [][]string{}
	for y in 0 .. int(parser.rows_count()!) {
		rows << parser.get_row(y)!
	}
	return table_from_data(rows, mut window)
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

// find the widest column for each column
fn table_column_widths(cfg &TableCfg) []f32 {
	if cfg.data.len == 0 || cfg.data[0].cells.len == 0 {
		return []
	}
	mut window := cfg.window
	mut column_widths := []f32{}
	for idx in 0 .. cfg.data[0].cells.len {
		mut longest := f32(0)
		for row in cfg.data {
			l := get_text_width(row.cells[idx].value, gui_theme.text_style, mut window)
			longest = f32_max(l, longest)
		}
		column_widths << longest
	}
	return column_widths
}
