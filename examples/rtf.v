import gui

// Rich Text Format
// =============================
// RTF allows mixing different colors and fonts in the same text block.
// Hyperlinks are also supported.

@[heap]
fn main() {
	mut window := gui.window(
		width:   300
		height:  300
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(window &gui.Window) &gui.View {
	w, h := window.window_size()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		h_align: .center
		v_align: .middle
		content: [
			gui.rtf(
				mode:  .wrap
				spans: [
					gui.span('Hello', gui.theme().n3),
					gui.span(' RTF ', gui.theme().b3),
					gui.span('World', gui.theme().n3),
					gui.br(),
					gui.br(),
					gui.strike_span('Now is the', gui.theme().n3),
					gui.span(' ', gui.theme().n3),
					gui.span('time', gui.theme().i3),
					gui.span(' for all good men to come to the aid of their ', gui.theme().n3),
					gui.uspan('country', gui.theme().b3),
					gui.br(),
					gui.br(),
					gui.span('This is a ', gui.theme().n3),
					gui.hyperlink('hyperlink', 'https://vlang.io', gui.theme().n3),
				]
			),
		]
	)
}
