module gui

import vglyph

fn test_text_style_to_vglyph_cfg_mapping() {
	ts := TextStyle{
		family:        'Roboto'
		size:          16.0
		underline:     true
		strikethrough: true
	}

	cfg := ts.to_vglyph_cfg()

	assert cfg.style.font_name == 'Roboto'
	assert cfg.style.size == 16.0
	assert cfg.style.underline == true
	assert cfg.style.strikethrough == true
}

fn test_text_style_defaults() {
	ts := TextStyle{}
	cfg := ts.to_vglyph_cfg()

	assert cfg.style.underline == false
	assert cfg.style.strikethrough == false
	assert ts.rotation_radians == 0
	assert ts.affine_transform == none
	assert !ts.has_text_transform()
}

fn test_text_style_rotation_transform() {
	ts := TextStyle{
		rotation_radians: 0.5
	}

	assert ts.has_text_transform()
	transform := ts.effective_text_transform()
	expected := vglyph.affine_rotation(0.5)
	assert transform.xx == expected.xx
	assert transform.xy == expected.xy
	assert transform.yx == expected.yx
	assert transform.yy == expected.yy
}

fn test_text_style_affine_overrides_rotation() {
	affine := vglyph.AffineTransform{
		xx: 1.0
		xy: 0.2
		yx: 0.1
		yy: 1.0
		x0: 4.0
		y0: 7.0
	}
	ts := TextStyle{
		rotation_radians: 1.2
		affine_transform: affine
	}

	assert ts.has_text_transform()
	transform := ts.effective_text_transform()
	assert transform.xx == affine.xx
	assert transform.xy == affine.xy
	assert transform.yx == affine.yx
	assert transform.yy == affine.yy
	assert transform.x0 == affine.x0
	assert transform.y0 == affine.y0
}
