module gui

import svg
import gg
import hash.fnv1a
import math
import os
import vglyph

const max_svg_source_bytes = i64(4 * 1024 * 1024)
const valid_svg_extensions = ['.svg']

// svg_to_color converts an svg.SvgColor to gui.Color.
@[inline]
fn svg_to_color(c svg.SvgColor) Color {
	return Color{c.r, c.g, c.b, c.a}
}

struct CachedSvgPath {
	triangles     []f32
	color         gg.Color
	vertex_colors []gg.Color
	is_clip_mask  bool
	clip_group    int
	group_id      string
}

struct CachedSvgTextDraw {
	text string
	cfg  vglyph.TextConfig
	x    f32
	y    f32
}

fn cached_svg_paths(paths []svg.TessellatedPath) []CachedSvgPath {
	mut out := []CachedSvgPath{cap: paths.len}
	for path in paths {
		mut vcols := []gg.Color{len: 0}
		if path.vertex_colors.len > 0 {
			vcols = []gg.Color{cap: path.vertex_colors.len}
			for vc in path.vertex_colors {
				vcols << gg.Color{vc.r, vc.g, vc.b, vc.a}
			}
		}
		out << CachedSvgPath{
			triangles:     path.triangles
			color:         gg.Color{path.color.r, path.color.g, path.color.b, path.color.a}
			vertex_colors: vcols
			is_clip_mask:  path.is_clip_mask
			clip_group:    path.clip_group
			group_id:      path.group_id
		}
	}
	return out
}

fn cached_svg_text_gradient(fill_gradient_id string, gradients map[string]svg.SvgGradientDef) &vglyph.GradientConfig {
	if fill_gradient_id.len == 0 {
		return unsafe { nil }
	}
	gdef := gradients[fill_gradient_id] or { return unsafe { nil } }
	mut stops := []vglyph.GradientStop{cap: gdef.stops.len}
	for s in gdef.stops {
		stops << vglyph.GradientStop{
			color:    gg.Color{s.color.r, s.color.g, s.color.b, s.color.a}
			position: s.offset
		}
	}
	dx := gdef.x2 - gdef.x1
	dy := gdef.y2 - gdef.y1
	dir := if math.abs(dx) >= math.abs(dy) {
		vglyph.GradientDirection.horizontal
	} else {
		vglyph.GradientDirection.vertical
	}
	return &vglyph.GradientConfig{
		stops:     stops
		direction: dir
	}
}

fn cached_svg_text_draws(texts []svg.SvgText, scale f32, gradients map[string]svg.SvgGradientDef, mut window Window) []CachedSvgTextDraw {
	mut draws := []CachedSvgTextDraw{cap: texts.len}
	for t in texts {
		if t.text.len == 0 {
			continue
		}
		typeface := match true {
			t.bold && t.italic { vglyph.Typeface.bold_italic }
			t.bold { vglyph.Typeface.bold }
			t.italic { vglyph.Typeface.italic }
			else { vglyph.Typeface.regular }
		}
		text_style := TextStyle{
			family:         t.font_family
			size:           t.font_size * scale
			typeface:       typeface
			color:          if t.opacity < 1.0 {
				Color{t.color.r, t.color.g, t.color.b, u8(f32(t.color.a) * t.opacity)}
			} else {
				svg_to_color(t.color)
			}
			underline:      t.underline
			strikethrough:  t.strikethrough
			letter_spacing: t.letter_spacing * scale
			gradient:       cached_svg_text_gradient(t.fill_gradient_id, gradients)
			stroke_width:   t.stroke_width * scale
			stroke_color:   if t.opacity < 1.0 {
				Color{t.stroke_color.r, t.stroke_color.g, t.stroke_color.b, u8(f32(t.stroke_color.a) * t.opacity)}
			} else {
				svg_to_color(t.stroke_color)
			}
		}
		cfg := text_style.to_vglyph_cfg()
		tw := if window.text_system == unsafe { nil } {
			f32(0)
		} else {
			window.text_system.text_width(t.text, cfg) or { 0 }
		}
		fh := if window.text_system == unsafe { nil } {
			t.font_size * scale
		} else {
			window.text_system.font_height(cfg) or { t.font_size * scale }
		}
		ascent := fh * 0.8
		mut x := t.x * scale
		y := t.y * scale - ascent
		if t.anchor == 1 {
			x -= tw / 2
		} else if t.anchor == 2 {
			x -= tw
		}
		draws << CachedSvgTextDraw{
			text: t.text
			cfg:  cfg
			x:    x
			y:    y
		}
	}
	return draws
}

