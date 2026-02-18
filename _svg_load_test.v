module gui

import os

fn test_check_svg_source_size_accepts_small_inline_svg() {
	check_svg_source_size('<svg></svg>') or { assert false, err.msg() }
}

fn test_check_svg_source_size_rejects_large_inline_svg() {
	inline := '<svg>' + 'a'.repeat(int(max_svg_source_bytes + 1)) + '</svg>'
	if _ := check_svg_source_size(inline) {
		assert false, 'expected size guard error'
	} else {
		assert err.msg().contains('too large')
	}
}

fn test_check_svg_source_size_rejects_large_svg_file() {
	path := os.join_path(os.temp_dir(), 'gui_svg_size_guard_${os.getpid()}.svg')
	defer {
		os.rm(path) or {}
	}
	os.write_file(path, 'a'.repeat(int(max_svg_source_bytes + 1))) or { assert false, err.msg() }
	if _ := check_svg_source_size(path) {
		assert false, 'expected file size guard error'
	} else {
		assert err.msg().contains('too large')
	}
}
