module gui

fn test_in_memory_cursor_data_source_pages_with_cursor() {
	source := InMemoryDataSource{
		rows:          data_source_rows(10)
		default_limit: 3
	}
	first := source.fetch_data(GridDataRequest{
		grid_id: 'grid'
		query:   GridQueryState{}
		page:    GridPageRequest(GridCursorPageReq{
			cursor: ''
			limit:  3
		})
	}) or { panic(err) }
	assert first.rows.len == 3
	assert first.rows[0].id == '1'
	assert first.next_cursor == 'i:3'
	assert first.prev_cursor == ''
	assert first.has_more == true
	if total := first.row_count {
		assert total == 10
	} else {
		assert false
	}
	second := source.fetch_data(GridDataRequest{
		grid_id: 'grid'
		query:   GridQueryState{}
		page:    GridPageRequest(GridCursorPageReq{
			cursor: first.next_cursor
			limit:  3
		})
	}) or { panic(err) }
	assert second.rows.len == 3
	assert second.rows[0].id == '4'
	assert second.prev_cursor == 'i:0'
}

fn test_in_memory_offset_data_source_pages_with_offsets() {
	source := InMemoryDataSource{
		rows:            data_source_rows(10)
		default_limit:   4
		supports_cursor: false
	}
	res := source.fetch_data(GridDataRequest{
		grid_id: 'grid'
		query:   GridQueryState{}
		page:    GridPageRequest(GridOffsetPageReq{
			start_index: 2
			end_index:   5
		})
	}) or { panic(err) }
	assert res.rows.len == 3
	assert res.rows[0].id == '3'
	assert res.rows[2].id == '5'
	assert res.next_cursor == 'i:5'
	assert res.prev_cursor == 'i:0'
}

fn test_in_memory_source_applies_query_sort_filter() {
	rows := [
		GridRow{
			id:    '1'
			cells: {
				'name':  'Ada'
				'team':  'Platform'
				'score': '81'
			}
		},
		GridRow{
			id:    '2'
			cells: {
				'name':  'Bob'
				'team':  'Data'
				'score': '92'
			}
		},
		GridRow{
			id:    '3'
			cells: {
				'name':  'Cara'
				'team':  'Data'
				'score': '77'
			}
		},
	]
	source := InMemoryDataSource{
		rows: rows
	}
	res := source.fetch_data(GridDataRequest{
		grid_id: 'grid'
		query:   GridQueryState{
			sorts:   [
				GridSort{
					col_id: 'name'
					dir:    .desc
				},
			]
			filters: [
				GridFilter{
					col_id: 'team'
					op:     'equals'
					value:  'Data'
				},
			]
		}
		page:    GridPageRequest(GridCursorPageReq{
			cursor: ''
			limit:  10
		})
	}) or { panic(err) }
	assert res.rows.len == 2
	assert res.rows[0].id == '3'
	assert res.rows[1].id == '2'
}

fn test_in_memory_source_honors_abort_signal() {
	source := InMemoryDataSource{
		rows:       data_source_rows(20)
		latency_ms: 30
	}
	mut controller := new_grid_abort_controller()
	controller.abort()
	_ := source.fetch_data(GridDataRequest{
		grid_id: 'grid'
		query:   GridQueryState{}
		page:    GridPageRequest(GridCursorPageReq{})
		signal:  controller.signal
	}) or {
		assert err.msg().contains('aborted')
		return
	}
	assert false
}

fn test_data_grid_source_effective_pagination_kind_fallback() {
	cursor_only := GridDataCapabilities{
		supports_cursor_pagination: true
		supports_offset_pagination: false
	}
	offset_only := GridDataCapabilities{
		supports_cursor_pagination: false
		supports_offset_pagination: true
	}
	assert data_grid_source_effective_pagination_kind(.offset, cursor_only) == .cursor
	assert data_grid_source_effective_pagination_kind(.cursor, offset_only) == .offset
}

