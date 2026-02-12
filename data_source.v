module gui

import strings
import time

pub enum GridPaginationKind as u8 {
	cursor
	offset
}

pub enum GridMutationKind as u8 {
	create
	update
	delete
}

@[minify]
pub struct GridCursorPageReq {
pub:
	cursor string
	limit  int = 100
}

@[minify]
pub struct GridOffsetPageReq {
pub:
	start_index int
	end_index   int
}

pub type GridPageRequest = GridCursorPageReq | GridOffsetPageReq

// GridAbortSignal communicates cancellation from the main
// thread to a spawned goroutine. `aborted` is a plain bool
// (not atomic) — the stale-response request_id guard in
// apply_success catches races, so a missed cancellation only
// wastes work rather than causing incorrect state.
@[heap; minify]
pub struct GridAbortSignal {
mut:
	aborted bool
}

// is_aborted reports cancellation status.
pub fn (signal &GridAbortSignal) is_aborted() bool {
	return signal.aborted
}

fn (mut signal GridAbortSignal) set_aborted(value bool) {
	signal.aborted = value
}

@[heap; minify]
pub struct GridAbortController {
pub mut:
	signal &GridAbortSignal = unsafe { nil }
}

// new_grid_abort_controller allocates a fresh abort controller.
pub fn new_grid_abort_controller() &GridAbortController {
	signal := &GridAbortSignal{}
	return &GridAbortController{
		signal: signal
	}
}

// abort marks request as cancelled.
pub fn (mut controller GridAbortController) abort() {
	if isnil(controller.signal) {
		return
	}
	controller.signal.set_aborted(true)
}

@[minify]
pub struct GridDataRequest {
pub:
	grid_id    string
	query      GridQueryState
	page       GridPageRequest
	signal     &GridAbortSignal = unsafe { nil }
	request_id u64
}

@[minify]
pub struct GridDataResult {
pub:
	rows           []GridRow
	next_cursor    string
	prev_cursor    string
	row_count      ?int
	has_more       bool
	received_count int
}

@[minify]
pub struct GridDataCapabilities {
pub:
	supports_cursor_pagination bool = true
	supports_offset_pagination bool
	supports_numbered_pages    bool
	row_count_known            bool
	supports_create            bool
	supports_update            bool
	supports_delete            bool
	supports_batch_delete      bool
}

@[minify]
pub struct GridMutationRequest {
pub:
	grid_id    string
	kind       GridMutationKind
	query      GridQueryState
	rows       []GridRow
	row_ids    []string
	edits      []GridCellEdit
	signal     &GridAbortSignal = unsafe { nil }
	request_id u64
}

@[minify]
pub struct GridMutationResult {
pub:
	created     []GridRow
	updated     []GridRow
	deleted_ids []string
	row_count   ?int
}

pub interface DataGridDataSource {
	capabilities() GridDataCapabilities
	fetch_data(req GridDataRequest) !GridDataResult
mut:
	mutate_data(req GridMutationRequest) !GridMutationResult
}

@[heap; minify]
pub struct InMemoryCursorDataSource {
pub mut:
	rows []GridRow
pub:
	default_limit   int = 100
	latency_ms      int
	row_count_known bool = true
	supports_offset bool = true
}

pub fn (source InMemoryCursorDataSource) capabilities() GridDataCapabilities {
	return GridDataCapabilities{
		supports_cursor_pagination: true
		supports_offset_pagination: source.supports_offset
		supports_numbered_pages:    source.supports_offset
		row_count_known:            source.row_count_known
		supports_create:            true
		supports_update:            true
		supports_delete:            true
		supports_batch_delete:      true
	}
}

