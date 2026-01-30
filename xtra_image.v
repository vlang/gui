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
	return ctx.get_cached_image_by_idx(window.view_state.image_map[real_path] or {
		image := ctx.create_image(file_name)! // ctx.create_image caches images
		window.view_state.image_map[real_path] = image.id
		return &image
	})
}

// remove_image_from_cache removes the given image from cache.
// Does nothing if not in cache.
pub fn (mut window Window) remove_image_from_cache(image &Image) {
	mut ctx := window.context()
	ctx.remove_cached_image_by_idx(image.id)
	for key, value in window.view_state.image_map {
		if value == image.id {
			window.view_state.image_map.delete(key)
			break
		}
	}
}

// remove_image_from_cache_by_file_name removes a previously cached image.
// Does nothing if not in cache.
pub fn (mut window Window) remove_image_from_cache_by_file_name(file_name string) {
	real_path := os.real_path(file_name)
	image_idx := window.view_state.image_map[real_path] or { return }
	window.view_state.image_map.delete(real_path)
	mut ctx := window.context()
	ctx.remove_cached_image_by_idx(image_idx)
}
