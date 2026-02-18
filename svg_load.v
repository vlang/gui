module gui

import svg
import gg
import hash.fnv1a
import os

const max_svg_source_bytes = i64(4 * 1024 * 1024)

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
}

fn cached_svg_paths(paths []svg.TessellatedPath) []CachedSvgPath {
	mut out := []CachedSvgPath{cap: paths.len}
	for path in paths {
		mut vcols := []gg.Color{}
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
		}
	}
	return out
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
	text_paths      []svg.SvgTextPath
	defs_paths      map[string]string // id -> raw d attribute
	filtered_groups []CachedFilteredGroup
	gradients       map[string]svg.SvgGradientDef
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
	if total_verts > max_cached_verts {
		return &CachedSvg{
			render_paths:    render_paths
			triangles:       triangles
			texts:           vg.texts
			text_paths:      vg.text_paths
			defs_paths:      vg.defs_paths
			filtered_groups: cached_fg
			gradients:       vg.gradients
			width:           vg.width
			height:          vg.height
			scale:           scale
		}
	}

	cached := &CachedSvg{
		render_paths:    render_paths
		triangles:       triangles
		texts:           vg.texts
		text_paths:      vg.text_paths
		defs_paths:      vg.defs_paths
		filtered_groups: cached_fg
		gradients:       vg.gradients
		width:           vg.width
		height:          vg.height
		scale:           scale
	}

	window.view_state.svg_cache.set(cache_key, cached)
	return cached
}

// get_svg_dimensions returns natural SVG dimensions without full
// parse+tessellate. Reads from cache or parses just the header.
pub fn (mut window Window) get_svg_dimensions(svg_src string) !(f32, f32) {
	src_hash := fnv1a.sum64_string(svg_src).hex()
	if dims := window.view_state.svg_dim_cache[src_hash] {
		return dims[0], dims[1]
	}
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
