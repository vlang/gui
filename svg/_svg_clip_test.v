module svg

fn test_parse_clip_path_url() {
	// Element with clip-path attribute
	elem := '<rect width="100" fill="blue" clip-path="url(#myClip)"/>'
	id := parse_clip_path_url(elem) or { '' }
	assert id == 'myClip', 'expected "myClip", got "${id}"'

	// Element without clip-path
	elem2 := '<rect width="100" fill="blue"/>'
	id2 := parse_clip_path_url(elem2) or { '' }
	assert id2 == '', 'expected empty, got "${id2}"'
}

fn test_parse_defs_clip_paths() {
	src := '<svg viewBox="0 0 100 100"><defs><clipPath id="c1"><circle cx="50" cy="50" r="40"/></clipPath></defs></svg>'
	clip_paths := parse_defs_clip_paths(src)
	assert clip_paths.len == 1, 'expected 1 clip path, got ${clip_paths.len}'
	assert 'c1' in clip_paths, 'expected key "c1"'
	paths := clip_paths['c1']
	assert paths.len > 0, 'expected parsed paths for c1'
}

fn test_svg_clip_path_on_path() {
	src := '<svg viewBox="0 0 100 100"><defs><clipPath id="cp"><rect width="50" height="50"/></clipPath></defs><rect width="100" height="100" fill="red" clip-path="url(#cp)"/></svg>'
	vg := parse_svg(src) or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert vg.clip_paths.len == 1, 'clip_paths: ${vg.clip_paths.len}'
	assert vg.paths.len == 1, 'paths: ${vg.paths.len}'
	assert vg.paths[0].clip_path_id == 'cp', 'clip_path_id: "${vg.paths[0].clip_path_id}"'
}

fn test_svg_clip_group_tessellation() {
	src := '<svg viewBox="0 0 100 100"><defs><clipPath id="cp"><rect width="50" height="50"/></clipPath></defs><rect width="100" height="100" fill="red" clip-path="url(#cp)"/></svg>'
	vg := parse_svg(src) or {
		assert false, 'parse failed: ${err}'
		return
	}
	tris := vg.get_triangles(1.0)
	mut has_mask := false
	mut has_content := false
	mut max_group := 0
	for t in tris {
		if t.clip_group > max_group {
			max_group = t.clip_group
		}
		if t.is_clip_mask {
			has_mask = true
		}
		if t.clip_group > 0 && !t.is_clip_mask {
			has_content = true
		}
	}
	assert has_mask, 'no clip mask tessellated'
	assert has_content, 'no clipped content tessellated'
	assert max_group > 0, 'clip_group never set'
}
