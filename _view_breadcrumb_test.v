module gui

fn test_breadcrumb_item_helper() {
	item := breadcrumb_item('home', 'Home', [])
	assert item.id == 'home'
	assert item.label == 'Home'
	assert item.content.len == 0
	assert item.disabled == false
}

fn test_bc_selected_index_prefers_explicit() {
	items := [
		BreadcrumbItemCfg{
			id:    'home'
			label: 'Home'
		},
		BreadcrumbItemCfg{
			id:    'docs'
			label: 'Docs'
		},
		BreadcrumbItemCfg{
			id:    'page'
			label: 'Page'
		},
	]
	assert bc_selected_index(items, 'docs') == 1
}

fn test_bc_selected_index_falls_back_to_last_enabled() {
	items := [
		BreadcrumbItemCfg{
			id:    'home'
			label: 'Home'
		},
		BreadcrumbItemCfg{
			id:    'docs'
			label: 'Docs'
		},
		BreadcrumbItemCfg{
			id:       'page'
			label:    'Page'
			disabled: true
		},
	]
	// Missing id → fallback to last enabled
	assert bc_selected_index(items, 'missing') == 1
	// Empty string → fallback to last enabled
	assert bc_selected_index(items, '') == 1
}

fn test_bc_selected_index_disabled_selected() {
	items := [
		BreadcrumbItemCfg{
			id:    'home'
			label: 'Home'
		},
		BreadcrumbItemCfg{
			id:       'docs'
			label:    'Docs'
			disabled: true
		},
	]
	// Selecting disabled item → fallback to last enabled
	assert bc_selected_index(items, 'docs') == 0
}

fn test_bc_next_prev_enabled_index() {
	items := [
		BreadcrumbItemCfg{
			id:    'home'
			label: 'Home'
		},
		BreadcrumbItemCfg{
			id:       'mid'
			label:    'Mid'
			disabled: true
		},
		BreadcrumbItemCfg{
			id:    'end'
			label: 'End'
		},
	]
	assert bc_next_enabled_index(items, 0) == 2
	assert bc_next_enabled_index(items, 2) == 0
	assert bc_prev_enabled_index(items, 2) == 0
	assert bc_prev_enabled_index(items, 0) == 2
}

fn test_bc_first_last_enabled_index() {
	items := [
		BreadcrumbItemCfg{
			id:       'a'
			label:    'A'
			disabled: true
		},
		BreadcrumbItemCfg{
			id:    'b'
			label: 'B'
		},
		BreadcrumbItemCfg{
			id:    'c'
			label: 'C'
		},
		BreadcrumbItemCfg{
			id:       'd'
			label:    'D'
			disabled: true
		},
	]
	assert bc_first_enabled_index(items) == 1
	assert bc_last_enabled_index(items) == 2
}

fn test_bc_enabled_index_all_disabled() {
	items := [
		BreadcrumbItemCfg{
			id:       'a'
			label:    'A'
			disabled: true
		},
		BreadcrumbItemCfg{
			id:       'b'
			label:    'B'
			disabled: true
		},
	]
	assert bc_first_enabled_index(items) == -1
	assert bc_last_enabled_index(items) == -1
	assert bc_next_enabled_index(items, 0) == -1
	assert bc_prev_enabled_index(items, 1) == -1
}

fn test_breadcrumb_builds_view() {
	_ := breadcrumb(
		id:        'bc_test'
		selected:  'home'
		items:     [
			breadcrumb_item('home', 'Home', []),
			breadcrumb_item('docs', 'Docs', [text(text: 'Documentation')]),
		]
		on_select: fn (_ string, mut _e Event, mut _w Window) {}
	)
}
