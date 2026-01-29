// Tiger example demonstrates v-gui's SVG rendering capabilities using the classic
// Ghostscript Tiger - a standard SVG test image with 240 paths featuring transforms,
// strokes, and nested groups.
//
// The tiger.svg file must be in the same directory as the executable.
// Download from: https://commons.wikimedia.org/wiki/File:Ghostscript_Tiger.svg
import gui
import os

fn main() {
	exe_dir := os.dir(os.executable())
	svg_path := os.join_path(exe_dir, 'tiger.svg')

	mut window := gui.window(
		title:   'Ghostscript Tiger'
		width:   500
		height:  550
		on_init: fn [svg_path] (mut w gui.Window) {
			w.update_view(fn [svg_path] (window &gui.Window) gui.View {
				return gui.column(
					padding: gui.Padding{10, 10, 10, 10}
					spacing: 10
					content: [
						gui.text(text: 'Ghostscript Tiger', text_style: gui.theme().b1),
						gui.svg(file_name: svg_path, width: 450, height: 450),
					]
				)
			})
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}
