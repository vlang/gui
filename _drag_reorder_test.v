module gui

struct DragKeyboardCapture {
mut:
	called bool
	moved  string
	before string
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
	handled := drag_reorder_keyboard_move(.down, .none, .vertical, 1, ['a', 'b', 'c'],
		fn [mut cap] (_ string, _ string, mut _ Window) {
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
	handled := drag_reorder_keyboard_move(.right, .alt, .horizontal, 1, ['a', 'b', 'c', 'd'],
		fn [mut cap] (m string, b string, mut _ Window) {
		cap.called = true
		cap.moved = m
		cap.before = b
	}, mut w)
	assert handled
	assert cap.called
	assert cap.moved == 'b'
	assert cap.before == 'd'

	mut boundary_cap := &DragKeyboardCapture{}
	handled_boundary := drag_reorder_keyboard_move(.left, .alt, .horizontal, 0, ['a', 'b', 'c'],
		fn [mut boundary_cap] (_ string, _ string, mut _ Window) {
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
	drag_reorder_start(drag_key_ok, 0, 'a', .vertical, ['a', 'b'], fn (_ string, _ string, mut _ Window) {},
		['a', 'b'], 0, 0, &item, &e, mut w)
	state_ok := drag_reorder_get(mut w, drag_key_ok)
	assert state_ok.started
	assert state_ok.layouts_valid

	drag_key_missing := 'drag_layout_missing'
	drag_reorder_start(drag_key_missing, 0, 'a', .vertical, ['a', 'b'], fn (_ string, _ string, mut _ Window) {},
		['a', 'missing'], 0, 0, &item, &e, mut w)
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
	mut cap := &DragKeyboardCapture{}
	drag_reorder_start(drag_key, 0, 'a', .vertical, ['a', 'b', 'c'], fn [mut cap] (m string, b string, mut _ Window) {
		cap.called = true
		cap.moved = m
		cap.before = b
	}, ['a', 'b', 'c'], 0, 0, &item, &e, mut w)

	// Simulate list mutation before mouse-up.
	drag_reorder_on_mouse_up(drag_key, ['a', 'c'], fn [mut cap] (_ string, _ string, mut _ Window) {
		cap.called = true
	}, mut w)
	assert !cap.called
	state := drag_reorder_get(mut w, drag_key)
	assert !state.started
	assert !state.active
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
