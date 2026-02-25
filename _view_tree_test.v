module gui

struct TreeReorderCapture {
mut:
	called    bool
	moved     string
	before    string
	parent_id string
}

fn test_tree_compilation() {
	mut w := Window{}
	cfg := TreeCfg{
		id:    'test_tree'
		nodes: [
			tree_node(
				text:  'Root'
				nodes: [
					tree_node(text: 'Child'),
				]
			),
		]
	}
	w.view_state.tree_state.set('test_tree', {
		'Root': true
	})
	v := w.tree(cfg)
	assert v.content.len > 0
}

fn test_tree_focus_cache_uses_tree_cap() {
	mut w := Window{}
	mut tf := state_map[string, string](mut w, ns_tree_focus, cap_tree_focus)
	assert tf.max_size == cap_tree_focus
	for i in 0 .. cap_tree_focus + 5 {
		tf.set('tree_${i}', 'node_${i}')
	}
	assert tf.len() == cap_tree_focus
	assert tf.get('tree_0') == none
}

fn test_tree_collect_flat_rows() {
	mut w := Window{}
	nodes := [
		TreeNodeCfg{
			text:  'Animals'
			nodes: [
				TreeNodeCfg{
					text: 'Cat'
				},
				TreeNodeCfg{
					text: 'Dog'
				},
			]
		},
		TreeNodeCfg{
			text: 'Plants'
		},
	]
	tree_map := {
		'Animals': true
	}
	mut lazy_sm := state_map[string, bool](mut w, ns_tree_lazy, cap_tree_lazy)
	mut out := []TreeFlatRow{}
	tree_collect_flat_rows(nodes, tree_map, 'test', mut lazy_sm, mut out, 0, '')

	assert out.len == 4
	// Root level
	assert out[0].id == 'Animals'
	assert out[0].depth == 0
	assert out[0].has_children == true
	assert out[0].is_expanded == true
	// Children
	assert out[1].id == 'Cat'
	assert out[1].depth == 1
	assert out[1].has_children == false
	assert out[2].id == 'Dog'
	assert out[2].depth == 1
	// Sibling at root
	assert out[3].id == 'Plants'
	assert out[3].depth == 0
	assert out[3].has_children == false
}

fn test_tree_collect_flat_rows_collapsed() {
	mut w := Window{}
	nodes := [
		TreeNodeCfg{
			text:  'Animals'
			nodes: [
				TreeNodeCfg{
					text: 'Cat'
				},
			]
		},
	]
	tree_map := map[string]bool{}
	mut lazy_sm := state_map[string, bool](mut w, ns_tree_lazy, cap_tree_lazy)
	mut out := []TreeFlatRow{}
	tree_collect_flat_rows(nodes, tree_map, 'test', mut lazy_sm, mut out, 0, '')

	assert out.len == 1
	assert out[0].id == 'Animals'
	assert out[0].is_expanded == false
}

fn test_tree_collect_flat_rows_with_lazy() {
	mut w := Window{}
	nodes := [
		TreeNodeCfg{
			text: 'Server'
			lazy: true
		},
	]
	// Expand and mark as loading.
	tree_map := {
		'Server': true
	}
	mut lazy_sm := state_map[string, bool](mut w, ns_tree_lazy, cap_tree_lazy)
	lazy_sm.set(tree_lazy_key('test', 'Server'), true)

	mut out := []TreeFlatRow{}
	tree_collect_flat_rows(nodes, tree_map, 'test', mut lazy_sm, mut out, 0, '')

	// Should have node + loading sentinel.
	assert out.len == 2
	assert out[0].id == 'Server'
	assert out[0].is_lazy == true
	assert out[0].is_loading == false
	assert out[1].id == 'Server.__loading__'
	assert out[1].is_loading == true
	assert out[1].depth == 1
}

