module gui

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

fn data_grid_has_source(cfg DataGridCfg) bool {
	return cfg.data_source != none
}

fn data_grid_resolve_source_cfg(cfg DataGridCfg, mut window Window) (DataGridCfg, DataGridSourceState, bool, GridDataCapabilities) {
	if !data_grid_has_source(cfg) {
		return cfg, DataGridSourceState{}, false, GridDataCapabilities{}
	}
	data_source := cfg.data_source or {
		return cfg, DataGridSourceState{}, false, GridDataCapabilities{}
	}

	caps := data_source.capabilities()
	state := data_grid_source_resolve_state(cfg, caps, mut window)
	mut row_count := cfg.row_count
	if count := state.row_count {
		row_count = ?int(count)
	}
	resolved := DataGridCfg{
		...cfg
		rows:       state.rows.clone()
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
	kind := data_grid_source_effective_pagination_kind(cfg.pagination_kind, caps)
	if state.pagination_kind != kind {
		state.pagination_kind = kind
		state.current_cursor = cfg.cursor
		state.next_cursor = ''
		state.prev_cursor = ''
		state.offset_start = 0
		state.request_key = ''
		state.rows = []GridRow{}
	}
	if cfg.cursor != state.config_cursor {
		state.config_cursor = cfg.cursor
		state.current_cursor = cfg.cursor
		state.request_key = ''
	}
	data_grid_source_apply_query_reset(mut state, cfg)
	if kind == .offset && cfg.page_size > 0 {
		desired_start := int_max(0, cfg.page_index * cfg.page_size)
		if desired_start != state.offset_start {
			state.offset_start = desired_start
			state.request_key = ''
		}
	}
	request_key := data_grid_source_request_key(cfg, state, kind)
	if request_key != state.request_key {
		data_grid_source_start_request(cfg, caps, kind, request_key, mut state, mut window)
	}
	window.view_state.data_grid_source_state.set(cfg.id, state)
	return state
}

fn data_grid_source_apply_query_reset(mut state DataGridSourceState, cfg DataGridCfg) {
	query_signature := grid_query_signature(cfg.query)
	if query_signature == state.query_signature {
		return
	}
	state.query_signature = query_signature
	state.current_cursor = cfg.cursor
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
		return .cursor
	}
	if caps.supports_offset_pagination {
		return .offset
	}
	if caps.supports_cursor_pagination {
		return .cursor
	}
	return .offset
}

fn data_grid_page_limit(cfg DataGridCfg) int {
	if cfg.page_limit > 0 {
		return cfg.page_limit
	}
	if cfg.page_size > 0 {
		return cfg.page_size
	}
	return 100
}

fn data_grid_source_request_key(cfg DataGridCfg, state DataGridSourceState, kind GridPaginationKind) string {
	limit := data_grid_page_limit(cfg)
	query_sig := grid_query_signature(cfg.query)
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
	if state.loading && !isnil(state.active_abort) {
		mut active := state.active_abort
		active.abort()
		state.cancelled_count++
	}
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
		result := source.fetch_data(req) or {
			if !isnil(req.signal) && req.signal.is_aborted() {
				return
			}
			err_msg := err.msg()
			w.queue_command(fn [grid_id, next_request_id, err_msg] (mut w Window) {
				data_grid_source_apply_error(grid_id, next_request_id, err_msg, mut w)
			})
			return
		}
		if !isnil(req.signal) && req.signal.is_aborted() {
			return
		}
		w.queue_command(fn [grid_id, next_request_id, result, caps] (mut w Window) {
			data_grid_source_apply_success(grid_id, next_request_id, result, caps, mut
				w)
		})
	}(mut window)
}

