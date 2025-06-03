module gui

@[heap]
pub struct TableCfg {
pub:
	id   string
	data []TableRowCfg
pub mut:
	window Window @[required]
}

pub struct TableRowCfg {
pub:
	id      string
	columns []TableCellCfg
}

pub struct TableCellCfg {
pub:
	id         string
	width      f32
	min_width  f32
	max_width  f32
	height     f32
	min_height f32
	max_height f32
	value      string
}

const t_color = white

pub fn table(cfg &TableCfg) View {
	mut rows := []View{}
	columns_longest := compute_longest_column(cfg)
	cell_padding := padding_two_five
	for r in cfg.data {
		mut cols := []View{}
		for i, col in r.columns {
			cols << column(
				spacing:   0
				radius:    0
				color:     t_color
				min_width: columns_longest[i] + cell_padding.width()
				padding:   cell_padding
				content:   [text(text: col.value)]
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
		spacing: 0
		radius:  0
		color:   t_color
		padding: padding_none
		content: rows
	)
}

pub fn tr(cols []TableCellCfg) TableRowCfg {
	return TableRowCfg{
		columns: cols
	}
}

pub fn td(value string) TableCellCfg {
	return TableCellCfg{
		value: value
	}
}

fn compute_longest_column(cfg &TableCfg) []f32 {
	mut window := cfg.window
	mut columns_longest := []f32{}
	col_count := cfg.data[0].columns.len
	for idx in 0 .. col_count {
		mut longest := f32(0)
		for row in cfg.data {
			l := get_text_width(row.columns[idx].value, gui_theme.text_style, mut window)
			longest = f32_max(l, longest)
		}
		columns_longest << longest
	}
	return columns_longest
}