fn test_data_grid_source_apply_query_reset_resets_paging() {
	mut state := DataGridSourceState{
		query_signature: grid_query_signature(GridQueryState{})
		current_cursor:  'i:400'
		next_cursor:     'i:600'
		prev_cursor:     'i:200'
		offset_start:    400
		request_key:     'old'
	}
	cfg := DataGridCfg{
		id:      'grid'
		columns: [
			GridColumnCfg{
				id:    'name'
				title: 'Name'
			},
		]
		query:   GridQueryState{
			quick_filter: 'ada'
		}
	}
	data_grid_source_apply_query_reset(mut state, cfg, grid_query_signature(cfg.query))
	assert state.current_cursor == ''
	assert state.next_cursor == ''
	assert state.prev_cursor == ''
	assert state.offset_start == 0
	assert state.request_key == ''
	assert state.query_signature == grid_query_signature(cfg.query)
}

fn test_data_grid_source_rows_text_cursor_uses_range() {
	state := DataGridSourceState{
		current_cursor: 'i:220'
		received_count: 220
		row_count:      ?int(50000)
	}
	text := data_grid_source_rows_text(.cursor, state)
	assert text == 'Rows 221-440/50000'
}

fn test_data_grid_source_rows_text_cursor_opaque_fallback() {
	state := DataGridSourceState{
		current_cursor: 'opaque-token'
		received_count: 220
		row_count:      ?int(50000)
	}
	text := data_grid_source_rows_text(.cursor, state)
	assert text == 'Rows 220/50000'
}

fn test_data_grid_source_row_position_text_offset() {
	cfg := DataGridCfg{
		id:        'source-row-position'
		columns:   []
		rows:      [
			GridRow{
				id: '101'
			},
			GridRow{
				id: '102'
			},
		]
		selection: GridSelection{
			active_row_id: '102'
		}
	}
	state := DataGridSourceState{
		offset_start: 100
		row_count:    ?int(500)
	}
	assert data_grid_source_row_position_text(cfg, state, .offset) == 'Row 102 of 500'
}

fn test_data_grid_source_jump_enabled_rules() {
	on_sel := fn (_ GridSelection, mut _ Event, mut _ Window) {}
	row_count := ?int(1000)
	assert data_grid_source_jump_enabled(on_sel, row_count, false, '', .offset, 200)
	assert !data_grid_source_jump_enabled(on_sel, row_count, false, '', .cursor, 200)
	assert !data_grid_source_jump_enabled(on_sel, ?int(none), false, '', .offset, 200)
}

fn test_in_memory_cursor_data_source_mutate_crud() {
	mut source := InMemoryDataSource{
		rows: data_source_rows(3)
	}
	create_res := source.mutate_data(GridMutationRequest{
		grid_id: 'grid'
		kind:    .create
		rows:    [
			GridRow{
				id:    ''
				cells: {
					'name':  'New User'
					'team':  'Data'
					'score': '91'
				}
			},
		]
	}) or { panic(err) }
	assert create_res.created.len == 1
	assert create_res.created[0].id == '4'

	update_res := source.mutate_data(GridMutationRequest{
		grid_id: 'grid'
		kind:    .update
		edits:   [
			GridCellEdit{
				row_id: '2'
				col_id: 'team'
				value:  'Core'
			},
		]
	}) or { panic(err) }
	assert update_res.updated.len == 1
	assert update_res.updated[0].cells['team'] == 'Core'

	delete_res := source.mutate_data(GridMutationRequest{
		grid_id: 'grid'
		kind:    .delete
		row_ids: ['1']
	}) or { panic(err) }
	assert delete_res.deleted_ids == ['1']
	final := source.fetch_data(GridDataRequest{
		grid_id: 'grid'
		query:   GridQueryState{}
		page:    GridPageRequest(GridCursorPageReq{
			limit: 20
		})
	}) or { panic(err) }
	assert final.rows.len == 3
	assert final.rows[0].id == '2'
	assert final.rows[0].cells['team'] == 'Core'
}