fn data_grid_source_apply_success(grid_id string, request_id u64, result GridDataResult, caps GridDataCapabilities, mut window Window) {
	mut state := window.view_state.data_grid_source_state.get(grid_id) or { return }
	if request_id != state.request_id {
		state.stale_drop_count++
		window.view_state.data_grid_source_state.set(grid_id, state)
		return
	}
	state.loading = false
	state.load_error = ''
	state.has_loaded = true
	state.rows = result.rows.clone()
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
	if request_id != state.request_id {
		state.stale_drop_count++
		window.view_state.data_grid_source_state.set(grid_id, state)
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
		start := state.offset_start
		if state.received_count <= 0 {
			if total := state.row_count {
				return 'Rows 0/${total}'
			}
			return 'Rows 0/?'
		}
		end := start + state.received_count
		if total := state.row_count {
			return 'Rows ${start + 1}-${end}/${total}'
		}
		return 'Rows ${start + 1}-${end}/?'
	}
	if start := grid_data_source_cursor_to_index_opt(state.current_cursor) {
		if state.received_count <= 0 {
			if total := state.row_count {
				return 'Rows 0/${total}'
			}
			return 'Rows 0/?'
		}
		mut end := start + state.received_count
		if total := state.row_count {
			end = int_min(end, total)
			return 'Rows ${start + 1}-${end}/${total}'
		}
		return 'Rows ${start + 1}-${end}/?'
	}
	if total := state.row_count {
		return 'Rows ${state.received_count}/${total}'
	}
	return 'Rows ${state.received_count}/?'
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
		step := if state.received_count > 0 {
			state.received_count
		} else {
			int_max(1, page_limit)
		}
		state.offset_start += step
	}
	state.request_key = ''
	state.load_error = ''
	window.view_state.data_grid_source_state.set(grid_id, state)
	window.update_window()
}

fn data_grid_source_retry(grid_id string, mut window Window) {
	mut state := window.view_state.data_grid_source_state.get(grid_id) or { return }
	state.request_key = ''
	state.load_error = ''
	window.view_state.data_grid_source_state.set(grid_id, state)
	window.update_window()
}

fn data_grid_source_pager_row(cfg DataGridCfg, focus_id u32, state DataGridSourceState, caps GridDataCapabilities) View {
	kind := data_grid_source_effective_pagination_kind(cfg.pagination_kind, caps)
	page_limit := data_grid_page_limit(cfg)
	has_prev := data_grid_source_can_prev(kind, state, page_limit)
	has_next := data_grid_source_can_next(kind, state, page_limit)
	rows_text := data_grid_source_rows_text(kind, state)
	mode_text := if kind == .cursor { 'Cursor' } else { 'Offset' }
	status := if state.loading {
		'Loading...'
	} else if state.load_error.len > 0 {
		'Error'
	} else {
		mode_text
	}
	grid_id := cfg.id
	mut content := []View{cap: 8}
	content << button(
		width:        data_grid_header_control_width + 10
		sizing:       fixed_fill
		padding:      padding_none
		size_border:  0
		radius:       0
		color:        color_transparent
		color_hover:  cfg.color_header_hover
		color_focus:  color_transparent
		color_click:  cfg.color_header_hover
		color_border: color_transparent
		disabled:     state.loading || !has_prev
		on_click:     fn [grid_id, kind, page_limit, focus_id] (_ &Layout, mut e Event, mut w Window) {
			data_grid_source_prev_page(grid_id, kind, page_limit, mut w)
			if focus_id > 0 {
				w.set_id_focus(focus_id)
			}
			e.is_handled = true
		}
		content:      [
			text(
				text:       '◀'
				mode:       .single_line
				text_style: data_grid_indicator_text_style(cfg.text_style_header)
			),
		]
	)
	content << text(
		text:       status
		mode:       .single_line
		text_style: cfg.text_style_filter
	)
	content << button(
		width:        data_grid_header_control_width + 10
		sizing:       fixed_fill
		padding:      padding_none
		size_border:  0
		radius:       0
		color:        color_transparent
		color_hover:  cfg.color_header_hover
		color_focus:  color_transparent
		color_click:  cfg.color_header_hover
		color_border: color_transparent
		disabled:     state.loading || !has_next
		on_click:     fn [grid_id, kind, page_limit, focus_id] (_ &Layout, mut e Event, mut w Window) {
			data_grid_source_next_page(grid_id, kind, page_limit, mut w)
			if focus_id > 0 {
				w.set_id_focus(focus_id)
			}
			e.is_handled = true
		}
		content:      [
			text(
				text:       '▶'
				mode:       .single_line
				text_style: data_grid_indicator_text_style(cfg.text_style_header)
			),
		]
	)
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
		content: [
			text(
				text:       rows_text
				mode:       .single_line
				text_style: data_grid_indicator_text_style(cfg.text_style_filter)
			),
		]
	)
	return row(
		name:         'data_grid source pager row'
		height:       data_grid_pager_height(cfg)
		sizing:       fill_fixed
		color:        cfg.color_filter
		color_border: cfg.color_border
		size_border:  0
		padding:      cfg.padding_filter
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
