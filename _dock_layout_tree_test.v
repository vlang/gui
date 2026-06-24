module gui

fn dock_test_group(id string, panel_ids []string, selected_id string) &DockNode {
	return dock_panel_group(id, panel_ids, selected_id)
}

fn dock_test_root() &DockNode {
	left := dock_test_group('left', ['left_a', 'left_b'], 'left_b')
	right := dock_test_group('right', ['right_a'], 'right_a')
	return dock_split('root', .horizontal, 0.35, left, right)
}

fn dock_same_node(a &DockNode, b &DockNode) bool {
	return unsafe { a == b }
}

fn test_dock_tree_remove_absent_panel_returns_same_root() {
	root := dock_test_root()
	same_root := dock_tree_remove_panel(root, 'missing')

	assert dock_same_node(same_root, root)
	assert root.kind == .split
	assert root.first.panel_ids == ['left_a', 'left_b']
	assert root.first.selected_id == 'left_b'
	assert root.second.panel_ids == ['right_a']
}

fn test_dock_tree_remove_selected_tab_selects_first_remaining_tab() {
	root := dock_test_root()
	new_root := dock_tree_remove_panel(root, 'left_b')

	assert !dock_same_node(new_root, root)
	assert !dock_same_node(new_root.first, root.first)
	assert dock_same_node(new_root.second, root.second)
	assert new_root.first.panel_ids == ['left_a']
	assert new_root.first.selected_id == 'left_a'
	assert root.first.panel_ids == ['left_a', 'left_b']
	assert root.first.selected_id == 'left_b'
}

fn test_dock_tree_remove_last_panel_collapses_split_to_sibling() {
	root := dock_test_root()
	new_root := dock_tree_remove_panel(root, 'right_a')

	assert dock_same_node(new_root, root.first)
	assert new_root.id == 'left'
	assert new_root.panel_ids == ['left_a', 'left_b']
}

fn test_dock_tree_add_tab_appends_and_selects_added_panel() {
	root := dock_test_root()
	new_root := dock_tree_add_tab(root, 'right', 'right_b')

	assert !dock_same_node(new_root, root)
	assert dock_same_node(new_root.first, root.first)
	assert !dock_same_node(new_root.second, root.second)
	assert new_root.second.panel_ids == ['right_a', 'right_b']
	assert new_root.second.selected_id == 'right_b'
	assert root.second.panel_ids == ['right_a']
	assert root.second.selected_id == 'right_a'
}

fn test_dock_tree_split_at_preserves_direction_and_child_ordering() {
	base := dock_test_group('target', ['existing'], 'existing')

	left := dock_tree_split_at(base, 'target', 'new_left', .left)
	assert left.dir == .horizontal
	assert left.first.panel_ids == ['new_left']
	assert left.second.panel_ids == ['existing']

	right := dock_tree_split_at(base, 'target', 'new_right', .right)
	assert right.dir == .horizontal
	assert right.first.panel_ids == ['existing']
	assert right.second.panel_ids == ['new_right']

	top := dock_tree_split_at(base, 'target', 'new_top', .top)
	assert top.dir == .vertical
	assert top.first.panel_ids == ['new_top']
	assert top.second.panel_ids == ['existing']

	bottom := dock_tree_split_at(base, 'target', 'new_bottom', .bottom)
	assert bottom.dir == .vertical
	assert bottom.first.panel_ids == ['existing']
	assert bottom.second.panel_ids == ['new_bottom']
}

fn test_dock_tree_move_center_removes_then_adds_tab() {
	root := dock_test_root()
	new_root := dock_tree_move_panel(root, 'left_b', 'right', .center)

	assert new_root.kind == .split
	assert new_root.first.panel_ids == ['left_a']
	assert new_root.first.selected_id == 'left_a'
	assert new_root.second.panel_ids == ['right_a', 'left_b']
	assert new_root.second.selected_id == 'left_b'
	assert root.first.panel_ids == ['left_a', 'left_b']
	assert root.second.panel_ids == ['right_a']
}

fn test_dock_tree_move_window_edge_wraps_after_remove() {
	root := dock_test_root()
	new_root := dock_tree_move_panel(root, 'left_b', '', .window_right)

	assert new_root.kind == .split
	assert new_root.dir == .horizontal
	assert new_root.ratio == f32(0.8)
	assert new_root.first.kind == .split
	assert new_root.first.first.panel_ids == ['left_a']
	assert new_root.first.second.panel_ids == ['right_a']
	assert new_root.second.panel_ids == ['left_b']
	assert new_root.second.selected_id == 'left_b'
}

fn test_dock_tree_select_panel_noop_and_change_behavior() {
	root := dock_test_root()
	same_root := dock_tree_select_panel(root, 'left', 'left_b')
	new_root := dock_tree_select_panel(root, 'left', 'left_a')

	assert dock_same_node(same_root, root)
	assert !dock_same_node(new_root, root)
	assert !dock_same_node(new_root.first, root.first)
	assert dock_same_node(new_root.second, root.second)
	assert new_root.first.panel_ids == ['left_a', 'left_b']
	assert new_root.first.selected_id == 'left_a'
	assert root.first.selected_id == 'left_b'
}
