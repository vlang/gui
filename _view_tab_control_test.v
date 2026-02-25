module gui

struct TabReorderCapture {
mut:
	called bool
}

fn test_tab_item_helper() {
	item := tab_item('one', 'One', [])
	assert item.id == 'one'
	assert item.label == 'One'
	assert item.content.len == 0
	assert item.disabled == false
}

fn test_tab_selected_index_prefers_selected() {
	ids := ['one', 'two']
	disabled := [false, false]
	assert tab_selected_index(ids, disabled, 'two') == 1
}

fn test_tab_selected_index_falls_back_to_first_enabled() {
	ids := ['one', 'two', 'three']
	disabled := [true, false, false]
	assert tab_selected_index(ids, disabled, 'missing') == 1
	assert tab_selected_index(ids, disabled, 'one') == 1
}

fn test_tab_next_prev_enabled_index() {
	disabled := [false, true, false]
	assert tab_next_enabled_index(disabled, 0) == 2
	assert tab_next_enabled_index(disabled, 2) == 0
	assert tab_prev_enabled_index(disabled, 2) == 0
	assert tab_prev_enabled_index(disabled, 0) == 2
}

fn test_tab_enabled_index_all_disabled() {
	disabled := [true, true]
	assert tab_first_enabled_index(disabled) == -1
	assert tab_last_enabled_index(disabled) == -1
	assert tab_next_enabled_index(disabled, 0) == -1
	assert tab_prev_enabled_index(disabled, 1) == -1
}

fn test_tab_control_builds_view() {
	_ := tab_control(
		id:        'tabs_test'
		selected:  'one'
		items:     [
			tab_item('one', 'One', [text(text: 'A')]),
			tab_item('two', 'Two', [text(text: 'B')]),
		]
		on_select: fn (_ string, mut _e Event, mut _w Window) {}
	)
}

fn test_tab_control_keydown_disabled_blocks_reorder() {
	mut w := Window{}
	mut cap := &TabReorderCapture{}
	mut e := Event{
		key_code:  .right
		modifiers: .alt
	}
	tab_control_on_keydown(true, ['one', 'two'], [false, false], 'one', fn (_ string, mut _ Event, mut _ Window) {},
		0, true, fn [mut cap] (_ string, _ string, mut _ Window) {
		cap.called = true
	}, 'tabs', ['one', 'two'], mut e, mut w)
	assert !cap.called
	assert !e.is_handled
}

fn test_tab_control_nil_on_reorder_disables_drag_views() {
	cfg := TabControlCfg{
		id:          'tabs_nil_reorder'
		selected:    'one'
		reorderable: true
		items:       [
			tab_item('one', 'One', [text(text: 'A')]),
			tab_item('two', 'Two', [text(text: 'B')]),
			tab_item('three', 'Three', [text(text: 'C')]),
		]
		on_select:   fn (_ string, mut _e Event, mut _w Window) {}
	}
	drag := DragReorderState{
		active:        true
		source_index:  1
		current_index: 2
		item_width:    120
		item_height:   24
	}
	mut v := tab_control_build(cfg, drag)
	mut cv := v as ContainerView
	mut header := cv.content[0] as ContainerView
	assert header.content.len == 3
}
