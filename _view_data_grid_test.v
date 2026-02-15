module gui

import compress.szip
import os
import time

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

fn test_data_grid_query_set_filter_add_update_remove() {
	base := GridQueryState{}
	q1 := data_grid_query_set_filter(base, 'name', 'alice')
	assert q1.filters.len == 1
	assert q1.filters[0].col_id == 'name'
	assert q1.filters[0].value == 'alice'

	q2 := data_grid_query_set_filter(q1, 'name', 'bob')
	assert q2.filters.len == 1
	assert q2.filters[0].value == 'bob'

	q3 := data_grid_query_set_filter(q2, 'name', '   ')
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

fn test_grid_rows_to_tsv_sanitizes_formulas() {
	columns := [
		GridColumnCfg{
			id:    'danger'
			title: 'Danger'
		},
	]
	rows := [
		GridRow{
			id:    '1'
			cells: {
				'danger': '=2+2'
			}
		},
	]
	tsv := grid_rows_to_tsv(columns, rows)
	assert tsv == "Danger\n'=2+2"
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

fn test_grid_rows_to_csv_sanitizes_formulas() {
	columns := [
		GridColumnCfg{
			id:    'danger'
			title: 'Danger'
		},
	]
	rows := [
		GridRow{
			id:    '1'
			cells: {
				'danger': '@cmd'
			}
		},
	]
	csv := grid_rows_to_csv(columns, rows)
	assert csv == "Danger\n'@cmd"
}

fn test_grid_rows_to_csv_with_cfg_disable_sanitize() {
	columns := [
		GridColumnCfg{
			id:    'danger'
			title: 'Danger'
		},
	]
	rows := [
		GridRow{
			id:    '1'
			cells: {
				'danger': '=2+2'
			}
		},
	]
	csv := grid_rows_to_csv_with_cfg(columns, rows, GridExportCfg{
		sanitize_spreadsheet_formulas: false
	})
	assert csv == 'Danger\n=2+2'
}

fn test_grid_data_from_csv_basic() {
	parsed := grid_data_from_csv('Name,Team\nAlice,Core\nBob,Data') or { panic(err) }
	assert parsed.columns.len == 2
	assert parsed.columns[0].title == 'Name'
	assert parsed.columns[0].id == 'name'
	assert parsed.columns[1].title == 'Team'
	assert parsed.columns[1].id == 'team'
	assert parsed.rows.len == 2
	assert parsed.rows[0].id == '1'
	assert parsed.rows[0].cells['name'] == 'Alice'
	assert parsed.rows[0].cells['team'] == 'Core'
	assert parsed.rows[1].id == '2'
	assert parsed.rows[1].cells['name'] == 'Bob'
	assert parsed.rows[1].cells['team'] == 'Data'
}

fn test_grid_data_from_csv_normalizes_headers_and_row_widths() {
	data := '\xEF\xBB\xBFName,,Name\nAlice,,One\nBob,Ops,Two\nCara'
	parsed := grid_data_from_csv(data) or { panic(err) }
	assert parsed.columns.len == 3
	assert parsed.columns[0].title == 'Name'
	assert parsed.columns[0].id == 'name'
	assert parsed.columns[1].title == 'Column 2'
	assert parsed.columns[1].id == 'col_2'
	assert parsed.columns[2].title == 'Name'
	assert parsed.columns[2].id == 'name_2'
	assert parsed.rows.len == 3
	assert parsed.rows[0].cells['name'] == 'Alice'
	assert parsed.rows[0].cells['col_2'] == ''
	assert parsed.rows[0].cells['name_2'] == 'One'
	assert parsed.rows[1].cells['name'] == 'Bob'
	assert parsed.rows[1].cells['col_2'] == 'Ops'
	assert parsed.rows[1].cells['name_2'] == 'Two'
	assert parsed.rows[2].cells['name'] == 'Cara'
	assert parsed.rows[2].cells['col_2'] == ''
	assert parsed.rows[2].cells['name_2'] == ''
}

fn test_grid_data_from_csv_quotes() {
	parsed := grid_data_from_csv('Name,Note\n"Alice, Jr","He said ""hi"""') or { panic(err) }
	assert parsed.rows.len == 1
	assert parsed.rows[0].cells['name'] == 'Alice, Jr'
	assert parsed.rows[0].cells['note'] == 'He said "hi"'
}

fn test_grid_data_from_csv_empty_error() {
	_ := grid_data_from_csv('   ') or {
		assert err.msg() == 'csv data is required'
		return
	}
	assert false
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
	assert cfg.freeze_header == false
	assert cfg.show_filter_row == false
	assert cfg.show_quick_filter == false
}

fn test_data_grid_static_top_height_include_header_toggle() {
	cfg := DataGridCfg{
		id:                  'top-height-header-toggle'
		show_quick_filter:   true
		show_column_chooser: true
		show_header:         true
		show_filter_row:     true
		row_height:          30
		header_height:       34
		columns:             []
		rows:                []
	}
	with_header := data_grid_static_top_height(cfg, 30, false, true)
	without_header := data_grid_static_top_height(cfg, 30, false, false)
	assert with_header == without_header + cfg.header_height
}

fn test_data_grid_filter_and_quick_filter_height_prefer_header_height() {
	cfg := DataGridCfg{
		id:            'filter-height'
		row_height:    30
		header_height: 34
		columns:       []
		rows:          []
	}
	assert data_grid_filter_height(cfg) == 34
	assert data_grid_quick_filter_height(cfg) == 34
}

fn test_data_grid_static_top_height_excludes_quick_filter_row() {
	cfg := DataGridCfg{
		id:                'top-height-no-quick-filter'
		show_quick_filter: true
		row_height:        30
		header_height:     34
		columns:           []
		rows:              []
	}
	assert data_grid_static_top_height(cfg, 30, false, false) == 0
}

fn test_data_grid_quick_filter_matches_text_local() {
	cfg := DataGridCfg{
		id:      'matches-local'
		columns: []
		rows:    [
			GridRow{
				id: '1'
			},
			GridRow{
				id: '2'
			},
		]
	}
	assert data_grid_quick_filter_matches_text(cfg) == 'Matches 2'
}

fn test_data_grid_quick_filter_matches_text_with_total() {
	cfg := DataGridCfg{
		id:        'matches-total'
		row_count: ?int(50)
		columns:   []
		rows:      [
			GridRow{
				id: '1'
			},
			GridRow{
				id: '2'
			},
		]
	}
	assert data_grid_quick_filter_matches_text(cfg) == 'Matches 2/50'
}

fn test_data_grid_jump_digits_and_target_parsing() {
	assert data_grid_jump_digits('1a-2') == '12'
	if target := data_grid_parse_jump_target('3', 10) {
		assert target == 2
	} else {
		assert false
	}
	if target := data_grid_parse_jump_target('999', 10) {
		assert target == 9
	} else {
		assert false
	}
	if _ := data_grid_parse_jump_target('0', 10) {
		assert false
	}
	if _ := data_grid_parse_jump_target('', 10) {
		assert false
	}
}

fn test_data_grid_apply_pending_local_jump_scroll_clears_missing_mapping() {
	mut w := Window{}
	cfg := DataGridCfg{
		id:      'pending-jump-clear'
		columns: []
		rows:    [
			GridRow{
				id: '1'
			},
		]
	}
	w.view_state.data_grid_pending_jump_row.set(cfg.id, 0)
	data_grid_apply_pending_local_jump_scroll(cfg, 120, 20, 0, 11, map[int]int{}, mut
		w)
	pending := w.view_state.data_grid_pending_jump_row.get(cfg.id) or { -1 }
	assert pending == -1
}

fn test_data_grid_row_position_text_uses_page_start_without_selection() {
	mut rows := []GridRow{cap: 100}
	for i in 0 .. 100 {
		rows << GridRow{
			id: '${i + 1}'
		}
	}
	cfg := DataGridCfg{
		id:        'row-pos-page-start'
		page_size: 20
		columns:   []
		rows:      rows
	}
	assert data_grid_row_position_text(cfg, 40, 60, 100) == 'Row 41 of 100'
}

fn test_data_grid_row_position_text_uses_active_row() {
	cfg := DataGridCfg{
		id:        'row-pos-active'
		columns:   []
		rows:      [
			GridRow{
				id: '1'
			},
			GridRow{
				id: '2'
			},
			GridRow{
				id: '3'
			},
		]
		selection: GridSelection{
			active_row_id: '2'
		}
	}
	assert data_grid_row_position_text(cfg, 0, 3, 3) == 'Row 2 of 3'
}

fn test_data_grid_pager_padding_uses_cell_gutter_when_filter_padding_is_zero() {
	cfg := DataGridCfg{
		id:             'pager-padding-fallback'
		columns:        []
		rows:           []
		padding_cell:   padding(0, 7, 0, 5)
		padding_filter: padding_none
	}
	pad := data_grid_pager_padding(cfg)
	assert pad.left == 5
	assert pad.right == 7
}

fn test_data_grid_pager_padding_preserves_larger_filter_padding() {
	cfg := DataGridCfg{
		id:             'pager-padding-filter'
		columns:        []
		rows:           []
		padding_cell:   padding(0, 4, 0, 3)
		padding_filter: padding(2, 10, 1, 8)
	}
	pad := data_grid_pager_padding(cfg)
	assert pad.top == 2
	assert pad.bottom == 1
	assert pad.left == 8
	assert pad.right == 10
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

fn test_data_grid_column_order_move() {
	order := ['a', 'b', 'c', 'd']
	left := data_grid_column_order_move(order, 'c', -1)
	assert left == ['a', 'c', 'b', 'd']

	right := data_grid_column_order_move(order, 'b', 2)
	assert right == ['a', 'c', 'd', 'b']

	clamped := data_grid_column_order_move(order, 'a', -1)
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
	cols := data_grid_effective_columns(cfg.columns, cfg.column_order, cfg.hidden_column_ids)
	assert cols.len == 3
	assert cols[0].id == 'b'
	assert cols[1].id == 'a'
	assert cols[2].id == 'c'
}

fn test_data_grid_effective_columns_respects_hidden_columns() {
	cfg := DataGridCfg{
		id:                'hidden-cols'
		column_order:      ['a', 'b', 'c']
		hidden_column_ids: {
			'b': true
		}
		columns:           [
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
		rows:              []
	}
	cols := data_grid_effective_columns(cfg.columns, cfg.column_order, cfg.hidden_column_ids)
	assert cols.len == 2
	assert cols[0].id == 'a'
	assert cols[1].id == 'c'
}

fn test_data_grid_next_hidden_columns_keeps_one_visible() {
	columns := [
		GridColumnCfg{
			id:    'a'
			title: 'A'
		},
		GridColumnCfg{
			id:    'b'
			title: 'B'
		},
	]
	base := {
		'b': true
	}
	next_a := data_grid_next_hidden_columns(base, 'a', columns)
	assert next_a['a'] == false
	assert next_a['b'] == true

	next_b := data_grid_next_hidden_columns(base, 'b', columns)
	assert next_b['b'] == false
}

fn test_data_grid_effective_columns_keeps_one_when_all_hidden() {
	cfg := DataGridCfg{
		id:                'all-hidden'
		column_order:      ['a', 'b']
		hidden_column_ids: {
			'a': true
			'b': true
		}
		columns:           [
			GridColumnCfg{
				id:    'a'
				title: 'A'
			},
			GridColumnCfg{
				id:    'b'
				title: 'B'
			},
		]
		rows:              []
	}
	cols := data_grid_effective_columns(cfg.columns, cfg.column_order, cfg.hidden_column_ids)
	assert cols.len == 1
	assert cols[0].id == 'a'
}

fn test_data_grid_column_next_pin_cycles() {
	assert data_grid_column_next_pin(.none) == .left
	assert data_grid_column_next_pin(.left) == .right
	assert data_grid_column_next_pin(.right) == .none
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
	indices := []int{len: rows.len, init: index}
	ranges := data_grid_group_ranges(rows, indices, ['team', 'status'])
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

fn test_data_grid_next_detail_expanded_map_toggle() {
	base := {
		'2': true
	}
	next1 := data_grid_next_detail_expanded_map(base, '2')
	assert next1['2'] == false

	next2 := data_grid_next_detail_expanded_map(base, '3')
	assert next2['2'] == true
	assert next2['3'] == true
}

fn test_data_grid_presentation_with_master_detail_rows() {
	cfg := DataGridCfg{
		id:                      'detail'
		columns:                 [
			GridColumnCfg{
				id:    'name'
				title: 'Name'
			},
		]
		rows:                    [
			GridRow{
				id:    '1'
				cells: {
					'name': 'A'
				}
			},
			GridRow{
				id:    '2'
				cells: {
					'name': 'B'
				}
			},
		]
		detail_expanded_row_ids: {
			'2': true
		}
		on_detail_row_view:      fn (_ GridRow, mut _ Window) View {
			return rectangle(
				width:  1
				height: 1
				sizing: fixed_fixed
				color:  color_transparent
			)
		}
	}
	p := data_grid_presentation(cfg, cfg.columns)
	assert p.rows.len == 3
	assert p.rows[0].kind == .data
	assert p.rows[1].kind == .data
	assert p.rows[2].kind == .detail
	assert p.rows[2].data_row_idx == 1
	assert p.data_to_display[0] == 0
	assert p.data_to_display[1] == 1
}

fn test_data_grid_first_editable_column_index() {
	cfg := DataGridCfg{
		id:           'edit-cols'
		columns:      [
			GridColumnCfg{
				id:    'name'
				title: 'Name'
			},
			GridColumnCfg{
				id:       'team'
				title:    'Team'
				editable: true
			},
		]
		rows:         []
		on_cell_edit: fn (_ GridCellEdit, mut _ Event, mut _ Window) {}
	}
	assert data_grid_first_editable_column_index(cfg, cfg.columns) == 1
}

fn test_data_grid_first_editable_column_index_without_callback() {
	cfg := DataGridCfg{
		id:      'edit-cols-no-callback'
		columns: [
			GridColumnCfg{
				id:       'name'
				title:    'Name'
				editable: true
			},
		]
		rows:    []
	}
	assert data_grid_first_editable_column_index(cfg, cfg.columns) == -1
}

fn test_data_grid_cell_editor_focus_id() {
	cfg := DataGridCfg{
		id_focus: 500
		id:       'focus'
		columns:  []
		rows:     []
	}
	assert data_grid_cell_editor_focus_id(cfg, 3, 0, 0) == 504
	assert data_grid_cell_editor_focus_id(cfg, 3, 2, 1) == 505
	assert data_grid_cell_editor_focus_id(cfg, 3, 99, 1) == 505
	assert data_grid_cell_editor_focus_id(cfg, 3, -1, 0) == 0
}

fn test_data_grid_editor_bool_value() {
	assert data_grid_editor_bool_value('true') == true
	assert data_grid_editor_bool_value('YES') == true
	assert data_grid_editor_bool_value('1') == true
	assert data_grid_editor_bool_value('false') == false
	assert data_grid_editor_bool_value('0') == false
	assert data_grid_editor_bool_value('abc') == false
}

fn test_data_grid_resolve_cell_format_defaults() {
	base := TextStyle{
		color: white
		size:  13
	}
	next_style, bg := data_grid_resolve_cell_format(base, GridCellFormat{})
	assert next_style.color == base.color
	assert next_style.size == base.size
	assert bg == color_transparent
}

fn test_data_grid_resolve_cell_format_overrides() {
	base := TextStyle{
		color: white
		size:  13
	}
	next_style, bg := data_grid_resolve_cell_format(base, GridCellFormat{
		has_bg_color:   true
		bg_color:       red
		has_text_color: true
		text_color:     green
	})
	assert next_style.color == green
	assert next_style.size == base.size
	assert bg == red
}

fn test_data_grid_parse_editor_date() {
	parsed := data_grid_parse_editor_date('2/10/2026')
	assert parsed.custom_format('M/D/YYYY') == '2/10/2026'
}

fn test_data_grid_row_id_prefers_explicit_id() {
	row := GridRow{
		id:    'row-7'
		cells: {
			'name': 'Ada'
		}
	}
	assert data_grid_row_id(row, 99) == 'row-7'
}

fn test_data_grid_row_id_fallback_is_stable_for_same_cells() {
	row := GridRow{
		id:    ''
		cells: {
			'team':  'Core'
			'name':  'Ada'
			'score': '95'
		}
	}
	id1 := data_grid_row_id(row, 1)
	id2 := data_grid_row_id(row, 27)
	assert id1 == id2
	assert id1.starts_with('__auto_')
}

fn test_data_grid_row_id_fallback_differs_for_diff_cells() {
	row_a := GridRow{
		id:    ''
		cells: {
			'name':  'Ada'
			'score': '95'
		}
	}
	row_b := GridRow{
		id:    ''
		cells: {
			'name':  'Ada'
			'score': '40'
		}
	}
	assert data_grid_row_id(row_a, 0) != data_grid_row_id(row_b, 0)
}

fn test_data_grid_has_row_id() {
	rows := [
		GridRow{
			id: '1'
		},
		GridRow{
			id: '2'
		},
	]
	assert data_grid_has_row_id(rows, '2') == true
	assert data_grid_has_row_id(rows, '3') == false
}

fn test_data_grid_has_keyboard_modifiers_ignores_mouse_bits() {
	mut e := Event{
		modifiers: .lmb
	}
	assert data_grid_has_keyboard_modifiers(&e) == false

	e.modifiers = .shift
	assert data_grid_has_keyboard_modifiers(&e) == true

	e.modifiers = .ctrl_alt
	assert data_grid_has_keyboard_modifiers(&e) == true
}

fn test_data_grid_page_bounds_disabled() {
	start, end, page, count := data_grid_page_bounds(23, 0, 9)
	assert start == 0
	assert end == 23
	assert page == 0
	assert count == 1
}

fn test_data_grid_page_bounds_enabled() {
	start, end, page, count := data_grid_page_bounds(23, 10, 2)
	assert start == 20
	assert end == 23
	assert page == 2
	assert count == 3
}

fn test_data_grid_page_row_indices() {
	indices := data_grid_page_row_indices(3, 7)
	assert indices == [3, 4, 5, 6]
}

fn test_data_grid_split_frozen_top_indices_no_frozen_ids() {
	cfg := DataGridCfg{
		id:      'freeze-none'
		columns: []
		rows:    [
			GridRow{
				id: '1'
			},
			GridRow{
				id: '2'
			},
			GridRow{
				id: '3'
			},
		]
	}
	top, body := data_grid_split_frozen_top_indices(cfg, [0, 1, 2])
	assert top.len == 0
	assert body == [0, 1, 2]
}

fn test_data_grid_split_frozen_top_indices_preserves_visible_order() {
	cfg := DataGridCfg{
		id:                 'freeze-order'
		frozen_top_row_ids: ['3', 'missing', '1', '3']
		columns:            []
		rows:               [
			GridRow{
				id: '1'
			},
			GridRow{
				id: '2'
			},
			GridRow{
				id: '3'
			},
			GridRow{
				id: '4'
			},
		]
	}
	top, body := data_grid_split_frozen_top_indices(cfg, [0, 1, 2, 3])
	assert top == [0, 2]
	assert body == [1, 3]
}

fn test_data_grid_split_frozen_top_indices_page_scope_only() {
	cfg := DataGridCfg{
		id:                 'freeze-page'
		frozen_top_row_ids: ['1', '4']
		columns:            []
		rows:               [
			GridRow{
				id: '1'
			},
			GridRow{
				id: '2'
			},
			GridRow{
				id: '3'
			},
			GridRow{
				id: '4'
			},
		]
	}
	top, body := data_grid_split_frozen_top_indices(cfg, [2, 3])
	assert top == [3]
	assert body == [2]
}

fn test_data_grid_split_frozen_top_indices_keeps_body_for_duplicate_row_ids() {
	cfg := DataGridCfg{
		id:                 'freeze-dup-id'
		frozen_top_row_ids: ['dup']
		columns:            []
		rows:               [
			GridRow{
				id: 'dup'
			},
			GridRow{
				id: 'dup'
			},
			GridRow{
				id: '3'
			},
		]
	}
	top, body := data_grid_split_frozen_top_indices(cfg, [0, 1, 2])
	assert top == [0]
	assert body == [1, 2]
}

fn test_data_grid_presentation_rows_paginates() {
	cfg := DataGridCfg{
		id:      'paged'
		columns: [
			GridColumnCfg{
				id:    'name'
				title: 'Name'
			},
		]
		rows:    [
			GridRow{
				id:    '1'
				cells: {
					'name': 'A'
				}
			},
			GridRow{
				id:    '2'
				cells: {
					'name': 'B'
				}
			},
			GridRow{
				id:    '3'
				cells: {
					'name': 'C'
				}
			},
		]
	}
	p := data_grid_presentation_rows(cfg, cfg.columns, [1, 2])
	assert p.rows.len == 2
	assert p.rows[0].kind == .data
	assert p.rows[0].data_row_idx == 1
	assert p.rows[1].data_row_idx == 2
	assert p.data_to_display[1] == 0
	assert p.data_to_display[2] == 1
	assert p.data_to_display[0] == 0
}

fn test_data_grid_next_page_index_for_key_ctrl_page() {
	mut e := Event{
		modifiers: .ctrl
		key_code:  .page_down
	}
	next := data_grid_next_page_index_for_key(1, 4, &e) or { -1 }
	assert next == 2

	e.key_code = .page_up
	prev := data_grid_next_page_index_for_key(1, 4, &e) or { -1 }
	assert prev == 0
}

fn test_data_grid_next_page_index_for_key_alt_home_end() {
	mut e := Event{
		modifiers: .alt
		key_code:  .home
	}
	first := data_grid_next_page_index_for_key(2, 6, &e) or { -1 }
	assert first == 0

	e.key_code = .end
	last := data_grid_next_page_index_for_key(2, 6, &e) or { -1 }
	assert last == 5
}

fn test_data_grid_next_page_index_for_key_invalid_combo() {
	e := Event{
		modifiers: .none
		key_code:  .page_down
	}
	assert data_grid_next_page_index_for_key(1, 4, &e) == none
}

fn test_grid_rows_to_pdf_signature() {
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
	]
	pdf := grid_rows_to_pdf(columns, rows)
	assert pdf.starts_with('%PDF-1.4')
	assert pdf.contains('/Type /Catalog')
	assert pdf.contains('Alice')
}

fn test_grid_rows_to_pdf_file() {
	columns := [
		GridColumnCfg{
			id:    'name'
			title: 'Name'
		},
	]
	rows := [
		GridRow{
			id:    '1'
			cells: {
				'name': 'Alice'
			}
		},
	]
	path := os.join_path(os.temp_dir(), 'data_grid_pdf_${time.now().unix_micro()}.pdf')
	defer {
		os.rm(path) or {}
	}
	grid_rows_to_pdf_file(path, columns, rows) or { panic(err) }
	data := os.read_file(path) or { panic(err) }
	assert data.starts_with('%PDF-1.4')
}

fn test_pdf_col_widths_proportional() {
	columns := [
		GridColumnCfg{
			id:    'a'
			title: 'ID'
		},
		GridColumnCfg{
			id:    'b'
			title: 'Description'
		},
	]
	rows := [
		GridRow{
			id:    '1'
			cells: {
				'a': '1'
				'b': 'A longer description value'
			}
		},
		GridRow{
			id:    '2'
			cells: {
				'a': '2'
				'b': 'Short'
			}
		},
	]
	widths := data_grid_pdf_col_widths(columns, rows)
	assert widths.len == 2
	// "Description" col (natural 25 runes) wider than "ID" col
	// (natural 2 runes).
	assert widths[1] > widths[0]
	// Both fit within budget, so natural widths are used.
	assert widths[0] == 2
	assert widths[1] == 26
}

fn test_pdf_pad_clips_long_text() {
	assert data_grid_pdf_pad('Hello World', 5) == 'He...'
	assert data_grid_pdf_pad('OK', 5) == 'OK   '
	assert data_grid_pdf_pad('exact', 5) == 'exact'
}

fn test_data_grid_xlsx_col_ref() {
	assert data_grid_xlsx_col_ref(0) == 'A'
	assert data_grid_xlsx_col_ref(25) == 'Z'
	assert data_grid_xlsx_col_ref(26) == 'AA'
	assert data_grid_xlsx_col_ref(27) == 'AB'
	assert data_grid_xlsx_col_ref(51) == 'AZ'
	assert data_grid_xlsx_col_ref(52) == 'BA'
	assert data_grid_xlsx_col_ref(701) == 'ZZ'
	assert data_grid_xlsx_col_ref(702) == 'AAA'
}

fn test_grid_rows_to_xlsx_signature() {
	columns := [
		GridColumnCfg{
			id:    'name'
			title: 'Name'
		},
	]
	rows := [
		GridRow{
			id:    '1'
			cells: {
				'name': 'Alice'
			}
		},
	]
	bytes := grid_rows_to_xlsx(columns, rows) or { panic(err) }
	assert bytes.len > 2
	assert bytes[0] == `P`
	assert bytes[1] == `K`
}

fn test_grid_rows_to_xlsx_file_contains_sheet() {
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
	]
	path := os.join_path(os.temp_dir(), 'data_grid_xlsx_${time.now().unix_micro()}.xlsx')
	defer {
		os.rm(path) or {}
	}
	grid_rows_to_xlsx_file(path, columns, rows) or { panic(err) }
	sheet := zip_entry_text(path, 'xl/worksheets/sheet1.xml') or { panic(err) }
	assert sheet.contains('SheetData') == false
	assert sheet.contains('Name')
	assert sheet.contains('Alice')
	assert sheet.contains('<c r="B2" t="inlineStr"><is><t>30</t></is></c>')
}

fn test_grid_rows_to_xlsx_file_with_cfg_auto_type() {
	columns := [
		GridColumnCfg{
			id:    'age'
			title: 'Age'
		},
	]
	rows := [
		GridRow{
			id:    '1'
			cells: {
				'age': '30'
			}
		},
	]
	path := os.join_path(os.temp_dir(), 'data_grid_xlsx_typed_${time.now().unix_micro()}.xlsx')
	defer {
		os.rm(path) or {}
	}
	grid_rows_to_xlsx_file_with_cfg(path, columns, rows, GridExportCfg{
		xlsx_auto_type: true
	}) or { panic(err) }
	sheet := zip_entry_text(path, 'xl/worksheets/sheet1.xml') or { panic(err) }
	assert sheet.contains('<c r="A2"><v>30</v></c>')
}

fn test_grid_rows_to_xlsx_file_sanitizes_formulas() {
	columns := [
		GridColumnCfg{
			id:    'danger'
			title: 'Danger'
		},
	]
	rows := [
		GridRow{
			id:    '1'
			cells: {
				'danger': '=2+2'
			}
		},
	]
	path := os.join_path(os.temp_dir(), 'data_grid_xlsx_safe_${time.now().unix_micro()}.xlsx')
	defer {
		os.rm(path) or {}
	}
	grid_rows_to_xlsx_file(path, columns, rows) or { panic(err) }
	sheet := zip_entry_text(path, 'xl/worksheets/sheet1.xml') or { panic(err) }
	assert sheet.contains('&apos;=2+2')
}

fn test_data_grid_crud_build_payload() {
	state := DataGridCrudState{
		committed_rows:  [
			GridRow{
				id:    '1'
				cells: {
					'name': 'A'
				}
			},
			GridRow{
				id:    '2'
				cells: {
					'name': 'B'
				}
			},
		]
		working_rows:    [
			GridRow{
				id:    '__draft_grid_1'
				cells: {
					'name': 'Draft'
				}
			},
			GridRow{
				id:    '1'
				cells: {
					'name': 'A+'
				}
			},
		]
		dirty_row_ids:   {
			'1':              true
			'__draft_grid_1': true
		}
		draft_row_ids:   {
			'__draft_grid_1': true
		}
		deleted_row_ids: {
			'2': true
		}
	}
	create_rows, update_rows, edits, delete_ids := data_grid_crud_build_payload(state)
	assert create_rows.len == 1
	assert create_rows[0].id == '__draft_grid_1'
	assert update_rows.len == 1
	assert update_rows[0].id == '1'
	assert edits.len == 1
	assert edits[0].row_id == '1'
	assert edits[0].col_id == 'name'
	assert edits[0].value == 'A+'
	assert delete_ids == ['2']
}

fn test_data_grid_crud_add_row_scrolls_to_top() {
	mut w := Window{}
	mut e := Event{}
	grid_id := 'crud-add-scroll'
	scroll_id := u32(77)
	w.view_state.scroll_y.set(scroll_id, -180)
	selection_key := '${grid_id}:selected'
	data_grid_crud_add_row(grid_id, [
		GridColumnCfg{
			id:    'name'
			title: 'Name'
		},
	], fn [selection_key] (sel GridSelection, mut _ Event, mut w Window) {
		w.view_state.data_grid_jump_input.set(selection_key, sel.active_row_id)
	}, 0, scroll_id, 0, 0, unsafe { nil }, mut e, mut w)
	state := w.view_state.data_grid_crud_state.get(grid_id) or { DataGridCrudState{} }
	draft_id := '__draft_${grid_id}_1'
	assert state.working_rows.len == 1
	assert state.working_rows[0].id == draft_id
	assert (w.view_state.scroll_y.get(scroll_id) or { f32(1) }) == 0
	assert (w.view_state.data_grid_jump_input.get(selection_key) or { '' }) == draft_id
	assert e.is_handled
}

fn test_data_grid_crud_add_row_paged_requests_first_page() {
	mut w := Window{}
	mut e := Event{}
	grid_id := 'crud-add-paged'
	scroll_id := u32(99)
	w.view_state.scroll_y.set(scroll_id, -240)
	page_key := '${grid_id}:requested'
	data_grid_crud_add_row(grid_id, [
		GridColumnCfg{
			id:    'name'
			title: 'Name'
		},
	], fn (_ GridSelection, mut _ Event, mut _ Window) {}, 0, scroll_id, 20, 2, fn [page_key] (page int, mut _ Event, mut w Window) {
		w.view_state.data_grid_pending_jump_row.set(page_key, page)
	}, mut e, mut w)
	assert (w.view_state.data_grid_pending_jump_row.get(page_key) or { -1 }) == 0
	assert (w.view_state.data_grid_pending_jump_row.get(grid_id) or { -1 }) == 0
	assert (w.view_state.scroll_y.get(scroll_id) or { f32(1) }) == 0
	assert e.is_handled
}

fn test_data_grid_crud_add_row_paged_first_page_no_jump_request() {
	mut w := Window{}
	mut e := Event{}
	grid_id := 'crud-add-page-zero'
	scroll_id := u32(101)
	w.view_state.scroll_y.set(scroll_id, -240)
	page_key := '${grid_id}:requested'
	data_grid_crud_add_row(grid_id, [
		GridColumnCfg{
			id:    'name'
			title: 'Name'
		},
	], fn (_ GridSelection, mut _ Event, mut _ Window) {}, 0, scroll_id, 20, 0, fn [page_key] (page int, mut _ Event, mut w Window) {
		w.view_state.data_grid_pending_jump_row.set(page_key, page)
	}, mut e, mut w)
	assert (w.view_state.data_grid_pending_jump_row.get(page_key) or { -1 }) == -1
	assert (w.view_state.data_grid_pending_jump_row.get(grid_id) or { -1 }) == -1
	assert (w.view_state.scroll_y.get(scroll_id) or { f32(1) }) == 0
	assert e.is_handled
}

fn test_data_grid_selection_remove_ids() {
	selection := GridSelection{
		anchor_row_id:    '2'
		active_row_id:    '3'
		selected_row_ids: {
			'1': true
			'2': true
			'3': true
		}
	}
	next := data_grid_selection_remove_ids(selection, {
		'2': true
		'3': true
	})
	assert next.anchor_row_id == ''
	assert next.active_row_id == ''
	assert next.selected_row_ids.len == 1
	assert next.selected_row_ids['1']
}

fn zip_entry_text(path string, entry_name string) !string {
	mut zip := szip.open(path, .no_compression, .read_only)!
	defer {
		zip.close()
	}
	total := zip.total()!
	for idx in 0 .. total {
		zip.open_entry_by_index(idx)!
		name := zip.name()
		if name == entry_name {
			size := int(zip.size())
			mut buf := []u8{len: int_max(1, size)}
			read_len := zip.read_entry_buf(buf.data, buf.len)!
			zip.close_entry()
			return buf[..read_len].bytestr()
		}
		zip.close_entry()
	}
	return error('zip entry not found: ${entry_name}')
}