fn test_in_memory_offset_data_source_mutate_batch_delete() {
	mut source := InMemoryDataSource{
		rows:            data_source_rows(5)
		supports_cursor: false
	}
	res := source.mutate_data(GridMutationRequest{
		grid_id: 'grid'
		kind:    .delete
		row_ids: ['2', '4']
	}) or { panic(err) }
	assert res.deleted_ids.len == 2
	assert res.deleted_ids[0] == '2'
	assert res.deleted_ids[1] == '4'
	page := source.fetch_data(GridDataRequest{
		grid_id: 'grid'
		query:   GridQueryState{}
		page:    GridPageRequest(GridOffsetPageReq{
			start_index: 0
			end_index:   10
		})
	}) or { panic(err) }
	assert page.rows.len == 3
	assert page.rows[0].id == '1'
	assert page.rows[1].id == '3'
	assert page.rows[2].id == '5'
}

fn test_in_memory_cursor_data_source_empty_fetch() {
	source := InMemoryDataSource{
		rows: []GridRow{}
	}
	res := source.fetch_data(GridDataRequest{
		grid_id: 'grid'
		query:   GridQueryState{}
		page:    GridPageRequest(GridCursorPageReq{
			limit: 10
		})
	}) or { panic(err) }
	assert res.rows.len == 0
	assert res.next_cursor == ''
	assert res.prev_cursor == ''
	assert res.has_more == false
	assert res.received_count == 0
}

fn test_in_memory_offset_data_source_with_cursor_request() {
	source := InMemoryDataSource{
		rows:            data_source_rows(10)
		default_limit:   5
		supports_cursor: false
	}
	res := source.fetch_data(GridDataRequest{
		grid_id: 'grid'
		query:   GridQueryState{}
		page:    GridPageRequest(GridCursorPageReq{
			cursor: 'i:3'
			limit:  4
		})
	}) or { panic(err) }
	assert res.rows.len == 4
	assert res.rows[0].id == '4'
	assert res.rows[3].id == '7'
	assert res.has_more == true
}

fn test_in_memory_source_starts_with_ends_with_filters() {
	rows := [
		GridRow{
			id:    '1'
			cells: {
				'name': 'Alice'
			}
		},
		GridRow{
			id:    '2'
			cells: {
				'name': 'Bob'
			}
		},
		GridRow{
			id:    '3'
			cells: {
				'name': 'Alicia'
			}
		},
	]
	source := InMemoryDataSource{
		rows: rows
	}
	starts := source.fetch_data(GridDataRequest{
		grid_id: 'grid'
		query:   GridQueryState{
			filters: [
				GridFilter{
					col_id: 'name'
					op:     'starts_with'
					value:  'Ali'
				},
			]
		}
		page:    GridPageRequest(GridCursorPageReq{
			limit: 10
		})
	}) or { panic(err) }
	assert starts.rows.len == 2
	assert starts.rows[0].id == '1'
	assert starts.rows[1].id == '3'

	ends := source.fetch_data(GridDataRequest{
		grid_id: 'grid'
		query:   GridQueryState{
			filters: [
				GridFilter{
					col_id: 'name'
					op:     'ends_with'
					value:  'ce'
				},
			]
		}
		page:    GridPageRequest(GridCursorPageReq{
			limit: 10
		})
	}) or { panic(err) }
	assert ends.rows.len == 1
	assert ends.rows[0].id == '1'
}

fn test_in_memory_source_update_empty_row_id_returns_error() {
	mut source := InMemoryDataSource{
		rows: data_source_rows(3)
	}
	_ := source.mutate_data(GridMutationRequest{
		grid_id: 'grid'
		kind:    .update
		rows:    [
			GridRow{
				id:    ''
				cells: {
					'name': 'Oops'
				}
			},
		]
	}) or {
		assert err.msg().contains('empty id')
		return
	}
	assert false
}

