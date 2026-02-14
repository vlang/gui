module gui

import hash.fnv1a

const data_grid_default_page_limit = 100
const data_grid_jump_input_width = 68

pub struct DataGridSourceStats {
pub:
	loading          bool
	load_error       string
	request_count    int
	cancelled_count  int
	stale_drop_count int
	has_more         bool
	received_count   int
	row_count        ?int
}

// data_grid_source_stats returns runtime async stats for a data-source grid.
pub fn (window &Window) data_grid_source_stats(grid_id string) DataGridSourceStats {
	if state := window.view_state.data_grid_source_state.get(grid_id) {
		return DataGridSourceStats{
			loading:          state.loading
			load_error:       state.load_error
			request_count:    state.request_count
			cancelled_count:  state.cancelled_count
			stale_drop_count: state.stale_drop_count
			has_more:         state.has_more
			received_count:   state.received_count
			row_count:        state.row_count
		}
	}
	return DataGridSourceStats{}
}

fn data_grid_source_apply_local_mutation(grid_id string, rows []GridRow, row_count ?int, mut window Window) {
	mut state := window.view_state.data_grid_source_state.get(grid_id) or { DataGridSourceState{} }
	data_grid_source_cancel_active(mut state)
	state.request_id++
	state.rows = rows
	state.received_count = rows.len
	state.has_loaded = true
	state.loading = false
	state.load_error = ''
	state.rows_dirty = true
	state.rows_signature = data_grid_rows_signature(rows, []string{})
	state.active_abort = unsafe { nil }
	if count := row_count {
		state.row_count = ?int(count)
	} else {
		state.row_count = none
	}
	window.view_state.data_grid_source_state.set(grid_id, state)
}

fn data_grid_source_cancel_active(mut state DataGridSourceState) {
	if !state.loading || isnil(state.active_abort) {
		return
	}
	mut active := state.active_abort
	active.abort()
	state.cancelled_count++
}

fn data_grid_source_force_refetch(grid_id string, mut window Window) {
	mut state := window.view_state.data_grid_source_state.get(grid_id) or { return }
	data_grid_source_cancel_active(mut state)
	state.loading = false
	state.request_key = ''
	state.load_error = ''
	state.caps_cached = false
	state.active_abort = unsafe { nil }
	window.view_state.data_grid_source_state.set(grid_id, state)
	window.update_window()
}

fn data_grid_has_source(cfg DataGridCfg) bool {
	return cfg.data_source != none
}

fn data_grid_resolve_source_cfg(cfg DataGridCfg, mut window Window) (DataGridCfg, DataGridSourceState, bool, GridDataCapabilities) {
	data_source := cfg.data_source or {
		return cfg, DataGridSourceState{}, false, GridDataCapabilities{}
	}

	// Use cached capabilities when available; invalidated
	// on force_refetch.
	existing := window.view_state.data_grid_source_state.get(cfg.id) or { DataGridSourceState{} }
	caps := if existing.caps_cached {
		existing.cached_caps
	} else {
		data_source.capabilities()
	}
	// Read rows_dirty before resolve_state clears it.
	was_dirty := existing.rows_dirty
	state := data_grid_source_resolve_state(cfg, caps, mut window)
	mut row_count := cfg.row_count
	if count := state.row_count {
		row_count = ?int(count)
	}
	// Skip clone when rows unchanged since last frame.
	rows := if was_dirty { state.rows.clone() } else { state.rows }
	resolved := DataGridCfg{
		...cfg
		rows:       rows
		page_size:  0
		page_index: 0
		loading:    state.loading
		load_error: state.load_error
		row_count:  row_count
	}
	return resolved, state, true, caps
}