// validate_svg_source rejects file paths containing '..'. This is a
// basic traversal guard; it does not catch URL-encoded sequences or
// symlinks. OS file permissions and max_svg_source_bytes (4MB) are
// the primary defenses.
fn validate_svg_source(svg_src string) ! {
	if svg_src.starts_with('<') {
		return
	}
	if svg_src.contains('..') {
		return error('invalid svg path: contains ..')
	}
	ext := os.file_ext(svg_src).to_lower()
	if ext !in valid_svg_extensions {
		return error('unsupported svg format: ${ext}')
	}
}

fn check_svg_source_size(svg_src string) ! {
	if svg_src.starts_with('<') {
		if i64(svg_src.len) > max_svg_source_bytes {
			return error('SVG source too large')
		}
		return
	}
	if !os.exists(svg_src) {
		return error('SVG not found: ${svg_src}')
	}
	size := i64(os.file_size(svg_src))
	if size > max_svg_source_bytes {
		return error('SVG file too large')
	}
}

// CachedFilteredGroup holds tessellated geometry for a filter group.
pub struct CachedFilteredGroup {
pub:
	filter       svg.SvgFilter
	render_paths []CachedSvgPath
	triangles    []svg.TessellatedPath
	texts        []svg.SvgText
	text_draws   []CachedSvgTextDraw
	text_paths   []svg.SvgTextPath
	gradients    map[string]svg.SvgGradientDef
	bbox         [4]f32 // x, y, width, height in viewBox coords
}

// CachedSvg holds pre-tessellated SVG data for efficient rendering.
pub struct CachedSvg {
pub:
	render_paths    []CachedSvgPath
	triangles       []svg.TessellatedPath // Tessellated paths
	texts           []svg.SvgText         // Text elements for DrawText rendering
	text_draws      []CachedSvgTextDraw
	text_paths      []svg.SvgTextPath
	defs_paths      map[string]string // id -> raw d attribute
	filtered_groups []CachedFilteredGroup
	gradients       map[string]svg.SvgGradientDef
	animations      []svg.SvgAnimation
	has_animations  bool
	width           f32 // Original viewBox width
	height          f32 // Original viewBox height
	scale           f32 // Scale factor applied during tessellation
}

