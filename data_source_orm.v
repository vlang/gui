module gui

const grid_orm_default_filter_ops = ['contains', 'equals', 'starts_with', 'ends_with']
const grid_orm_max_filter_value_len = 500

@[minify]
pub struct GridOrmColumnSpec {
	// Pre-lowered allowed_ops; populated by
	// grid_orm_validate_column_map. Module-internal.
	normalized_ops []string
pub:
	id               string @[required]
	db_field         string @[required]
	quick_filter     bool = true
	filterable       bool = true
	sortable         bool = true
	case_insensitive bool = true
	allowed_ops      []string
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

// GridOrmFetchFn fetches a page of grid data. Implementations
// MUST use parameterized queries for all user-provided values
// (quick_filter, filter values, cursor). Column IDs and
// operators are pre-validated, but values are passed through
// unescaped.
pub type GridOrmFetchFn = fn (spec GridOrmQuerySpec, signal &GridAbortSignal) !GridOrmPage

// GridOrmCreateFn persists new rows and returns them with
// assigned IDs. Implementations MUST use parameterized queries
// for all cell values — they come from user input unescaped.
pub type GridOrmCreateFn = fn (rows []GridRow, signal &GridAbortSignal) ![]GridRow

// GridOrmUpdateFn applies row replacements and cell edits,
// returns updated rows. Implementations MUST use parameterized
// queries for cell values and row IDs — they come from user
// input unescaped.
pub type GridOrmUpdateFn = fn (rows []GridRow, edits []GridCellEdit, signal &GridAbortSignal) ![]GridRow

// GridOrmDeleteFn deletes a single row by ID, returns the
// deleted ID (or empty to skip). Implementations MUST use
// parameterized queries for the row ID — it comes from user
// input unescaped.
pub type GridOrmDeleteFn = fn (row_id string, signal &GridAbortSignal) !string

// GridOrmDeleteManyFn deletes multiple rows by ID, returns
// the deleted IDs. Implementations MUST use parameterized
// queries for row IDs — they come from user input unescaped.
pub type GridOrmDeleteManyFn = fn (row_ids []string, signal &GridAbortSignal) ![]string

// GridOrmDataSource wraps user-provided ORM callbacks with
// column validation, query normalization, and abort handling.
// Construct via new_grid_orm_data_source() to pre-validate
// columns and cache the column map. Direct construction
// re-validates columns on each fetch/mutate call.
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
		validated_columns << column_map[col.id.trim_space()]
	}
	return &GridOrmDataSource{
		...src
		columns:    validated_columns
		column_map: column_map
	}
}

