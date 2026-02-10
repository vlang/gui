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

fn test_grid_column_order_move() {
	order := ['a', 'b', 'c', 'd']
	left := grid_column_order_move(order, 'c', -1)
	assert left == ['a', 'c', 'b', 'd']

	right := grid_column_order_move(order, 'b', 2)
	assert right == ['a', 'c', 'd', 'b']

	clamped := grid_column_order_move(order, 'a', -1)
	assert clamped == order
}

fn test_data_grid_effective_columns_respects_order_and_pin() {
	cfg := DataGridCfg{
		id:           'effective-cols'
		column_order: ['c', 'a', 'b']
		columns:      [
			GridColumnCfg{
				id:    'a'
				title: 'A'
				pin:   .none
			},
			GridColumnCfg{
				id:    'b'
				title: 'B'
				pin:   .left
			},
			GridColumnCfg{
				id:    'c'
				title: 'C'
				pin:   .right
			},
		]
		rows:         []
	}
	cols := data_grid_effective_columns(cfg)
	assert cols.len == 3
	assert cols[0].id == 'b'
	assert cols[1].id == 'a'
	assert cols[2].id == 'c'
}

fn test_grid_column_next_pin_cycles() {
	assert grid_column_next_pin(.none) == .left
	assert grid_column_next_pin(.left) == .right
	assert grid_column_next_pin(.right) == .none
}

fn test_data_grid_header_control_state_compacts_when_narrow() {
	state := data_grid_header_control_state(50, padding_two_five, true, true, true)
	assert state.show_label == false
	assert state.show_reorder == true
	assert state.show_pin == false
	assert state.show_resize == true
}

fn test_data_grid_header_control_state_keeps_all_when_wide() {
	state := data_grid_header_control_state(220, padding_two_five, true, true, true)
	assert state.show_label == true
	assert state.show_reorder == true
	assert state.show_pin == true
	assert state.show_resize == true
}

fn test_data_grid_show_header_controls() {
	assert data_grid_show_header_controls('name', 'name', '', '') == true
	assert data_grid_show_header_controls('name', '', 'name', '') == true
	assert data_grid_show_header_controls('name', '', '', 'name') == true
	assert data_grid_show_header_controls('name', 'team', '', '') == false
	assert data_grid_show_header_controls('', 'name', 'name', 'name') == false
}

fn test_data_grid_header_col_id_from_layout_id() {
	assert data_grid_header_col_id_from_layout_id('users', 'users:header:name') == 'name'
	assert data_grid_header_col_id_from_layout_id('users:grid', 'users:grid:header:team') == 'team'
	assert data_grid_header_col_id_from_layout_id('users', 'users:row:1') == ''
}

fn test_data_grid_header_focus_ids_are_sequential() {
	cfg := DataGridCfg{
		id_focus: 100
		id:       'grid'
		columns:  []
		rows:     []
	}
	assert data_grid_header_focus_id(cfg, 4, 0) == 101
	assert data_grid_header_focus_id(cfg, 4, 3) == 104
	assert data_grid_header_focus_index(cfg, 4, 103) == 2
}

fn test_data_grid_header_focused_col_id() {
	cfg := DataGridCfg{
		id_focus: 1000
		id:       'grid'
		columns:  []
		rows:     []
	}
	cols := [
		GridColumnCfg{
			id:    'a'
			title: 'A'
		},
		GridColumnCfg{
			id:    'b'
			title: 'B'
		},
		GridColumnCfg{
			id:    'c'
			title: 'C'
		},
	]
	assert data_grid_header_focused_col_id(cfg, cols, 1002) == 'b'
	assert data_grid_header_focused_col_id(cfg, cols, 77) == ''
}

fn test_data_grid_group_columns_filters_invalid_and_duplicates() {
	columns := [
		GridColumnCfg{
			id:    'team'
			title: 'Team'
		},
		GridColumnCfg{
			id:    'status'
			title: 'Status'
		},
	]
	group_cols := data_grid_group_columns(['team', 'missing', 'team', 'status'], columns)
	assert group_cols == ['team', 'status']
}

fn test_data_grid_group_ranges_nested() {
	rows := [
		GridRow{
			id:    '1'
			cells: {
				'team':   'Core'
				'status': 'Open'
			}
		},
		GridRow{
			id:    '2'
			cells: {
				'team':   'Core'
				'status': 'Open'
			}
		},
		GridRow{
			id:    '3'
			cells: {
				'team':   'Core'
				'status': 'Closed'
			}
		},
		GridRow{
			id:    '4'
			cells: {
				'team':   'Data'
				'status': 'Open'
			}
		},
	]
	ranges := data_grid_group_ranges(rows, ['team', 'status'])
	assert ranges[data_grid_group_range_key(0, 0)] == 2
	assert ranges[data_grid_group_range_key(1, 0)] == 1
	assert ranges[data_grid_group_range_key(1, 2)] == 2
	assert ranges[data_grid_group_range_key(0, 3)] == 3
	assert ranges[data_grid_group_range_key(1, 3)] == 3
}

fn test_data_grid_presentation_with_group_headers() {
	cfg := DataGridCfg{
		id:         'grouped'
		columns:    [
			GridColumnCfg{
				id:    'team'
				title: 'Team'
			},
			GridColumnCfg{
				id:    'score'
				title: 'Score'
			},
		]
		group_by:   ['team']
		rows:       [
			GridRow{
				id:    '1'
				cells: {
					'team':  'Core'
					'score': '10'
				}
			},
			GridRow{
				id:    '2'
				cells: {
					'team':  'Core'
					'score': '20'
				}
			},
			GridRow{
				id:    '3'
				cells: {
					'team':  'Data'
					'score': '5'
				}
			},
		]
		aggregates: [
			GridAggregateCfg{
				op:     .sum
				col_id: 'score'
				label:  'sum'
			},
		]
	}
	p := data_grid_presentation(cfg, cfg.columns)
	assert p.rows.len == 5
	assert p.rows[0].kind == .group_header
	assert p.rows[0].group_value == 'Core'
	assert p.rows[0].group_count == 2
	assert p.rows[0].aggregate_text.contains('sum: 30')
	assert p.rows[1].kind == .data
	assert p.rows[1].data_row_idx == 0
	assert p.rows[3].kind == .group_header
	assert p.rows[3].group_value == 'Data'
	assert p.data_to_display[0] == 1
	assert p.data_to_display[1] == 2
	assert p.data_to_display[2] == 4
}

fn test_data_grid_aggregate_value_numeric_ops() {
	rows := [
		GridRow{
			id:    '1'
			cells: {
				'score': '10'
			}
		},
		GridRow{
			id:    '2'
			cells: {
				'score': '15'
			}
		},
		GridRow{
			id:    '3'
			cells: {
				'score': '25'
			}
		},
	]
	sum := data_grid_aggregate_value(rows, 0, 2, GridAggregateCfg{
		op:     .sum
		col_id: 'score'
	}) or { '' }
	avg := data_grid_aggregate_value(rows, 0, 2, GridAggregateCfg{
		op:     .avg
		col_id: 'score'
	}) or { '' }
	min := data_grid_aggregate_value(rows, 0, 2, GridAggregateCfg{
		op:     .min
		col_id: 'score'
	}) or { '' }
	max := data_grid_aggregate_value(rows, 0, 2, GridAggregateCfg{
		op:     .max
		col_id: 'score'
	}) or { '' }
	assert sum == '50'
	assert avg == '16.6667'
	assert min == '10'
	assert max == '25'
}