fn test_in_memory_source_update_nonexistent_row_returns_error() {
	mut source := InMemoryDataSource{
		rows: data_source_rows(3)
	}
	_ := source.mutate_data(GridMutationRequest{
		grid_id: 'grid'
		kind:    .update
		rows:    [
			GridRow{
				id:    'no-such-id'
				cells: {
					'name': 'Ghost'
				}
			},
		]
	}) or {
		assert err.msg().contains('update row not found')
		return
	}
	assert false
}

fn test_in_memory_source_edit_empty_col_id_returns_error() {
	mut source := InMemoryDataSource{
		rows: data_source_rows(3)
	}
	_ := source.mutate_data(GridMutationRequest{
		grid_id: 'grid'
		kind:    .update
		edits:   [
			GridCellEdit{
				row_id: '1'
				col_id: ''
				value:  'x'
			},
		]
	}) or {
		assert err.msg().contains('empty col id')
		return
	}
	assert false
}

fn test_in_memory_source_row_count_unknown() {
	source := InMemoryDataSource{
		rows:            data_source_rows(5)
		row_count_known: false
	}
	res := source.fetch_data(GridDataRequest{
		grid_id: 'grid'
		query:   GridQueryState{}
		page:    GridPageRequest(GridCursorPageReq{
			limit: 10
		})
	}) or { panic(err) }
	assert res.rows.len == 5
	assert res.row_count == none
}

fn test_next_mutation_row_id_falls_back_to_random() {
	// Build 1000 rows with IDs "1001".."2000".
	// rows.len=1000, so numeric candidates="1001".."2000"
	// are all exhausted; random hex fallback should succeed.
	n := 1000
	mut rows := []GridRow{cap: n}
	mut existing := map[string]bool{}
	for i in 0 .. n {
		row := GridRow{
			id: '${n + i + 1}'
		}
		existing[data_grid_row_id(row, i)] = true
		rows << row
	}
	id := grid_data_source_next_create_row_id(rows, existing, '') or {
		assert false
		return
	}
	assert id.starts_with('__gen_')
}

fn test_contains_lower_ascii() {
	assert grid_contains_lower('Hello World', 'hello')
	assert grid_contains_lower('ABCDEF', 'cde')
	assert !grid_contains_lower('ABC', 'xyz')
	assert grid_contains_lower('', '')
	assert !grid_contains_lower('', 'a')
	assert grid_equals_lower('Hello', 'hello')
	assert !grid_equals_lower('Hello', 'hell')
	assert grid_starts_with_lower('Hello', 'hel')
	assert !grid_starts_with_lower('Hello', 'elo')
	assert grid_ends_with_lower('Hello', 'llo')
	assert !grid_ends_with_lower('Hello', 'hel')
}

fn test_multi_sort_secondary_priority() {
	rows := [
		GridRow{
			id:    '1'
			cells: {
				'team':  'Data'
				'score': '80'
			}
		},
		GridRow{
			id:    '2'
			cells: {
				'team':  'Core'
				'score': '90'
			}
		},
		GridRow{
			id:    '3'
			cells: {
				'team':  'Data'
				'score': '95'
			}
		},
		GridRow{
			id:    '4'
			cells: {
				'team':  'Core'
				'score': '70'
			}
		},
	]
	sorted := grid_data_source_apply_query(rows, GridQueryState{
		sorts: [
			GridSort{
				col_id: 'team'
				dir:    .asc
			},
			GridSort{
				col_id: 'score'
				dir:    .desc
			},
		]
	})
	assert sorted.len == 4
	// Core group: score desc → 90, 70
	assert sorted[0].id == '2'
	assert sorted[1].id == '4'
	// Data group: score desc → 95, 80
	assert sorted[2].id == '3'
	assert sorted[3].id == '1'
}

