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
@[heap]
pub struct TableCfg {
pub:
	id                   string
	color_border         Color     = gui_theme.color_border
	cell_padding         Padding   = padding_two_five
	text_style           TextStyle = gui_theme.n3
	text_style_head      TextStyle = gui_theme.b3
	column_width_default f32       = 50
pub mut:
	data []TableRowCfg
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
	on_click   fn (&Layout, mut Event, mut Window) = unsafe { nil }
}

// table generates a table from the given [TableCfg](#TableCfg)
pub fn (mut window Window) table(cfg TableCfg) View {
	mut rows := []View{cap: cfg.data.len}
	unsafe { rows.flags.set(.noslices) }
	column_widths := window.table_column_widths(cfg)
	for r in cfg.data {
		mut cells := []View{cap: r.cells.len}
		unsafe { cells.flags.set(.noslices) }
		for idx, cell in r.cells {
			cell_text_style := cell.text_style or {
				if cell.head_cell { cfg.text_style_head } else { cfg.text_style }
			}

			column_width := match idx < column_widths.len {
				true { column_widths[idx] }
				else { cfg.column_width_default }
			}

			h_align := match cell.head_cell {
				true { HorizontalAlign.center }
				else { HorizontalAlign.start }
			}

			cells << column(
				name:     'table cell border'
				color:    cfg.color_border
				padding:  cfg.cell_padding
				radius:   0
				spacing:  0
				sizing:   fixed_fill
				width:    column_width + cfg.cell_padding.width()
				on_click: cell.on_click
				content:  [
					column(
						name:     'table cell interior'
						fill:     true
						h_align:  h_align
						color:    color_transparent
						padding:  padding_none
						sizing:   fill_fill
						content:  [
							text(text: cell.value, text_style: cell_text_style),
						]
						on_hover: fn [cell] (mut layout Layout, mut e Event, mut w Window) {
							if cell.on_click != unsafe { nil } {
								w.set_mouse_cursor_pointing_hand()
								layout.shape.color = gui_theme.color_hover
							}
						}
					),
				]
			)
		}
		rows << row(
			name:    'table row'
			spacing: 0
			radius:  0
			padding: padding_none
			content: cells
		)
	}
	return column(
		name:    'table'
		id:      cfg.id
		color:   cfg.color_border
		padding: padding_none
		radius:  0
		spacing: 0
		content: rows
	)
}

// table from data takes `[][]string` and creates a table.
// First row is treated as a header row.
pub fn table_cfg_from_data(data [][]string) TableCfg {
	mut row_cfg := []TableRowCfg{cap: data.len}
	unsafe { row_cfg.flags.set(.noslices) }
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

// table_from_csv converts a string representing a csv format to a TableCfg.
// First row is treated as a header row.
pub fn table_cfg_from_csv_string(data string) !TableCfg {
	mut parser := csv.csv_reader_from_string(data)!
	mut rows := [][]string{}
	for y in 0 .. int(parser.rows_count()!) {
		rows << parser.get_row(y)!
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

// table_column_widths find the widest column for each column
fn (mut window Window) table_column_widths(cfg &TableCfg) []f32 {
	if cfg.data.len == 0 || cfg.data[0].cells.len == 0 {
		return []
	}
	mut column_widths := []f32{cap: cfg.data[0].cells.len}
	unsafe { column_widths.flags.set(.noslices) }
	for idx, cell in cfg.data[0].cells {
		mut longest := f32(0)
		for row in cfg.data {
			text_style := cell.text_style or {
				if cell.head_cell { cfg.text_style_head } else { cfg.text_style }
			}

			width := get_text_width(row.cells[idx].value, text_style, mut window)
			longest = f32_max(width, longest)
		}
		column_widths << longest
	}
	return column_widths
}