fn data_grid_source_resolve_state(cfg DataGridCfg, caps GridDataCapabilities, mut window Window) DataGridSourceState {
	mut state := window.view_state.data_grid_source_state.get(cfg.id) or {
		DataGridSourceState{
			current_cursor:  cfg.cursor
			offset_start:    int_max(0, cfg.page_index * data_grid_page_limit(cfg))
			pagination_kind: cfg.pagination_kind
			config_cursor:   cfg.cursor
		}
	}
	if !state.caps_cached {
		state.cached_caps = caps
		state.caps_cached = true
	}
	kind := data_grid_source_effective_pagination_kind(cfg.pagination_kind, caps)
	if state.pagination_kind != kind {
		state.pagination_kind = kind
		data_grid_source_reset_pagination(mut state, cfg.cursor)
		state.rows = []GridRow{}
	}
	if cfg.cursor != state.config_cursor {
		state.config_cursor = cfg.cursor
		state.current_cursor = cfg.cursor
		state.request_key = ''
	}
	query_sig := grid_query_signature(cfg.query)
	data_grid_source_apply_query_reset(mut state, cfg, query_sig)
	if kind == .offset && cfg.page_size > 0 {
		desired_start := int_max(0, cfg.page_index * cfg.page_size)
		if desired_start != state.offset_start {
			state.offset_start = desired_start
			state.request_key = ''
		}
	}
	request_key := data_grid_source_request_key(cfg, state, kind, query_sig)
	if request_key != state.request_key {
		data_grid_source_start_request(cfg, caps, kind, request_key, mut state, mut window)
	}
	state.rows_dirty = false
	window.view_state.data_grid_source_state.set(cfg.id, state)
	return state
}

fn data_grid_source_apply_pending_jump_selection(cfg DataGridCfg, state DataGridSourceState, mut window Window) {
	if cfg.on_selection_change == unsafe { nil } || state.pending_jump_row < 0 {
		return
	}
	if state.loading {
		return
	}
	local_idx := state.pending_jump_row - state.offset_start
	if local_idx < 0 || local_idx >= cfg.rows.len {
		return
	}
	row_id := data_grid_row_id(cfg.rows[local_idx], local_idx)
	next := GridSelection{
		anchor_row_id:    row_id
		active_row_id:    row_id
		selected_row_ids: {
			row_id: true
		}
	}
	mut e := Event{}
	cfg.on_selection_change(next, mut e, mut window)
	data_grid_set_anchor(cfg.id, row_id, mut window)
	mut next_state := window.view_state.data_grid_source_state.get(cfg.id) or { return }
	next_state.pending_jump_row = -1
	window.view_state.data_grid_source_state.set(cfg.id, next_state)
}

fn data_grid_source_apply_query_reset(mut state DataGridSourceState, cfg DataGridCfg, query_sig u64) {
	if query_sig == state.query_signature {
		return
	}
	state.query_signature = query_sig
	data_grid_source_reset_pagination(mut state, cfg.cursor)
	state.pending_jump_row = -1
}

fn data_grid_source_reset_pagination(mut state DataGridSourceState, cursor string) {
	state.current_cursor = cursor
	state.next_cursor = ''
	state.prev_cursor = ''
	state.offset_start = 0
	state.request_key = ''
}

fn data_grid_source_effective_pagination_kind(preferred GridPaginationKind, caps GridDataCapabilities) GridPaginationKind {
	if preferred == .cursor {
		if caps.supports_cursor_pagination {
			return .cursor
		}
		if caps.supports_offset_pagination {
			return .offset
		}
		// Neither kind declared; use preferred — source
		// must handle fetch_data regardless.
		return .cursor
	}
	if caps.supports_offset_pagination {
		return .offset
	}
	if caps.supports_cursor_pagination {
		return .cursor
	}
	// Neither kind declared; use preferred — source
	// must handle fetch_data regardless.
	return .offset
}

fn data_grid_page_limit(cfg DataGridCfg) int {
	if cfg.page_limit > 0 {
		return cfg.page_limit
	}
	if cfg.page_size > 0 {
		return cfg.page_size
	}
	return data_grid_default_page_limit
}

