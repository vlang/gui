module gui

import json
import os
import strings

// JSON-friendly intermediate structs for theme bundle decoding.
// Optional fields let JSON omit keys; missing values fall back
// to ThemeCfg{} defaults.

struct TextBundle {
	color  string
	size   f32 = -1
	family string
}

struct PaddingBundle {
	top    f32
	right  f32
	bottom f32
	left   f32
}

struct SizesBundle {
	text_tiny    f32 = -1
	text_x_small f32 = -1
	text_small   f32 = -1
	text_medium  f32 = -1
	text_large   f32 = -1
	text_x_large f32 = -1
}

struct SpacingBundle {
	small  f32 = -1
	medium f32 = -1
	large  f32 = -1
	text   f32 = -1
}

struct ScrollBundle {
	multiplier f32 = -1
	delta_line f32 = -1
	delta_page f32 = -1
	gap_edge   f32 = -1
	gap_end    f32 = -1
}

struct WidgetsBundle {
	switch_width        f32 = -1
	switch_height       f32 = -1
	radio               f32 = -1
	scrollbar           f32 = -1
	scrollbar_min_thumb f32 = -1
	progress_bar        f32 = -1
	range_slider        f32 = -1
	range_slider_thumb  f32 = -1
	splitter_handle     f32 = -1
	submenu_min         f32 = -1
	submenu_max         f32 = -1
}

struct ThemeBundle {
	name           string
	colors         map[string]string
	titlebar_dark  int = -1
	fill           int = -1
	fill_border    int = -1
	text           ?TextBundle
	padding        ?PaddingBundle
	padding_small  ?PaddingBundle
	padding_medium ?PaddingBundle
	padding_large  ?PaddingBundle
	size_border    f32 = -1
	radius         f32 = -1
	radius_border  f32 = -1
	radius_small   f32 = -1
	radius_medium  f32 = -1
	radius_large   f32 = -1
	spacing        ?SpacingBundle
	sizes          ?SizesBundle
	scroll         ?ScrollBundle
	widgets        ?WidgetsBundle
}

// theme_parse decodes a JSON string into a Theme.
// Missing keys fall back to ThemeCfg{} defaults (dark theme).
pub fn theme_parse(content string) !Theme {
	bundle := json.decode(ThemeBundle, content) or { return error('invalid JSON: ${err}') }
	cfg := bundle.to_theme_cfg()
	return theme_maker(cfg)
}

// theme_load reads a JSON theme file and returns a Theme.
pub fn theme_load(path string) !Theme {
	content := os.read_file(path) or { return error('cannot read file: ${path}') }
	return theme_parse(content)
}

