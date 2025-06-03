module gui

@[heap]
pub struct TableCfg {
pub:
	id                   string
	window               &Window @[required]
	color                Color     = gui_theme.color_border
	cell_padding         Padding   = padding_two_five
	column_width_default f32       = 50
	text_style           TextStyle = gui_theme.n3
	text_style_head      TextStyle = gui_theme.b3
	on_click             fn (&TableCellCfg, mut Event, mut Window) = unsafe { nil }
	data                 []TableRowCfg
}

pub struct TableRowCfg {
pub:
	id      string
	columns []TableCellCfg
}

pub struct TableCellCfg {
pub:
	id         string
	value      string
	head_cell  bool
	text_style ?TextStyle
}

pub fn table(cfg &TableCfg) View {
	mut rows := []View{}
	column_widths := table_column_widths(cfg)
	for r in cfg.data {
		mut cols := []View{}
		for idx, col in r.columns {
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
				color:   cfg.color
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
		color:   cfg.color
		padding: padding_none
		radius:  0
		spacing: 0
		content: rows
	)
}

pub fn tr(cols []TableCellCfg) TableRowCfg {
	return TableRowCfg{
		columns: cols
	}
}

pub fn th(value string) TableCellCfg {
	return TableCellCfg{
		value:     value
		head_cell: true
	}
}

pub fn td(value string) TableCellCfg {
	return TableCellCfg{
		value: value
	}
}

fn table_column_widths(cfg &TableCfg) []f32 {
	if cfg.data.len == 0 || cfg.data[0].columns.len == 0 {
		return []
	}
	mut window := cfg.window
	mut column_widths := []f32{}
	for idx in 0 .. cfg.data[0].columns.len {
		mut longest := f32(0)
		for row in cfg.data {
			l := get_text_width(row.columns[idx].value, gui_theme.text_style, mut window)
			longest = f32_max(l, longest)
		}
		column_widths << longest
	}
	return column_widths
}
