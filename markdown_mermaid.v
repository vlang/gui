module gui

import net.http
import os
import rand
import stbi
import time

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
	width    f32
	height   f32
	dpi      f32 // DPI used for rendering (for scale calc)
}

// write_stbi_temp writes an stbi image to a temp PNG file.
// Returns the file path or an error string.
fn write_stbi_temp(prefix string, hash i64, img stbi.Image) !string {
	rand_suffix := rand.intn(1000000) or { 0 }
	tmp_path := os.join_path(os.temp_dir(), '${prefix}_${hash}_${rand_suffix}.png')
	stbi.stbi_write_png(tmp_path, img.width, img.height, img.nr_channels, img.data, img.width * img.nr_channels)!
	return tmp_path
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

struct MermaidFetchResult {
	res     http.Response
	err_msg string
	is_err  bool
}

// fetch_mermaid_async fetches a mermaid diagram from Kroki API in background thread.
// Uses PNG format since SVG from Kroki uses foreignObject/CSS which our parser doesn't support.
// Updates diagram_cache with result and triggers window refresh.
// NOTE: Mermaid source is sent to external kroki.io API for rendering.
fn fetch_mermaid_async(mut window Window, source string, hash i64, max_width int) {
	spawn fn [mut window, source, hash, max_width] () {
		ch := chan MermaidFetchResult{}

		// Spawn fetcher thread WITHOUT window reference to avoid holding it if hung
		spawn fn [source, ch] () {
			result := http.fetch(
				method: .post
				url:    'https://kroki.io/mermaid/png'
				data:   source
			) or {
				ch <- MermaidFetchResult{
					err_msg: err.msg()
					is_err:  true
				}
				return
			}
			ch <- MermaidFetchResult{
				res:    result
				is_err: false
			}
		}()

		// Wait for result with 15s timeout
		mut fetch_res := MermaidFetchResult{
			is_err:  true
			err_msg: 'Request timed out'
		}

		select {
			res := <-ch {
				fetch_res = res
			}
			15 * time.second {
				// use default timeout value
			}
		}

		if fetch_res.is_err {
			err_msg := fetch_res.err_msg
			window.queue_command(fn [hash, err_msg] (mut w Window) {
				w.view_state.diagram_cache.set(hash, DiagramCacheEntry{
					state: .error
					error: err_msg
				})
				w.update_window()
			})
			return
		}

		result := fetch_res.res
		if result.status_code == 200 {
			// Reject oversized responses (>10MB)
			if result.body.len > 10 * 1024 * 1024 {
				body_len := result.body.len
				window.queue_command(fn [hash, body_len] (mut w Window) {
					w.view_state.diagram_cache.set(hash, DiagramCacheEntry{
						state: .error
						error: 'Response too large (>${body_len / 1024 / 1024}MB)'
					})
					w.update_window()
				})
				return
			}
			// Load PNG from memory and resize if needed
			png_bytes := result.body.bytes()
			img := stbi.load_from_memory(png_bytes.data, png_bytes.len) or {
				err_msg := err.msg()
				window.queue_command(fn [hash, err_msg] (mut w Window) {
					w.view_state.diagram_cache.set(hash, DiagramCacheEntry{
						state: .error
						error: 'Failed to decode PNG: ${err_msg}'
					})
					w.update_window()
				})
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
					err_msg := err.msg()
					window.queue_command(fn [hash, err_msg] (mut w Window) {
						w.view_state.diagram_cache.set(hash, DiagramCacheEntry{
							state: .error
							error: 'Failed to resize: ${err_msg}'
						})
						w.update_window()
					})
					return
				}
			}

			// Fill transparent pixels with ghost white background
			fill_transparent_with_bg(final_img.data, final_img.width, final_img.height,
				final_img.nr_channels)

			tmp_path := write_stbi_temp('mermaid', hash, final_img) or {
				img.free()
				if resized {
					final_img.free()
				}
				err_msg := err.msg()
				window.queue_command(fn [hash, err_msg] (mut w Window) {
					w.view_state.diagram_cache.set(hash, DiagramCacheEntry{
						state: .error
						error: 'Failed to write temp file: ${err_msg}'
					})
					w.update_window()
				})
				return
			}
			// Free stbi memory after writing PNG
			img.free()
			if resized {
				final_img.free()
			}
			final_w := f32(final_img.width)
			final_h := f32(final_img.height)
			window.queue_command(fn [hash, tmp_path, final_w, final_h] (mut w Window) {
				w.view_state.diagram_cache.set(hash, DiagramCacheEntry{
					state:    .ready
					png_path: tmp_path
					width:    final_w
					height:   final_h
				})
				w.update_window()
			})
		} else {
			body_preview := if result.body.len > 200 {
				result.body[..200] + '...'
			} else {
				result.body
			}
			status_code := result.status_code
			window.queue_command(fn [hash, status_code, body_preview] (mut w Window) {
				w.view_state.diagram_cache.set(hash, DiagramCacheEntry{
					state: .error
					error: 'HTTP ${status_code}: ${body_preview}'
				})
				w.update_window()
			})
		}
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
