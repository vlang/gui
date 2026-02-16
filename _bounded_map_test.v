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

fn test_bounded_map_max_size_one() {
	mut m := BoundedMap[string, int]{
		max_size: 1
	}

	m.set('a', 1)
	assert m.get('a') or { -1 } == 1
	assert m.len() == 1

	// Adding 'b' should evict 'a'
	m.set('b', 2)
	assert m.get('a') == none
	assert m.get('b') or { -1 } == 2
	assert m.len() == 1
}

fn test_bounded_map_max_size_zero() {
	mut m := BoundedMap[string, int]{
		max_size: 0
	}

	m.set('a', 1)
	assert m.len() == 0 // nothing stored when max_size < 1
}

fn test_bounded_map_delete_nonexistent() {
	mut m := BoundedMap[string, int]{
		max_size: 3
	}

	m.set('a', 1)
	m.delete('nonexistent') // should not panic
	assert m.len() == 1
	assert m.get('a') or { -1 } == 1
}

fn test_bounded_markdown_cache_fifo() {
	mut m := BoundedMarkdownCache{
		max_size: 2
	}

	m.set(100, [])
	m.set(200, [])
	assert m.len() == 2

	// Adding third should evict first (FIFO)
	m.set(300, [])
	assert m.get(100) == none
	assert m.get(200) != none
	assert m.get(300) != none
	assert m.len() == 2
}

fn test_bounded_map_keys_stable_after_delete_and_insert() {
	mut m := BoundedMap[string, int]{
		max_size: 4
	}
	m.set('a', 1)
	m.set('b', 2)
	m.set('c', 3)
	m.delete('b')
	m.set('d', 4)
	assert m.keys() == ['a', 'c', 'd']
}

fn test_bounded_tree_state_update_preserves_fifo_position() {
	mut m := BoundedTreeState{
		max_size: 2
	}
	m.set('left', {
		'a': true
	})
	m.set('right', {
		'b': true
	})
	// update existing key; should not move to back
	m.set('left', {
		'a': false
	})
	m.set('third', {
		'c': true
	})
	assert m.get('left') == none
	assert m.get('right') != none
	assert m.get('third') != none
}

fn test_bounded_markdown_cache_update_preserves_fifo_position() {
	mut m := BoundedMarkdownCache{
		max_size: 2
	}
	m.set(10, [])
	m.set(20, [])
	m.set(10, [])
	m.set(30, [])
	assert m.get(10) == none
	assert m.get(20) != none
	assert m.get(30) != none
}
