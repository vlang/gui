module gui

struct LayoutPool {
mut:
	available     []Layout
	in_use_map    map[u64]bool
	max_pool_size int = 15_000
	total_created u64
	total_reused  u64
}

fn get_layout() Layout {
	if layout_pool.available.len > 0 {
		layout := layout_pool.available.pop()
		layout_pool.total_reused++
		layout_pool.in_use_map[layout.shape.uid] = true
		return layout
	}

	layout := Layout{}
	layout_pool.total_created++
	layout_pool.in_use_map[layout.shape.uid] = true
	return layout
}

fn return_layout_tree(mut layout Layout) {
	// Return children first (depth-first)
	for mut child in layout.children {
		return_layout_tree(mut child)
	}

	// Return this layout to pool
	return_layout(mut layout)
}

fn return_layout(mut layout Layout) {
	uid := layout.shape.uid
	if uid !in layout_pool.in_use_map {
		return
	}
	// Clean up
	layout.cleanup()

	// Remove from in-use tracking
	layout_pool.in_use_map.delete(uid)

	// Return to pool if not full
	if layout_pool.available.len < layout_pool.max_pool_size {
		layout_pool.available << layout
	}
	// Otherwise let GC handle it
}

// layout_pool_stats returns available, in_use, total created, total reused
fn layout_pool_stats() (int, int, u64, u64) {
	return layout_pool.available.len, layout_pool.in_use_map.len, layout_pool.total_created, layout_pool.total_reused
}

// layout_pool_stats_str formats layout pool stats in a table format
fn layout_pool_stats_str() string {
	return 'Layout Pool Statistics\n======================\n' +
		'available ${num_with_commas(u64(layout_pool.available.len)):12}\n' +
		'in_use_map ${num_with_commas(u64(layout_pool.in_use_map.len)):11}\n' +
		'created ${num_with_commas(layout_pool.total_created):14}\n' +
		'reused ${num_with_commas(layout_pool.total_reused):15}'
}

// num_with_commas converts a u64  to a comma separated string
pub fn num_with_commas(num u64) string {
	if num < 1000 {
		return num.str()
	}
	return num_with_commas(num / 1000) + ',${(num % 1000):03u}'
}
