module gui

struct TreeReorderCapture {
mut:
	called bool
	moved  string
	before string
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
	tree_collect_flat_rows(nodes, tree_map, 'test', mut lazy_sm, mut out, 0)

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
	tree_collect_flat_rows(nodes, tree_map, 'test', mut lazy_sm, mut out, 0)

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
	tree_collect_flat_rows(nodes, tree_map, 'test', mut lazy_sm, mut out, 0)

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
	tree_collect_flat_rows(nodes, tree_map, 'test', mut lazy_sm, mut out, 0)

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
	], true, fn [mut cap] (m string, b string, mut _ Window) {
		cap.called = true
		cap.moved = m
		cap.before = b
	}, ['a', 'b', 'c'], mut e, mut w)
	assert cap.called
	assert cap.moved == 'b'
	assert cap.before == 'a'
	assert e.is_handled
	mut tf2 := state_map[string, string](mut w, ns_tree_focus, cap_tree_focus)
	focused := tf2.get('tree') or { '' }
	assert focused == 'b'
}