fn test_cursor_to_index_plain_integer() {
	// Plain integer (no "i:" prefix).
	if idx := grid_data_source_cursor_to_index_opt('5') {
		assert idx == 5
	} else {
		assert false
	}
	// Invalid non-numeric string returns none.
	assert grid_data_source_cursor_to_index_opt('abc') == none
	// Empty string returns 0.
	if idx := grid_data_source_cursor_to_index_opt('') {
		assert idx == 0
	} else {
		assert false
	}
}

fn test_in_memory_offset_data_source_pages_full_assertions() {
	source := InMemoryDataSource{
		rows:            data_source_rows(10)
		default_limit:   4
		supports_cursor: false
	}
	res := source.fetch_data(GridDataRequest{
		grid_id: 'grid'
		query:   GridQueryState{}
		page:    GridPageRequest(GridOffsetPageReq{
			start_index: 2
			end_index:   5
		})
	}) or { panic(err) }
	assert res.rows.len == 3
	assert res.has_more == true
	assert res.received_count == 3
	if total := res.row_count {
		assert total == 10
	} else {
		assert false
	}
}

fn test_in_memory_cursor_capabilities() {
	source := InMemoryDataSource{
		rows:            data_source_rows(3)
		supports_offset: false
	}
	caps := source.capabilities()
	assert caps.supports_cursor_pagination == true
	assert caps.supports_offset_pagination == false
	assert caps.supports_numbered_pages == false
	assert caps.row_count_known == true
	assert caps.supports_create == true
	assert caps.supports_update == true
	assert caps.supports_delete == true
	assert caps.supports_batch_delete == true
}

fn test_in_memory_offset_capabilities() {
	source := InMemoryDataSource{
		rows:            data_source_rows(3)
		supports_cursor: false
		row_count_known: false
	}
	caps := source.capabilities()
	assert caps.supports_cursor_pagination == false
	assert caps.supports_offset_pagination == true
	assert caps.supports_numbered_pages == true
	assert caps.row_count_known == false
}

fn test_grid_query_signature_stable_across_filter_order() {
	q1 := GridQueryState{
		filters: [
			GridFilter{
				col_id: 'name'
				op:     'equals'
				value:  'Ada'
			},
			GridFilter{
				col_id: 'team'
				op:     'contains'
				value:  'Data'
			},
		]
	}
	q2 := GridQueryState{
		filters: [
			GridFilter{
				col_id: 'team'
				op:     'contains'
				value:  'Data'
			},
			GridFilter{
				col_id: 'name'
				op:     'equals'
				value:  'Ada'
			},
		]
	}
	assert grid_query_signature(q1) == grid_query_signature(q2)
}

fn test_grid_query_signature_different_ops_on_same_col() {
	q1 := GridQueryState{
		filters: [
			GridFilter{
				col_id: 'name'
				op:     'contains'
				value:  'A'
			},
			GridFilter{
				col_id: 'name'
				op:     'equals'
				value:  'A'
			},
		]
	}
	q2 := GridQueryState{
		filters: [
			GridFilter{
				col_id: 'name'
				op:     'equals'
				value:  'A'
			},
			GridFilter{
				col_id: 'name'
				op:     'contains'
				value:  'A'
			},
		]
	}
	assert grid_query_signature(q1) == grid_query_signature(q2)
}

fn test_in_memory_source_sort_only_no_filter() {
	rows := [
		GridRow{
			id:    '1'
			cells: {
				'name': 'Cara'
			}
		},
		GridRow{
			id:    '2'
			cells: {
				'name': 'Ada'
			}
		},
		GridRow{
			id:    '3'
			cells: {
				'name': 'Bob'
			}
		},
	]
	sorted := grid_data_source_apply_query(rows, GridQueryState{
		sorts: [
			GridSort{
				col_id: 'name'
				dir:    .asc
			},
		]
	})
	assert sorted.len == 3
	assert sorted[0].id == '2'
	assert sorted[1].id == '3'
	assert sorted[2].id == '1'
}

