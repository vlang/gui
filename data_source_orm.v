module gui

const grid_orm_default_filter_ops = ['contains', 'equals', 'starts_with', 'ends_with']

@[minify]
pub struct GridOrmColumnSpec {
pub:
	id               string @[required]
	db_field         string @[required]
	quick_filter     bool = true
	filterable       bool = true
	sortable         bool = true
	case_insensitive bool = true
	allowed_ops      []string
	normalized_ops   []string // pre-lowered allowed_ops; populated by new_grid_orm_data_source
}

@[minify]
pub struct GridOrmQuerySpec {
pub:
	quick_filter string
	sorts        []GridSort
	filters      []GridFilter
	limit        int = 100
	offset       int
	cursor       string
}

@[minify]
pub struct GridOrmPage {
pub:
	rows        []GridRow
	next_cursor string
	prev_cursor string
	row_count   ?int
	has_more    bool
}

pub type GridOrmFetchFn = fn (spec GridOrmQuerySpec, signal &GridAbortSignal) !GridOrmPage

pub type GridOrmCreateFn = fn (rows []GridRow, signal &GridAbortSignal) ![]GridRow

pub type GridOrmUpdateFn = fn (rows []GridRow, edits []GridCellEdit, signal &GridAbortSignal) ![]GridRow

pub type GridOrmDeleteFn = fn (row_id string, signal &GridAbortSignal) !string

pub type GridOrmDeleteManyFn = fn (row_ids []string, signal &GridAbortSignal) ![]string

@[heap; minify]
pub struct GridOrmDataSource {
pub:
	columns         []GridOrmColumnSpec
	column_map      map[string]GridOrmColumnSpec // validated; built by new_grid_orm_data_source
	fetch_fn        GridOrmFetchFn @[required]
	default_limit   int                 = 100
	supports_offset bool                = true
	row_count_known bool                = true
	create_fn       GridOrmCreateFn     = unsafe { nil }
	update_fn       GridOrmUpdateFn     = unsafe { nil }
	delete_fn       GridOrmDeleteFn     = unsafe { nil }
	delete_many_fn  GridOrmDeleteManyFn = unsafe { nil }
}

// new_grid_orm_data_source validates columns and builds
// the cached column_map with pre-normalized filter ops.
pub fn new_grid_orm_data_source(src GridOrmDataSource) !&GridOrmDataSource {
	column_map := grid_orm_validate_column_map(src.columns)!
	mut validated_columns := []GridOrmColumnSpec{cap: src.columns.len}
	for col in src.columns {
		validated_columns << column_map[col.id.trim_space()] or { col }
	}
	return &GridOrmDataSource{
		...src
		columns:    validated_columns
		column_map: column_map
	}
}

// resolved_column_map returns the cached column_map or
// validates one on the fly (direct-construction fallback).
fn (source GridOrmDataSource) resolved_column_map() !map[string]GridOrmColumnSpec {
	if source.column_map.len > 0 {
		return source.column_map
	}
	return grid_orm_validate_column_map(source.columns)
}

pub fn (source GridOrmDataSource) capabilities() GridDataCapabilities {
	return GridDataCapabilities{
		supports_cursor_pagination: true
		supports_offset_pagination: source.supports_offset
		supports_numbered_pages:    source.supports_offset
		row_count_known:            source.row_count_known
		supports_create:            source.create_fn != unsafe { nil }
		supports_update:            source.update_fn != unsafe { nil }
		supports_delete:            source.delete_fn != unsafe { nil }
			|| source.delete_many_fn != unsafe { nil }
		supports_batch_delete:      source.delete_many_fn != unsafe { nil }
	}
}

pub fn (source GridOrmDataSource) fetch_data(req GridDataRequest) !GridDataResult {
	grid_abort_check(req.signal)!
	column_map := source.resolved_column_map()!
	query := grid_orm_validate_query_with_map(req.query, column_map)!
	limit, offset, cursor := grid_orm_resolve_page(req.page, source.default_limit)
	page := source.fetch_fn(GridOrmQuerySpec{
		quick_filter: query.quick_filter
		sorts:        query.sorts
		filters:      query.filters
		limit:        limit
		offset:       offset
		cursor:       cursor
	}, req.signal)!
	grid_abort_check(req.signal)!
	mut next_cursor := page.next_cursor
	if next_cursor.len == 0 && page.has_more {
		next_cursor = grid_data_source_cursor_from_index(offset + page.rows.len)
	}
	mut prev_cursor := page.prev_cursor
	if prev_cursor.len == 0 {
		prev_cursor = grid_data_source_prev_cursor(offset, limit)
	}
	return GridDataResult{
		rows:           page.rows
		next_cursor:    next_cursor
		prev_cursor:    prev_cursor
		row_count:      page.row_count
		has_more:       page.has_more
		received_count: page.rows.len
	}
}

pub fn (mut source GridOrmDataSource) mutate_data(req GridMutationRequest) !GridMutationResult {
	grid_abort_check(req.signal)!
	column_map := source.resolved_column_map()!
	return match req.kind {
		.create {
			if source.create_fn == unsafe { nil } {
				return error('create not supported')
			}
			grid_orm_validate_mutation_columns(req.rows, []GridCellEdit{}, column_map)!
			created := source.create_fn(req.rows.clone(), req.signal)!
			grid_abort_check(req.signal)!
			GridMutationResult{
				created: created
			}
		}
		.update {
			if source.update_fn == unsafe { nil } {
				return error('update not supported')
			}
			grid_orm_validate_mutation_columns(req.rows, req.edits, column_map)!
			updated := source.update_fn(req.rows.clone(), req.edits.clone(), req.signal)!
			grid_abort_check(req.signal)!
			GridMutationResult{
				updated: updated
			}
		}
		.delete {
			id_set := grid_deduplicate_row_ids(req.rows, req.row_ids)
			ids := id_set.keys()
			if ids.len == 0 {
				return GridMutationResult{}
			}
			mut deleted_ids := []string{}
			if source.delete_many_fn != unsafe { nil } {
				deleted_ids = source.delete_many_fn(ids, req.signal)!
			} else if source.delete_fn != unsafe { nil } {
				mut out := []string{cap: ids.len}
				for row_id in ids {
					deleted := source.delete_fn(row_id, req.signal)!
					if deleted.len > 0 {
						out << deleted
					}
				}
				deleted_ids = unsafe { out }
			} else {
				return error('delete not supported')
			}
			grid_abort_check(req.signal)!
			GridMutationResult{
				deleted_ids: deleted_ids
			}
		}
	}
}