// theme_to_json serializes a ThemeCfg to formatted JSON.
pub fn theme_to_json(cfg ThemeCfg) string {
	mut sb := strings.new_builder(1024)
	sb.writeln('{')
	sb.writeln('  "name": "${cfg.name}",')
	// Colors
	sb.writeln('  "colors": {')
	sb.writeln('    "background": "${cfg.color_background.to_hex_string()}",')
	sb.writeln('    "panel": "${cfg.color_panel.to_hex_string()}",')
	sb.writeln('    "interior": "${cfg.color_interior.to_hex_string()}",')
	sb.writeln('    "hover": "${cfg.color_hover.to_hex_string()}",')
	sb.writeln('    "focus": "${cfg.color_focus.to_hex_string()}",')
	sb.writeln('    "active": "${cfg.color_active.to_hex_string()}",')
	sb.writeln('    "border": "${cfg.color_border.to_hex_string()}",')
	sb.writeln('    "border_focus": "${cfg.color_border_focus.to_hex_string()}",')
	sb.writeln('    "select": "${cfg.color_select.to_hex_string()}"')
	sb.writeln('  },')
	// Titlebar/fill
	sb.writeln('  "titlebar_dark": ${if cfg.titlebar_dark { 1 } else { 0 }},')
	sb.writeln('  "fill": ${if cfg.fill { 1 } else { 0 }},')
	sb.writeln('  "fill_border": ${if cfg.fill_border { 1 } else { 0 }},')
	// Text
	sb.writeln('  "text": {')
	sb.writeln('    "color": "${cfg.text_style.color.to_hex_string()}",')
	sb.writeln('    "size": ${cfg.text_style.size},')
	sb.writeln('    "family": "${cfg.text_style.family}"')
	sb.writeln('  },')
	// Padding
	write_padding(mut sb, 'padding', cfg.padding)
	sb.write_string(',\n')
	write_padding(mut sb, 'padding_small', cfg.padding_small)
	sb.write_string(',\n')
	write_padding(mut sb, 'padding_medium', cfg.padding_medium)
	sb.write_string(',\n')
	write_padding(mut sb, 'padding_large', cfg.padding_large)
	sb.write_string(',\n')
	// Border/radius
	sb.writeln('  "size_border": ${cfg.size_border},')
	sb.writeln('  "radius": ${cfg.radius},')
	sb.writeln('  "radius_border": ${cfg.radius_border},')
	sb.writeln('  "radius_small": ${cfg.radius_small},')
	sb.writeln('  "radius_medium": ${cfg.radius_medium},')
	sb.writeln('  "radius_large": ${cfg.radius_large},')
	// Spacing
	sb.writeln('  "spacing": {')
	sb.writeln('    "small": ${cfg.spacing_small},')
	sb.writeln('    "medium": ${cfg.spacing_medium},')
	sb.writeln('    "large": ${cfg.spacing_large},')
	sb.writeln('    "text": ${cfg.spacing_text}')
	sb.writeln('  },')
	// Sizes
	sb.writeln('  "sizes": {')
	sb.writeln('    "text_tiny": ${cfg.size_text_tiny},')
	sb.writeln('    "text_x_small": ${cfg.size_text_x_small},')
	sb.writeln('    "text_small": ${cfg.size_text_small},')
	sb.writeln('    "text_medium": ${cfg.size_text_medium},')
	sb.writeln('    "text_large": ${cfg.size_text_large},')
	sb.writeln('    "text_x_large": ${cfg.size_text_x_large}')
	sb.writeln('  },')
	// Scroll
	sb.writeln('  "scroll": {')
	sb.writeln('    "multiplier": ${cfg.scroll_multiplier},')
	sb.writeln('    "delta_line": ${cfg.scroll_delta_line},')
	sb.writeln('    "delta_page": ${cfg.scroll_delta_page},')
	sb.writeln('    "gap_edge": ${cfg.scroll_gap_edge},')
	sb.writeln('    "gap_end": ${cfg.scroll_gap_end}')
	sb.writeln('  },')
	// Widgets
	sb.writeln('  "widgets": {')
	sb.writeln('    "switch_width": ${cfg.size_switch_width},')
	sb.writeln('    "switch_height": ${cfg.size_switch_height},')
	sb.writeln('    "radio": ${cfg.size_radio},')
	sb.writeln('    "scrollbar": ${cfg.size_scrollbar},')
	sb.writeln('    "scrollbar_min_thumb": ${cfg.size_scrollbar_min_thumb},')
	sb.writeln('    "progress_bar": ${cfg.size_progress_bar},')
	sb.writeln('    "range_slider": ${cfg.size_range_slider},')
	sb.writeln('    "range_slider_thumb": ${cfg.size_range_slider_thumb},')
	sb.writeln('    "splitter_handle": ${cfg.size_splitter_handle},')
	sb.writeln('    "submenu_min": ${cfg.width_submenu_min},')
	sb.writeln('    "submenu_max": ${cfg.width_submenu_max}')
	sb.writeln('  }')
	sb.writeln('}')
	return sb.str()
}

// theme_save writes a Theme's cfg to a JSON file.
pub fn theme_save(path string, t Theme) ! {
	content := theme_to_json(t.cfg)
	os.write_file(path, content) or { return error('cannot write file: ${path}') }
}