// resolved_column_map returns the cached column_map or
// validates one on the fly (direct-construction fallback).
// The on-the-fly path re-validates every call; prefer
// new_grid_orm_data_source factory for production use.
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
	mut prev_cursor := page.prev_cursor
	if req.page is GridCursorPageReq {
		if next_cursor.len == 0 && page.has_more {
			next_cursor = data_grid_source_cursor_from_index(offset + page.rows.len)
		}
		if prev_cursor.len == 0 {
			prev_cursor = data_grid_source_prev_cursor(offset, limit)
		}
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
				return error('grid orm: create not supported')
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
				return error('grid orm: update not supported')
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
					grid_abort_check(req.signal)!
					if deleted.len > 0 {
						out << deleted
					}
				}
				// V requires unsafe or clone for array reassignment.
				deleted_ids = unsafe { out }
			} else {
				return error('grid orm: delete not supported')
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

// grid_orm_validate_query_with_map silently drops unknown,
// non-sortable, or non-filterable columns from queries.
// This is intentional graceful degradation: the UI may
// reference stale column IDs after schema changes.
fn grid_orm_validate_query_with_map(query GridQueryState, column_map map[string]GridOrmColumnSpec) !GridQueryState {
	if query.quick_filter.len > grid_orm_max_filter_value_len {
		return error('grid orm: quick_filter exceeds max length (${grid_orm_max_filter_value_len})')
	}
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
		if filter.value.len > grid_orm_max_filter_value_len {
			return error('grid orm: filter value exceeds max length (${grid_orm_max_filter_value_len})')
		}
		col := column_map[filter.col_id] or { continue }
		if !col.filterable {
			continue
		}
		op := grid_orm_normalize_filter_op(filter.op)
		if !grid_orm_column_allows_filter_op(col, op) {
			continue
		}
		// Linear scan dedup — O(n²) is fine for typical
		// filter counts (< ~50, UI-driven).
		mut is_dup := false
		for f in filters {
			if f.col_id == filter.col_id && f.op == op && f.value == filter.value {
				is_dup = true
				break
			}
		}
		if is_dup {
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
	default_limit := int_clamp(if configured_limit > 0 { configured_limit } else { 100 },
		1, data_grid_source_max_page_limit)
	return match page {
		GridCursorPageReq {
			limit := int_clamp(if page.limit > 0 { page.limit } else { default_limit },
				1, data_grid_source_max_page_limit)
			offset := int_max(0, data_grid_source_cursor_to_index(page.cursor))
			limit, offset, data_grid_source_cursor_from_index(offset)
		}
		GridOffsetPageReq {
			offset := int_max(0, page.start_index)
			limit := int_clamp(if page.end_index > page.start_index {
				page.end_index - page.start_index
			} else {
				default_limit
			}, 1, data_grid_source_max_page_limit)
			limit, offset, ''
		}
	}
}

fn grid_orm_validate_column_map(columns []GridOrmColumnSpec) !map[string]GridOrmColumnSpec {
	mut out := map[string]GridOrmColumnSpec{}
	for col in columns {
		id := col.id.trim_space()
		if id.len == 0 {
			return error('grid orm: column id is required')
		}
		db_field := col.db_field.trim_space()
		if db_field.len == 0 {
			return error('grid orm: column "${id}" requires db_field')
		}
		if !grid_orm_valid_db_field(db_field) {
			return error('grid orm: column "${id}" has invalid db_field: ${db_field}')
		}
		if id in out {
			return error('grid orm: duplicate column id: ${id}')
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
	if col.normalized_ops.len > 0 {
		return op in col.normalized_ops
	}
	return op in grid_orm_default_filter_ops
}

// grid_orm_validate_mutation_columns rejects unknown columns
// strictly (returns error), unlike query validation which
// silently drops them. Mutations must be correct — writing
// to an unknown column indicates a bug, not stale UI state.
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
				return error('grid orm: unknown column id: ${col_id}')
			}
			seen[col_id] = true
		}
	}
	for edit in edits {
		if seen[edit.col_id] {
			continue
		}
		if edit.col_id !in column_map {
			return error('grid orm: unknown column id: ${edit.col_id}')
		}
		seen[edit.col_id] = true
	}
}

@[minify]
pub struct GridOrmSqlBuilder {
pub:
	where_sql  string   // e.g. "lower(name) like ? and status = ?"
	order_sql  string   // e.g. "name desc, email asc"
	limit_sql  string   // "limit ?"
	offset_sql string   // "offset ?"
	params     []string // ordered to match ? placeholders
}

// build_sql validates the query spec against the source's
// columns and builds SQL fragments with parameterized
// placeholders. Delegates to grid_orm_build_sql.
pub fn (source GridOrmDataSource) build_sql(spec GridOrmQuerySpec) !GridOrmSqlBuilder {
	column_map := source.resolved_column_map()!
	return grid_orm_build_sql(spec, column_map)
}

