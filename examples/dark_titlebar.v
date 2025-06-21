import gui
import gui.titlebar

// set Windows window bar as dark color
// =============================

@[heap]
struct DropFilesApp {
pub mut:
	dropped_files []string
}

fn main() {
	mut window := gui.window(
		state:   &DropFilesApp{}
		width:   500
		height:  300
		on_init: fn (mut w gui.Window) {
			$if windows {
				titlebar.prefer_dark_titlebar(nil, true) // todo get handle from window
			}
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}