fn data_grid_source_request_key(cfg DataGridCfg, state DataGridSourceState, kind GridPaginationKind, query_sig u64) string {
	limit := data_grid_page_limit(cfg)
	return match kind {
		.cursor {
			'k:cursor|cursor:${state.current_cursor}|limit:${limit}|q:${query_sig}'
		}
		.offset {
			end := state.offset_start + limit
			'k:offset|start:${state.offset_start}|end:${end}|q:${query_sig}'
		}
	}
}

fn data_grid_source_start_request(cfg DataGridCfg, caps GridDataCapabilities, kind GridPaginationKind, request_key string, mut state DataGridSourceState, mut window Window) {
	source := cfg.data_source or { return }
	data_grid_source_cancel_active(mut state)
	limit := data_grid_page_limit(cfg)
	controller := new_grid_abort_controller()
	next_request_id := state.request_id + 1
	page := match kind {
		.cursor {
			GridPageRequest(GridCursorPageReq{
				cursor: state.current_cursor
				limit:  limit
			})
		}
		.offset {
			GridPageRequest(GridOffsetPageReq{
				start_index: state.offset_start
				end_index:   state.offset_start + limit
			})
		}
	}
	req := GridDataRequest{
		grid_id:    cfg.id
		query:      cfg.query
		page:       page
		signal:     controller.signal
		request_id: next_request_id
	}
	state.loading = true
	state.load_error = ''
	state.request_id = next_request_id
	state.request_key = request_key
	state.active_abort = controller
	state.request_count++
	state.pagination_kind = kind
	grid_id := cfg.id
	spawn fn [source, req, grid_id, next_request_id, caps] (mut w Window) {
		if req.signal.is_aborted() {
			return
		}
		result := source.fetch_data(req) or {
			if req.signal.is_aborted() {
				return
			}
			err_msg := err.msg()
			w.queue_command(fn [grid_id, next_request_id, err_msg] (mut w Window) {
				data_grid_source_apply_error(grid_id, next_request_id, err_msg, mut w)
			})
			return
		}
		if req.signal.is_aborted() {
			return
		}
		w.queue_command(fn [grid_id, next_request_id, result, caps] (mut w Window) {
			data_grid_source_apply_success(grid_id, next_request_id, result, caps, mut
				w)
		})
	}(mut window)
}

fn data_grid_source_drop_if_stale(request_id u64, mut state DataGridSourceState, mut window Window, grid_id string) bool {
	if request_id != state.request_id {
		state.stale_drop_count++
		window.view_state.data_grid_source_state.set(grid_id, state)
		return true
	}
	return false
}

fn data_grid_source_apply_success(grid_id string, request_id u64, result GridDataResult, caps GridDataCapabilities, mut window Window) {
	mut state := window.view_state.data_grid_source_state.get(grid_id) or { return }
	if data_grid_source_drop_if_stale(request_id, mut state, mut window, grid_id) {
		return
	}
	state.loading = false
	state.load_error = ''
	state.has_loaded = true
	state.rows_signature = data_grid_rows_signature(result.rows, []string{})
	state.rows_dirty = true
	state.rows = result.rows
	state.next_cursor = result.next_cursor
	state.prev_cursor = result.prev_cursor
	state.has_more = result.has_more
	state.received_count = if result.received_count > 0 {
		result.received_count
	} else {
		result.rows.len
	}
	if count := result.row_count {
		state.row_count = ?int(count)
	} else if !caps.row_count_known {
		state.row_count = none
	}
	state.active_abort = unsafe { nil }
	window.view_state.data_grid_source_state.set(grid_id, state)
	window.update_window()
}

fn data_grid_source_apply_error(grid_id string, request_id u64, err_msg string, mut window Window) {
	mut state := window.view_state.data_grid_source_state.get(grid_id) or { return }
	if data_grid_source_drop_if_stale(request_id, mut state, mut window, grid_id) {
		return
	}
	state.loading = false
	state.load_error = err_msg
	state.active_abort = unsafe { nil }
	window.view_state.data_grid_source_state.set(grid_id, state)
	window.update_window()
}

