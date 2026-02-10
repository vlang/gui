module gui

fn noop_splitter_change(_ f32, _ SplitterCollapsed, mut _e Event, mut _w Window) {}

fn test_splitter_state_normalize() {
	state := splitter_state_normalize(SplitterState{
		ratio:     1.5
		collapsed: .first
	})
	assert state.ratio == 1
	assert state.collapsed == .first
}

fn test_splitter_effective_collapsed() {
	cfg := SplitterCfg{
		id:        'splitter-collapse'
		on_change: noop_splitter_change
		first:     SplitterPaneCfg{
			collapsible: false
		}
		second:    SplitterPaneCfg{
			collapsible: true
		}
	}
	assert splitter_effective_collapsed(&cfg, .first) == .none
	assert splitter_effective_collapsed(&cfg, .second) == .second
	assert splitter_effective_collapsed(&cfg, .none) == .none
}

fn test_splitter_toggle_target() {
	cfg := SplitterCfg{
		id:        'splitter-toggle'
		on_change: noop_splitter_change
		first:     SplitterPaneCfg{
			collapsible: false
		}
		second:    SplitterPaneCfg{
			collapsible: true
		}
	}
	assert splitter_toggle_target(&cfg, .none) == .second
}

fn test_splitter_toggle_target_prefers_current_collapsed() {
	cfg := SplitterCfg{
		id:        'splitter-toggle-current'
		on_change: noop_splitter_change
		first:     SplitterPaneCfg{
			collapsible: true
		}
		second:    SplitterPaneCfg{
			collapsible: true
		}
	}
	assert splitter_toggle_target(&cfg, .second) == .second
	assert splitter_toggle_target(&cfg, .first) == .first
	assert splitter_toggle_target(&cfg, .none) == .first
}

fn test_splitter_clamp_ratio_respects_constraints() {
	cfg := SplitterCfg{
		id:        'splitter-clamp'
		on_change: noop_splitter_change
		first:     SplitterPaneCfg{
			min_size: 100
		}
		second:    SplitterPaneCfg{
			min_size: 200
		}
	}
	available := f32(600)
	min_ratio := splitter_clamp_ratio(&cfg, available, 0.0)
	max_ratio := splitter_clamp_ratio(&cfg, available, 1.0)
	assert f32_are_close(min_ratio, 100 / 600.0)
	assert f32_are_close(max_ratio, 400 / 600.0)
}

fn test_splitter_compute_collapsed_first() {
	cfg := SplitterCfg{
		id:        'splitter-compute'
		on_change: noop_splitter_change
		collapsed: .first
		first:     SplitterPaneCfg{
			collapsible:    true
			collapsed_size: 20
			min_size:       10
		}
		second:    SplitterPaneCfg{
			min_size: 100
		}
	}
	computed := splitter_compute(&cfg, 300)
	assert computed.collapsed == .first
	assert computed.handle_main == cfg.handle_size
	assert computed.first_main >= 10
	assert computed.second_main >= 100
}

fn test_splitter_collapsed_second_rebalances_after_max_clamp() {
	cfg := SplitterCfg{
		id:        'splitter-collapsed-second'
		on_change: noop_splitter_change
		first:     SplitterPaneCfg{
			max_size: 300
		}
		second:    SplitterPaneCfg{
			max_size:       100
			collapsible:    true
			collapsed_size: 0
		}
	}
	first, second := splitter_collapsed_second(&cfg, 500)
	assert f32_are_close(second, 100)
	assert f32_are_close(first + second, 500)
}

fn test_splitter_builds_view() {
	_ := splitter(
		id:        'splitter-build'
		on_change: noop_splitter_change
		first:     SplitterPaneCfg{
			content: [text(text: 'A')]
		}
		second:    SplitterPaneCfg{
			content: [text(text: 'B')]
		}
	)
}