pub fn (source InMemoryCursorDataSource) fetch_data(req GridDataRequest) !GridDataResult {
	if grid_data_request_is_aborted(req) {
		return error('request aborted')
	}
	if grid_data_source_sleep_with_abort(req.signal, source.latency_ms) {
		return error('request aborted')
	}
	filtered := grid_data_source_apply_query(source.rows, req.query)
	limit := int_max(1, if source.default_limit > 0 { source.default_limit } else { 100 })
	match req.page {
		GridCursorPageReq {
			start := int_clamp(grid_data_source_cursor_to_index(req.page.cursor), 0, filtered.len)
			chunk_limit := int_max(1, if req.page.limit > 0 { req.page.limit } else { limit })
			end := int_min(filtered.len, start + chunk_limit)
			rows := filtered[start..end].clone()
			next_cursor := if end < filtered.len {
				grid_data_source_cursor_from_index(end)
			} else {
				''
			}
			prev_start := int_max(0, start - chunk_limit)
			prev_cursor := if start > 0 {
				grid_data_source_cursor_from_index(prev_start)
			} else {
				''
			}
			if grid_data_request_is_aborted(req) {
				return error('request aborted')
			}
			return GridDataResult{
				rows:           rows
				next_cursor:    next_cursor
				prev_cursor:    prev_cursor
				row_count:      if source.row_count_known { ?int(filtered.len) } else { none }
				has_more:       end < filtered.len
				received_count: rows.len
			}
		}
		GridOffsetPageReq {
			start := int_clamp(req.page.start_index, 0, filtered.len)
			mut end := int_clamp(req.page.end_index, start, filtered.len)
			if end <= start {
				end = int_min(filtered.len, start + limit)
			}
			rows := filtered[start..end].clone()
			if grid_data_request_is_aborted(req) {
				return error('request aborted')
			}
			return GridDataResult{
				rows:           rows
				next_cursor:    if end < filtered.len {
					grid_data_source_cursor_from_index(end)
				} else {
					''
				}
				prev_cursor:    if start > 0 {
					grid_data_source_cursor_from_index(int_max(0, start - (end - start)))
				} else {
					''
				}
				row_count:      if source.row_count_known { ?int(filtered.len) } else { none }
				has_more:       end < filtered.len
				received_count: rows.len
			}
		}
	}
}

pub fn (mut source InMemoryCursorDataSource) mutate_data(req GridMutationRequest) !GridMutationResult {
	if grid_data_mutation_is_aborted(req) {
		return error('request aborted')
	}
	if grid_data_source_sleep_with_abort(req.signal, source.latency_ms) {
		return error('request aborted')
	}
	mut rows := source.rows.clone()
	result := grid_data_source_apply_mutation(mut rows, req.kind, req.rows, req.row_ids,
		req.edits)!
	if grid_data_mutation_is_aborted(req) {
		return error('request aborted')
	}
	source.rows = rows
	return GridMutationResult{
		created:     result.created.clone()
		updated:     result.updated.clone()
		deleted_ids: result.deleted_ids.clone()
		row_count:   if source.row_count_known { ?int(source.rows.len) } else { none }
	}
}

@[heap; minify]
pub struct InMemoryOffsetDataSource {
pub mut:
	rows []GridRow
pub:
	default_page_size int = 100
	latency_ms        int
	row_count_known   bool = true
}

pub fn (source InMemoryOffsetDataSource) capabilities() GridDataCapabilities {
	return GridDataCapabilities{
		supports_cursor_pagination: false
		supports_offset_pagination: true
		supports_numbered_pages:    true
		row_count_known:            source.row_count_known
		supports_create:            true
		supports_update:            true
		supports_delete:            true
		supports_batch_delete:      true
	}
}

pub fn (source InMemoryOffsetDataSource) fetch_data(req GridDataRequest) !GridDataResult {
	if grid_data_request_is_aborted(req) {
		return error('request aborted')
	}
	if grid_data_source_sleep_with_abort(req.signal, source.latency_ms) {
		return error('request aborted')
	}
	filtered := grid_data_source_apply_query(source.rows, req.query)
	page_size := int_max(1, if source.default_page_size > 0 { source.default_page_size } else { 100 })
	start, end := match req.page {
		GridOffsetPageReq {
			mut next_end := int_clamp(req.page.end_index, req.page.start_index, filtered.len)
			if next_end <= req.page.start_index {
				next_end = int_min(filtered.len, req.page.start_index + page_size)
			}
			int_clamp(req.page.start_index, 0, filtered.len), int_clamp(next_end, 0, filtered.len)
		}
		GridCursorPageReq {
			next_start := int_clamp(grid_data_source_cursor_to_index(req.page.cursor),
				0, filtered.len)
			next_size := int_max(1, if req.page.limit > 0 { req.page.limit } else { page_size })
			next_start, int_min(filtered.len, next_start + next_size)
		}
	}
	rows := filtered[start..end].clone()
	if grid_data_request_is_aborted(req) {
		return error('request aborted')
	}
	return GridDataResult{
		rows:           rows
		next_cursor:    if end < filtered.len { grid_data_source_cursor_from_index(end) } else { '' }
		prev_cursor:    if start > 0 {
			grid_data_source_cursor_from_index(int_max(0, start - (end - start)))
		} else {
			''
		}
		row_count:      if source.row_count_known { ?int(filtered.len) } else { none }
		has_more:       end < filtered.len
		received_count: rows.len
	}
}

