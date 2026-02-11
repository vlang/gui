module gui

fn test_in_memory_cursor_data_source_pages_with_cursor() {
	source := InMemoryCursorDataSource{
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
	source := InMemoryOffsetDataSource{
		rows:              data_source_rows(10)
		default_page_size: 4
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
	source := InMemoryCursorDataSource{
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
	source := InMemoryCursorDataSource{
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
	data_grid_source_apply_query_reset(mut state, cfg)
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
