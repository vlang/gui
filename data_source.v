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
	if grid_abort_signal_is_aborted(req.signal) {
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
			prev_cursor := grid_data_source_prev_cursor(start, chunk_limit)
			if grid_abort_signal_is_aborted(req.signal) {
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
			start, end := grid_data_source_offset_bounds(req.page.start_index, req.page.end_index,
				filtered.len, limit)
			rows := filtered[start..end].clone()
			if grid_abort_signal_is_aborted(req.signal) {
				return error('request aborted')
			}
			return GridDataResult{
				rows:           rows
				next_cursor:    if end < filtered.len {
					grid_data_source_cursor_from_index(end)
				} else {
					''
				}
				prev_cursor:    grid_data_source_prev_cursor(start, end - start)
				row_count:      if source.row_count_known { ?int(filtered.len) } else { none }
				has_more:       end < filtered.len
				received_count: rows.len
			}
		}
	}
}

pub fn (mut source InMemoryCursorDataSource) mutate_data(req GridMutationRequest) !GridMutationResult {
	return grid_data_source_inmemory_mutate(mut source.rows, source.latency_ms, source.row_count_known,
		req)
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
	if grid_abort_signal_is_aborted(req.signal) {
		return error('request aborted')
	}
	if grid_data_source_sleep_with_abort(req.signal, source.latency_ms) {
		return error('request aborted')
	}
	filtered := grid_data_source_apply_query(source.rows, req.query)
	page_size := int_max(1, if source.default_page_size > 0 { source.default_page_size } else { 100 })
	start, end := match req.page {
		GridOffsetPageReq {
			grid_data_source_offset_bounds(req.page.start_index, req.page.end_index, filtered.len,
				page_size)
		}
		GridCursorPageReq {
			next_start := int_clamp(grid_data_source_cursor_to_index(req.page.cursor),
				0, filtered.len)
			next_size := int_max(1, if req.page.limit > 0 { req.page.limit } else { page_size })
			next_start, int_min(filtered.len, next_start + next_size)
		}
	}
	rows := filtered[start..end].clone()
	if grid_abort_signal_is_aborted(req.signal) {
		return error('request aborted')
	}
	return GridDataResult{
		rows:           rows
		next_cursor:    if end < filtered.len { grid_data_source_cursor_from_index(end) } else { '' }
		prev_cursor:    grid_data_source_prev_cursor(start, end - start)
		row_count:      if source.row_count_known { ?int(filtered.len) } else { none }
		has_more:       end < filtered.len
		received_count: rows.len
	}
}

pub fn (mut source InMemoryOffsetDataSource) mutate_data(req GridMutationRequest) !GridMutationResult {
	return grid_data_source_inmemory_mutate(mut source.rows, source.latency_ms, source.row_count_known,
		req)
}

fn grid_data_source_inmemory_mutate(mut rows []GridRow, latency_ms int, row_count_known bool, req GridMutationRequest) !GridMutationResult {
	if grid_abort_signal_is_aborted(req.signal) {
		return error('request aborted')
	}
	if grid_data_source_sleep_with_abort(req.signal, latency_ms) {
		return error('request aborted')
	}
	mut work := rows.clone()
	result := grid_data_source_apply_mutation(mut work, req.kind, req.rows, req.row_ids,
		req.edits)!
	if grid_abort_signal_is_aborted(req.signal) {
		return error('request aborted')
	}
	rows = unsafe { work }
	return GridMutationResult{
		created:     result.created
		updated:     result.updated
		deleted_ids: result.deleted_ids
		row_count:   if row_count_known { ?int(rows.len) } else { none }
	}
}

// grid_data_source_offset_bounds clamps start/end to [0,total]
// and falls back to default_limit when the range is empty.
fn grid_data_source_offset_bounds(start_index int, end_index int, total int, default_limit int) (int, int) {
	start := int_clamp(start_index, 0, total)
	mut end := int_clamp(end_index, start, total)
	if end <= start {
		end = int_min(total, start + default_limit)
	}
	return start, end
}

fn grid_abort_signal_is_aborted(signal &GridAbortSignal) bool {
	if isnil(signal) {
		return false
	}
	return signal.aborted
}

fn grid_data_source_sleep_with_abort(signal &GridAbortSignal, latency_ms int) bool {
	if latency_ms <= 0 {
		return grid_abort_signal_is_aborted(signal)
	}
	mut remaining := latency_ms
	for remaining > 0 {
		if grid_abort_signal_is_aborted(signal) {
			return true
		}
		step_ms := int_min(remaining, 20)
		time.sleep(step_ms * time.millisecond)
		remaining -= step_ms
	}
	return grid_abort_signal_is_aborted(signal)
}

fn grid_data_source_cursor_from_index(index int) string {
	return 'i:${int_max(0, index)}'
}

