module gui

import os
import time

fn test_clear_view_state_clears_diagram_cache_temp_files() {
	tmp_path := os.join_path(os.temp_dir(), 'gui_diagram_test_${time.now().unix_micro()}.png')
	os.write_file(tmp_path, 'x') or { panic(err) }
	defer {
		if os.exists(tmp_path) {
			os.rm(tmp_path) or {}
		}
	}

	mut w := Window{}
	w.view_state.diagram_cache.set(1, DiagramCacheEntry{
		state:    .ready
		png_path: tmp_path
	})
	assert os.exists(tmp_path)

	w.clear_view_state()

	assert !os.exists(tmp_path)
	assert w.view_state.diagram_cache.len() == 0
}

fn test_bounded_image_map_fifo_eviction() {
	mut w := Window{}
	mut ctx := w.context()
	mut m := BoundedImageMap{
		max_size: 2
	}

	m.set('a', 1, mut ctx)
	m.set('b', 2, mut ctx)
	assert m.len() == 2
	assert m.keys() == ['a', 'b']

	// Adding 'c' should evict 'a' (FIFO)
	m.set('c', 3, mut ctx)
	assert m.len() == 2
	assert m.get('a') == none
	assert m.get('b') or { -1 } == 2
	assert m.get('c') or { -1 } == 3
	assert m.keys() == ['b', 'c']

	// Deleting 'b' and adding 'd'
	m.delete('b')
	assert m.len() == 1
	m.set('d', 4, mut ctx)
	assert m.len() == 2
	assert m.keys() == ['c', 'd']
}

fn test_state_registry_clear_drops_maps() {
	mut w := Window{}
	_ = state_map[string, int](mut w, 'test.a', 10)
	_ = state_map[string, bool](mut w, 'test.b', 10)
	assert w.view_state.registry.maps.len == 2

	w.view_state.registry.clear()
	assert w.view_state.registry.maps.len == 0
	assert w.view_state.registry.meta.len == 0
}
