module gui

fn test_collect_focus_candidates_dedupes_first_seen() {
	s1 := &Shape{
		id_focus: 9
	}
	s2 := &Shape{
		id_focus: 9
	}
	root := Layout{
		shape:    &Shape{}
		children: [
			Layout{
				shape: s1
			},
			Layout{
				shape: s2
			},
		]
	}
	mut candidates := []FocusCandidate{}
	mut seen := map[u32]bool{}
	collect_focus_candidates(&root, mut candidates, mut seen)
	assert candidates.len == 1
	assert candidates[0].id == 9
}

fn test_focus_find_next_by_id_without_sort() {
	s1 := &Shape{
		id_focus: 30
	}
	s2 := &Shape{
		id_focus: 10
	}
	s3 := &Shape{
		id_focus: 40
	}
	candidates := [
		FocusCandidate{
			id:    30
			shape: s1
		},
		FocusCandidate{
			id:    10
			shape: s2
		},
		FocusCandidate{
			id:    40
			shape: s3
		},
	]
	next := focus_find_next(candidates, 20) or { panic('missing next focus') }
	assert next.id_focus == 30
	fallback := focus_find_next(candidates, 99) or { panic('missing fallback focus') }
	assert fallback.id_focus == 10
}

fn test_focus_find_previous_by_id_without_sort() {
	s1 := &Shape{
		id_focus: 30
	}
	s2 := &Shape{
		id_focus: 10
	}
	s3 := &Shape{
		id_focus: 40
	}
	candidates := [
		FocusCandidate{
			id:    30
			shape: s1
		},
		FocusCandidate{
			id:    10
			shape: s2
		},
		FocusCandidate{
			id:    40
			shape: s3
		},
	]
	prev := focus_find_previous(candidates, 35) or { panic('missing previous focus') }
	assert prev.id_focus == 30
	fallback := focus_find_previous(candidates, 1) or { panic('missing fallback focus') }
	assert fallback.id_focus == 40
}
