module gui

const drag_reorder_lifetime_payload_len = 64

struct DragKeyboardCapture {
mut:
	called bool
	moved  string
	before string
	value  int
}

fn drag_reorder_lifetime_item_layout(id string, y f32) Layout {
	return Layout{
		shape: &Shape{
			id:     id
			x:      0
			y:      y
			width:  100
			height: 10
		}
	}
}

fn drag_reorder_lifetime_layout(drag_key string, seed int) Layout {
	payload := []int{len: drag_reorder_lifetime_payload_len, init: seed + index}
	return Layout{
		shape:    &Shape{
			id: 'root'
		}
		children: [
			Layout{
				shape: &Shape{
					id:     drag_reorder_drop_handler_id(drag_key)
					events: &EventHandlers{
						on_scroll: fn [drag_key, payload] (_ &Layout, mut w Window) {
							drop := drag_reorder_drop_take(mut w, drag_key) or { return }
							mut cap := unsafe { &DragKeyboardCapture(w.state) }
							cap.called = true
							cap.moved = drop.moved_id
							cap.before = drop.before_id
							cap.value = payload[0] + payload[payload.len - 1]
						}
					}
				}
			},
			drag_reorder_lifetime_item_layout('a', 0),
			drag_reorder_lifetime_item_layout('b', 10),
			drag_reorder_lifetime_item_layout('c', 20),
		]
	}
}

fn drag_reorder_rebuild_lifetime_layout(mut w Window, drag_key string, seed int) {
	w.layout_callback_lifetime.lifetime.frame(fn [mut w, drag_key, seed] () {
		layout_clear(mut w.layout)
		w.layout = drag_reorder_lifetime_layout(drag_key, seed)
	}) or { panic(err) }
	w.reclaim_old_layout_callbacks()
}

fn drag_reorder_collect_and_churn_test() {
	gc_collect()
	for _ in 0 .. 1024 {
		unsafe {
			p := malloc(32)
			vmemset(p, 0x55, 32)
		}
	}
	gc_collect()
}

fn test_reorder_indices_cases() {
	ids := ['a', 'b', 'c', 'd']
	from_a, to_a := reorder_indices(ids, 'c', 'b')
	assert from_a == 2
	assert to_a == 1

	from_b, to_b := reorder_indices(ids, 'b', 'd')
	assert from_b == 1
	assert to_b == 2

	from_c, to_c := reorder_indices(ids, 'b', '')
	assert from_c == 1
	assert to_c == 3

	from_d, to_d := reorder_indices(ids, 'b', 'c')
	assert from_d == -1
	assert to_d == -1

	from_e, to_e := reorder_indices(ids, 'z', 'a')
	assert from_e == -1
	assert to_e == -1

	from_f, to_f := reorder_indices(ids, 'b', 'missing')
	assert from_f == -1
	assert to_f == -1
}

fn test_drag_reorder_keyboard_move_requires_alt() {
	mut w := Window{}
	w.layout = Layout{
		shape: &Shape{
			id: 'root'
		}
	}
	mut cap := &DragKeyboardCapture{}
	handled := drag_reorder_keyboard_move(.down, .none, .vertical, 1, ['a', 'b', 'c'], fn [mut cap] (_ string, _ string, mut _ Window) {
		cap.called = true
	}, mut w)
	assert !handled
	assert !cap.called
}

fn test_drag_reorder_keyboard_move_payload_and_boundary() {
	mut w := Window{}
	w.layout = Layout{
		shape: &Shape{
			id: 'root'
		}
	}
	mut cap := &DragKeyboardCapture{}
	handled := drag_reorder_keyboard_move(.right, .alt, .horizontal, 1, ['a', 'b', 'c', 'd'], fn [mut cap] (m string, b string, mut _ Window) {
		cap.called = true
		cap.moved = m
		cap.before = b
	}, mut w)
	assert handled
	assert cap.called
	assert cap.moved == 'b'
	assert cap.before == 'd'

	mut boundary_cap := &DragKeyboardCapture{}
	handled_boundary := drag_reorder_keyboard_move(.left, .alt, .horizontal, 0, ['a', 'b', 'c'], fn [mut boundary_cap] (_ string, _ string, mut _ Window) {
		boundary_cap.called = true
	}, mut w)
	assert !handled_boundary
	assert !boundary_cap.called
}

