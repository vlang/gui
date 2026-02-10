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
	assert head.name == '---States'
	assert head.value == ''
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

fn list_box_test_data(count int) []ListBoxOption {
	mut out := []ListBoxOption{cap: count}
	for i in 0 .. count {
		out << list_box_option('id_${i}', 'Option ${i}', '${i}')
	}
	return out
}
