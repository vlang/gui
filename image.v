module gui

import gg

type Image = gg.Image

// load_image loads an image from disk.
// Images are cached so calling this multiple times is performant.
// see `remove_image_from_cache()` and `remove_image_from_cache_by_file_name`
pub fn (mut window Window) load_image(file_name string) !&Image {
	mut ctx := window.context()

	return ctx.get_cached_image_by_idx(window.view_state.image_map[file_name] or {
		image := ctx.create_image(file_name)!
		window.view_state.image_map[file_name] = image.id
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

// remove_image_from_cache_by_file_name removes a perviously cached image.
// Does nothing if not in cache.
pub fn (mut window Window) remove_image_from_cache_by_file_name(file_name string) {
	image_idx := window.view_state.image_map[file_name] or { return }
	window.view_state.image_map.delete(file_name)
	mut ctx := window.context()
	ctx.remove_cached_image_by_idx(image_idx)
}
