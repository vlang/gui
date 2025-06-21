import gui
import gui.titlebar
import sokol.sapp

// set Windows window bar as dark color
// =============================

fn main() {
	mut window := gui.window(
		width:   500
		height:  300
		on_init: fn (mut w gui.Window) {
			$if windows {
				titlebar.prefer_dark_titlebar(sapp.win32_get_hwnd(), true)
			}
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}