pub fn (mut source InMemoryOffsetDataSource) mutate_data(req GridMutationRequest) !GridMutationResult {
	if grid_data_mutation_is_aborted(req) {
		return error('request aborted')
	}
	if grid_data_source_sleep_with_abort(req.signal, source.latency_ms) {
		return error('request aborted')
	}
	mut rows := source.rows.clone()
	result := grid_data_source_apply_mutation(mut rows, req.kind, req.rows, req.row_ids,
		req.edits)!
	if grid_data_mutation_is_aborted(req) {
		return error('request aborted')
	}
	source.rows = rows
	return GridMutationResult{
		created:     result.created.clone()
		updated:     result.updated.clone()
		deleted_ids: result.deleted_ids.clone()
		row_count:   if source.row_count_known { ?int(source.rows.len) } else { none }
	}
}

fn grid_data_request_is_aborted(req GridDataRequest) bool {
	if isnil(req.signal) {
		return false
	}
	return req.signal.is_aborted()
}

fn grid_data_mutation_is_aborted(req GridMutationRequest) bool {
	if isnil(req.signal) {
		return false
	}
	return req.signal.is_aborted()
}

fn grid_data_source_sleep_with_abort(signal &GridAbortSignal, latency_ms int) bool {
	if latency_ms <= 0 {
		return !isnil(signal) && signal.is_aborted()
	}
	mut remaining := latency_ms
	for remaining > 0 {
		if !isnil(signal) && signal.is_aborted() {
			return true
		}
		step_ms := int_min(remaining, 20)
		time.sleep(step_ms * time.millisecond)
		remaining -= step_ms
	}
	return !isnil(signal) && signal.is_aborted()
}

fn grid_data_source_cursor_from_index(index int) string {
	return 'i:${int_max(0, index)}'
}

fn grid_data_source_cursor_to_index(cursor string) int {
	if idx := grid_data_source_cursor_to_index_opt(cursor) {
		return idx
	}
	return 0
}

fn grid_data_source_cursor_to_index_opt(cursor string) ?int {
	trimmed := cursor.trim_space()
	if trimmed.len == 0 {
		return ?int(0)
	}
	if trimmed.starts_with('i:') {
		val := trimmed[2..]
		if !grid_data_source_is_decimal(val) {
			return none
		}
		return ?int(int_max(0, val.int()))
	}
	if !grid_data_source_is_decimal(trimmed) {
		return none
	}
	return ?int(int_max(0, trimmed.int()))
}

fn grid_data_source_is_decimal(input string) bool {
	if input.len == 0 {
		return false
	}
	for ch in input {
		if ch < `0` || ch > `9` {
			return false
		}
	}
	return true
}

fn grid_data_source_apply_query(rows []GridRow, query GridQueryState) []GridRow {
	mut filtered := rows.filter(grid_data_source_row_matches_query(it, query))
	if query.sorts.len == 0 {
		return filtered
	}
	for sort_idx in 0 .. query.sorts.len {
		i := query.sorts.len - 1 - sort_idx
		sort := query.sorts[i]
		filtered.sort_with_compare(fn [sort] (a &GridRow, b &GridRow) int {
			a_value := a.cells[sort.col_id] or { '' }
			b_value := b.cells[sort.col_id] or { '' }
			if a_value == b_value {
				return 0
			}
			if sort.dir == .asc {
				return if a_value < b_value { -1 } else { 1 }
			}
			return if a_value > b_value { -1 } else { 1 }
		})
	}
	return filtered
}

fn grid_data_source_row_matches_query(row GridRow, query GridQueryState) bool {
	if query.quick_filter.len > 0 {
		needle := query.quick_filter.to_lower()
		mut matched := false
		for _, value in row.cells {
			if value.to_lower().contains(needle) {
				matched = true
				break
			}
		}
		if !matched {
			return false
		}
	}
	for filter in query.filters {
		cell := row.cells[filter.col_id] or { '' }
		value := filter.value.to_lower()
		cell_lower := cell.to_lower()
		matched := match filter.op {
			'equals' { cell_lower == value }
			'starts_with' { cell_lower.starts_with(value) }
			'ends_with' { cell_lower.ends_with(value) }
			else { cell_lower.contains(value) }
		}
		if !matched {
			return false
		}
	}
	return true
}

fn grid_query_signature(query GridQueryState) string {
	mut out := strings.new_builder(128)
	out.write_string(query.quick_filter)
	out.write_string('|s:')
	for sort in query.sorts {
		dir := if sort.dir == .desc { 'd' } else { 'a' }
		out.write_string('${sort.col_id}:${dir};')
	}
	out.write_string('|f:')
	for filter in query.filters {
		out.write_string('${filter.col_id}:${filter.op}:${filter.value};')
	}
	return out.str()
}

