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

fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		h_align: .center
		v_align: .middle
		content: [
			gui.rtf(
				mode:      .wrap
				rich_text: gui.RichText{
					runs: [
						gui.rich_run('Hello', gui.theme().n3),
						gui.rich_run(' RTF ', gui.theme().b3),
						gui.rich_run('World', gui.theme().n3),
						gui.rich_br(),
						gui.rich_br(),
						gui.RichTextRun{
							text:  'Now is the'
							style: gui.TextStyle{
								...gui.theme().n3
								strikethrough: true
							}
						},
						gui.rich_run(' ', gui.theme().n3),
						gui.RichTextRun{
							text:  'time'
							style: gui.theme().i3
						},
						gui.rich_run(' for all good men to come to the aid of their ',
							gui.theme().n3),
						gui.RichTextRun{
							text:  'country'
							style: gui.TextStyle{
								...gui.theme().b3
								underline: true
							}
						},
						gui.rich_br(),
						gui.rich_br(),
						gui.rich_run('This is a ', gui.theme().n3),
						gui.rich_link('hyperlink', 'https://vlang.io', gui.theme().n3),
					]
				}
			),
		]
	)
}