fn test_drag_reorder_calc_index_from_mids() {
	mids := [f32(5), 25, 45]
	idx_a := drag_reorder_calc_index_from_mids(6, mids) or {
		panic('expected index for first midpoint set')
	}
	assert idx_a == 1
	idx_b := drag_reorder_calc_index_from_mids(26, mids) or {
		panic('expected index for second midpoint set')
	}
	assert idx_b == 2
	idx_c := drag_reorder_calc_index_from_mids(90, mids) or {
		panic('expected index at end for midpoint set')
	}
	assert idx_c == 3
}

fn test_drag_reorder_item_mids_from_layouts() {
	mut w := Window{}
	w.layout = Layout{
		shape:    &Shape{
			id: 'root'
		}
		children: [
			Layout{
				shape: &Shape{
					id:     'a'
					x:      0
					y:      0
					width:  100
					height: 10
				}
			},
			Layout{
				shape: &Shape{
					id:     'b'
					x:      0
					y:      10
					width:  100
					height: 30
				}
			},
			Layout{
				shape: &Shape{
					id:     'c'
					x:      0
					y:      40
					width:  100
					height: 10
				}
			},
		]
	}
	mids := drag_reorder_item_mids_from_layouts(.vertical, ['a', 'b', 'c'], &w) or {
		panic('expected item mids from layout ids')
	}
	assert mids.len == 3
	assert mids[0] == f32(5)
	assert mids[1] == f32(25)
	assert mids[2] == f32(45)
}

fn test_drag_reorder_item_mids_from_layouts_missing_layout_returns_none() {
	mut w := Window{}
	w.layout = Layout{
		shape:    &Shape{
			id: 'root'
		}
		children: [
			Layout{
				shape: &Shape{
					id:     'a'
					width:  10
					height: 10
				}
			},
		]
	}
	if _ := drag_reorder_item_mids_from_layouts(.vertical, ['a', 'missing'], &w) {
		assert false
	}
}

fn test_drag_reorder_escape_cancels_started_drag() {
	mut w := Window{}
	w.layout = Layout{
		shape: &Shape{
			id: 'root'
		}
	}
	drag_key := 'drag_escape'
	drag_reorder_set(mut w, drag_key, DragReorderState{
		started: true
	})
	handled := drag_reorder_escape(drag_key, .escape, mut w)
	assert handled
	state := drag_reorder_get(mut w, drag_key)
	assert !state.started
}

fn test_drag_reorder_start_sets_layout_validity() {
	mut w := Window{}
	w.layout = Layout{
		shape:    &Shape{
			id: 'root'
		}
		children: [
			Layout{
				shape: &Shape{
					id:     'a'
					x:      0
					y:      0
					width:  10
					height: 10
				}
			},
			Layout{
				shape: &Shape{
					id:     'b'
					x:      0
					y:      10
					width:  10
					height: 10
				}
			},
		]
	}
	mut parent := Layout{
		shape: &Shape{
			id:     'parent'
			x:      0
			y:      0
			width:  100
			height: 100
		}
	}
	mut item := Layout{
		shape:  &Shape{
			id:     'a'
			x:      0
			y:      0
			width:  10
			height: 10
		}
		parent: &parent
	}
	mut e := Event{
		mouse_x: 1
		mouse_y: 1
	}

	drag_key_ok := 'drag_layout_ok'
	drag_reorder_start(drag_key_ok, 0, 'a', .vertical, ['a', 'b'], ['a', 'b'], 0, 0, '', &item, &e, mut
		w)
	state_ok := drag_reorder_get(mut w, drag_key_ok)
	assert state_ok.started
	assert state_ok.layouts_valid

	drag_key_missing := 'drag_layout_missing'
	drag_reorder_start(drag_key_missing, 0, 'a', .vertical, ['a', 'b'], ['a', 'missing'], 0, 0, '',
		&item, &e, mut w)
	state_missing := drag_reorder_get(mut w, drag_key_missing)
	assert state_missing.started
	assert !state_missing.layouts_valid
}

