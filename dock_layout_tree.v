module gui

// dock_layout_tree.v — user-owned, serializable layout tree for
// IDE-style docking panels. Binary tree of splits; leaves are
// panel groups (one or more panels shown as tabs).
//
// Uses a tagged struct (not a sumtype) to avoid a V compiler bug
// where pointer-based sumtype variants get dangling pointers when
// created from compound literals (is_mut=true skips memdup).

// DockSplitDir controls how two panes are arranged in a split.
pub enum DockSplitDir as u8 {
	horizontal // left | right
	vertical   // top | bottom
}

// DockNodeKind distinguishes split nodes from leaf panel groups.
pub enum DockNodeKind as u8 {
	split
	panel_group
}

// DockNode is a single node in the dock layout tree: either a
// split (with two children) or a leaf panel group.
pub struct DockNode {
pub mut:
	kind DockNodeKind
	id   string
	// Split fields (used when kind == .split).
	dir    DockSplitDir
	ratio  f32       = 0.5
	first  &DockNode = unsafe { nil }
	second &DockNode = unsafe { nil }
	// Panel group fields (used when kind == .panel_group).
	panel_ids   []string
	selected_id string
}

// dock_split creates a heap-allocated split node.
pub fn dock_split(id string, dir DockSplitDir, ratio f32, first &DockNode, second &DockNode) &DockNode {
	return &DockNode{
		kind:   .split
		id:     id
		dir:    dir
		ratio:  ratio
		first:  unsafe { first }
		second: unsafe { second }
	}
}

// dock_panel_group creates a heap-allocated panel group node.
pub fn dock_panel_group(id string, panel_ids []string, selected_id string) &DockNode {
	return &DockNode{
		kind:        .panel_group
		id:          id
		panel_ids:   panel_ids
		selected_id: selected_id
	}
}

// dock_tree_collect_panel_nodes returns pointers to all panel group
// nodes in the tree. Used for zone detection during drag.
pub fn dock_tree_collect_panel_nodes(node &DockNode) []&DockNode {
	mut result := []&DockNode{}
	dock_tree_collect_panel_nodes_rec(node, mut result)
	return result
}

fn dock_tree_collect_panel_nodes_rec(node &DockNode, mut result []&DockNode) {
	if node.kind == .split {
		if node.first != unsafe { nil } {
			dock_tree_collect_panel_nodes_rec(node.first, mut result)
		}
		if node.second != unsafe { nil } {
			dock_tree_collect_panel_nodes_rec(node.second, mut result)
		}
	} else {
		result << unsafe { node }
	}
}

// dock_tree_find_group_by_panel returns the panel group node
// containing the given panel_id, or none if not found.
pub fn dock_tree_find_group_by_panel(node &DockNode, panel_id string) ?&DockNode {
	if node.kind == .split {
		if node.first != unsafe { nil } {
			if g := dock_tree_find_group_by_panel(node.first, panel_id) {
				return g
			}
		}
		if node.second != unsafe { nil } {
			if g := dock_tree_find_group_by_panel(node.second, panel_id) {
				return g
			}
		}
	} else {
		for id in node.panel_ids {
			if id == panel_id {
				return unsafe { node }
			}
		}
	}
	return none
}

// dock_tree_find_group_by_id returns the panel group node with the
// given group id, or none if not found.
pub fn dock_tree_find_group_by_id(node &DockNode, group_id string) ?&DockNode {
	if node.kind == .split {
		if node.first != unsafe { nil } {
			if g := dock_tree_find_group_by_id(node.first, group_id) {
				return g
			}
		}
		if node.second != unsafe { nil } {
			if g := dock_tree_find_group_by_id(node.second, group_id) {
				return g
			}
		}
	} else {
		if node.id == group_id {
			return unsafe { node }
		}
	}
	return none
}

// dock_tree_remove_panel removes a panel from the tree. If the
// group becomes empty, collapses the parent split (replaces it
// with the remaining sibling). Returns the new root.
pub fn dock_tree_remove_panel(root &DockNode, panel_id string) &DockNode {
	return dock_tree_remove_panel_rec(root, panel_id)
}

fn dock_tree_remove_panel_rec(nd &DockNode, panel_id string) &DockNode {
	orig := unsafe { nd }
	if nd.kind == .split {
		if nd.first == unsafe { nil } || nd.second == unsafe { nil } {
			return orig
		}
		new_first := dock_tree_remove_panel_rec(nd.first, panel_id)
		new_second := dock_tree_remove_panel_rec(nd.second, panel_id)
		if dock_tree_is_empty(new_first) {
			return new_second
		}
		if dock_tree_is_empty(new_second) {
			return new_first
		}
		if new_first != nd.first || new_second != nd.second {
			return dock_split(nd.id, nd.dir, nd.ratio, new_first, new_second)
		}
		return orig
	} else {
		mut found := false
		for id in nd.panel_ids {
			if id == panel_id {
				found = true
				break
			}
		}
		if !found {
			return orig
		}
		mut new_ids := []string{cap: if nd.panel_ids.len > 0 { nd.panel_ids.len - 1 } else { 0 }}
		for id in nd.panel_ids {
			if id != panel_id {
				new_ids << id
			}
		}
		if new_ids.len == 0 {
			return dock_panel_group('__dock_empty__', []string{}, '')
		}
		mut new_selected := nd.selected_id
		if new_selected == panel_id {
			new_selected = new_ids[0]
		}
		return dock_panel_group(nd.id, new_ids, new_selected)
	}
}