fn test_tree_lazy_auto_clear() {
	mut w := Window{}
	// Lazy node that now has children (load completed).
	nodes := [
		TreeNodeCfg{
			text:  'Server'
			lazy:  true
			nodes: [
				TreeNodeCfg{
					text: 'File1'
				},
			]
		},
	]
	tree_map := {
		'Server': true
	}
	mut lazy_sm := state_map[string, bool](mut w, ns_tree_lazy, cap_tree_lazy)
	lk := tree_lazy_key('test', 'Server')
	lazy_sm.set(lk, true)

	mut out := []TreeFlatRow{}
	tree_collect_flat_rows(nodes, tree_map, 'test', mut lazy_sm, mut out, 0, '')

	// Loading should be auto-cleared.
	assert lazy_sm.get(lk) == none
	// Should show node + child, no loading sentinel.
	assert out.len == 2
	assert out[0].id == 'Server'
	assert out[1].id == 'File1'
	assert out[1].is_loading == false
}

fn test_tree_visible_range() {
	mut w := Window{}
	// 100 rows, 20px each, viewport 100px = 5 visible + buffer.
	first, last := tree_visible_range(100.0, 20.0, 100, 1, mut w)
	// At scroll_y=0: first=0, visible=6, with buffer of 2.
	assert first == 0
	assert last == 8 // 0 + 6 + 2
}

fn test_tree_visible_range_empty() {
	mut w := Window{}
	first, last := tree_visible_range(100.0, 20.0, 0, 1, mut w)
	assert first == 0
	assert last == -1
}

fn test_tree_flat_rows_all_rendered_without_scroll() {
	mut w := Window{}
	cfg := TreeCfg{
		id:    'no_scroll'
		nodes: [
			tree_node(
				text:  'A'
				nodes: [
					tree_node(text: 'B'),
				]
			),
			tree_node(text: 'C'),
		]
	}
	w.view_state.tree_state.set('no_scroll', {
		'A': true
	})
	// No id_scroll, no height → no virtualization, all rows rendered.
	v := w.tree(cfg)
	// content should be 3 flat rows (A, B, C), no spacers.
	assert v.content.len == 3
}

fn test_tree_lazy_key_format() {
	k := tree_lazy_key('my_tree', 'node_42')
	assert k == 'my_tree\tnode_42'
}

fn test_tree_keyboard_reorder_keeps_focus_on_moved_id() {
	mut w := Window{}
	w.layout = Layout{
		shape: &Shape{
			id: 'root'
		}
	}
	mut tf := state_map[string, string](mut w, ns_tree_focus, cap_tree_focus)
	tf.set('tree', 'b')
	mut cap := &TreeReorderCapture{}
	mut e := Event{
		key_code:  .up
		modifiers: .alt
	}
	tree_on_keydown('tree', fn (_ string, mut _ Window) {}, fn (_ string, _ string, mut _ Window) {},
		[
		'a',
		'b',
		'c',
	], true, fn [mut cap] (m string, b string, _ string, mut _ Window) {
		cap.called = true
		cap.moved = m
		cap.before = b
	}, {
		'': ['a', 'b', 'c']
	}, {
		'a': 0
		'b': 1
		'c': 2
	}, {
		'a': ''
		'b': ''
		'c': ''
	}, mut e, mut w)
	assert cap.called
	assert cap.moved == 'b'
	assert cap.before == 'a'
	assert e.is_handled
	mut tf2 := state_map[string, string](mut w, ns_tree_focus, cap_tree_focus)
	focused := tf2.get('tree') or { '' }
	assert focused == 'b'
}

