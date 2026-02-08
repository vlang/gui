module gui

import log
import net.http
import hash
import os
import time

@[minify]
struct ImageView implements View {
	ImageCfg
mut:
	content []View // not used
}

@[minify]
pub struct ImageCfg {
pub:
	id         string
	src        string
	on_click   fn (&Layout, mut Event, mut Window)    = unsafe { nil }
	on_hover   fn (mut Layout, mut Event, mut Window) = unsafe { nil }
	width      f32
	height     f32
	min_width  f32
	min_height f32
	max_width  f32
	max_height f32
	invisible  bool
}

fn (mut iv ImageView) generate_layout(mut window Window) Layout {
	// window.stats.increment_layouts()
	window.stats.increment_image_views()

	mut image_path := iv.src
	is_url := iv.src.starts_with('http://') || iv.src.starts_with('https://')

	if is_url {
		// Calculate cache path
		hash_sum := hash.sum64(iv.src.bytes(), 0).hex()
		ext := os.file_ext(iv.src)
		cache_dir := os.join_path(os.temp_dir(), 'gui_cache', 'images')
		if !os.exists(cache_dir) {
			os.mkdir_all(cache_dir) or {}
		}
		cache_path := os.join_path(cache_dir, '${hash_sum}${ext}')

		if os.exists(cache_path) {
			image_path = cache_path
		} else {
			// Check if already downloading
			if !window.view_state.active_downloads.contains(iv.src) {
				window.view_state.active_downloads.set(iv.src, time.now().unix())
				spawn download_image(iv.src, cache_path, mut window)
			}
			// Show placeholder or empty while downloading
			// For now, let's return an empty layout (or maybe a loading placeholder in future)
			// But to avoid error log from load_image, we can return early
			mut layout := Layout{
				shape: &Shape{
					shape_type: .rectangle // Placeholder
					id:         iv.id
					width:      if iv.width > 0 { iv.width } else { 100 }
					height:     if iv.height > 0 { iv.height } else { 100 }
					color:      theme().color_background
				}
			}
			apply_fixed_sizing_constraints(mut layout.shape)
			return layout
		}
	}

	image := window.load_image(image_path) or {
		log.error('${@FILE_LINE} > ${err.msg()}')
		mut error_text := text(
			text:       '[missing: ${iv.src}]'
			text_style: TextStyle{
				...gui_theme.text_style
				color: magenta
			}
		)
		return error_text.generate_layout(mut window)
	}

	width := if iv.width > 0 { iv.width } else { image.width }
	height := if iv.height > 0 { iv.height } else { image.height }

	mut events := unsafe { &EventHandlers(nil) }
	if iv.on_click != unsafe { nil } || iv.on_hover != unsafe { nil } {
		events = &EventHandlers{
			on_click: iv.on_click
			on_hover: iv.on_hover
		}
	}
	mut layout := Layout{
		shape: &Shape{
			shape_type: .image
			id:         iv.id
			resource:   image_path
			width:      width
			min_width:  iv.min_width
			max_width:  iv.max_width
			height:     height
			min_height: iv.min_height
			max_height: iv.max_height
			events:     events
		}
	}
	apply_fixed_sizing_constraints(mut layout.shape)

	return layout
}

struct ImageFetchResult {
	err_msg string
	is_err  bool
}

// download_image downloads a file from a URL to a local path in a background thread.
// It performs security checks (Content-Length < 50MB, Content-Type is image/*)
// and handles thread synchronization for updating active downloads state.
fn download_image(url string, path string, mut w Window) {
	spawn fn [url, path, mut w] () {
		ch := chan ImageFetchResult{}

		// Spawn fetcher thread WITHOUT window reference to avoid holding it if hung
		spawn fn [url, path, ch] () {
			// Security check: Verify Content-Length and Content-Type
			// We use i64 for max size to match http.Response.content_length
			max_size := i64(50 * 1024 * 1024)

			head := http.head(url) or {
				ch <- ImageFetchResult{
					err_msg: 'Failed to fetch image headers for ${url}: ${err}'
					is_err:  true
				}
				return
			}

			// Validate content length
			content_length := head.header.get(.content_length) or { '0' }.i64()
			if content_length > max_size {
				ch <- ImageFetchResult{
					err_msg: 'Image too large (${content_length} bytes > ${max_size} bytes): ${url}'
					is_err:  true
				}
				return
			}

			// Validate content type
			if !head.header.get(.content_type) or { '' }.starts_with('image/') {
				ch <- ImageFetchResult{
					err_msg: 'Invalid content type for image (expected image/*): ${url}'
					is_err:  true
				}
				return
			}

			// Download file
			http.download_file(url, path) or {
				ch <- ImageFetchResult{
					err_msg: 'Failed to download image ${url}: ${err}'
					is_err:  true
				}
				return
			}

			ch <- ImageFetchResult{
				is_err: false
			}
		}()

		// Wait for result with 30s timeout (images can be large)
		mut fetch_res := ImageFetchResult{
			is_err:  true
			err_msg: 'Image download timed out: ${url}'
		}

		select {
			res := <-ch {
				fetch_res = res
			}
			30 * time.second {
				// use default timeout value
			}
		}

		if fetch_res.is_err {
			log.error(fetch_res.err_msg)
			w.queue_command(fn [url] (mut w Window) {
				w.view_state.active_downloads.delete(url)
			})
			return
		}

		// Remove from active downloads (thread-safe)
		w.queue_command(fn [url] (mut w Window) {
			w.view_state.active_downloads.delete(url)
			w.update_window()
		})
	}()
}

// image creates a new image view from the provided configuration.
// It displays the specified image file. Supports local paths and remote http/https URLs.
// Remote images are cached locally and validated (max 50MB, image/* type).
// If cfg.invisible is true, it returns an invisible ContainerView instead.
pub fn image(cfg ImageCfg) View {
	if cfg.invisible {
		return invisible_container_view()
	}
	return ImageView{
		id:         cfg.id
		src:        cfg.src
		width:      cfg.width
		min_width:  cfg.min_width
		max_width:  cfg.max_width
		height:     cfg.height
		min_height: cfg.min_height
		max_height: cfg.max_height
		invisible:  cfg.invisible
		on_click:   cfg.left_click()
		on_hover:   cfg.on_hover
	}
}

fn (cfg &ImageCfg) left_click() fn (&Layout, mut Event, mut Window) {
	if cfg.on_click == unsafe { nil } {
		return cfg.on_click
	}
	on_click := cfg.on_click
	return fn [on_click] (layout &Layout, mut e Event, mut w Window) {
		if e.mouse_button == .left {
			on_click(layout, mut e, mut w)
		}
	}
}
