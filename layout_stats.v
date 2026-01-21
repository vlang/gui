module gui

import time

// LayoutStats captures layout performance metrics when debug_layout is enabled.
pub struct LayoutStats {
pub mut:
	total_time_us  i64 // total layout time in microseconds
	node_count     int // number of layout nodes
	floating_count int // number of floating layouts
}

// layout_stats_timer is a helper for measuring elapsed time.
struct LayoutStatsTimer {
	start time.Time
}

fn layout_stats_timer_start() LayoutStatsTimer {
	return LayoutStatsTimer{
		start: time.now()
	}
}

fn (t LayoutStatsTimer) elapsed_us() i64 {
	return time.since(t.start).microseconds()
}

// count_nodes recursively counts the number of layout nodes.
fn count_nodes(layout &Layout) int {
	mut count := 1
	for child in layout.children {
		count += count_nodes(child)
	}
	return count
}
