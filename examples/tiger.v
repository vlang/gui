// Tiger example demonstrates v-gui's SVG rendering capabilities using the classic
// Ghostscript Tiger - a standard SVG test image with 240 paths featuring transforms,
// strokes, and nested groups.
import gui

const tiger_svg = $embed_file('../assets/svgs/tiger.svg').to_string()

fn main() {
	mut window := gui.window(
		title:   'Ghostscript Tiger'
		width:   500
		height:  550
		on_init: fn (mut w gui.Window) {
			w.update_view(fn (window &gui.Window) gui.View {
				return gui.column(
					padding: gui.Padding{10, 10, 10, 10}
					spacing: 10
					content: [
						gui.text(text: 'Ghostscript Tiger', text_style: gui.theme().b1),
						gui.svg(svg_data: tiger_svg, width: 450, height: 450),
					]
				)
			})
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}