fn data_grid_source_rows_text(kind GridPaginationKind, state DataGridSourceState) string {
	if kind == .offset {
		return data_grid_source_format_rows(state.offset_start, state.received_count,
			state.row_count)
	}
	if start := data_grid_source_cursor_to_index_opt(state.current_cursor) {
		return data_grid_source_format_rows(start, state.received_count, state.row_count)
	}
	total_text := if total := state.row_count { '${total}' } else { '?' }
	return 'Rows ${state.received_count}/${total_text}'
}

fn data_grid_source_format_rows(start int, count int, total ?int) string {
	total_text := if t := total { '${t}' } else { '?' }
	if count <= 0 {
		return 'Rows 0/${total_text}'
	}
	mut end := start + count
	if t := total {
		end = int_min(end, t)
	}
	return 'Rows ${start + 1}-${end}/${total_text}'
}

fn data_grid_source_can_prev(kind GridPaginationKind, state DataGridSourceState, page_limit int) bool {
	if kind == .cursor {
		return state.prev_cursor.len > 0
	}
	return state.offset_start > 0 && page_limit > 0
}

fn data_grid_source_can_next(kind GridPaginationKind, state DataGridSourceState, page_limit int) bool {
	if kind == .cursor {
		return state.next_cursor.len > 0
	}
	if total := state.row_count {
		return state.offset_start + state.received_count < total
	}
	if state.has_more {
		return true
	}
	return state.received_count >= int_max(1, page_limit)
}

fn data_grid_source_prev_page(grid_id string, kind GridPaginationKind, page_limit int, mut window Window) {
	mut state := window.view_state.data_grid_source_state.get(grid_id) or { return }
	if state.loading {
		return
	}
	if kind == .cursor {
		if state.prev_cursor.len == 0 {
			return
		}
		state.current_cursor = state.prev_cursor
	} else {
		if page_limit <= 0 {
			return
		}
		state.offset_start = int_max(0, state.offset_start - page_limit)
	}
	state.request_key = ''
	state.load_error = ''
	window.view_state.data_grid_source_state.set(grid_id, state)
	window.update_window()
}

fn data_grid_source_next_page(grid_id string, kind GridPaginationKind, page_limit int, mut window Window) {
	mut state := window.view_state.data_grid_source_state.get(grid_id) or { return }
	if state.loading {
		return
	}
	if kind == .cursor {
		if state.next_cursor.len == 0 {
			return
		}
		state.current_cursor = state.next_cursor
	} else {
		state.offset_start += int_max(1, page_limit)
		if total := state.row_count {
			state.offset_start = int_min(state.offset_start, int_max(0, total - 1))
		}
	}
	state.request_key = ''
	state.load_error = ''
	window.view_state.data_grid_source_state.set(grid_id, state)
	window.update_window()
}

fn data_grid_source_jump_to_row(grid_id string, target_idx int, page_limit int, mut window Window) {
	if page_limit <= 0 || target_idx < 0 {
		return
	}
	mut state := window.view_state.data_grid_source_state.get(grid_id) or { return }
	if state.loading {
		return
	}
	state.pending_jump_row = target_idx
	page_start := (target_idx / page_limit) * page_limit
	if page_start != state.offset_start {
		state.offset_start = page_start
		state.request_key = ''
		state.load_error = ''
	}
	window.view_state.data_grid_source_state.set(grid_id, state)
	window.update_window()
}

