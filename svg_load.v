module gui

import hash.fnv1a
import os

// CachedFilteredGroup holds tessellated geometry for a filter group.
pub struct CachedFilteredGroup {
pub:
	filter     SvgFilter
	triangles  []TessellatedPath
	texts      []SvgText
	text_paths []SvgTextPath
	gradients  map[string]SvgGradientDef
	bbox       [4]f32 // x, y, width, height in viewBox coords
}

// CachedSvg holds pre-tessellated SVG data for efficient rendering.
pub struct CachedSvg {
pub:
	triangles       []TessellatedPath // Tessellated paths
	texts           []SvgText         // Text elements for DrawText rendering
	text_paths      []SvgTextPath
	defs_paths      map[string]string // id -> raw d attribute
	filtered_groups []CachedFilteredGroup
	gradients       map[string]SvgGradientDef
	width           f32 // Original viewBox width
	height          f32 // Original viewBox height
	scale           f32 // Scale factor applied during tessellation
}

// load_svg loads and tessellates an SVG, caching the result.
// The svg_src can be a file path or inline SVG data.
// Width and height determine the display size and tessellation scale.
// If width/height are 0, uses the SVG's natural dimensions (scale 1.0).
pub fn (mut window Window) load_svg(svg_src string, width f32, height f32) !&CachedSvg {
	// Generate cache key including size for scale-specific caching
	// Round to 0.1px precision to reduce collisions while maintaining distinct scales
	// Use fnv1a hash (faster than MD5, sufficient for cache keys)
	src_hash := fnv1a.sum64_string(svg_src).hex()
	cache_key := '${src_hash}:${int(width * 10)}x${int(height * 10)}'

	// Check cache first (LRU: get moves to end)
	if cached := window.view_state.svg_cache.get(cache_key) {
		return cached
	}

	// Parse SVG
	vg := if svg_src.starts_with('<') {
		// Inline SVG data
		parse_svg(svg_src)!
	} else if os.exists(svg_src) {
		// File path
		parse_svg_file(svg_src)!
	} else {
		return error('SVG not found: ${svg_src}')
	}

	// Cache dimensions for O(1) lookup by get_svg_dimensions
	window.view_state.svg_dim_cache[src_hash] = [vg.width, vg.height]!

	// Calculate scale to fit requested dimensions
	// If width/height are 0, use natural dimensions (scale 1.0)
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

	// Tessellate at the target scale
	triangles := vg.get_triangles(scale)

	// Tessellate filtered groups
	mut cached_fg := []CachedFilteredGroup{cap: vg.filtered_groups.len}
	for fg in vg.filtered_groups {
		filter := vg.filters[fg.filter_id]
		// Build temp VectorGraphic for this group's paths
		mut fg_vg := VectorGraphic{
			width:      vg.width
			height:     vg.height
			paths:      fg.paths
			gradients:  vg.gradients
			clip_paths: vg.clip_paths
		}
		fg_tris := fg_vg.get_triangles(scale)
		// Compute bbox from triangle vertices
		bbox := compute_triangle_bbox(fg_tris)
		cached_fg << CachedFilteredGroup{
			filter:     filter
			triangles:  fg_tris
			texts:      fg.texts
			text_paths: fg.text_paths
			gradients:  vg.gradients
			bbox:       bbox
		}
	}

	// Validate size: prevent caching extremely complex SVGs (>10MB of geometry)
	// Each triangle vertex is 2 f32 (8 bytes), rough estimate
	mut total_verts := 0
	for tri in triangles {
		total_verts += tri.triangles.len
	}
	for cfg_ in cached_fg {
		for tri in cfg_.triangles {
			total_verts += tri.triangles.len
		}
	}
	max_cached_verts := 1250000 // ~10MB limit
	if total_verts > max_cached_verts {
		// Return without caching - too large
		return &CachedSvg{
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

	// set handles LRU eviction internally
	window.view_state.svg_cache.set(cache_key, cached)
	return cached
}

// get_svg_dimensions returns natural SVG dimensions without full
// parse+tessellate. Reads from cache or parses just the header.
pub fn (mut window Window) get_svg_dimensions(svg_src string) !(f32, f32) {
	src_hash := fnv1a.sum64_string(svg_src).hex()
	// O(1) lookup in dimension cache
	if dims := window.view_state.svg_dim_cache[src_hash] {
		return dims[0], dims[1]
	}
	// Not cached — parse dimensions only
	content := if svg_src.starts_with('<') {
		svg_src
	} else if os.exists(svg_src) {
		os.read_file(svg_src) or { return error('SVG not found: ${svg_src}') }
	} else {
		return error('SVG not found: ${svg_src}')
	}
	w, h := parse_svg_dimensions(content)
	window.view_state.svg_dim_cache[src_hash] = [w, h]!
	return w, h
}

// remove_svg_from_cache removes a cached SVG by its source identifier.
pub fn (mut window Window) remove_svg_from_cache(svg_src string) {
	// Remove all cache entries for this source (any size)
	// Cache keys are formatted as "${src_hash}:${width}x${height}"
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
// Returns [x, y, width, height] in viewBox coordinates.
fn compute_triangle_bbox(tpaths []TessellatedPath) [4]f32 {
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
