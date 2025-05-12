module gui

import gg

type Image = gg.Image

pub fn (mut window Window) load_image_from_file(file_name string) !&Image {
	mut ctx := window.context()

	return ctx.get_cached_image_by_idx(window.view_state.image_map[file_name] or {
		image := ctx.create_image(file_name)!
		window.view_state.image_map[file_name] = ctx.cache_image(image)
		window.view_state.image_map[file_name]
	})
}
