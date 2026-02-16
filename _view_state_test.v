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
