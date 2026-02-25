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

fn test_drag_reorder_calc_index_from_layouts_uses_live_geometry() {
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
	idx_a := drag_reorder_calc_index_from_layouts(6, .vertical, ['a', 'b', 'c'], &w) or {
		panic('expected live index for a')
	}
	assert idx_a == 1
	idx_b := drag_reorder_calc_index_from_layouts(26, .vertical, ['a', 'b', 'c'], &w) or {
		panic('expected live index for b')
	}
	assert idx_b == 2
	idx_c := drag_reorder_calc_index_from_layouts(90, .vertical, ['a', 'b', 'c'], &w) or {
		panic('expected live index for c')
	}
	assert idx_c == 3
}

fn test_drag_reorder_calc_index_from_layouts_missing_layout_returns_none() {
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
	if _ := drag_reorder_calc_index_from_layouts(1, .vertical, ['a', 'missing'], &w) {
		assert false
	}
}

fn test_drag_reorder_calc_index_from_layouts_past_end() {
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
					height: 10
				}
			},
		]
	}
	// mouse at y=50 is past 'a' (0..10) and 'b' (10..20)
	idx := drag_reorder_calc_index_from_layouts(50, .vertical, ['a', 'b'], &w) or {
		panic('expected index at end')
	}
	assert idx == 2
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
