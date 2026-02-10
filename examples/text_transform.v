import gui
import vglyph

@[heap]
fn main() {
	mut window := gui.window(
		width:   760
		height:  420
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
		padding: gui.padding_large
		spacing: gui.spacing_large
		content: [
			gui.text(text: 'Text transforms', text_style: gui.theme().b1),
			gui.text(
				text:       'Rotated text via TextStyle.rotation_radians'
				text_style: gui.TextStyle{
					...gui.theme().b2
					rotation_radians: 0.35
				}
			),
			gui.text(
				text:       'Affine text: skew + translate'
				text_style: gui.TextStyle{
					...gui.theme().b2
					affine_transform: vglyph.AffineTransform{
						xx: 1.0
						xy: -0.35
						yx: 0.15
						yy: 1.0
						x0: 24
						y0: 6
					}
				}
			),
			gui.rtf(
				mode:      .wrap
				rich_text: gui.RichText{
					runs: [
						gui.RichTextRun{
							text:  'RTF '
							style: gui.TextStyle{
								...gui.theme().b2
								rotation_radians: -0.2
							}
						},
						gui.RichTextRun{
							text:  'uniform '
							style: gui.TextStyle{
								...gui.theme().b2
								rotation_radians: -0.2
							}
						},
						gui.RichTextRun{
							text:  'transform'
							style: gui.TextStyle{
								...gui.theme().b2
								rotation_radians: -0.2
								underline:        true
							}
						},
					]
				}
			),
			gui.text(
				text:       'Focusable text (id_focus > 0) disables transforms.'
				id_focus:   1
				mode:       .wrap
				text_style: gui.TextStyle{
					...gui.theme().n4
					rotation_radians: 0.35
				}
			),
		]
	)
}