fn test_drag_reorder_calc_index_with_scroll_delta() {
	mut w := Window{}
	w.layout = Layout{
		shape: &Shape{
			id: 'root'
		}
	}
	drag_key := 'drag_scroll'
	id_scroll := u32(100)

	// Start scroll at -10
	mut sy := state_map[u32, f32](mut w, ns_scroll_y, cap_scroll)
	sy.set(id_scroll, -10.0)

	state := DragReorderState{
		active:         true
		item_y:         100.0
		item_height:    20.0
		source_index:   0
		item_count:     5
		id_scroll:      id_scroll
		start_scroll_y: -10.0
	}
	drag_reorder_set(mut w, drag_key, state)

	// Container scrolls down to -20 (delta = -10, items move UP 10px)
	sy.set(id_scroll, -20.0)

	// Cursor is at 115. Relative to original list, it should be at 125.
	// item 0: 100..120 (original)
	// item 1: 120..140 (original)
	// Midpoint 0: 110. Midpoint 1: 130.
	// Adjusted mouse_main should be 125, which is > Midpoint 0 and < Midpoint 1, so index 1.
	drag_reorder_on_mouse_move(drag_key, .vertical, 0, 115, mut w)

	new_state := drag_reorder_get(mut w, drag_key)
	assert new_state.current_index == 1
}

fn test_drag_reorder_auto_scroll_timer_activation() {
	mut w := Window{}
	w.layout = Layout{
		shape: &Shape{
			id: 'root'
		}
	}
	drag_key := 'drag_timer'
	id_scroll := u32(100)

	state := DragReorderState{
		active:          true
		item_y:          0.0
		item_height:     20.0
		source_index:    0
		item_count:      5
		id_scroll:       id_scroll
		container_start: 0.0
		container_end:   100.0
	}
	drag_reorder_set(mut w, drag_key, state)

	// Mouse is near start (scroll_zone is 40.0)
	// mouse_main - container_start = 5 - 0 = 5 < 40.0
	drag_reorder_on_mouse_move(drag_key, .vertical, 0, 5, mut w)

	new_state := drag_reorder_get(mut w, drag_key)
	assert new_state.scroll_timer_active
	assert w.has_animation(drag_reorder_scroll_animation_id)

	// Mouse moves away from scroll zone
	drag_reorder_on_mouse_move(drag_key, .vertical, 0, 50, mut w)
	state_after := drag_reorder_get(mut w, drag_key)
	assert !state_after.scroll_timer_active
	assert !w.has_animation(drag_reorder_scroll_animation_id)
}

fn test_drag_reorder_cancels_on_mid_drag_mutation() {
	mut w := Window{}
	w.layout = Layout{
		shape: &Shape{
			id: 'root'
		}
	}
	mut parent := Layout{
		shape: &Shape{
			id:     'parent'
			x:      0
			y:      0
			width:  100
			height: 100
		}
	}
	mut item := Layout{
		shape:  &Shape{
			id:     'a'
			x:      0
			y:      0
			width:  10
			height: 10
		}
		parent: &parent
	}
	mut e := Event{
		mouse_x: 1
		mouse_y: 1
	}

	drag_key := 'drag_mutation'
	drag_reorder_start(drag_key, 0, 'a', .vertical, ['a', 'b', 'c'], ['a', 'b', 'c'], 0, 0, '',
		&item, &e, mut w)
	drag_reorder_ids_meta_set(mut w, drag_key, ['a', 'b', 'c'])

	// Simulate list mutation before mouse-up.
	drag_reorder_ids_meta_set(mut w, drag_key, ['a', 'c'])
	drag_reorder_on_mouse_up(drag_key, ['a', 'c'], mut w)
	state := drag_reorder_get(mut w, drag_key)
	assert !state.started
	assert !state.active
}

