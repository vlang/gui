import gui
import gui.titlebar

// set Windows window bar as dark color
// =============================

fn main() {
	mut window := gui.window(
		width:   500
		height:  300
		on_init: fn (mut w gui.Window) {
			titlebar.set_dark_titlebar(true)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}
