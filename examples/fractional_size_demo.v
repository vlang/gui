import gui

fn main() {
	mut window := gui.window(
		title:   'Fractional Size Demo'
		width:   800
		height:  800
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.run()
}

fn main_view(window &gui.Window) gui.View {
	sizes := [f32(10.0), 10.5, 11.0, 11.2, 11.5, 11.8, 12.0, 12.25, 12.5, 12.75, 13.0, 14.0]
	mut texts := []gui.View{}

	for size in sizes {
		texts << gui.text(
			text:       'Size ${size:.2f}: The quick brown fox jumps over the lazy dog.'
			text_style: gui.TextStyle{
				size:   size
				color:  gui.white
				family: 'Normal'
			}
		)
	}

	return gui.column(
		content:     texts
		scroll_mode: .vertical_only
		id_scroll:   1
		padding:     gui.padding(20, 20, 20, 20)
		spacing:     10
	)
}