// load_svg loads and tessellates an SVG, caching the result.
// The svg_src can be a file path or inline SVG data.
// Width and height determine the display size and tessellation scale.
// If width/height are 0, uses the SVG's natural dimensions (scale 1.0).
pub fn (mut window Window) load_svg(svg_src string, width f32, height f32) !&CachedSvg {
	src_hash := fnv1a.sum64_string(svg_src).hex()
	cache_key := '${src_hash}:${int(width * 10)}x${int(height * 10)}'

	if cached := window.view_state.svg_cache.get(cache_key) {
		return cached
	}

	validate_svg_source(svg_src)!
	check_svg_source_size(svg_src)!

	vg := if svg_src.starts_with('<') {
		svg.parse_svg(svg_src)!
	} else if os.exists(svg_src) {
		svg.parse_svg_file(svg_src)!
	} else {
		return error('SVG not found: ${svg_src}')
	}

	window.view_state.svg_dim_cache[src_hash] = [vg.width, vg.height]!

	scale := if width <= 0 || height <= 0 {
		f32(1)
	} else {
		scale_x := if vg.width > 0 { width / vg.width } else { f32(1) }
		scale_y := if vg.height > 0 { height / vg.height } else { f32(1) }
		if scale_x < scale_y {
			scale_x
		} else {
			scale_y
		}
	}

	triangles := vg.get_triangles(scale)
	render_paths := cached_svg_paths(triangles)
	text_draws := cached_svg_text_draws(vg.texts, scale, vg.gradients, mut window)

	mut cached_fg := []CachedFilteredGroup{cap: vg.filtered_groups.len}
	for fg in vg.filtered_groups {
		filter := vg.filters[fg.filter_id]
		mut fg_vg := svg.VectorGraphic{
			width:      vg.width
			height:     vg.height
			paths:      fg.paths
			gradients:  vg.gradients
			clip_paths: vg.clip_paths
		}
		fg_tris := fg_vg.get_triangles(scale)
		fg_render_paths := cached_svg_paths(fg_tris)
		bbox := compute_triangle_bbox(fg_tris)
		cached_fg << CachedFilteredGroup{
			filter:       filter
			render_paths: fg_render_paths
			triangles:    fg_tris
			texts:        fg.texts
			text_draws:   cached_svg_text_draws(fg.texts, scale, vg.gradients, mut window)
			text_paths:   fg.text_paths
			gradients:    vg.gradients
			bbox:         bbox
		}
	}

	mut total_verts := 0
	for path in render_paths {
		total_verts += path.triangles.len
	}
	for cfg_ in cached_fg {
		for path in cfg_.render_paths {
			total_verts += path.triangles.len
		}
	}
	max_cached_verts := 1250000
	cached := &CachedSvg{
		render_paths:    render_paths
		triangles:       triangles
		texts:           vg.texts
		text_draws:      text_draws
		text_paths:      vg.text_paths
		defs_paths:      vg.defs_paths
		filtered_groups: cached_fg
		gradients:       vg.gradients
		animations:      vg.animations
		has_animations:  vg.animations.len > 0
		width:           vg.width
		height:          vg.height
		scale:           scale
	}

	if total_verts <= max_cached_verts {
		window.view_state.svg_cache.set(cache_key, cached)
	}
	return cached
}

// get_svg_dimensions returns natural SVG dimensions without full
// parse+tessellate. Reads from cache or parses just the header.
pub fn (mut window Window) get_svg_dimensions(svg_src string) !(f32, f32) {
	src_hash := fnv1a.sum64_string(svg_src).hex()
	if dims := window.view_state.svg_dim_cache[src_hash] {
		return dims[0], dims[1]
	}
	validate_svg_source(svg_src)!
	check_svg_source_size(svg_src)!
	content := if svg_src.starts_with('<') {
		svg_src
	} else if os.exists(svg_src) {
		os.read_file(svg_src) or { return error('SVG not found: ${svg_src}') }
	} else {
		return error('SVG not found: ${svg_src}')
	}
	w, h := svg.parse_svg_dimensions(content)
	window.view_state.svg_dim_cache[src_hash] = [w, h]!
	return w, h
}

// remove_svg_from_cache removes a cached SVG by its source identifier.
pub fn (mut window Window) remove_svg_from_cache(svg_src string) {
	src_hash := fnv1a.sum64_string(svg_src).hex()
	prefix := '${src_hash}:'
	mut keys_to_delete := []string{}
	for key in window.view_state.svg_cache.keys() {
		if key.starts_with(prefix) {
			keys_to_delete << key
		}
	}
	for key in keys_to_delete {
		window.view_state.svg_cache.delete(key)
	}
	window.view_state.svg_dim_cache.delete(src_hash)
}

// clear_svg_cache removes all cached SVGs.
pub fn (mut window Window) clear_svg_cache() {
	window.view_state.svg_cache.clear()
	window.view_state.svg_dim_cache = map[string][2]f32{}
}

// compute_triangle_bbox computes bounding box from tessellated paths.
fn compute_triangle_bbox(tpaths []svg.TessellatedPath) [4]f32 {
	mut min_x := f32(1e30)
	mut min_y := f32(1e30)
	mut max_x := f32(-1e30)
	mut max_y := f32(-1e30)
	mut has_data := false

	for tp in tpaths {
		mut i := 0
		for i < tp.triangles.len - 1 {
			x := tp.triangles[i]
			y := tp.triangles[i + 1]
			if x < min_x {
				min_x = x
			}
			if x > max_x {
				max_x = x
			}
			if y < min_y {
				min_y = y
			}
			if y > max_y {
				max_y = y
			}
			has_data = true
			i += 2
		}
	}

	if !has_data {
		return [f32(0), 0, 0, 0]!
	}
	return [min_x, min_y, max_x - min_x, max_y - min_y]!
}
