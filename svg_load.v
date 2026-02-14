module gui

import hash.fnv1a
import os

// CachedSvg holds pre-tessellated SVG data for efficient rendering.
pub struct CachedSvg {
pub:
	triangles []TessellatedPath // Tessellated paths
	width     f32               // Original viewBox width
	height    f32               // Original viewBox height
	scale     f32               // Scale factor applied during tessellation
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

	// Validate size: prevent caching extremely complex SVGs (>10MB of geometry)
	// Each triangle vertex is 2 f32 (8 bytes), rough estimate
	mut total_verts := 0
	for tri in triangles {
		total_verts += tri.triangles.len
	}
	max_cached_verts := 1250000 // ~10MB limit
	if total_verts > max_cached_verts {
		// Return without caching - too large
		return &CachedSvg{
			triangles: triangles
			width:     vg.width
			height:    vg.height
			scale:     scale
		}
	}

	cached := &CachedSvg{
		triangles: triangles
		width:     vg.width
		height:    vg.height
		scale:     scale
	}

	// set handles LRU eviction internally
	window.view_state.svg_cache.set(cache_key, cached)
	return cached
}

// get_svg_dimensions returns natural SVG dimensions without full
// parse+tessellate. Reads from cache or parses just the header.
pub fn (mut window Window) get_svg_dimensions(svg_src string) !(f32, f32) {
	// Check if any cached entry exists for this source
	src_hash := fnv1a.sum64_string(svg_src).hex()
	prefix := '${src_hash}:'
	for key in window.view_state.svg_cache.keys() {
		if key.starts_with(prefix) {
			if cached := window.view_state.svg_cache.get(key) {
				return cached.width, cached.height
			}
		}
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
}

// clear_svg_cache removes all cached SVGs.
pub fn (mut window Window) clear_svg_cache() {
	window.view_state.svg_cache.clear()
}