fn data_grid_source_row_position_text(cfg DataGridCfg, state DataGridSourceState, kind GridPaginationKind) string {
	total_text := if total := state.row_count {
		total.str()
	} else {
		'?'
	}
	if cfg.rows.len == 0 {
		return 'Row 0 of ${total_text}'
	}
	mut local_idx := data_grid_active_row_index_strict(cfg.rows, cfg.selection)
	if local_idx < 0 || local_idx >= cfg.rows.len {
		local_idx = 0
	}
	mut current := local_idx + 1
	if kind == .offset {
		current = state.offset_start + local_idx + 1
	} else if start := data_grid_source_cursor_to_index_opt(state.current_cursor) {
		current = start + local_idx + 1
	}
	if total := state.row_count {
		current = int_clamp(current, 1, total)
	}
	return 'Row ${current} of ${total_text}'
}

fn data_grid_source_jump_enabled(on_selection_change fn (GridSelection, mut Event, mut Window), row_count ?int, loading bool, load_error string, kind GridPaginationKind, page_limit int) bool {
	if on_selection_change == unsafe { nil } || page_limit <= 0 {
		return false
	}
	if kind != .offset || loading || load_error.len > 0 {
		return false
	}
	if total := row_count {
		return total > 0
	}
	return false
}

fn data_grid_source_submit_jump(on_selection_change fn (GridSelection, mut Event, mut Window), row_count ?int, loading bool, load_error string, kind GridPaginationKind, page_limit int, grid_id string, focus_id u32, mut e Event, mut window Window) {
	if !data_grid_source_jump_enabled(on_selection_change, row_count, loading, load_error,
		kind, page_limit) {
		return
	}
	total := row_count or { return }
	jump_text := window.view_state.data_grid_jump_input.get(grid_id) or { '' }
	target_idx := data_grid_parse_jump_target(jump_text, total) or { return }
	window.view_state.data_grid_jump_input.set(grid_id, '${target_idx + 1}')
	data_grid_source_jump_to_row(grid_id, target_idx, page_limit, mut window)
	if focus_id > 0 {
		window.set_id_focus(focus_id)
	}
	e.is_handled = true
}

fn data_grid_source_retry(grid_id string, mut window Window) {
	mut state := window.view_state.data_grid_source_state.get(grid_id) or { return }
	state.request_key = ''
	state.load_error = ''
	window.view_state.data_grid_source_state.set(grid_id, state)
	window.update_window()
}

