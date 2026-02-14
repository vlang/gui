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

fn test_grid_orm_validate_query_deduplicates_filters() {
	query := GridQueryState{
		filters: [
			GridFilter{
				col_id: 'name'
				op:     'contains'
				value:  'first'
			},
			GridFilter{
				col_id: 'name'
				op:     'contains'
				value:  'second'
			},
			GridFilter{
				col_id: 'team'
				op:     'equals'
				value:  'Data'
			},
		]
	}
	next := grid_orm_validate_query(query, orm_test_columns()) or { panic(err) }
	// Duplicate (name, contains) collapsed to first occurrence.
	assert next.filters.len == 2
	assert next.filters[0].col_id == 'name'
	assert next.filters[0].op == 'contains'
	assert next.filters[0].value == 'first'
	assert next.filters[1].col_id == 'team'
	assert next.filters[1].op == 'equals'
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
			assert spec.cursor == ''
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
			assert row_ids.len == 2
			assert '7' in row_ids
			assert '8' in row_ids
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
	assert delete_res.deleted_ids.len == 2
	assert '7' in delete_res.deleted_ids
	assert '8' in delete_res.deleted_ids
}

fn test_grid_orm_data_source_mutate_delete_single_fn() {
	mut source := GridOrmDataSource{
		columns:   orm_test_columns()
		fetch_fn:  orm_test_fetch_ok
		delete_fn: fn (row_id string, _ &GridAbortSignal) !string {
			return row_id
		}
	}
	res := source.mutate_data(GridMutationRequest{
		grid_id: 'orm-grid'
		kind:    .delete
		row_ids: ['3', '5']
	}) or { panic(err) }
	assert res.deleted_ids.len == 2
	assert '3' in res.deleted_ids
	assert '5' in res.deleted_ids
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

fn test_grid_orm_validate_column_map_rejects_bad_db_field() {
	_ := grid_orm_validate_query(GridQueryState{}, [
		GridOrmColumnSpec{
			id:       'col'
			db_field: 'valid_field'
		},
	]) or {
		assert false
		return
	}
	// SQL injection attempt
	_ := grid_orm_validate_query(GridQueryState{}, [
		GridOrmColumnSpec{
			id:       'col'
			db_field: 'name; DROP TABLE--'
		},
	]) or {
		assert err.msg().contains('invalid db_field')
		return
	}
	assert false
}

fn test_new_grid_orm_data_source_factory() {
	source := new_grid_orm_data_source(GridOrmDataSource{
		columns:  orm_test_columns()
		fetch_fn: orm_test_fetch_ok
	}) or { panic(err) }
	assert source.column_map.len == 3
	assert 'name' in source.column_map
	assert 'team' in source.column_map
	assert 'email' in source.column_map
	// Factory pre-normalizes allowed_ops.
	email_col := source.column_map['email']
	assert email_col.normalized_ops.len == 1
	assert email_col.normalized_ops[0] == 'equals'
}

fn test_new_grid_orm_data_source_factory_rejects_bad_columns() {
	_ := new_grid_orm_data_source(GridOrmDataSource{
		columns:  [
			GridOrmColumnSpec{
				id:       ''
				db_field: 'x'
			},
		]
		fetch_fn: orm_test_fetch_ok
	}) or {
		assert err.msg().contains('column id is required')
		return
	}
	assert false
}

fn test_grid_orm_capabilities_with_mutation_fns() {
	mut source := GridOrmDataSource{
		columns:        orm_test_columns()
		fetch_fn:       orm_test_fetch_ok
		create_fn:      fn (_ []GridRow, _ &GridAbortSignal) ![]GridRow {
			return []GridRow{}
		}
		update_fn:      fn (_ []GridRow, _ []GridCellEdit, _ &GridAbortSignal) ![]GridRow {
			return []GridRow{}
		}
		delete_many_fn: fn (_ []string, _ &GridAbortSignal) ![]string {
			return []string{}
		}
	}
	caps := source.capabilities()
	assert caps.supports_create
	assert caps.supports_update
	assert caps.supports_delete
	assert caps.supports_batch_delete
}

fn test_grid_orm_validate_mutation_columns_rejects_unknown() {
	column_map := grid_orm_validate_column_map(orm_test_columns()) or { panic(err) }
	grid_orm_validate_mutation_columns([
		GridRow{
			id:    '1'
			cells: {
				'bogus': 'value'
			}
		},
	], []GridCellEdit{}, column_map) or {
		assert err.msg().contains('unknown column id')
		return
	}
	assert false
}

fn test_grid_orm_delete_fn_empty_string_skipped() {
	mut source := GridOrmDataSource{
		columns:   orm_test_columns()
		fetch_fn:  orm_test_fetch_ok
		delete_fn: fn (row_id string, _ &GridAbortSignal) !string {
			if row_id == '2' {
				return ''
			}
			return row_id
		}
	}
	res := source.mutate_data(GridMutationRequest{
		grid_id: 'orm-grid'
		kind:    .delete
		row_ids: ['1', '2', '3']
	}) or { panic(err) }
	assert res.deleted_ids.len == 2
	assert '1' in res.deleted_ids
	assert '3' in res.deleted_ids
}

fn test_grid_orm_data_source_mutate_honors_abort() {
	mut controller := new_grid_abort_controller()
	controller.abort()
	mut source := GridOrmDataSource{
		columns:   orm_test_columns()
		fetch_fn:  orm_test_fetch_ok
		create_fn: fn (_ []GridRow, _ &GridAbortSignal) ![]GridRow {
			return []GridRow{}
		}
	}
	_ := source.mutate_data(GridMutationRequest{
		grid_id: 'orm-grid'
		kind:    .create
		rows:    [GridRow{
			id:    ''
			cells: {
				'name': 'x'
			}
		}]
		signal:  controller.signal
	}) or {
		assert err.msg().contains('aborted')
		return
	}
	assert false
}

fn test_grid_orm_validate_query_rejects_long_quick_filter() {
	long_val := 'x'.repeat(grid_orm_max_filter_value_len + 1)
	_ := grid_orm_validate_query(GridQueryState{
		quick_filter: long_val
	}, orm_test_columns()) or {
		assert err.msg().contains('max length')
		return
	}
	assert false
}

fn test_grid_orm_validate_query_rejects_long_filter_value() {
	long_val := 'x'.repeat(grid_orm_max_filter_value_len + 1)
	_ := grid_orm_validate_query(GridQueryState{
		filters: [
			GridFilter{
				col_id: 'name'
				op:     'contains'
				value:  long_val
			},
		]
	}, orm_test_columns()) or {
		assert err.msg().contains('max length')
		return
	}
	assert false
}

fn test_grid_orm_valid_db_field_accepts_qualified_names() {
	assert grid_orm_valid_db_field('users')
	assert grid_orm_valid_db_field('users.name')
	assert grid_orm_valid_db_field('_private')
	assert grid_orm_valid_db_field('t1.col_2')
	assert !grid_orm_valid_db_field('')
	assert !grid_orm_valid_db_field('1bad')
	assert !grid_orm_valid_db_field('no spaces')
	assert !grid_orm_valid_db_field('semi;colon')
	assert !grid_orm_valid_db_field('dash-name')
	assert !grid_orm_valid_db_field('table.')
	assert !grid_orm_valid_db_field('table..col')
	assert !grid_orm_valid_db_field('a.b.c')
}

fn test_grid_orm_direct_construction_fallback() {
	// Construct without factory; resolved_column_map rebuilds
	// on-the-fly and fetch_data should still succeed.
	source := GridOrmDataSource{
		columns:  orm_test_columns()
		fetch_fn: fn (spec GridOrmQuerySpec, _ &GridAbortSignal) !GridOrmPage {
			return GridOrmPage{
				rows: orm_test_rows(['1', '2'])
			}
		}
	}
	assert source.column_map.len == 0
	res := source.fetch_data(GridDataRequest{
		grid_id: 'direct-grid'
		query:   GridQueryState{
			sorts: [
				GridSort{
					col_id: 'name'
					dir:    .asc
				},
			]
		}
		page:    GridPageRequest(GridCursorPageReq{
			limit: 10
		})
	}) or { panic(err) }
	assert res.rows.len == 2
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
