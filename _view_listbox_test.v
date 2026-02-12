module gui

fn test_list_box_option_helper_sets_fields() {
	opt := list_box_option('x1', 'Alpha', 'A')
	assert opt.id == 'x1'
	assert opt.name == 'Alpha'
	assert opt.value == 'A'
}

fn test_list_box_subheading_helper_sets_marker() {
	head := list_box_subheading('hdr', 'States')
	assert head.id == 'hdr'
	assert head.name == 'States'
	assert head.is_subheading
}

fn test_list_box_visible_range_bounds() {
	mut w := Window{}
	cfg := ListBoxCfg{
		id_scroll: 1
		height:    100
		data:      list_box_test_data(200)
	}
	row_h := list_box_estimate_row_height_no_window(cfg)

	first_a, last_a := list_box_visible_range(100, row_h, cfg, mut w)
	assert first_a == 0
	assert last_a > first_a

	w.view_state.scroll_y.set(1, -(row_h * 40))
	first_b, last_b := list_box_visible_range(100, row_h, cfg, mut w)
	assert first_b >= 38
	assert last_b > first_b

	w.view_state.scroll_y.set(1, -(row_h * 1000))
	first_c, last_c := list_box_visible_range(100, row_h, cfg, mut w)
	assert first_c >= 0
	assert last_c == cfg.data.len - 1
	assert first_c <= last_c
}

fn test_window_list_box_virtualization_reduces_row_count() {
	mut w := Window{}
	cfg := ListBoxCfg{
		id_scroll: 2
		height:    120
		data:      list_box_test_data(300)
	}
	v := w.list_box(cfg)
	assert v.content.len > 0
	assert v.content.len < cfg.data.len
}

fn test_list_box_without_virtualization_renders_all_rows() {
	cfg := ListBoxCfg{
		data: list_box_test_data(12)
	}
	v := list_box(cfg)
	assert v.content.len == 12
}

fn test_list_box_selection_uses_id_not_value() {
	cfg := ListBoxCfg{
		selected_ids: ['id_b']
		data:         [
			list_box_option('id_a', 'Alpha', 'dup'),
			list_box_option('id_b', 'Beta', 'dup'),
		]
	}
	assert cfg.data[0].value == cfg.data[1].value
	assert cfg.data[1].id in cfg.selected_ids
	assert cfg.data[0].id !in cfg.selected_ids
}

fn test_list_box_source_request_key_uses_query_and_source_key() {
	cfg := ListBoxCfg{
		id:         'list_a'
		query:      'Ada'
		source_key: 'rev_1'
	}
	assert list_box_source_request_key(cfg) == 'k:list_a|q:Ada|s:rev_1'
	assert list_box_source_request_key(ListBoxCfg{
		id:         'list_a'
		query:      'Ada'
		source_key: 'rev_2'
	}) != list_box_source_request_key(cfg)
}

fn test_list_box_resolve_source_cfg_requires_id() {
	mut w := Window{}
	source := ListBoxDataSource(&InMemoryListBoxDataSource{
		data: list_box_test_data(4)
	})
	resolved, has_source := list_box_resolve_source_cfg(ListBoxCfg{
		data_source: source
	}, mut w)
	assert has_source
	assert !resolved.loading
	assert resolved.data.len == 0
	assert resolved.load_error.contains('id is required')
}

fn test_window_list_box_source_sets_loading_state_and_stats() {
	mut w := Window{}
	source := ListBoxDataSource(&InMemoryListBoxDataSource{
		data:       list_box_test_data(12)
		latency_ms: 40
	})
	resolved, has_source := list_box_resolve_source_cfg(ListBoxCfg{
		id:          'list_loading'
		data_source: source
	}, mut w)
	assert has_source
	assert resolved.loading
	assert resolved.data.len == 0
	state := w.view_state.list_box_source_state.get('list_loading') or {
		panic('expected list box source state')
	}
	assert state.loading
	assert state.request_count == 1
	stats := w.list_box_source_stats('list_loading')
	assert stats.loading
	assert stats.request_count == 1
}

fn test_list_box_source_force_refetch_clears_request_key() {
	mut w := Window{}
	source := ListBoxDataSource(&InMemoryListBoxDataSource{
		data:       list_box_test_data(8)
		latency_ms: 40
	})
	_, _ = list_box_resolve_source_cfg(ListBoxCfg{
		id:          'list_refetch'
		data_source: source
	}, mut w)
	state_before := w.view_state.list_box_source_state.get('list_refetch') or {
		panic('expected source state before refetch')
	}
	assert state_before.request_key.len > 0
	list_box_source_force_refetch('list_refetch', mut w)
	state_after := w.view_state.list_box_source_state.get('list_refetch') or {
		panic('expected source state after refetch')
	}
	assert state_after.request_key == ''
}

fn test_in_memory_list_box_data_source_applies_query() {
	source := InMemoryListBoxDataSource{
		data: [
			list_box_option('1', 'Alice', 'A'),
			list_box_option('2', 'Bob', 'B'),
			list_box_option('3', 'Cara', 'C'),
		]
	}
	res := source.fetch_data(ListBoxDataRequest{
		list_box_id: 'list_query'
		query:       'ali'
	}) or { panic(err) }
	assert res.data.len == 1
	assert res.data[0].id == '1'
}

fn test_in_memory_list_box_data_source_honors_abort_signal() {
	source := InMemoryListBoxDataSource{
		data:       list_box_test_data(10)
		latency_ms: 30
	}
	mut controller := new_grid_abort_controller()
	controller.abort()
	_ := source.fetch_data(ListBoxDataRequest{
		list_box_id: 'list_abort'
		signal:      controller.signal
	}) or {
		assert err.msg().contains('aborted')
		return
	}
	assert false
}

fn test_list_box_renders_source_loading_status_row() {
	cfg := ListBoxCfg{
		loading: true
	}
	v := list_box(cfg)
	assert v.content.len == 1
}

fn test_list_box_renders_source_error_status_row() {
	cfg := ListBoxCfg{
		load_error: 'network down'
	}
	v := list_box(cfg)
	assert v.content.len == 1
}

fn list_box_test_data(count int) []ListBoxOption {
	mut out := []ListBoxOption{cap: count}
	for i in 0 .. count {
		out << list_box_option('id_${i}', 'Option ${i}', '${i}')
	}
	return out
}
