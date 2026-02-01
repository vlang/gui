module gui

import net.http
import os
import rand
import stbi

// DiagramState represents the loading state of a diagram.
enum DiagramState {
	loading
	ready
	error
}

// DiagramCacheEntry stores cached diagram data with its state.
struct DiagramCacheEntry {
	state    DiagramState
	png_path string // temp file path for PNG
	error    string
}

// fill_transparent_with_bg replaces transparent pixels with ghost white background.
// Modifies RGBA image data in place.
fn fill_transparent_with_bg(data &u8, width int, height int, channels int) {
	if channels != 4 {
		return
	}
	// Ghost white: RGB(248, 248, 255)
	bg_r, bg_g, bg_b := f32(248), f32(248), f32(255)
	total := width * height * 4
	mut ptr := unsafe { data }
	for i := 0; i < total; i += 4 {
		alpha := unsafe { ptr[i + 3] }
		if alpha < 255 {
			a := f32(alpha) / 255.0
			inv_a := 1.0 - a
			unsafe {
				ptr[i] = u8(f32(ptr[i]) * a + bg_r * inv_a)
				ptr[i + 1] = u8(f32(ptr[i + 1]) * a + bg_g * inv_a)
				ptr[i + 2] = u8(f32(ptr[i + 2]) * a + bg_b * inv_a)
				ptr[i + 3] = 255
			}
		}
	}
}

// fetch_mermaid_async fetches a mermaid diagram from Kroki API in background thread.
// Uses PNG format since SVG from Kroki uses foreignObject/CSS which our parser doesn't support.
// Updates diagram_cache with result and triggers window refresh.
// NOTE: Mermaid source is sent to external kroki.io API for rendering.
fn fetch_mermaid_async(mut window Window, source string, hash i64, max_width int) {
	spawn fn [mut window, source, hash, max_width] () {
		// Use fetch with explicit config for binary data
		// Note: V's http.fetch doesn't support timeout config
		result := http.fetch(
			method: .post
			url:    'https://kroki.io/mermaid/png'
			data:   source
		) or {
			window.lock()
			window.view_state.diagram_cache.set(hash, DiagramCacheEntry{
				state: .error
				error: 'Network error: ${err.msg()}'
			})
			window.unlock()
			window.update_window()
			return
		}

		if result.status_code == 200 {
			// Reject oversized responses (>10MB)
			if result.body.len > 10 * 1024 * 1024 {
				window.lock()
				window.view_state.diagram_cache.set(hash, DiagramCacheEntry{
					state: .error
					error: 'Response too large (>${result.body.len / 1024 / 1024}MB)'
				})
				window.unlock()
				window.update_window()
				return
			}
			// Load PNG from memory and resize if needed
			png_bytes := result.body.bytes()
			img := stbi.load_from_memory(png_bytes.data, png_bytes.len) or {
				window.lock()
				window.view_state.diagram_cache.set(hash, DiagramCacheEntry{
					state: .error
					error: 'Failed to decode PNG: ${err.msg()}'
				})
				window.unlock()
				window.update_window()
				return
			}

			// Scale down if wider than max_width
			mut final_img := img
			resized := img.width > max_width
			if resized {
				scale := f64(max_width) / f64(img.width)
				new_h := int(f64(img.height) * scale)
				final_img = stbi.resize_uint8(&img, max_width, new_h) or {
					img.free()
					window.lock()
					window.view_state.diagram_cache.set(hash, DiagramCacheEntry{
						state: .error
						error: 'Failed to resize: ${err.msg()}'
					})
					window.unlock()
					window.update_window()
					return
				}
			}

			// Fill transparent pixels with ghost white background
			fill_transparent_with_bg(final_img.data, final_img.width, final_img.height,
				final_img.nr_channels)

			// Write PNG to temp file with random suffix
			rand_suffix := rand.intn(1000000) or { 0 }
			tmp_path := os.join_path(os.temp_dir(), 'mermaid_${hash}_${rand_suffix}.png')
			stbi.stbi_write_png(tmp_path, final_img.width, final_img.height, final_img.nr_channels,
				final_img.data, final_img.width * final_img.nr_channels) or {
				// Free stbi memory before returning
				img.free()
				if resized {
					final_img.free()
				}
				window.lock()
				window.view_state.diagram_cache.set(hash, DiagramCacheEntry{
					state: .error
					error: 'Failed to write temp file: ${err.msg()}'
				})
				window.unlock()
				window.update_window()
				return
			}
			// Free stbi memory after writing PNG
			img.free()
			if resized {
				final_img.free()
			}
			window.lock()
			window.view_state.diagram_cache.set(hash, DiagramCacheEntry{
				state:    .ready
				png_path: tmp_path
			})
		} else {
			body_preview := if result.body.len > 200 {
				result.body[..200] + '...'
			} else {
				result.body
			}
			window.lock()
			window.view_state.diagram_cache.set(hash, DiagramCacheEntry{
				state: .error
				error: 'HTTP ${result.status_code}: ${body_preview}'
			})
		}
		window.unlock()
		window.update_window()
	}()
}

// BoundedDiagramCache is a FIFO cache for diagram entries.
struct BoundedDiagramCache {
mut:
	data      map[i64]DiagramCacheEntry
	order     []i64
	index_map map[i64]int
	max_size  int = 50
}

// get returns cached diagram entry.
fn (m &BoundedDiagramCache) get(key i64) ?DiagramCacheEntry {
	return m.data[key] or { return none }
}

// set adds diagram entry to cache. Evicts oldest if at capacity.
fn (mut m BoundedDiagramCache) set(key i64, value DiagramCacheEntry) {
	if m.max_size < 1 {
		return
	}
	if key !in m.data {
		if m.data.len >= m.max_size && m.order.len > 0 {
			oldest := m.order[0]
			// Clean up temp file before evicting
			if oldest_entry := m.data[oldest] {
				if oldest_entry.png_path.len > 0 {
					os.rm(oldest_entry.png_path) or {}
				}
			}
			m.data.delete(oldest)
			m.index_map.delete(oldest)
			m.order.delete(0)
			for k, idx in m.index_map {
				m.index_map[k] = idx - 1
			}
		}
		m.index_map[key] = m.order.len
		m.order << key
	}
	m.data[key] = value
}

// len returns number of entries.
fn (m &BoundedDiagramCache) len() int {
	return m.data.len
}

// clear removes all entries and deletes temp files.
fn (mut m BoundedDiagramCache) clear() {
	for _, entry in m.data {
		if entry.png_path.len > 0 {
			os.rm(entry.png_path) or {}
		}
	}
	m.data.clear()
	m.order.clear()
	m.index_map.clear()
}