fn write_padding(mut sb strings.Builder, name string, p Padding) {
	sb.write_string('  "${name}": { "top": ${p.top}, "right": ${p.right}, "bottom": ${p.bottom}, "left": ${p.left} }')
}

fn (b ThemeBundle) to_theme_cfg() ThemeCfg {
	d := ThemeCfg{
		name: 'default'
	}
	return ThemeCfg{
		name:                     if b.name.len > 0 { b.name } else { d.name }
		color_background:         color_or(b.colors, 'background', d.color_background)
		color_panel:              color_or(b.colors, 'panel', d.color_panel)
		color_interior:           color_or(b.colors, 'interior', d.color_interior)
		color_hover:              color_or(b.colors, 'hover', d.color_hover)
		color_focus:              color_or(b.colors, 'focus', d.color_focus)
		color_active:             color_or(b.colors, 'active', d.color_active)
		color_border:             color_or(b.colors, 'border', d.color_border)
		color_border_focus:       color_or(b.colors, 'border_focus', d.color_border_focus)
		color_select:             color_or(b.colors, 'select', d.color_select)
		titlebar_dark:            if b.titlebar_dark >= 0 {
			b.titlebar_dark == 1
		} else {
			d.titlebar_dark
		}
		fill:                     if b.fill >= 0 { b.fill == 1 } else { d.fill }
		fill_border:              if b.fill_border >= 0 {
			b.fill_border == 1
		} else {
			d.fill_border
		}
		text_style:               text_or(b.text, d.text_style)
		padding:                  padding_or(b.padding, d.padding)
		padding_small:            padding_or(b.padding_small, d.padding_small)
		padding_medium:           padding_or(b.padding_medium, d.padding_medium)
		padding_large:            padding_or(b.padding_large, d.padding_large)
		size_border:              f32_or(b.size_border, d.size_border)
		radius:                   f32_or(b.radius, d.radius)
		radius_border:            f32_or(b.radius_border, d.radius_border)
		radius_small:             f32_or(b.radius_small, d.radius_small)
		radius_medium:            f32_or(b.radius_medium, d.radius_medium)
		radius_large:             f32_or(b.radius_large, d.radius_large)
		spacing_small:            spacing_f32_or(b.spacing, 'small', d.spacing_small)
		spacing_medium:           spacing_f32_or(b.spacing, 'medium', d.spacing_medium)
		spacing_large:            spacing_f32_or(b.spacing, 'large', d.spacing_large)
		spacing_text:             spacing_f32_or(b.spacing, 'text', d.spacing_text)
		size_text_tiny:           sizes_f32_or(b.sizes, 'text_tiny', d.size_text_tiny)
		size_text_x_small:        sizes_f32_or(b.sizes, 'text_x_small', d.size_text_x_small)
		size_text_small:          sizes_f32_or(b.sizes, 'text_small', d.size_text_small)
		size_text_medium:         sizes_f32_or(b.sizes, 'text_medium', d.size_text_medium)
		size_text_large:          sizes_f32_or(b.sizes, 'text_large', d.size_text_large)
		size_text_x_large:        sizes_f32_or(b.sizes, 'text_x_large', d.size_text_x_large)
		scroll_multiplier:        scroll_f32_or(b.scroll, 'multiplier', d.scroll_multiplier)
		scroll_delta_line:        scroll_f32_or(b.scroll, 'delta_line', d.scroll_delta_line)
		scroll_delta_page:        scroll_f32_or(b.scroll, 'delta_page', d.scroll_delta_page)
		scroll_gap_edge:          scroll_f32_or(b.scroll, 'gap_edge', d.scroll_gap_edge)
		scroll_gap_end:           scroll_f32_or(b.scroll, 'gap_end', d.scroll_gap_end)
		size_switch_width:        widgets_f32_or(b.widgets, 'switch_width', d.size_switch_width)
		size_switch_height:       widgets_f32_or(b.widgets, 'switch_height', d.size_switch_height)
		size_radio:               widgets_f32_or(b.widgets, 'radio', d.size_radio)
		size_scrollbar:           widgets_f32_or(b.widgets, 'scrollbar', d.size_scrollbar)
		size_scrollbar_min_thumb: widgets_f32_or(b.widgets, 'scrollbar_min_thumb', d.size_scrollbar_min_thumb)
		size_progress_bar:        widgets_f32_or(b.widgets, 'progress_bar', d.size_progress_bar)
		size_range_slider:        widgets_f32_or(b.widgets, 'range_slider', d.size_range_slider)
		size_range_slider_thumb:  widgets_f32_or(b.widgets, 'range_slider_thumb', d.size_range_slider_thumb)
		size_splitter_handle:     widgets_f32_or(b.widgets, 'splitter_handle', d.size_splitter_handle)
		width_submenu_min:        widgets_f32_or(b.widgets, 'submenu_min', d.width_submenu_min)
		width_submenu_max:        widgets_f32_or(b.widgets, 'submenu_max', d.width_submenu_max)
	}
}

