module gui

fn test_data_grid_toggle_sort_single_cycle() {
	base := GridQueryState{}
	q1 := data_grid_toggle_sort(base, 'name', false, false)
	assert q1.sorts.len == 1
	assert q1.sorts[0].col_id == 'name'
	assert q1.sorts[0].dir == .asc

	q2 := data_grid_toggle_sort(q1, 'name', false, false)
	assert q2.sorts.len == 1
	assert q2.sorts[0].dir == .desc

	q3 := data_grid_toggle_sort(q2, 'name', false, false)
	assert q3.sorts.len == 0
}

fn test_data_grid_toggle_sort_multi_append() {
	base := GridQueryState{}
	q1 := data_grid_toggle_sort(base, 'name', true, true)
	q2 := data_grid_toggle_sort(q1, 'age', true, true)
	assert q2.sorts.len == 2
	assert q2.sorts[0].col_id == 'name'
	assert q2.sorts[1].col_id == 'age'

	q3 := data_grid_toggle_sort(q2, 'name', true, true)
	assert q3.sorts.len == 2
	assert q3.sorts[0].col_id == 'name'
	assert q3.sorts[0].dir == .desc

	q4 := data_grid_toggle_sort(q3, 'name', true, true)
	assert q4.sorts.len == 1
	assert q4.sorts[0].col_id == 'age'
}

fn test_grid_query_set_filter_add_update_remove() {
	base := GridQueryState{}
	q1 := grid_query_set_filter(base, 'name', 'alice')
	assert q1.filters.len == 1
	assert q1.filters[0].col_id == 'name'
	assert q1.filters[0].value == 'alice'

	q2 := grid_query_set_filter(q1, 'name', 'bob')
	assert q2.filters.len == 1
	assert q2.filters[0].value == 'bob'

	q3 := grid_query_set_filter(q2, 'name', '   ')
	assert q3.filters.len == 0
}

fn test_grid_rows_to_tsv_with_header() {
	columns := [
		GridColumnCfg{
			id:    'name'
			title: 'Name'
		},
		GridColumnCfg{
			id:    'age'
			title: 'Age'
		},
	]
	rows := [
		GridRow{
			id:    '1'
			cells: {
				'name': 'Alice'
				'age':  '30'
			}
		},
		GridRow{
			id:    '2'
			cells: {
				'name': 'Bob'
				'age':  '25'
			}
		},
	]
	tsv := grid_rows_to_tsv(columns, rows)
	assert tsv == 'Name\tAge\nAlice\t30\nBob\t25'
}

fn test_grid_rows_to_csv_quotes() {
	columns := [
		GridColumnCfg{
			id:    'name'
			title: 'Name'
		},
		GridColumnCfg{
			id:    'note'
			title: 'Note'
		},
	]
	rows := [
		GridRow{
			id:    '1'
			cells: {
				'name': 'Alice, Jr'
				'note': 'He said "hi"'
			}
		},
	]
	csv := grid_rows_to_csv(columns, rows)
	assert csv == 'Name,Note\n"Alice, Jr","He said ""hi"""'
}

fn test_data_grid_visible_range_for_scroll() {
	first, last := data_grid_visible_range_for_scroll(0, 120, 20, 100, 40, 2)
	assert first == 0
	assert last == 9

	first2, last2 := data_grid_visible_range_for_scroll(220, 120, 20, 100, 40, 2)
	assert first2 == 7
	assert last2 == 18
}

fn test_data_grid_range_indices() {
	rows := [
		GridRow{
			id: 'a'
		},
		GridRow{
			id: 'b'
		},
		GridRow{
			id: 'c'
		},
		GridRow{
			id: 'd'
		},
	]
	start, end := data_grid_range_indices(rows, 'b', 'd')
	assert start == 1
	assert end == 3

	start2, end2 := data_grid_range_indices(rows, 'd', 'b')
	assert start2 == 1
	assert end2 == 3
}

fn test_data_grid_defaults_hide_optional_filter_rows() {
	cfg := DataGridCfg{
		id:      'defaults'
		columns: []
		rows:    []
	}
	assert cfg.show_header == true
	assert cfg.show_filter_row == false
	assert cfg.show_quick_filter == false
}

fn test_data_grid_scroll_padding_visible() {
	cfg := DataGridCfg{
		id:      'padding-visible'
		columns: []
		rows:    []
	}
	pad := data_grid_scroll_padding(cfg)
	assert pad.right == data_grid_scroll_gutter()
}

fn test_data_grid_scroll_padding_hidden() {
	cfg := DataGridCfg{
		id:        'padding-hidden'
		columns:   []
		rows:      []
		scrollbar: .hidden
	}
	pad := data_grid_scroll_padding(cfg)
	assert pad.right == 0
}