fn dock_tree_is_empty(node &DockNode) bool {
	return node.kind == .panel_group && node.panel_ids.len == 0
}

// dock_tree_add_tab adds a panel to an existing group (by group_id).
// Returns the new root.
pub fn dock_tree_add_tab(root &DockNode, group_id string, panel_id string) &DockNode {
	return dock_tree_add_tab_rec(root, group_id, panel_id)
}

fn dock_tree_add_tab_rec(nd &DockNode, group_id string, panel_id string) &DockNode {
	orig := unsafe { nd }
	if nd.kind == .split {
		if nd.first == unsafe { nil } || nd.second == unsafe { nil } {
			return orig
		}
		new_first := dock_tree_add_tab_rec(nd.first, group_id, panel_id)
		new_second := dock_tree_add_tab_rec(nd.second, group_id, panel_id)
		if new_first != nd.first || new_second != nd.second {
			return dock_split(nd.id, nd.dir, nd.ratio, new_first, new_second)
		}
		return orig
	} else {
		if nd.id != group_id {
			return orig
		}
		mut new_ids := nd.panel_ids.clone()
		new_ids << panel_id
		return dock_panel_group(nd.id, new_ids, panel_id)
	}
}

// dock_tree_split_at replaces a group (by group_id) with a new
// split containing the original group and a new single-panel group.
// The new panel goes into the position indicated by zone.
pub fn dock_tree_split_at(root &DockNode, group_id string, panel_id string, zone DockDropZone) &DockNode {
	return dock_tree_split_at_rec(root, group_id, panel_id, zone)
}

fn dock_tree_split_at_rec(nd &DockNode, group_id string, panel_id string, zone DockDropZone) &DockNode {
	orig := unsafe { nd }
	if nd.kind == .split {
		if nd.first == unsafe { nil } || nd.second == unsafe { nil } {
			return orig
		}
		new_first := dock_tree_split_at_rec(nd.first, group_id, panel_id, zone)
		new_second := dock_tree_split_at_rec(nd.second, group_id, panel_id, zone)
		if new_first != nd.first || new_second != nd.second {
			return dock_split(nd.id, nd.dir, nd.ratio, new_first, new_second)
		}
		return orig
	} else {
		if nd.id != group_id {
			return orig
		}
		new_group := dock_panel_group('${group_id}_new_${panel_id}', [panel_id], panel_id)
		existing := dock_panel_group(nd.id, nd.panel_ids, nd.selected_id)
		dir := dock_zone_to_split_dir(zone)
		first_is_new := zone == .left || zone == .top
		return dock_split('${group_id}_split', dir, 0.5, if first_is_new {
			new_group
		} else {
			existing
		}, if first_is_new { existing } else { new_group })
	}
}

// dock_tree_wrap_root wraps the current root in a new split for
// window-edge docking. The new panel goes at the indicated edge.
pub fn dock_tree_wrap_root(root &DockNode, panel_id string, zone DockDropZone) &DockNode {
	new_group := dock_panel_group('dock_edge_${panel_id}', [panel_id], panel_id)
	dir := dock_zone_to_split_dir(zone)
	first_is_new := zone == .window_left || zone == .window_top
	ratio := if first_is_new { f32(0.2) } else { f32(0.8) }
	return dock_split('dock_root_split', dir, ratio, if first_is_new { new_group } else { root },
		if first_is_new { root } else { new_group })
}

// dock_tree_move_panel removes a panel from its source group and
// inserts it at the target: either as a tab (center zone) or as a
// new split (edge zones). Returns the new root.
pub fn dock_tree_move_panel(root &DockNode, panel_id string, target_group_id string, zone DockDropZone) &DockNode {
	mut new_root := dock_tree_remove_panel(root, panel_id)
	if zone == .center {
		new_root = dock_tree_add_tab(new_root, target_group_id, panel_id)
	} else if zone == .window_top || zone == .window_bottom || zone == .window_left
		|| zone == .window_right {
		new_root = dock_tree_wrap_root(new_root, panel_id, zone)
	} else {
		new_root = dock_tree_split_at(new_root, target_group_id, panel_id, zone)
	}
	return new_root
}

// dock_tree_select_panel sets the selected panel in the group with
// the given group_id. Returns the new root.
pub fn dock_tree_select_panel(nd &DockNode, group_id string, panel_id string) &DockNode {
	orig := unsafe { nd }
	if nd.kind == .split {
		if nd.first == unsafe { nil } || nd.second == unsafe { nil } {
			return orig
		}
		new_first := dock_tree_select_panel(nd.first, group_id, panel_id)
		new_second := dock_tree_select_panel(nd.second, group_id, panel_id)
		if new_first != nd.first || new_second != nd.second {
			return dock_split(nd.id, nd.dir, nd.ratio, new_first, new_second)
		}
	} else {
		if nd.id == group_id && nd.selected_id != panel_id {
			return dock_panel_group(nd.id, nd.panel_ids, panel_id)
		}
	}
	return orig
}

// dock_zone_to_split_dir maps a drop zone to a split direction.
fn dock_zone_to_split_dir(zone DockDropZone) DockSplitDir {
	return match zone {
		.left, .right, .window_left, .window_right { .horizontal }
		else { .vertical }
	}
}