fn color_or(m map[string]string, key string, fallback Color) Color {
	s := m[key] or { return fallback }
	if s.len == 0 {
		return fallback
	}
	return color_from_hex_string(s) or { fallback }
}

fn f32_or(v f32, fallback f32) f32 {
	return if v >= 0 { v } else { fallback }
}

fn padding_or(p ?PaddingBundle, fallback Padding) Padding {
	pb := p or { return fallback }
	return Padding{
		top:    pb.top
		right:  pb.right
		bottom: pb.bottom
		left:   pb.left
	}
}

fn text_or(t ?TextBundle, fallback TextStyle) TextStyle {
	tb := t or { return fallback }
	return TextStyle{
		color:  if tb.color.len > 0 {
			color_from_hex_string(tb.color) or { fallback.color }
		} else {
			fallback.color
		}
		size:   if tb.size >= 0 { tb.size } else { fallback.size }
		family: if tb.family.len > 0 {
			tb.family
		} else {
			fallback.family
		}
	}
}

fn spacing_f32_or(sp ?SpacingBundle, field string, fallback f32) f32 {
	sb := sp or { return fallback }
	v := match field {
		'small' { sb.small }
		'medium' { sb.medium }
		'large' { sb.large }
		'text' { sb.text }
		else { f32(-1) }
	}
	return if v >= 0 { v } else { fallback }
}

fn sizes_f32_or(sz ?SizesBundle, field string, fallback f32) f32 {
	sb := sz or { return fallback }
	v := match field {
		'text_tiny' { sb.text_tiny }
		'text_x_small' { sb.text_x_small }
		'text_small' { sb.text_small }
		'text_medium' { sb.text_medium }
		'text_large' { sb.text_large }
		'text_x_large' { sb.text_x_large }
		else { f32(-1) }
	}
	return if v >= 0 { v } else { fallback }
}

fn scroll_f32_or(sc ?ScrollBundle, field string, fallback f32) f32 {
	sb := sc or { return fallback }
	v := match field {
		'multiplier' { sb.multiplier }
		'delta_line' { sb.delta_line }
		'delta_page' { sb.delta_page }
		'gap_edge' { sb.gap_edge }
		'gap_end' { sb.gap_end }
		else { f32(-1) }
	}
	return if v >= 0 { v } else { fallback }
}

fn widgets_f32_or(w ?WidgetsBundle, field string, fallback f32) f32 {
	wb := w or { return fallback }
	v := match field {
		'switch_width' { wb.switch_width }
		'switch_height' { wb.switch_height }
		'radio' { wb.radio }
		'scrollbar' { wb.scrollbar }
		'scrollbar_min_thumb' { wb.scrollbar_min_thumb }
		'progress_bar' { wb.progress_bar }
		'range_slider' { wb.range_slider }
		'range_slider_thumb' { wb.range_slider_thumb }
		'splitter_handle' { wb.splitter_handle }
		'submenu_min' { wb.submenu_min }
		'submenu_max' { wb.submenu_max }
		else { f32(-1) }
	}
	return if v >= 0 { v } else { fallback }
}
