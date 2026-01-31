module gui

fn test_bounded_map_basic_operations() {
	mut m := BoundedMap[string, int]{
		max_size: 3
	}

	// Test set and get
	m.set('a', 1)
	m.set('b', 2)
	m.set('c', 3)

	assert m.get('a') or { -1 } == 1
	assert m.get('b') or { -1 } == 2
	assert m.get('c') or { -1 } == 3
	assert m.len() == 3
}

fn test_bounded_map_eviction() {
	mut m := BoundedMap[string, int]{
		max_size: 3
	}

	m.set('a', 1)
	m.set('b', 2)
	m.set('c', 3)
	// Adding 'd' should evict 'a' (FIFO)
	m.set('d', 4)

	assert m.get('a') == none
	assert m.get('b') or { -1 } == 2
	assert m.get('c') or { -1 } == 3
	assert m.get('d') or { -1 } == 4
	assert m.len() == 3
}

fn test_bounded_map_update_existing() {
	mut m := BoundedMap[string, int]{
		max_size: 3
	}

	m.set('a', 1)
	m.set('b', 2)
	// Update 'a' should not cause eviction
	m.set('a', 10)
	m.set('c', 3)

	assert m.get('a') or { -1 } == 10
	assert m.get('b') or { -1 } == 2
	assert m.get('c') or { -1 } == 3
	assert m.len() == 3
}

fn test_bounded_map_contains() {
	mut m := BoundedMap[string, int]{
		max_size: 3
	}

	m.set('a', 1)
	assert m.contains('a') == true
	assert m.contains('b') == false
}

fn test_bounded_map_delete() {
	mut m := BoundedMap[string, int]{
		max_size: 3
	}

	m.set('a', 1)
	m.set('b', 2)
	m.delete('a')

	assert m.get('a') == none
	assert m.get('b') or { -1 } == 2
	assert m.len() == 1
}

fn test_bounded_map_clear() {
	mut m := BoundedMap[string, int]{
		max_size: 3
	}

	m.set('a', 1)
	m.set('b', 2)
	m.clear()

	assert m.len() == 0
	assert m.get('a') == none
}

fn test_bounded_map_keys() {
	mut m := BoundedMap[string, int]{
		max_size: 5
	}

	m.set('a', 1)
	m.set('b', 2)
	m.set('c', 3)

	keys := m.keys()
	assert keys.len == 3
	assert keys[0] == 'a'
	assert keys[1] == 'b'
	assert keys[2] == 'c'
}

fn test_bounded_tree_state() {
	mut m := BoundedTreeState{
		max_size: 2
	}

	m.set('tree1', {
		'node1': true
		'node2': false
	})
	m.set('tree2', {
		'nodeA': true
	})

	tree1 := m.get('tree1') or { return }
	assert tree1['node1'] == true
	assert tree1['node2'] == false

	// Adding third tree should evict tree1
	m.set('tree3', {
		'nodeX': true
	})

	assert m.get('tree1') == none
	assert m.contains('tree2') == true
	assert m.contains('tree3') == true
	assert m.len() == 2
}
