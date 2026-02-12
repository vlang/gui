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

@[heap; minify]
pub struct GridOrmDataSource {
pub:
	columns         []GridOrmColumnSpec
	fetch_fn        GridOrmFetchFn @[required]
	default_limit   int  = 100
	supports_offset bool = true
	row_count_known bool = true
}

pub fn (source GridOrmDataSource) capabilities() GridDataCapabilities {
	return GridDataCapabilities{
		supports_cursor_pagination: true
		supports_offset_pagination: source.supports_offset
		supports_numbered_pages:    source.supports_offset
		row_count_known:            source.row_count_known
	}
}

pub fn (source GridOrmDataSource) fetch_data(req GridDataRequest) !GridDataResult {
	if grid_data_request_is_aborted(req) {
		return error('request aborted')
	}
	query := grid_orm_validate_query(req.query, source.columns)!
	limit, offset, cursor := grid_orm_resolve_page(req.page, source.default_limit)
	page := source.fetch_fn(GridOrmQuerySpec{
		quick_filter: query.quick_filter
		sorts:        query.sorts
		filters:      query.filters
		limit:        limit
		offset:       offset
		cursor:       cursor
	}, req.signal)!
	if grid_data_request_is_aborted(req) {
		return error('request aborted')
	}
	mut next_cursor := page.next_cursor
	if next_cursor.len == 0 && page.has_more {
		next_cursor = grid_data_source_cursor_from_index(offset + page.rows.len)
	}
	mut prev_cursor := page.prev_cursor
	if prev_cursor.len == 0 && offset > 0 {
		prev_cursor = grid_data_source_cursor_from_index(int_max(0, offset - limit))
	}
	return GridDataResult{
		rows:           page.rows.clone()
		next_cursor:    next_cursor
		prev_cursor:    prev_cursor
		row_count:      page.row_count
		has_more:       page.has_more
		received_count: page.rows.len
	}
}

pub fn grid_orm_validate_query(query GridQueryState, columns []GridOrmColumnSpec) !GridQueryState {
	column_map := grid_orm_validate_column_map(columns)!
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
		if id in out {
			return error('duplicate orm column id: ${id}')
		}
		out[id] = GridOrmColumnSpec{
			...col
			id:       id
			db_field: db_field
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