fn data_grid_source_pager_row(cfg DataGridCfg, focus_id u32, state DataGridSourceState, caps GridDataCapabilities, jump_text string) View {
	kind := data_grid_source_effective_pagination_kind(cfg.pagination_kind, caps)
	page_limit := data_grid_page_limit(cfg)
	has_prev := data_grid_source_can_prev(kind, state, page_limit)
	has_next := data_grid_source_can_next(kind, state, page_limit)
	rows_text := data_grid_source_rows_text(kind, state)
	on_selection_change := cfg.on_selection_change
	row_count := state.row_count
	loading := state.loading
	load_error := state.load_error
	jump_enabled := data_grid_source_jump_enabled(on_selection_change, row_count, loading,
		load_error, kind, page_limit)
	mode_text := if kind == .cursor { 'Cursor' } else { 'Offset' }
	status := if state.loading {
		'Loading...'
	} else if state.load_error.len > 0 {
		'Error'
	} else {
		mode_text
	}
	grid_id := cfg.id
	jump_input_id := '${grid_id}:jump'
	mut content := []View{cap: 10}
	content << data_grid_indicator_button('◀', cfg.text_style_header, cfg.color_header_hover,
		state.loading || !has_prev, data_grid_header_control_width + 10, fn [grid_id, kind, page_limit, focus_id] (_ &Layout, mut e Event, mut w Window) {
		data_grid_source_prev_page(grid_id, kind, page_limit, mut w)
		if focus_id > 0 {
			w.set_id_focus(focus_id)
		}
		e.is_handled = true
	})
	content << text(
		text:       status
		mode:       .single_line
		text_style: cfg.text_style_filter
	)
	content << data_grid_indicator_button('▶', cfg.text_style_header, cfg.color_header_hover,
		state.loading || !has_next, data_grid_header_control_width + 10, fn [grid_id, kind, page_limit, focus_id] (_ &Layout, mut e Event, mut w Window) {
		data_grid_source_next_page(grid_id, kind, page_limit, mut w)
		if focus_id > 0 {
			w.set_id_focus(focus_id)
		}
		e.is_handled = true
	})
	content << row(
		name:    'data_grid source pager spacer'
		sizing:  fill_fill
		padding: padding_none
		content: []
	)
	if state.load_error.len > 0 {
		content << button(
			sizing:       fit_fill
			padding:      padding_none
			size_border:  0
			radius:       0
			color:        color_transparent
			color_hover:  cfg.color_header_hover
			color_focus:  color_transparent
			color_click:  cfg.color_header_hover
			color_border: color_transparent
			on_click:     fn [grid_id, focus_id] (_ &Layout, mut e Event, mut w Window) {
				data_grid_source_retry(grid_id, mut w)
				if focus_id > 0 {
					w.set_id_focus(focus_id)
				}
				e.is_handled = true
			}
			content:      [
				text(
					text:       'Retry'
					mode:       .single_line
					text_style: data_grid_indicator_text_style(cfg.text_style_filter)
				),
			]
		)
	}
	content << row(
		name:    'data_grid source rows status'
		sizing:  fit_fill
		padding: padding(0, 6, 0, 0)
		v_align: .middle
		content: [
			text(
				text:       rows_text
				mode:       .single_line
				text_style: data_grid_indicator_text_style(cfg.text_style_filter)
			),
		]
	)
	if kind == .offset {
		content << text(
			text:       'Jump'
			mode:       .single_line
			text_style: data_grid_indicator_text_style(cfg.text_style_filter)
		)
		content << input(
			id:              jump_input_id
			id_focus:        fnv1a.sum32_string(jump_input_id)
			text:            jump_text
			placeholder:     '#'
			disabled:        !jump_enabled
			width:           data_grid_jump_input_width
			sizing:          fixed_fill
			padding:         padding_none
			size_border:     0
			radius:          0
			color:           cfg.color_filter
			color_hover:     cfg.color_filter
			color_border:    cfg.color_border
			text_style:      cfg.text_style_filter
			on_text_changed: fn [on_selection_change, row_count, loading, load_error, kind, page_limit, grid_id] (_ &Layout, text string, mut w Window) {
				digits := data_grid_jump_digits(text)
				w.view_state.data_grid_jump_input.set(grid_id, digits)
				mut e := Event{}
				data_grid_source_submit_jump(on_selection_change, row_count, loading,
					load_error, kind, page_limit, grid_id, 0, mut e, mut w)
			}
			on_enter:        fn [on_selection_change, row_count, loading, load_error, kind, page_limit, grid_id, focus_id] (_ &Layout, mut e Event, mut w Window) {
				data_grid_source_submit_jump(on_selection_change, row_count, loading,
					load_error, kind, page_limit, grid_id, focus_id, mut e, mut w)
			}
		)
	}
	return row(
		name:         'data_grid source pager row'
		height:       data_grid_pager_height(cfg)
		sizing:       fill_fixed
		color:        cfg.color_filter
		color_border: cfg.color_border
		size_border:  0
		padding:      data_grid_pager_padding(cfg)
		spacing:      6
		v_align:      .middle
		content:      content
	)
}

fn data_grid_source_status_row(cfg DataGridCfg, message string) View {
	return row(
		name:         'data_grid source status row'
		height:       cfg.row_height
		sizing:       fill_fixed
		color:        cfg.color_filter
		color_border: cfg.color_border
		size_border:  0
		padding:      cfg.padding_filter
		v_align:      .middle
		content:      [
			text(
				text:       message
				mode:       .single_line
				text_style: data_grid_indicator_text_style(cfg.text_style_filter)
			),
		]
	)
}