pub fn grid_orm_validate_query(query GridQueryState, columns []GridOrmColumnSpec) !GridQueryState {
	column_map := grid_orm_validate_column_map(columns)!
	return grid_orm_validate_query_with_map(query, column_map)
}

fn grid_orm_validate_query_with_map(query GridQueryState, column_map map[string]GridOrmColumnSpec) !GridQueryState {
	mut sorts := []GridSort{}
	for sort in query.sorts {
		col := column_map[sort.col_id] or { continue }
		if !col.sortable {
			continue
		}
		sorts << GridSort{
			col_id: sort.col_id
			dir:    sort.dir
		}
	}
	mut filters := []GridFilter{}
	for filter in query.filters {
		col := column_map[filter.col_id] or { continue }
		if !col.filterable {
			continue
		}
		op := grid_orm_normalize_filter_op(filter.op)
		if !grid_orm_column_allows_filter_op(col, op) {
			continue
		}
		filters << GridFilter{
			col_id: filter.col_id
			op:     op
			value:  filter.value
		}
	}
	return GridQueryState{
		sorts:        sorts
		filters:      filters
		quick_filter: query.quick_filter
	}
}

fn grid_orm_resolve_page(page GridPageRequest, configured_limit int) (int, int, string) {
	default_limit := int_max(1, if configured_limit > 0 { configured_limit } else { 100 })
	return match page {
		GridCursorPageReq {
			limit := int_max(1, if page.limit > 0 { page.limit } else { default_limit })
			offset := int_max(0, grid_data_source_cursor_to_index(page.cursor))
			limit, offset, page.cursor
		}
		GridOffsetPageReq {
			offset := int_max(0, page.start_index)
			limit := if page.end_index > page.start_index {
				int_max(1, page.end_index - page.start_index)
			} else {
				default_limit
			}
			limit, offset, grid_data_source_cursor_from_index(offset)
		}
	}
}

fn grid_orm_validate_column_map(columns []GridOrmColumnSpec) !map[string]GridOrmColumnSpec {
	mut out := map[string]GridOrmColumnSpec{}
	for col in columns {
		id := col.id.trim_space()
		if id.len == 0 {
			return error('orm column id is required')
		}
		db_field := col.db_field.trim_space()
		if db_field.len == 0 {
			return error('orm column "${id}" requires db_field')
		}
		if !grid_orm_valid_db_field(db_field) {
			return error('orm column "${id}" has invalid db_field: ${db_field}')
		}
		if id in out {
			return error('duplicate orm column id: ${id}')
		}
		// Pre-normalize allowed_ops once at construction.
		mut norm_ops := []string{cap: col.allowed_ops.len}
		for raw_op in col.allowed_ops {
			norm_ops << grid_orm_normalize_filter_op(raw_op)
		}
		out[id] = GridOrmColumnSpec{
			...col
			id:             id
			db_field:       db_field
			normalized_ops: norm_ops
		}
	}
	return out
}

fn grid_orm_normalize_filter_op(op string) string {
	normalized := op.trim_space().to_lower()
	if normalized.len == 0 {
		return 'contains'
	}
	return normalized
}

fn grid_orm_column_allows_filter_op(col GridOrmColumnSpec, op string) bool {
	if op.len == 0 {
		return false
	}
	// Use pre-normalized ops when available (from factory fn).
	if col.normalized_ops.len > 0 {
		return op in col.normalized_ops
	}
	if col.allowed_ops.len == 0 {
		return op in grid_orm_default_filter_ops
	}
	for raw_op in col.allowed_ops {
		if grid_orm_normalize_filter_op(raw_op) == op {
			return true
		}
	}
	return false
}

fn grid_orm_validate_mutation_columns(rows []GridRow, edits []GridCellEdit, column_map map[string]GridOrmColumnSpec) ! {
	if column_map.len == 0 {
		return
	}
	mut seen := map[string]bool{}
	for row in rows {
		for col_id, _ in row.cells {
			if seen[col_id] {
				continue
			}
			if col_id !in column_map {
				return error('unknown column id: ${col_id}')
			}
			seen[col_id] = true
		}
	}
	for edit in edits {
		if seen[edit.col_id] {
			continue
		}
		if edit.col_id !in column_map {
			return error('unknown column id: ${edit.col_id}')
		}
		seen[edit.col_id] = true
	}
}

// grid_orm_valid_db_field checks that a db_field contains only
// alphanumeric chars, underscores, and dots (for table-qualified
// names). Must start with a letter or underscore.
fn grid_orm_valid_db_field(field string) bool {
	if field.len == 0 {
		return false
	}
	first := field[0]
	if !((first >= `a` && first <= `z`) || (first >= `A` && first <= `Z`) || first == `_`) {
		return false
	}
	for i := 1; i < field.len; i++ {
		c := field[i]
		if (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`) || (c >= `0` && c <= `9`)
			|| c == `_` || c == `.` {
			continue
		}
		return false
	}
	return true
}
