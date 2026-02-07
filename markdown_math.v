module gui

import net.http
import os
import rand
import stbi
import time

struct MathFetchResult {
	res     http.Response
	err_msg string
	is_err  bool
}

// math_cache_hash computes a cache key for a math expression ID.
fn math_cache_hash(math_id string) i64 {
	return i64((u64(math_id.hash()) << 32) | u64(math_id.len))
}

// fetch_math_async fetches a LaTeX math image from codecogs in
// a background thread. Uses PNG format. Updates diagram_cache
// with result and triggers window refresh.
// NOTE: LaTeX source is sent to external latex.codecogs.com API.
fn fetch_math_async(mut window Window, latex string, hash i64, display bool, fg_color Color) {
	spawn fn [mut window, latex, hash, display, fg_color] () {
		ch := chan MathFetchResult{}

		// Build codecogs URL with DPI and optional color prefix.
		// Use named color to avoid bracket syntax that breaks
		// when percent-encoded.
		dpi := if display { '150' } else { '200' }
		lum := 0.299 * f64(fg_color.r) + 0.587 * f64(fg_color.g) + 0.114 * f64(fg_color.b)
		color_cmd := if lum > 128.0 { '\\color{white}' } else { '' }
		prefix := '\\dpi{${dpi}}${color_cmd}'
		// Replace spaces with {} (empty group) — acts as
		// command terminator without visible output. V's
		// http library re-encodes %20 as + which codecogs
		// renders as literal plus signs.
		encoded := (prefix + latex).replace(' ', '{}').replace('#', '%23').replace('&', '%26')
		url := 'https://latex.codecogs.com/png.image?${encoded}'

		spawn fn [url, ch] () {
			result := http.fetch(
				method: .get
				url:    url
			) or {
				ch <- MathFetchResult{
					err_msg: err.msg()
					is_err:  true
				}
				return
			}
			ch <- MathFetchResult{
				res:    result
				is_err: false
			}
		}()

		// Wait with 15s timeout
		mut fetch_res := MathFetchResult{
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

			// No transparent fill — keep PNG alpha for blending
			// with any background color

			rand_suffix := rand.intn(1000000) or { 0 }
			tmp_path := os.join_path(os.temp_dir(), 'math_${hash}_${rand_suffix}.png')
			stbi.stbi_write_png(tmp_path, img.width, img.height, img.nr_channels, img.data,
				img.width * img.nr_channels) or {
				img.free()
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
			img_w := f32(img.width)
			img_h := f32(img.height)
			img.free()
			window.queue_command(fn [hash, tmp_path, img_w, img_h] (mut w Window) {
				w.view_state.diagram_cache.set(hash, DiagramCacheEntry{
					state:    .ready
					png_path: tmp_path
					width:    img_w
					height:   img_h
				})
				// Invalidate markdown cache to trigger re-layout
				// with actual inline math dimensions
				w.view_state.markdown_cache.clear()
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