fn test_drag_reorder_mouse_up_uses_current_callback_after_reclaim() {
	mut cap := &DragKeyboardCapture{}
	mut w := Window{
		state:                    cap
		layout_callback_lifetime: new_layout_callback_lifetime()
	}
	drag_key := 'drag_lifetime_drop'
	drag_reorder_rebuild_lifetime_layout(mut w, drag_key, 11)

	mut parent := Layout{
		shape: &Shape{
			id:     'parent'
			x:      0
			y:      0
			width:  100
			height: 100
		}
	}
	mut item := Layout{
		shape:  &Shape{
			id:     'a'
			x:      0
			y:      0
			width:  10
			height: 10
		}
		parent: &parent
	}
	mut e := Event{
		mouse_x: 1
		mouse_y: 1
	}

	drag_reorder_start(drag_key, 0, 'a', .vertical, ['a', 'b', 'c'], ['a', 'b', 'c'], 0, 0, '',
		&item, &e, mut w)
	mut state := drag_reorder_get(mut w, drag_key)
	state.active = true
	state.current_index = 2
	drag_reorder_set(mut w, drag_key, state)

	drag_reorder_rebuild_lifetime_layout(mut w, drag_key, 29)
	drag_reorder_rebuild_lifetime_layout(mut w, drag_key, 29)
	drag_reorder_collect_and_churn_test()

	mouse_up := w.view_state.mouse_lock.mouse_up or {
		assert false, 'expected mouse lock up callback'
		return
	}

	mut up := Event{}
	mouse_up(&w.layout, mut up, mut w)

	assert cap.called
	assert cap.moved == 'a'
	assert cap.before == 'c'
	assert cap.value == 29 + 29 + drag_reorder_lifetime_payload_len - 1

	layout_clear(mut w.layout)
	w.dispose_layout_callbacks()
}

fn test_drag_reorder_dispatch_snapshots_before_user_drop_handler() {
	drag_key := 'drag_snapshot_order'
	mut w := Window{}
	w.layout = Layout{
		shape:    &Shape{
			id: 'root'
		}
		children: [
			Layout{
				shape: &Shape{
					id:     drag_reorder_drop_handler_id(drag_key)
					events: &EventHandlers{
						on_scroll: fn [drag_key] (_ &Layout, mut w Window) {
							_ := drag_reorder_drop_take(mut w, drag_key) or { return }
							w.layout.children[1].shape.x = 99
						}
					}
				}
			},
			drag_reorder_lifetime_item_layout('a', 1),
		]
	}
	drag_reorder_drop_set(mut w, drag_key, DragReorderDrop{
		moved_id:  'a'
		before_id: ''
	})

	assert drag_reorder_dispatch_drop(drag_key, mut w)
	transition := w.get_layout_transition() or {
		assert false, 'expected layout transition'
		return
	}
	snapshot := transition.snapshots['a'] or {
		assert false, 'expected snapshot for item a'
		return
	}
	assert snapshot.x == 0
	assert w.layout.children[1].shape.x == 99
}

fn test_drag_reorder_cancels_on_mid_drag_move_mutation() {
	mut w := Window{}
	w.layout = Layout{
		shape: &Shape{
			id: 'root'
		}
	}
	drag_key := 'drag_move_mutation'

	state := DragReorderState{
		active:        true
		source_index:  0
		current_index: 0
		item_count:    3
		ids_len:       3
		ids_hash:      drag_reorder_ids_signature(['a', 'b', 'c'])
	}
	drag_reorder_set(mut w, drag_key, state)
	drag_reorder_ids_meta_set(mut w, drag_key, ['a', 'b', 'c'])

	// Mutate IDs before move.
	drag_reorder_ids_meta_set(mut w, drag_key, ['a', 'c'])
	drag_reorder_on_mouse_move(drag_key, .vertical, 0, 0, mut w)

	new_state := drag_reorder_get(mut w, drag_key)
	assert !new_state.started
	assert !new_state.active
	assert new_state.item_count == 0
}

fn test_drag_reorder_scroll_change_uses_uniform_estimate() {
	mut w := Window{}
	w.layout = Layout{
		shape: &Shape{
			id: 'root'
		}
	}
	drag_key := 'drag_scroll_uniform'
	id_scroll := u32(200)

	mut sy := state_map[u32, f32](mut w, ns_scroll_y, cap_scroll)
	sy.set(id_scroll, 10.0)

	state := DragReorderState{
		active:         true
		item_y:         0.0
		item_height:    10.0
		source_index:   0
		item_count:     5
		id_scroll:      id_scroll
		start_scroll_y: 0.0
		item_mids:      [f32(25), 35]
		mids_offset:    2
		layouts_valid:  true
	}
	drag_reorder_set(mut w, drag_key, state)

	// With scroll change, mids would yield index 2; uniform should yield 0.
	drag_reorder_on_mouse_move(drag_key, .vertical, 0, 15, mut w)

	new_state := drag_reorder_get(mut w, drag_key)
	assert new_state.current_index == 0
}