fn test_in_memory_source_quick_filter() {
	rows := [
		GridRow{
			id:    '1'
			cells: {
				'name': 'Alice'
				'team': 'Core'
			}
		},
		GridRow{
			id:    '2'
			cells: {
				'name': 'Bob'
				'team': 'Data'
			}
		},
		GridRow{
			id:    '3'
			cells: {
				'name': 'Charlie'
				'team': 'Core'
			}
		},
	]
	source := InMemoryDataSource{
		rows: rows
	}
	res := source.fetch_data(GridDataRequest{
		grid_id: 'grid'
		query:   GridQueryState{
			quick_filter: 'bob'
		}
		page:    GridPageRequest(GridCursorPageReq{
			limit: 10
		})
	}) or { panic(err) }
	assert res.rows.len == 1
	assert res.rows[0].id == '2'
}

fn test_in_memory_source_create_with_preferred_id() {
	mut source := InMemoryDataSource{
		rows: data_source_rows(3)
	}
	res := source.mutate_data(GridMutationRequest{
		grid_id: 'grid'
		kind:    .create
		rows:    [
			GridRow{
				id:    'custom-99'
				cells: {
					'name': 'Custom'
				}
			},
		]
	}) or { panic(err) }
	assert res.created.len == 1
	assert res.created[0].id == 'custom-99'
}

fn test_in_memory_source_delete_via_rows() {
	mut source := InMemoryDataSource{
		rows: data_source_rows(5)
	}
	res := source.mutate_data(GridMutationRequest{
		grid_id: 'grid'
		kind:    .delete
		rows:    [GridRow{
			id: '2'
		}, GridRow{
			id: '4'
		}]
	}) or { panic(err) }
	assert res.deleted_ids.len == 2
	assert '2' in res.deleted_ids
	assert '4' in res.deleted_ids
}

fn test_cursor_to_index_with_prefix() {
	if idx := grid_data_source_cursor_to_index_opt('i:42') {
		assert idx == 42
	} else {
		assert false
	}
	if idx := grid_data_source_cursor_to_index_opt('i:0') {
		assert idx == 0
	} else {
		assert false
	}
	assert grid_data_source_cursor_to_index_opt('i:abc') == none
}

fn test_offset_bounds_empty_range_fallback() {
	// When end <= start, falls back to default_limit.
	start, end := grid_data_source_offset_bounds(5, 5, 100, 10)
	assert start == 5
	assert end == 15

	// When start==0, end==0.
	s2, e2 := grid_data_source_offset_bounds(0, 0, 100, 20)
	assert s2 == 0
	assert e2 == 20

	// Total limits the fallback.
	s3, e3 := grid_data_source_offset_bounds(95, 95, 100, 20)
	assert s3 == 95
	assert e3 == 100
}

fn test_data_grid_source_apply_query_reset_clears_pending_jump() {
	mut state := DataGridSourceState{
		query_signature:  grid_query_signature(GridQueryState{})
		pending_jump_row: 42
	}
	cfg := DataGridCfg{
		id:      'grid'
		columns: []
		query:   GridQueryState{
			quick_filter: 'x'
		}
	}
	data_grid_source_apply_query_reset(mut state, cfg, grid_query_signature(cfg.query))
	assert state.pending_jump_row == -1
}

fn data_source_rows(count int) []GridRow {
	mut rows := []GridRow{cap: count}
	for i in 0 .. count {
		id := i + 1
		rows << GridRow{
			id:    '${id}'
			cells: {
				'name':  'User ${id}'
				'team':  if i % 2 == 0 { 'Data' } else { 'Platform' }
				'score': '${70 + i % 30}'
			}
		}
	}
	return rows
}