// grid_orm_build_sql builds SQL fragments from a query spec
// and pre-validated column map. No SQL keywords (WHERE,
// ORDER BY) are included — caller composes the final query.
// Use this when you have a column map but no GridOrmDataSource.
pub fn grid_orm_build_sql(spec GridOrmQuerySpec, column_map map[string]GridOrmColumnSpec) !GridOrmSqlBuilder {
	query := grid_orm_validate_query_with_map(GridQueryState{
		quick_filter: spec.quick_filter
		sorts:        spec.sorts
		filters:      spec.filters
	}, column_map)!
	mut params := []string{}
	mut where_parts := []string{}
	qf := grid_orm_build_quick_filter(query.quick_filter, column_map, mut params)
	if qf.len > 0 {
		where_parts << qf
	}
	for filter in query.filters {
		col := column_map[filter.col_id] or { continue }
		clause := grid_orm_build_filter_clause(col.db_field, filter.op, filter.value,
			col.case_insensitive, mut params)
		where_parts << clause
	}
	order := grid_orm_build_order(query.sorts, column_map)
	params << spec.limit.str()
	params << spec.offset.str()
	return GridOrmSqlBuilder{
		where_sql:  where_parts.join(' and ')
		order_sql:  order
		limit_sql:  'limit ?'
		offset_sql: 'offset ?'
		params:     params
	}
}

// grid_orm_build_quick_filter returns a parenthesized OR
// clause for quick_filter columns, or empty string.
fn grid_orm_build_quick_filter(needle string, columns map[string]GridOrmColumnSpec, mut params []string) string {
	trimmed := needle.trim_space()
	if trimmed.len == 0 {
		return ''
	}
	lower_needle := trimmed.to_lower()
	mut or_parts := []string{}
	for _, col in columns {
		if !col.quick_filter {
			continue
		}
		if col.case_insensitive {
			or_parts << 'lower(${col.db_field}) like ?'
			params << '%${lower_needle}%'
		} else {
			or_parts << '${col.db_field} like ?'
			params << '%${trimmed}%'
		}
	}
	if or_parts.len == 0 {
		return ''
	}
	return '(${or_parts.join(' or ')})'
}

// grid_orm_build_filter_clause returns a single WHERE clause
// and appends the parameterized value.
fn grid_orm_build_filter_clause(db_field string, op string, value string, case_insensitive bool, mut params []string) string {
	target_field := if case_insensitive { 'lower(${db_field})' } else { db_field }
	target_value := if case_insensitive { value.to_lower() } else { value }
	clause, param := match op {
		'equals' { '${target_field} = ?', target_value }
		'starts_with' { '${target_field} like ?', '${target_value}%' }
		'ends_with' { '${target_field} like ?', '%${target_value}' }
		else { '${target_field} like ?', '%${target_value}%' }
	}
	params << param
	return clause
}

// grid_orm_build_order returns comma-separated order terms
// or empty string.
fn grid_orm_build_order(sorts []GridSort, column_map map[string]GridOrmColumnSpec) string {
	mut parts := []string{}
	for sort in sorts {
		col := column_map[sort.col_id] or { continue }
		if !col.sortable {
			continue
		}
		dir := if sort.dir == .desc { 'desc' } else { 'asc' }
		parts << '${col.db_field} ${dir}'
	}
	return parts.join(', ')
}

// grid_orm_valid_db_field checks that a db_field contains only
// alphanumeric chars, underscores, and at most one dot (for
// table-qualified names like "table.column"). Must start with
// a letter or underscore. Rejects trailing/consecutive dots.
fn grid_orm_valid_db_field(field string) bool {
	if field.len == 0 {
		return false
	}
	first := field[0]
	if !((first >= `a` && first <= `z`) || (first >= `A` && first <= `Z`) || first == `_`) {
		return false
	}
	mut dot_count := 0
	for i := 1; i < field.len; i++ {
		c := field[i]
		if c == `.` {
			dot_count++
			if dot_count > 1 {
				return false
			}
			// Dot must not be last char or follow another dot.
			if i == field.len - 1 {
				return false
			}
			continue
		}
		if (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`) || (c >= `0` && c <= `9`) || c == `_` {
			continue
		}
		return false
	}
	return true
}