@[minify]
struct GridMutationApplyResult {
	created     []GridRow
	updated     []GridRow
	deleted_ids []string
}

fn grid_data_source_apply_mutation(mut rows []GridRow, kind GridMutationKind, req_rows []GridRow, req_row_ids []string, edits []GridCellEdit) !GridMutationApplyResult {
	return match kind {
		.create { grid_data_source_apply_create(mut rows, req_rows) }
		.update { grid_data_source_apply_update(mut rows, req_rows, edits) }
		.delete { grid_data_source_apply_delete(mut rows, req_rows, req_row_ids) }
	}
}

fn grid_data_source_apply_create(mut rows []GridRow, req_rows []GridRow) !GridMutationApplyResult {
	if req_rows.len == 0 {
		return GridMutationApplyResult{}
	}
	mut created := []GridRow{cap: req_rows.len}
	for row in req_rows {
		next_id := grid_data_source_next_mutation_row_id(rows, row.id)
		next_row := GridRow{
			...row
			id:    next_id
			cells: row.cells.clone()
		}
		rows << next_row
		created << next_row
	}
	return GridMutationApplyResult{
		created: created
	}
}

fn grid_data_source_apply_update(mut rows []GridRow, req_rows []GridRow, edits []GridCellEdit) !GridMutationApplyResult {
	mut updated := []GridRow{}
	if req_rows.len > 0 {
		for req_row in req_rows {
			if req_row.id.len == 0 {
				return error('update row has empty id')
			}
			if idx := grid_data_source_row_index(rows, req_row.id) {
				mut cells := rows[idx].cells.clone()
				for key, value in req_row.cells {
					cells[key] = value
				}
				rows[idx] = GridRow{
					...rows[idx]
					cells: cells
				}
				updated << rows[idx]
			}
		}
	}
	if edits.len > 0 {
		for edit in edits {
			if edit.row_id.len == 0 {
				return error('edit has empty row id')
			}
			if edit.col_id.len == 0 {
				return error('edit has empty col id')
			}
			if idx := grid_data_source_row_index(rows, edit.row_id) {
				mut cells := rows[idx].cells.clone()
				cells[edit.col_id] = edit.value
				rows[idx] = GridRow{
					...rows[idx]
					cells: cells
				}
				if !grid_data_source_rows_contains_id(updated, edit.row_id) {
					updated << rows[idx]
				}
			}
		}
	}
	return GridMutationApplyResult{
		updated: updated
	}
}

fn grid_data_source_apply_delete(mut rows []GridRow, req_rows []GridRow, req_row_ids []string) !GridMutationApplyResult {
	mut delete_ids := map[string]bool{}
	for row in req_rows {
		if row.id.len > 0 {
			delete_ids[row.id] = true
		}
	}
	for row_id in req_row_ids {
		id := row_id.trim_space()
		if id.len > 0 {
			delete_ids[id] = true
		}
	}
	if delete_ids.len == 0 {
		return GridMutationApplyResult{}
	}
	mut kept := []GridRow{cap: rows.len}
	mut deleted_ids := []string{}
	for idx, row in rows {
		row_id := data_grid_row_id(row, idx)
		if delete_ids[row_id] {
			deleted_ids << row_id
			continue
		}
		kept << row
	}
	rows = unsafe { kept }
	return GridMutationApplyResult{
		deleted_ids: deleted_ids
	}
}

fn grid_data_source_row_index(rows []GridRow, row_id string) ?int {
	if row_id.len == 0 {
		return none
	}
	for idx, row in rows {
		if data_grid_row_id(row, idx) == row_id {
			return idx
		}
	}
	return none
}

fn grid_data_source_rows_contains_id(rows []GridRow, row_id string) bool {
	for idx, row in rows {
		if data_grid_row_id(row, idx) == row_id {
			return true
		}
	}
	return false
}

fn grid_data_source_next_mutation_row_id(rows []GridRow, preferred_id string) string {
	id := preferred_id.trim_space()
	if id.len > 0 && !grid_data_source_rows_contains_id(rows, id) {
		return id
	}
	mut existing := map[string]bool{}
	for idx, row in rows {
		existing[data_grid_row_id(row, idx)] = true
	}
	mut next := rows.len + 1
	for {
		candidate := '${next}'
		if !existing[candidate] {
			return candidate
		}
		next++
	}
	return '${rows.len + 1}'
}
