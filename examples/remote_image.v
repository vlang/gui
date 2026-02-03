import gui
import os
import hash

const image_url = 'https://www.google.com/images/branding/googlelogo/2x/googlelogo_color_272x92dp.png'

fn main() {
	// Clear cache to force download
	hash_sum := hash.sum64(image_url.bytes(), 0).hex()
	ext := os.file_ext(image_url)
	cache_path := os.join_path(os.temp_dir(), 'gui_cache', 'images', '${hash_sum}${ext}')
	if os.exists(cache_path) {
		println('Removing cached image to test download: ${cache_path}')
		os.rm(cache_path) or { println('Failed to remove cache: ${err}') }
	}

	mut window := gui.window(
		width:   800
		height:  600
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		h_align: .center
		v_align: .middle
		spacing: 20
		content: [
			gui.text(text: 'Remote Image Test', text_style: gui.theme().b1),
			gui.image(
				width: 300
				src:   image_url
			),
			gui.text(
				text:       'If you see the Google logo above, it worked!'
				text_style: gui.theme().b2
			),
		]
	)
}