fn grid_data_source_prev_cursor(start int, page_size int) string {
	if start <= 0 {
		return ''
	}
	return grid_data_source_cursor_from_index(int_max(0, start - page_size))
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
	if query.quick_filter.len == 0 && query.filters.len == 0 && query.sorts.len == 0 {
		return rows
	}
	needle := query.quick_filter.to_lower()
	mut lowered_filters := []GridFilterLowered{cap: query.filters.len}
	for filter in query.filters {
		lowered_filters << GridFilterLowered{
			col_id: filter.col_id
			op:     filter.op
			value:  filter.value.to_lower()
		}
	}
	mut filtered := rows.filter(grid_data_source_row_matches_query(it, needle, lowered_filters))
	if query.sorts.len == 0 {
		return filtered
	}
	n := filtered.len
	mut idxs := []int{len: n, init: index}
	if query.sorts.len == 1 {
		// Single-sort fast path: one key array, no inner loop.
		sort0 := query.sorts[0]
		keys := []string{len: n, init: filtered[index].cells[sort0.col_id] or { '' }}
		if sort0.dir == .asc {
			idxs.sort_with_compare(fn [keys] (ia &int, ib &int) int {
				ka := keys[*ia]
				kb := keys[*ib]
				if ka < kb {
					return -1
				}
				if ka > kb {
					return 1
				}
				return 0
			})
		} else {
			idxs.sort_with_compare(fn [keys] (ia &int, ib &int) int {
				ka := keys[*ia]
				kb := keys[*ib]
				if ka > kb {
					return -1
				}
				if ka < kb {
					return 1
				}
				return 0
			})
		}
	} else {
		// Multi-sort: pre-extract key columns.
		sorts := query.sorts
		mut key_cols := [][]string{len: sorts.len}
		for si, sort in sorts {
			mut col := []string{len: n}
			for i, row in filtered {
				col[i] = row.cells[sort.col_id] or { '' }
			}
			key_cols[si] = col
		}
		idxs.sort_with_compare(fn [sorts, key_cols] (ia &int, ib &int) int {
			a := *ia
			b := *ib
			for si, sort in sorts {
				ka := key_cols[si][a]
				kb := key_cols[si][b]
				if ka == kb {
					continue
				}
				cmp := if ka < kb { -1 } else { 1 }
				return if sort.dir == .asc { cmp } else { -cmp }
			}
			return 0
		})
	}
	mut result := []GridRow{len: n}
	for i, idx in idxs {
		result[i] = filtered[idx]
	}
	return result
}

@[minify]
struct GridFilterLowered {
	col_id string
	op     string
	value  string
}

fn grid_data_source_row_matches_query(row GridRow, needle string, filters []GridFilterLowered) bool {
	if needle.len > 0 {
		mut matched := false
		for _, value in row.cells {
			if grid_contains_lower(value, needle) {
				matched = true
				break
			}
		}
		if !matched {
			return false
		}
	}
	for filter in filters {
		cell := row.cells[filter.col_id] or { '' }
		matched := match filter.op {
			'equals' { grid_equals_lower(cell, filter.value) }
			'starts_with' { grid_starts_with_lower(cell, filter.value) }
			'ends_with' { grid_ends_with_lower(cell, filter.value) }
			else { grid_contains_lower(cell, filter.value) }
		}
		if !matched {
			return false
		}
	}
	return true
}

// ASCII lowercase byte (a-z, A-Z only).
@[inline]
fn grid_lower_byte(c u8) u8 {
	if c >= `A` && c <= `Z` {
		return c | 0x20
	}
	return c
}

// grid_contains_lower checks haystack.to_lower().contains(needle)
// without allocating. `needle` must already be lowered.
fn grid_contains_lower(haystack string, needle string) bool {
	if needle.len == 0 {
		return true
	}
	if haystack.len < needle.len {
		return false
	}
	limit := haystack.len - needle.len
	for i := 0; i <= limit; i++ {
		mut found := true
		for j := 0; j < needle.len; j++ {
			if grid_lower_byte(unsafe { haystack.str[i + j] }) != unsafe { needle.str[j] } {
				found = false
				break
			}
		}
		if found {
			return true
		}
	}
	return false
}

// grid_equals_lower checks haystack.to_lower() == needle
// without allocating. `needle` must already be lowered.
fn grid_equals_lower(haystack string, needle string) bool {
	if haystack.len != needle.len {
		return false
	}
	for i := 0; i < haystack.len; i++ {
		if grid_lower_byte(unsafe { haystack.str[i] }) != unsafe { needle.str[i] } {
			return false
		}
	}
	return true
}

// grid_starts_with_lower checks haystack.to_lower().starts_with(needle)
// without allocating. `needle` must already be lowered.
fn grid_starts_with_lower(haystack string, needle string) bool {
	if haystack.len < needle.len {
		return false
	}
	for i := 0; i < needle.len; i++ {
		if grid_lower_byte(unsafe { haystack.str[i] }) != unsafe { needle.str[i] } {
			return false
		}
	}
	return true
}

