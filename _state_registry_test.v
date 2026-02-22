module gui

fn test_state_map_round_trip() {
	mut w := Window{}
	mut om := state_map[string, int](mut w, ns_overflow, cap_moderate)

	om.set('panel_a', 3)
	om.set('panel_b', 5)

	assert om.get('panel_a') or { -1 } == 3
	assert om.get('panel_b') or { -1 } == 5
	assert om.get('panel_c') == none
	assert om.len() == 2
}

fn test_state_map_returns_same_instance() {
	mut w := Window{}
	mut m1 := state_map[string, int](mut w, 'test.ns', 10)
	m1.set('x', 42)

	mut m2 := state_map[string, int](mut w, 'test.ns', 10)
	assert m2.get('x') or { -1 } == 42
}

fn test_state_map_eviction() {
	mut w := Window{}
	mut m := state_map[string, int](mut w, 'test.evict', 2)

	m.set('a', 1)
	m.set('b', 2)
	m.set('c', 3)

	assert m.get('a') == none
	assert m.get('b') or { -1 } == 2
	assert m.get('c') or { -1 } == 3
}

fn test_clear_view_state_drops_registry() {
	mut w := Window{}
	mut m := state_map[string, int](mut w, 'test.clear', 10)
	m.set('k', 99)

	w.clear_view_state()

	mut m2 := state_map[string, int](mut w, 'test.clear', 10)
	assert m2.get('k') == none
	assert m2.len() == 0
}

fn test_state_map_read_returns_none_for_missing_namespace() {
	w := Window{}
	if _ := state_map_read[string, int](&w, 'test.read.none') {
		assert false
	}
}

fn test_state_map_type_tag_persisted() {
	mut w := Window{}
	_ = state_map[string, int](mut w, 'test.tagged', 10)

	m := w.view_state.registry.meta['test.tagged'] or {
		assert false, 'meta entry missing'
		return
	}
	assert m.type_tag == state_map_type_tag[string, int]()
}

fn test_state_map_max_size_persisted() {
	mut w := Window{}
	_ = state_map[string, int](mut w, 'test.cap', 42)

	m := w.view_state.registry.meta['test.cap'] or {
		assert false, 'meta entry missing'
		return
	}
	assert m.max_size == 42
}

fn test_registry_entry_count() {
	mut w := Window{}
	mut sm := state_map[string, int](mut w, 'test.count', 10)
	assert w.view_state.registry.entry_count('test.count') == 0

	sm.set('a', 1)
	sm.set('b', 2)
	assert w.view_state.registry.entry_count('test.count') == 2

	assert w.view_state.registry.entry_count('no.such.ns') == 0
}

fn test_state_map_type_check_detects_mismatch() {
	mut w := Window{}
	_ = state_map[string, int](mut w, 'test.mismatch', 10)

	state_map_type_check[string, int](&w.view_state.registry, 'test.mismatch') or {
		assert false, err.msg()
		return
	}
	state_map_type_check[string, bool](&w.view_state.registry, 'test.mismatch') or {
		assert err.msg().contains('state_map type mismatch')
		assert err.msg().contains('test.mismatch')
		return
	}
	assert false
}
