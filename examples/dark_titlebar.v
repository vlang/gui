import gui

// set Windows window bar as dark color with dark theme
// =============================

fn main() {
	mut window := gui.window(
		width:   500
		height:  300
		on_init: fn (mut w gui.Window) {}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}