// grid_ends_with_lower checks haystack.to_lower().ends_with(needle)
// without allocating. `needle` must already be lowered.
fn grid_ends_with_lower(haystack string, needle string) bool {
	if haystack.len < needle.len {
		return false
	}
	off := haystack.len - needle.len
	for i := 0; i < needle.len; i++ {
		if grid_lower_byte(unsafe { haystack.str[i + off] }) != unsafe { needle.str[i] } {
			return false
		}
	}
	return true
}

fn grid_query_signature(query GridQueryState) string {
	mut out := strings.new_builder(128)
	out.write_string(query.quick_filter)
	// Sorts: preserve order (primary/secondary priority matters).
	out.write_string('|s:')
	for sort in query.sorts {
		out.write_string(sort.col_id)
		out.write_u8(`:`)
		out.write_u8(if sort.dir == .desc { `d` } else { `a` })
		out.write_u8(`;`)
	}
	// Filters: sort by col_id for stable signature
	// (AND-combined, so order is semantically irrelevant).
	out.write_string('|f:')
	if query.filters.len <= 1 {
		for filter in query.filters {
			out.write_string(filter.col_id)
			out.write_u8(`:`)
			out.write_string(filter.op)
			out.write_u8(`:`)
			out.write_string(filter.value)
			out.write_u8(`;`)
		}
	} else {
		filters := query.filters
		mut idxs := []int{len: filters.len, init: index}
		idxs.sort_with_compare(fn [filters] (ia &int, ib &int) int {
			fa := filters[*ia].col_id
			fb := filters[*ib].col_id
			if fa < fb {
				return -1
			}
			if fa > fb {
				return 1
			}
			return 0
		})
		for i in idxs {
			filter := query.filters[i]
			out.write_string(filter.col_id)
			out.write_u8(`:`)
			out.write_string(filter.op)
			out.write_u8(`:`)
			out.write_string(filter.value)
			out.write_u8(`;`)
		}
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
	// Build existing-id set once for O(1) lookups.
	mut existing := map[string]bool{}
	for idx, row in rows {
		existing[data_grid_row_id(row, idx)] = true
	}
	mut created := []GridRow{cap: req_rows.len}
	for row in req_rows {
		next_id := grid_data_source_next_create_row_id(rows, existing, row.id)!
		next_row := GridRow{
			...row
			id:    next_id
			cells: row.cells.clone()
		}
		rows << next_row
		existing[next_id] = true
		created << next_row
	}
	return GridMutationApplyResult{
		created: created
	}
}

fn grid_data_source_apply_update(mut rows []GridRow, req_rows []GridRow, edits []GridCellEdit) !GridMutationApplyResult {
	mut updated := []GridRow{cap: req_rows.len}
	mut updated_ids := map[string]bool{}
	// Group edits by row_id for single-pass application.
	mut edits_by_row := map[string][]GridCellEdit{}
	for edit in edits {
		if edit.row_id.len == 0 {
			return error('edit has empty row id')
		}
		if edit.col_id.len == 0 {
			return error('edit has empty col id')
		}
		edits_by_row[edit.row_id] << edit
	}
	// Build index map once to avoid O(n) scan per lookup.
	mut row_idx := map[string]int{}
	for idx, row in rows {
		row_idx[data_grid_row_id(row, idx)] = idx
	}
	// Apply req_rows with matching edits in one clone.
	for req_row in req_rows {
		if req_row.id.len == 0 {
			return error('update row has empty id')
		}
		if idx := row_idx[req_row.id] {
			mut cells := rows[idx].cells.clone()
			for key, value in req_row.cells {
				cells[key] = value
			}
			for edit in edits_by_row[req_row.id] or { []GridCellEdit{} } {
				cells[edit.col_id] = edit.value
			}
			rows[idx] = GridRow{
				...rows[idx]
				cells: cells
			}
			updated << rows[idx]
			updated_ids[req_row.id] = true
		}
	}
	// Apply remaining edits not covered by req_rows.
	for row_id, row_edits in edits_by_row {
		if updated_ids[row_id] {
			continue
		}
		if idx := row_idx[row_id] {
			mut cells := rows[idx].cells.clone()
			for edit in row_edits {
				cells[edit.col_id] = edit.value
			}
			rows[idx] = GridRow{
				...rows[idx]
				cells: cells
			}
			updated << rows[idx]
			updated_ids[row_id] = true
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

fn grid_data_source_next_create_row_id(rows []GridRow, existing map[string]bool, preferred_id string) !string {
	id := preferred_id.trim_space()
	if id.len > 0 && !existing[id] {
		return id
	}
	cap := rows.len + 1000
	mut next := rows.len + 1
	for next <= cap {
		candidate := '${next}'
		if !existing[candidate] {
			return candidate
		}
		next++
	}
	return error('unable to generate unique row id')
}
