import gui

const image_url = 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=300&h=300&fit=crop&crop=face'

fn main() {
	mut window := gui.window(
		width:   820
		height:  500
		title:   'Image Clip Demo'
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark)
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
		spacing: 30
		content: [
			gui.text(text: 'Image Clipping Demo', text_style: gui.theme().b1),
			gui.row(
				h_align: .center
				v_align: .middle
				spacing: 30
				content: [
					// Non-clipped
					label_group('No clip', gui.column(
						width:   120
						height:  120
						sizing:  gui.fixed_fixed
						padding: gui.padding_none
						content: [
							gui.image(
								src:    image_url
								width:  120
								height: 120
								sizing: gui.fixed_fixed
							),
						]
					)),
					// Rounded rectangle clip
					label_group('radius: 20', gui.column(
						clip:    true
						radius:  20
						width:   120
						height:  120
						sizing:  gui.fixed_fixed
						padding: gui.padding_none
						content: [
							gui.image(
								src:    image_url
								width:  120
								height: 120
								sizing: gui.fixed_fixed
							),
						]
					)),
					// Large radius clip
					label_group('radius: 40', gui.column(
						clip:    true
						radius:  40
						width:   120
						height:  120
						sizing:  gui.fixed_fixed
						padding: gui.padding_none
						color_border: gui.green
						size_border: 2
						content: [
							gui.image(
								src:    image_url
								width:  120
								height: 120
								sizing: gui.fixed_fixed
							),
						]
					)),
					// Circle clip
					label_group('circle\nborder\npadding', gui.circle(
						clip:    true
						width:   120
						height:  120
						sizing:  gui.fixed_fixed
						color_border: gui.green
						size_border: 2
						content: [
							gui.image(
								src:    image_url
								width:  120
								height: 120
								sizing: gui.fixed_fixed
							),
						]
					)),
					// Small circle
					label_group('small circle', gui.circle(
						clip:    true
						width:   60
						height:  60
						sizing:  gui.fixed_fixed
						padding: gui.padding_none
						content: [
							gui.image(
								src:    image_url
								width:  60
								height: 60
								sizing: gui.fixed_fixed
							),
						]
					)),
				]
			),
		]
	)
}

fn label_group(label string, content gui.View) gui.View {
	return gui.column(
		h_align: .center
		spacing: 8
		content: [
			content,
			gui.text(text: label, text_style: gui.theme().b2, mode: .multiline),
		]
	)
}
