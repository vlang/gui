module gui

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
pub fn (mut window Window) load_svg(svg_src string, width f32, height f32) !&CachedSvg {
	// Generate cache key including size for scale-specific caching
	// Round to nearest integer to reduce cache misses from minor float differences
	cache_key := '${svg_src}:${int(width + 0.5)}x${int(height + 0.5)}'

	// Check cache first
	if cached := window.view_state.svg_cache[cache_key] {
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
	scale_x := if vg.width > 0 { width / vg.width } else { f32(1) }
	scale_y := if vg.height > 0 { height / vg.height } else { f32(1) }
	scale := if scale_x < scale_y { scale_x } else { scale_y }

	// Tessellate at the target scale
	triangles := vg.get_triangles(scale)

	cached := &CachedSvg{
		triangles: triangles
		width:     vg.width
		height:    vg.height
		scale:     scale
	}

	window.view_state.svg_cache[cache_key] = cached
	return cached
}

// remove_svg_from_cache removes a cached SVG by its source identifier.
pub fn (mut window Window) remove_svg_from_cache(svg_src string) {
	// Remove all cache entries for this source (any size)
	// Cache keys are formatted as "${svg_src}:${width}x${height}"
	prefix := '${svg_src}:'
	mut keys_to_delete := []string{}
	for key, _ in window.view_state.svg_cache {
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
