module gui

fn test_tab_item_helper() {
	item := tab_item('one', 'One', [])
	assert item.id == 'one'
	assert item.label == 'One'
	assert item.content.len == 0
	assert item.disabled == false
}

fn test_tab_selected_index_prefers_selected() {
	items := [
		TabItemCfg{
			id:    'one'
			label: 'One'
		},
		TabItemCfg{
			id:    'two'
			label: 'Two'
		},
	]
	assert tab_selected_index(items, 'two') == 1
}

fn test_tab_selected_index_falls_back_to_first_enabled() {
	items := [
		TabItemCfg{
			id:       'one'
			label:    'One'
			disabled: true
		},
		TabItemCfg{
			id:    'two'
			label: 'Two'
		},
		TabItemCfg{
			id:    'three'
			label: 'Three'
		},
	]
	assert tab_selected_index(items, 'missing') == 1
	assert tab_selected_index(items, 'one') == 1
}

fn test_tab_next_prev_enabled_index() {
	items := [
		TabItemCfg{
			id:    'one'
			label: 'One'
		},
		TabItemCfg{
			id:       'two'
			label:    'Two'
			disabled: true
		},
		TabItemCfg{
			id:    'three'
			label: 'Three'
		},
	]
	assert tab_next_enabled_index(items, 0) == 2
	assert tab_next_enabled_index(items, 2) == 0
	assert tab_prev_enabled_index(items, 2) == 0
	assert tab_prev_enabled_index(items, 0) == 2
}

fn test_tab_enabled_index_all_disabled() {
	items := [
		TabItemCfg{
			id:       'one'
			label:    'One'
			disabled: true
		},
		TabItemCfg{
			id:       'two'
			label:    'Two'
			disabled: true
		},
	]
	assert tab_first_enabled_index(items) == -1
	assert tab_last_enabled_index(items) == -1
	assert tab_next_enabled_index(items, 0) == -1
	assert tab_prev_enabled_index(items, 1) == -1
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
