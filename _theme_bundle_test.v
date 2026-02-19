module gui

import os

fn test_to_hex_string() {
	assert rgb(255, 0, 0).to_hex_string() == '#FF0000'
	assert rgb(0, 255, 0).to_hex_string() == '#00FF00'
	assert rgb(0, 0, 255).to_hex_string() == '#0000FF'
	assert rgb(0, 0, 0).to_hex_string() == '#000000'
	assert rgb(255, 255, 255).to_hex_string() == '#FFFFFF'
	assert rgba(255, 0, 0, 128).to_hex_string() == '#FF000080'
	assert rgba(0, 0, 0, 0).to_hex_string() == '#00000000'
}

fn test_color_from_string_alpha() {
	c := color_from_string('#ff000080')
	assert c.r == 255
	assert c.g == 0
	assert c.b == 0
	assert c.a == 128

	c2 := color_from_string('#00ff00ff')
	assert c2.r == 0
	assert c2.g == 255
	assert c2.b == 0
	assert c2.a == 255
}

fn test_theme_parse_minimal() {
	t := theme_parse('{"name": "test"}') or {
		assert false, err.str()
		return
	}
	assert t.name == 'test'
	// Defaults match dark theme cfg
	d := ThemeCfg{
		name: 'default'
	}
	assert t.color_background.eq(d.color_background)
	assert t.color_panel.eq(d.color_panel)
	assert t.color_select.eq(d.color_select)
}

fn test_theme_parse_full() {
	content := '{
		"name": "custom",
		"colors": {
			"background": "#ff0000",
			"panel": "#00ff00",
			"interior": "#0000ff",
			"hover": "#111111",
			"focus": "#222222",
			"active": "#333333",
			"border": "#444444",
			"border_focus": "#555555",
			"select": "#666666"
		},
		"titlebar_dark": 1,
		"fill": 0,
		"fill_border": 0,
		"text": {
			"color": "#aaaaaa",
			"size": 18,
			"family": "monospace"
		},
		"padding": { "top": 8, "right": 8, "bottom": 8, "left": 8 },
		"padding_small": { "top": 3, "right": 3, "bottom": 3, "left": 3 },
		"padding_medium": { "top": 8, "right": 8, "bottom": 8, "left": 8 },
		"padding_large": { "top": 12, "right": 12, "bottom": 12, "left": 12 },
		"size_border": 2,
		"radius": 4,
		"radius_border": 6,
		"radius_small": 2,
		"radius_medium": 4,
		"radius_large": 6,
		"spacing": { "small": 3, "medium": 8, "large": 12, "text": 2 },
		"sizes": {
			"text_tiny": 8,
			"text_x_small": 10,
			"text_small": 12,
			"text_medium": 18,
			"text_large": 22,
			"text_x_large": 28
		},
		"scroll": {
			"multiplier": 15,
			"delta_line": 2,
			"delta_page": 8,
			"gap_edge": 4,
			"gap_end": 3
		},
		"widgets": {
			"switch_width": 40,
			"switch_height": 24,
			"radio": 18,
			"scrollbar": 8,
			"scrollbar_min_thumb": 25,
			"progress_bar": 12,
			"range_slider": 8,
			"range_slider_thumb": 18,
			"splitter_handle": 11,
			"submenu_min": 60,
			"submenu_max": 250
		}
	}'
	t := theme_parse(content) or {
		assert false, err.str()
		return
	}
	assert t.name == 'custom'
	assert t.color_background.eq(rgb(255, 0, 0))
	assert t.color_panel.eq(rgb(0, 255, 0))
	assert t.cfg.text_style.size == 18
	assert t.cfg.spacing_small == 3
	assert t.cfg.size_text_tiny == 8
	assert t.cfg.scroll_multiplier == 15
	assert t.cfg.size_switch_width == 40
	assert t.cfg.radius == 4
	assert t.cfg.padding.top == 8
	assert t.cfg.fill == false
	assert t.cfg.fill_border == false
	assert t.titlebar_dark == true
}

