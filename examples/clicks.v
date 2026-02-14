@[has_globals]
module main

import gui

__global clicks = 0

fn main() {
	mut window := gui.window(
		title:   'Click the button:'
		width:   300
		height:  40
		on_init: fn (mut w gui.Window) {
			w.update_view(fn (mut window gui.Window) gui.View {
				return gui.button(
					padding:  gui.pad_tblr(5, 120)
					content:  [gui.text(text: 'Clicks: ${clicks}')]
					on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
						clicks++
					}
				)
			})
		}
	)
	window.run()
}
