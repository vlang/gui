module gui

fn test_tree_compilation() {
	// Just verify it compiles and runs without crashing for a simple case
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

	// mock view state since we rely on it
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
