module gui

import crypto.md5
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
	// Round to nearest integer to reduce cache misses from minor float differences
	// Hash svg_src to prevent cache key injection via special characters
	src_hash := md5.hexhash(svg_src)
	cache_key := '${src_hash}:${int(width + 0.5)}x${int(height + 0.5)}'

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

// remove_svg_from_cache removes a cached SVG by its source identifier.
pub fn (mut window Window) remove_svg_from_cache(svg_src string) {
	// Remove all cache entries for this source (any size)
	// Cache keys are formatted as "${src_hash}:${width}x${height}"
	src_hash := md5.hexhash(svg_src)
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