fn test_tree_virtualized_drag_uses_global_top_level_index() {
	mut w := Window{}
	cfg := TreeCfg{
		id:          'tree_virtual_drag'
		id_scroll:   77
		height:      20
		reorderable: true
		on_reorder:  fn (_ string, _ string, _ string, mut _ Window) {}
		nodes:       [
			tree_node(id: 'a', text: 'A'),
			tree_node(id: 'b', text: 'B'),
			tree_node(id: 'c', text: 'C'),
			tree_node(id: 'd', text: 'D'),
			tree_node(id: 'e', text: 'E'),
		]
	}
	row_height := tree_estimate_row_height(cfg, mut w)
	mut sy := state_map[u32, f32](mut w, ns_scroll_y, cap_scroll)
	sy.set(cfg.id_scroll, -(row_height * 4))
	drag_reorder_set(mut w, cfg.id, DragReorderState{
		active:        true
		item_id:       'd'
		source_index:  3
		current_index: 4
		item_width:    120
		item_height:   20
	})
	mut v := w.tree(cfg)
	ids := tree_child_ids(v)
	if 'tr_tree_virtual_drag_d' in ids {
		assert false
	}
	if 'tr_tree_virtual_drag_c' in ids {
		assert true
	} else {
		assert false
	}
	if 'tr_tree_virtual_drag_e' in ids {
		assert true
	} else {
		assert false
	}
}

fn test_tree_nil_on_reorder_disables_reorder_ids() {
	mut w := Window{}
	cfg := TreeCfg{
		id:          'tree_nil_reorder'
		reorderable: true
		nodes:       [
			tree_node(id: 'a', text: 'A'),
			tree_node(id: 'b', text: 'B'),
		]
	}
	mut v := w.tree(cfg)
	ids := tree_child_ids(v)
	if 'tr_tree_nil_reorder_a' in ids {
		assert false
	}
	if 'tr_tree_nil_reorder_b' in ids {
		assert false
	}
}

fn test_tree_leaf_node_drag_produces_ghost_and_gap() {
	mut w := Window{}
	// Mimic the example: parent nodes with children + leaf nodes.
	cfg := TreeCfg{
		id:          'tree_leaf'
		reorderable: true
		on_reorder:  fn (_ string, _ string, _ string, mut _ Window) {}
		nodes:       [
			tree_node(
				id:    'src'
				text:  'src'
				nodes: [tree_node(id: 'main.v', text: 'main.v')]
			),
			tree_node(id: 'tests', text: 'tests'),
			tree_node(id: 'build', text: 'build'),
		]
	}
	// Expand src so the flat list is: src, main.v, tests, build.
	w.view_state.tree_state.set('tree_leaf', {
		'src': true
	})
	// Drag leaf node "tests" (root sibling index 1) towards "build" (index 2).
	drag_reorder_set(mut w, cfg.id, DragReorderState{
		active:        true
		item_id:       'tests'
		source_index:  1
		current_index: 2
		item_width:    200
		item_height:   20
	})
	mut v := w.tree(cfg)
	ids := tree_child_ids(v)
	// "tests" is the drag source — should NOT be in normal content.
	assert 'tr_tree_leaf_tests' !in ids
	// "src" and "build" must be present.
	assert 'tr_tree_leaf_src' in ids
	assert 'tr_tree_leaf_build' in ids
}

fn test_tree_leaf_node_gets_drag_layout_id() {
	mut w := Window{}
	cfg := TreeCfg{
		id:          'tree_id'
		reorderable: true
		on_reorder:  fn (_ string, _ string, _ string, mut _ Window) {}
		nodes:       [
			tree_node(
				id:    'parent'
				text:  'Parent'
				nodes: [tree_node(id: 'child', text: 'Child')]
			),
			tree_node(id: 'leaf', text: 'Leaf'),
		]
	}
	// Expand parent so child is visible.
	w.view_state.tree_state.set('tree_id', {
		'parent': true
	})
	mut v := w.tree(cfg)
	ids := tree_child_ids(v)
	// All non-loading nodes get drag layout IDs.
	assert 'tr_tree_id_parent' in ids
	assert 'tr_tree_id_child' in ids
	assert 'tr_tree_id_leaf' in ids
}

