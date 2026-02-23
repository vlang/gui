module gui

fn test_fuzzy_score_exact_match() {
	assert list_core_fuzzy_score('open', 'open') == 0
}

fn test_fuzzy_score_subsequence() {
	s := list_core_fuzzy_score('open file', 'of')
	assert s > 0
}

fn test_fuzzy_score_no_match() {
	assert list_core_fuzzy_score('open', 'z') == -1
}

fn test_fuzzy_score_empty_query() {
	assert list_core_fuzzy_score('anything', '') == 0
}

fn test_fuzzy_score_empty_candidate() {
	assert list_core_fuzzy_score('', 'q') == -1
}

fn test_fuzzy_score_case_insensitive() {
	// 'O' at 0, 'F' at 4 → gap 3.
	s1 := list_core_fuzzy_score('OpenFile', 'of')
	s2 := list_core_fuzzy_score('openfile', 'OF')
	assert s1 >= 0
	assert s1 == s2
}

fn test_filter_empty_query() {
	items := [
		ListCoreItem{
			id:    'a'
			label: 'alpha'
		},
		ListCoreItem{
			id:            'h'
			label:         'heading'
			is_subheading: true
		},
		ListCoreItem{
			id:    'b'
			label: 'beta'
		},
	]
	result := list_core_filter(items, '')
	assert result.len == 3
	assert result == [0, 1, 2]
}

fn test_filter_ranks_by_score() {
	items := [
		ListCoreItem{
			id:    'a'
			label: 'x_o_p_e_n'
		},
		ListCoreItem{
			id:    'b'
			label: 'open'
		},
	]
	result := list_core_filter(items, 'open')
	assert result.len == 2
	// Exact match (score 0) should come first.
	assert result[0] == 1
	assert result[1] == 0
}

fn test_filter_skips_subheadings() {
	items := [
		ListCoreItem{
			id:            'h'
			label:         'open group'
			is_subheading: true
		},
		ListCoreItem{
			id:    'a'
			label: 'open file'
		},
	]
	result := list_core_filter(items, 'open')
	assert result.len == 1
	assert result[0] == 1
}

fn test_visible_range_empty() {
	first, last := list_core_visible_range(0, 20, 100, 0)
	assert first == 0
	assert last == -1
}

fn test_visible_range_basic() {
	first, last := list_core_visible_range(50, 20, 100, 0)
	assert first == 0
	assert last > 0
	assert last < 50
}

fn test_visible_range_scroll() {
	first_a, _ := list_core_visible_range(50, 20, 100, 0)
	first_b, _ := list_core_visible_range(50, 20, 100, -200)
	assert first_b > first_a
}

fn test_visible_range_clamp() {
	_, last := list_core_visible_range(10, 20, 100, -9999)
	assert last <= 9
}

fn test_navigate_keys() {
	assert list_core_navigate(.up, 5, 2) == .move_up
	assert list_core_navigate(.down, 5, 2) == .move_down
	assert list_core_navigate(.enter, 5, 2) == .select_item
	assert list_core_navigate(.escape, 5, 2) == .dismiss
	assert list_core_navigate(.home, 5, 2) == .first
	assert list_core_navigate(.end, 5, 2) == .last
}

fn test_navigate_empty() {
	assert list_core_navigate(.up, 0, 0) == .none
	assert list_core_navigate(.down, 0, 0) == .none
}

fn test_row_height_estimate() {
	style := TextStyle{
		size: 14
	}
	pad := Padding{
		top:    2
		bottom: 3
	}
	assert list_core_row_height_estimate(style, pad) == 19
}

fn test_to_lower_byte() {
	assert to_lower_byte(u8(0x41)) == u8(0x61) // A -> a
	assert to_lower_byte(u8(0x5A)) == u8(0x7A) // Z -> z
	assert to_lower_byte(u8(0x61)) == u8(0x61) // a -> a
	assert to_lower_byte(u8(0x30)) == u8(0x30) // 0 unchanged
}

fn test_apply_nav_move_up() {
	next, changed := list_core_apply_nav(.move_up, 3, 10)
	assert next == 2
	assert changed == true
}

fn test_apply_nav_move_up_at_top() {
	next, changed := list_core_apply_nav(.move_up, 0, 10)
	assert next == 0
	assert changed == false
}

fn test_apply_nav_move_down() {
	next, changed := list_core_apply_nav(.move_down, 3, 10)
	assert next == 4
	assert changed == true
}

fn test_apply_nav_move_down_at_bottom() {
	next, changed := list_core_apply_nav(.move_down, 9, 10)
	assert next == 9
	assert changed == false
}

fn test_apply_nav_first() {
	next, changed := list_core_apply_nav(.first, 5, 10)
	assert next == 0
	assert changed == true
}

fn test_apply_nav_last() {
	next, changed := list_core_apply_nav(.last, 0, 10)
	assert next == 9
	assert changed == true
}

fn test_apply_nav_none() {
	next, changed := list_core_apply_nav(.none, 5, 10)
	assert next == 5
	assert changed == false
}

fn test_prepare_filters_and_clamps() {
	items := [
		ListCoreItem{
			id:    'a'
			label: 'alpha'
		},
		ListCoreItem{
			id:    'b'
			label: 'beta'
		},
		ListCoreItem{
			id:    'c'
			label: 'gamma'
		},
	]
	p := list_core_prepare(items, 'al', 99)
	assert p.items.len == 1
	assert p.items[0].id == 'a'
	assert p.ids == ['a']
	assert p.hl == 0 // clamped from 99
}

fn test_prepare_empty_query_returns_all() {
	items := [
		ListCoreItem{
			id:    'a'
			label: 'alpha'
		},
		ListCoreItem{
			id:    'b'
			label: 'beta'
		},
	]
	p := list_core_prepare(items, '', 1)
	assert p.items.len == 2
	assert p.hl == 1
}

fn test_prepare_excludes_subheadings_from_ids() {
	items := [
		ListCoreItem{
			id:            'h'
			label:         'heading'
			is_subheading: true
		},
		ListCoreItem{
			id:    'a'
			label: 'alpha'
		},
	]
	p := list_core_prepare(items, '', 0)
	// Items includes subheading for rendering.
	assert p.items.len == 2
	// IDs excludes subheading.
	assert p.ids.len == 1
	assert p.ids[0] == 'a'
}
