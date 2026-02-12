module gui

fn test_grid_orm_data_source_capabilities() {
	source := GridOrmDataSource{
		columns:         orm_test_columns()
		fetch_fn:        orm_test_fetch_ok
		supports_offset: true
		row_count_known: false
	}
	caps := source.capabilities()
	assert caps.supports_cursor_pagination
	assert caps.supports_offset_pagination
	assert caps.supports_numbered_pages
	assert !caps.row_count_known
}

fn test_grid_orm_validate_query_normalizes_and_whitelists() {
	query := GridQueryState{
		quick_filter: 'Ada'
		sorts:        [
			GridSort{
				col_id: 'name'
				dir:    .desc
			},
			GridSort{
				col_id: 'email'
				dir:    .asc
			},
		]
		filters:      [
			GridFilter{
				col_id: 'team'
				op:     'EQUALS'
				value:  'Data'
			},
			GridFilter{
				col_id: 'team'
				op:     'between'
				value:  'A,B'
			},
			GridFilter{
				col_id: 'email'
				op:     'contains'
				value:  '@'
			},
		]
	}
	next := grid_orm_validate_query(query, orm_test_columns()) or { panic(err) }
	assert next.quick_filter == 'Ada'
	assert next.sorts.len == 1
	assert next.sorts[0].col_id == 'name'
	assert next.sorts[0].dir == .desc
	assert next.filters.len == 1
	assert next.filters[0].col_id == 'team'
	assert next.filters[0].op == 'equals'
}

fn test_grid_orm_validate_query_rejects_duplicate_column_ids() {
	_ := grid_orm_validate_query(GridQueryState{}, [
		GridOrmColumnSpec{
			id:       'name'
			db_field: 'name'
		},
		GridOrmColumnSpec{
			id:       'name'
			db_field: 'display_name'
		},
	]) or {
		assert err.msg().contains('duplicate')
		return
	}
	assert false
}

fn test_grid_orm_data_source_fetch_data_maps_cursor_request() {
	source := GridOrmDataSource{
		columns:       orm_test_columns()
		fetch_fn:      fn (spec GridOrmQuerySpec, _ &GridAbortSignal) !GridOrmPage {
			assert spec.limit == 5
			assert spec.offset == 20
			assert spec.cursor == 'i:20'
			assert spec.quick_filter == 'Ada'
			assert spec.sorts.len == 1
			assert spec.filters.len == 1
			return GridOrmPage{
				rows:     orm_test_rows(['21', '22'])
				has_more: true
			}
		}
		default_limit: 100
	}
	res := source.fetch_data(GridDataRequest{
		grid_id: 'orm-grid'
		query:   GridQueryState{
			quick_filter: 'Ada'
			sorts:        [
				GridSort{
					col_id: 'name'
					dir:    .desc
				},
			]
			filters:      [
				GridFilter{
					col_id: 'team'
					op:     'equals'
					value:  'Data'
				},
			]
		}
		page:    GridPageRequest(GridCursorPageReq{
			cursor: 'i:20'
			limit:  5
		})
	}) or { panic(err) }
	assert res.rows.len == 2
	assert res.next_cursor == 'i:22'
	assert res.prev_cursor == 'i:15'
	assert res.received_count == 2
	assert res.has_more
}

fn test_grid_orm_data_source_fetch_data_maps_offset_request() {
	source := GridOrmDataSource{
		columns:       orm_test_columns()
		fetch_fn:      fn (spec GridOrmQuerySpec, _ &GridAbortSignal) !GridOrmPage {
			assert spec.limit == 3
			assert spec.offset == 4
			assert spec.cursor == 'i:4'
			return GridOrmPage{
				rows:        orm_test_rows(['5', '6', '7'])
				has_more:    false
				next_cursor: ''
				prev_cursor: ''
				row_count:   ?int(200)
			}
		}
		default_limit: 90
	}
	res := source.fetch_data(GridDataRequest{
		grid_id: 'orm-grid'
		query:   GridQueryState{}
		page:    GridPageRequest(GridOffsetPageReq{
			start_index: 4
			end_index:   7
		})
	}) or { panic(err) }
	assert res.received_count == 3
	assert res.next_cursor == ''
	assert res.prev_cursor == 'i:1'
	if total := res.row_count {
		assert total == 200
	} else {
		assert false
	}
}

fn test_grid_orm_data_source_honors_abort_before_fetch() {
	mut called := false
	mut controller := new_grid_abort_controller()
	controller.abort()
	source := GridOrmDataSource{
		columns:  orm_test_columns()
		fetch_fn: fn [mut called] (_ GridOrmQuerySpec, _ &GridAbortSignal) !GridOrmPage {
			called = true
			return GridOrmPage{}
		}
	}
	_ := source.fetch_data(GridDataRequest{
		grid_id: 'orm-grid'
		query:   GridQueryState{}
		page:    GridPageRequest(GridCursorPageReq{})
		signal:  controller.signal
	}) or {
		assert err.msg().contains('aborted')
		assert !called
		return
	}
	assert false
}

