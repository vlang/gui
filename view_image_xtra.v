module gui

import gg
import os

type Image = gg.Image

const valid_image_extensions = ['.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp']

fn validate_image_extension(file_name string) ! {
	ext := os.file_ext(file_name).to_lower()
	if ext !in valid_image_extensions {
		return error('unsupported image format: ${ext}')
	}
}

// load_image loads an image from disk with path validation.
// Images are cached so calling this multiple times is performant.
// see `remove_image_from_cache()` and `remove_image_from_cache_by_file_name`
pub fn (mut window Window) load_image(file_name string) !&Image {
	if file_name.contains('..') {
		return error('invalid image path: contains ..')
	}
	validate_image_extension(file_name)!
	return window.load_image_no_validate(file_name)
}

// load_image_no_validate loads an image without path validation.
// Use when you trust the source or need to bypass security checks.
pub fn (mut window Window) load_image_no_validate(file_name string) !&Image {
	real_path := os.real_path(file_name)
	mut ctx := window.context()
	return ctx.get_cached_image_by_idx(window.view_state.image_map.get(real_path) or {
		image := ctx.create_image(file_name)! // ctx.create_image caches images
		window.view_state.image_map.set(real_path, image.id, mut ctx)
		return &image
	})
}

// remove_image_from_cache removes the given image from cache.
// Does nothing if not in cache.
pub fn (mut window Window) remove_image_from_cache(image &Image) {
	mut ctx := window.context()
	ctx.remove_cached_image_by_idx(image.id)
	for key in window.view_state.image_map.keys() {
		if value := window.view_state.image_map.get(key) {
			if value == image.id {
				window.view_state.image_map.delete(key)
				break
			}
		}
	}
}

// remove_image_from_cache_by_file_name removes a previously cached image.
// Does nothing if not in cache.
pub fn (mut window Window) remove_image_from_cache_by_file_name(file_name string) {
	real_path := os.real_path(file_name)
	image_idx := window.view_state.image_map.get(real_path) or { return }
	window.view_state.image_map.delete(real_path)
	mut ctx := window.context()
	ctx.remove_cached_image_by_idx(image_idx)
}

// BoundedImageMap stores image paths -> cache IDs with eviction cleanup.
// On eviction, removes cached image from graphics context.
struct BoundedImageMap {
mut:
	data     map[string]int
	order    []string
	max_size int = 100
}

// set adds or updates image cache entry. Evicts oldest with cleanup if at capacity.
fn (mut m BoundedImageMap) set(key string, value int, mut ctx gg.Context) {
	if m.max_size < 1 {
		return
	}
	if key in m.data {
		m.data[key] = value
		return
	}
	if m.data.len >= m.max_size && m.order.len > 0 {
		oldest_key := m.order[0]
		if oldest_id := m.data[oldest_key] {
			ctx.remove_cached_image_by_idx(oldest_id)
		}
		m.data.delete(oldest_key)
		m.order.delete(0)
	}
	m.order << key
	m.data[key] = value
}

// get returns cache ID for image path, or none if not found.
fn (m &BoundedImageMap) get(key string) ?int {
	return m.data[key] or { return none }
}

// contains returns true if image path is cached.
fn (m &BoundedImageMap) contains(key string) bool {
	return key in m.data
}

// delete removes image from cache tracking (does not remove from graphics context).
fn (mut m BoundedImageMap) delete(key string) {
	if key !in m.data {
		return
	}
	m.data.delete(key)
	for i, item in m.order {
		if item == key {
			m.order.delete(i)
			break
		}
	}
}

// keys returns all cached image paths in insertion order.
fn (m &BoundedImageMap) keys() []string {
	return m.order.clone()
}

// len returns number of cached images.
fn (m &BoundedImageMap) len() int {
	return m.data.len
}

// clear removes all entries with graphics context cleanup.
fn (mut m BoundedImageMap) clear(mut ctx gg.Context) {
	for _, id in m.data {
		ctx.remove_cached_image_by_idx(id)
	}
	m.data.clear()
	array_clear(mut m.order)
}
