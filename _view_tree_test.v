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