fn test_tree_collect_flat_rows_sets_parent_id() {
	mut w := Window{}
	nodes := [
		TreeNodeCfg{
			id:    'src'
			text:  'src'
			nodes: [
				TreeNodeCfg{
					id:   'main.v'
					text: 'main.v'
				},
				TreeNodeCfg{
					id:   'util.v'
					text: 'util.v'
				},
			]
		},
		TreeNodeCfg{
			id:   'tests'
			text: 'tests'
		},
	]
	tree_map := {
		'src': true
	}
	mut lazy_sm := state_map[string, bool](mut w, ns_tree_lazy, cap_tree_lazy)
	mut out := []TreeFlatRow{}
	tree_collect_flat_rows(nodes, tree_map, 'test', mut lazy_sm, mut out, 0, '')

	assert out.len == 4
	// Root nodes have empty parent_id.
	assert out[0].id == 'src'
	assert out[0].parent_id == ''
	assert out[3].id == 'tests'
	assert out[3].parent_id == ''
	// Children have parent's id.
	assert out[1].id == 'main.v'
	assert out[1].parent_id == 'src'
	assert out[2].id == 'util.v'
	assert out[2].parent_id == 'src'
}

fn test_tree_sibling_drag_produces_ghost_among_siblings() {
	mut w := Window{}
	cfg := TreeCfg{
		id:          'tree_sib'
		reorderable: true
		on_reorder:  fn (_ string, _ string, _ string, mut _ Window) {}
		nodes:       [
			tree_node(
				id:    'src'
				text:  'src'
				nodes: [
					tree_node(id: 'main.v', text: 'main.v'),
					tree_node(id: 'util.v', text: 'util.v'),
				]
			),
			tree_node(id: 'tests', text: 'tests'),
		]
	}
	w.view_state.tree_state.set('tree_sib', {
		'src': true
	})
	// Drag child "main.v" (sibling index 0 within src) to index 1.
	drag_reorder_set(mut w, cfg.id, DragReorderState{
		active:        true
		item_id:       'main.v'
		source_index:  0
		current_index: 1
		item_width:    200
		item_height:   20
	})
	mut v := w.tree(cfg)
	ids := tree_child_ids(v)
	// "main.v" is the drag source — ghosted, not in normal content.
	assert 'tr_tree_sib_main.v' !in ids
	// "util.v" (sibling) should be present.
	assert 'tr_tree_sib_util.v' in ids
	// Parent "src" and root sibling "tests" unaffected.
	assert 'tr_tree_sib_src' in ids
	assert 'tr_tree_sib_tests' in ids
}

fn test_tree_keyboard_reorder_nested_siblings() {
	mut w := Window{}
	w.layout = Layout{
		shape: &Shape{
			id: 'root'
		}
	}
	// Focus on 'util.v' which is a child of 'src'.
	mut tf := state_map[string, string](mut w, ns_tree_focus, cap_tree_focus)
	tf.set('tree', 'util.v')
	mut cap := &TreeReorderCapture{}
	mut e := Event{
		key_code:  .up
		modifiers: .alt
	}
	tree_on_keydown('tree', fn (_ string, mut _ Window) {}, fn (_ string, _ string, mut _ Window) {},
		['src', 'main.v', 'util.v', 'tests'], true, fn [mut cap] (m string, b string, p string, mut _ Window) {
		cap.called = true
		cap.moved = m
		cap.before = b
		cap.parent_id = p
	}, {
		'':    ['src', 'tests']
		'src': ['main.v', 'util.v']
	}, {
		'src':    0
		'tests':  1
		'main.v': 0
		'util.v': 1
	}, {
		'src':    ''
		'tests':  ''
		'main.v': 'src'
		'util.v': 'src'
	}, mut e, mut w)
	assert cap.called
	assert cap.moved == 'util.v'
	assert cap.before == 'main.v'
	assert cap.parent_id == 'src'
	assert e.is_handled
}

fn tree_child_ids(v View) []string {
	mut root := v as ContainerView
	mut ids := []string{}
	for child in root.content {
		if child is ContainerView {
			if child.id.len > 0 {
				ids << child.id
			}
		}
	}
	return ids
}