fn test_grid_orm_data_source_honors_abort_after_fetch() {
	mut controller := new_grid_abort_controller()
	source := GridOrmDataSource{
		columns:  orm_test_columns()
		fetch_fn: fn [mut controller] (_ GridOrmQuerySpec, _ &GridAbortSignal) !GridOrmPage {
			controller.abort()
			return GridOrmPage{
				rows: orm_test_rows(['1'])
			}
		}
	}
	_ := source.fetch_data(GridDataRequest{
		grid_id: 'orm-grid'
		query:   GridQueryState{}
		page:    GridPageRequest(GridCursorPageReq{})
		signal:  controller.signal
	}) or {
		assert err.msg().contains('aborted')
		return
	}
	assert false
}

fn test_grid_orm_data_source_propagates_fetch_error() {
	source := GridOrmDataSource{
		columns:  orm_test_columns()
		fetch_fn: fn (_ GridOrmQuerySpec, _ &GridAbortSignal) !GridOrmPage {
			return error('db fetch failed')
		}
	}
	_ := source.fetch_data(GridDataRequest{
		grid_id: 'orm-grid'
		query:   GridQueryState{}
		page:    GridPageRequest(GridCursorPageReq{})
	}) or {
		assert err.msg().contains('db fetch failed')
		return
	}
	assert false
}

fn test_grid_orm_data_source_mutate_create_update_delete() {
	mut source := GridOrmDataSource{
		columns:        orm_test_columns()
		fetch_fn:       orm_test_fetch_ok
		create_fn:      fn (rows []GridRow, _ &GridAbortSignal) ![]GridRow {
			assert rows.len == 1
			return [
				GridRow{
					id:    '101'
					cells: rows[0].cells.clone()
				},
			]
		}
		update_fn:      fn (_ []GridRow, edits []GridCellEdit, _ &GridAbortSignal) ![]GridRow {
			assert edits.len == 1
			return [
				GridRow{
					id:    edits[0].row_id
					cells: {
						edits[0].col_id: edits[0].value
					}
				},
			]
		}
		delete_many_fn: fn (row_ids []string, _ &GridAbortSignal) ![]string {
			assert row_ids == ['7', '8']
			return row_ids
		}
	}
	create_res := source.mutate_data(GridMutationRequest{
		grid_id: 'orm-grid'
		kind:    .create
		rows:    [
			GridRow{
				id:    ''
				cells: {
					'name': 'New'
				}
			},
		]
	}) or { panic(err) }
	assert create_res.created.len == 1
	assert create_res.created[0].id == '101'

	update_res := source.mutate_data(GridMutationRequest{
		grid_id: 'orm-grid'
		kind:    .update
		edits:   [
			GridCellEdit{
				row_id: '5'
				col_id: 'name'
				value:  'Updated'
			},
		]
	}) or { panic(err) }
	assert update_res.updated.len == 1
	assert update_res.updated[0].id == '5'

	delete_res := source.mutate_data(GridMutationRequest{
		grid_id: 'orm-grid'
		kind:    .delete
		row_ids: ['7', '8']
	}) or { panic(err) }
	assert delete_res.deleted_ids == ['7', '8']
}

fn test_grid_orm_data_source_mutate_unsupported_operation() {
	mut source := GridOrmDataSource{
		columns:  orm_test_columns()
		fetch_fn: orm_test_fetch_ok
	}
	_ := source.mutate_data(GridMutationRequest{
		grid_id: 'orm-grid'
		kind:    .create
	}) or {
		assert err.msg().contains('not supported')
		return
	}
	assert false
}

fn orm_test_fetch_ok(_ GridOrmQuerySpec, _ &GridAbortSignal) !GridOrmPage {
	return GridOrmPage{}
}

fn orm_test_columns() []GridOrmColumnSpec {
	return [
		GridOrmColumnSpec{
			id:               'name'
			db_field:         'users.name'
			quick_filter:     true
			filterable:       true
			sortable:         true
			case_insensitive: true
		},
		GridOrmColumnSpec{
			id:               'team'
			db_field:         'users.team'
			quick_filter:     true
			filterable:       true
			sortable:         false
			case_insensitive: true
		},
		GridOrmColumnSpec{
			id:               'email'
			db_field:         'users.email'
			quick_filter:     true
			filterable:       false
			sortable:         false
			case_insensitive: true
			allowed_ops:      ['equals']
		},
	]
}

fn orm_test_rows(ids []string) []GridRow {
	mut rows := []GridRow{cap: ids.len}
	for id in ids {
		rows << GridRow{
			id:    id
			cells: {
				'name': 'User ${id}'
			}
		}
	}
	return rows
}
