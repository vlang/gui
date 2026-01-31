module gui

// Tests for table component

fn test_table_column_widths_empty_data() {
	// Empty data should return empty widths
	cfg := TableCfg{}
	// Cannot call window method without window, test via table_cfg_from_data
	assert cfg.data.len == 0
}

fn test_table_cfg_from_data_basic() {
	data := [['A', 'B'], ['1', '2']]
	cfg := table_cfg_from_data(data)
	assert cfg.data.len == 2
	assert cfg.data[0].cells.len == 2
	assert cfg.data[0].cells[0].head_cell == true
	assert cfg.data[0].cells[1].head_cell == true
	assert cfg.data[1].cells[0].head_cell == false
	assert cfg.data[1].cells[0].value == '1'
}

fn test_table_cfg_from_data_empty() {
	data := [][]string{}
	cfg := table_cfg_from_data(data)
	assert cfg.data.len == 0
}

fn test_table_cfg_from_csv_string_empty() {
	// Empty string returns error
	if _ := table_cfg_from_csv_string('') {
		assert false, 'expected error for empty string'
	}
}

fn test_table_helper_tr() {
	cells := [th('A'), td('B')]
	row := tr(cells)
	assert row.cells.len == 2
	assert row.cells[0].head_cell == true
	assert row.cells[1].head_cell == false
}

fn test_table_helper_th() {
	cell := th('Header')
	assert cell.value == 'Header'
	assert cell.head_cell == true
}

fn test_table_helper_td() {
	cell := td('Data')
	assert cell.value == 'Data'
	assert cell.head_cell == false
}

fn test_table_cfg_error() {
	cfg := table_cfg_error('Error message')
	assert cfg.data.len == 1
	assert cfg.data[0].cells.len == 1
	assert cfg.data[0].cells[0].value == 'Error message'
}

fn test_table_cfg_column_width_min_default() {
	cfg := TableCfg{}
	assert cfg.column_width_min == 20
}

fn test_table_cfg_column_width_default() {
	cfg := TableCfg{}
	assert cfg.column_width_default == 50
}

fn test_table_cfg_from_data_jagged_rows() {
	// Jagged rows (different column counts) should be handled
	data := [['A', 'B', 'C'], ['1', '2']]
	cfg := table_cfg_from_data(data)
	assert cfg.data.len == 2
	assert cfg.data[0].cells.len == 3
	assert cfg.data[1].cells.len == 2
}

fn test_table_alignment_config() {
	cfg := TableCfg{
		column_alignments: [HorizontalAlign.start, HorizontalAlign.center, HorizontalAlign.end]
	}
	assert cfg.column_alignments.len == 3
	assert cfg.column_alignments[0] == .start
	assert cfg.column_alignments[1] == .center
	assert cfg.column_alignments[2] == .end
}

fn test_table_cell_alignment_override() {
	cell := TableCellCfg{
		value:   'Test'
		h_align: HorizontalAlign.center
	}
	assert cell.h_align != none
	if align := cell.h_align {
		assert align == .center
	}
}

fn test_table_border_styles() {
	// Verify all border styles are accessible
	assert TableBorderStyle.none != TableBorderStyle.all
	assert TableBorderStyle.horizontal != TableBorderStyle.header_only
}

fn test_table_selection_config() {
	cfg := TableCfg{
		multi_select: true
		selected:     [1, 3]
	}
	assert cfg.multi_select == true
	assert cfg.selected.len == 2
	assert 1 in cfg.selected
	assert 3 in cfg.selected
}
