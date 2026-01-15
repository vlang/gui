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
}