fn test_theme_parse_colors_only() {
	content := '{
		"name": "partial",
		"colors": {
			"background": "#aabbcc",
			"select": "#112233"
		}
	}'
	t := theme_parse(content) or {
		assert false, err.str()
		return
	}
	assert t.name == 'partial'
	assert t.color_background.eq(rgb(0xaa, 0xbb, 0xcc))
	assert t.color_select.eq(rgb(0x11, 0x22, 0x33))
	// Unset colors fall back to defaults
	d := ThemeCfg{
		name: 'default'
	}
	assert t.color_panel.eq(d.color_panel)
}

fn test_theme_parse_bad_json() {
	if _ := theme_parse('not json') {
		assert false, 'expected error for bad json'
	}
}

fn test_theme_to_json_roundtrip() {
	cfg := theme_dark_cfg
	json_str := theme_to_json(cfg)
	t := theme_parse(json_str) or {
		assert false, err.str()
		return
	}
	assert t.name == 'dark'
	assert t.color_background.eq(cfg.color_background)
	assert t.color_panel.eq(cfg.color_panel)
	assert t.color_interior.eq(cfg.color_interior)
	assert t.color_hover.eq(cfg.color_hover)
	assert t.color_focus.eq(cfg.color_focus)
	assert t.color_active.eq(cfg.color_active)
	assert t.color_border.eq(cfg.color_border)
	assert t.color_select.eq(cfg.color_select)
	assert t.cfg.text_style.size == cfg.text_style.size
	assert t.cfg.radius == cfg.radius
	assert t.cfg.spacing_small == cfg.spacing_small
	assert t.cfg.size_text_medium == cfg.size_text_medium
	assert t.cfg.scroll_multiplier == cfg.scroll_multiplier
	assert t.cfg.size_switch_width == cfg.size_switch_width
	assert t.cfg.padding.top == cfg.padding.top
}

fn test_theme_save_load() {
	dir := os.join_path(os.temp_dir(), 'gui_theme_test')
	os.mkdir_all(dir) or {}
	defer {
		os.rmdir_all(dir) or {}
	}
	path := os.join_path(dir, 'test.json')
	theme_save(path, theme_dark) or {
		assert false, err.str()
		return
	}
	t := theme_load(path) or {
		assert false, err.str()
		return
	}
	assert t.name == 'dark'
	assert t.color_background.eq(theme_dark.color_background)
	assert t.cfg.radius == theme_dark.cfg.radius
}

fn test_theme_registry() {
	// Built-in themes registered by init()
	t := theme_get('dark') or {
		assert false, err.str()
		return
	}
	assert t.name == 'dark'

	t2 := theme_get('light') or {
		assert false, err.str()
		return
	}
	assert t2.name == 'light'

	// Nonexistent
	if _ := theme_get('nonexistent') {
		assert false, 'expected error for nonexistent theme'
	}

	// Overwrite
	custom := theme_maker(ThemeCfg{
		name:             'dark'
		color_background: rgb(10, 20, 30)
	})
	theme_register(custom)
	t3 := theme_get('dark') or {
		assert false, err.str()
		return
	}
	assert t3.color_background.eq(rgb(10, 20, 30))

	// Restore original
	theme_register(theme_dark)
}

fn test_theme_load_dir() {
	dir := os.join_path(os.temp_dir(), 'gui_theme_dir_test')
	os.mkdir_all(dir) or {}
	defer {
		os.rmdir_all(dir) or {}
	}
	// Write two theme files
	theme_save(os.join_path(dir, 'a.json'), theme_dark) or {
		assert false, err.str()
		return
	}
	theme_save(os.join_path(dir, 'b.json'), theme_light) or {
		assert false, err.str()
		return
	}
	theme_load_dir(dir) or {
		assert false, err.str()
		return
	}
	a := theme_get('dark') or {
		assert false, err.str()
		return
	}
	assert a.name == 'dark'
	b := theme_get('light') or {
		assert false, err.str()
		return
	}
	assert b.name == 'light'
}
