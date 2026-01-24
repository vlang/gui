import gui

fn main() {
	mut window := gui.window(
		title:   'Gaussian Blur / Glow Demo'
		width:   800
		height:  800
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_no_padding)
	window.run()
}

fn main_view(mut w gui.Window) gui.View {
	return gui.column(
		sizing:  gui.fit_fit
		spacing: 60
		padding: gui.Padding{40, 40, 40, 40}
		h_align: .center
		content: [
			gui.text(
				text:       'Soft Shapes & Glows'
				text_style: gui.TextStyle{
					size:  30
					color: gui.white
				}
			),
			gui.row(
				spacing: 40
				content: [
					gui.column(
						width:       150
						height:      150
						radius:      75 // Circle
						fill:        true
						color:       gui.Color{0, 255, 0, 150}
						blur_radius: 20 // Soft Green Glow / Orb
						h_align:     .center
						v_align:     .middle
						content:     [gui.text(text: 'Soft Orb')]
					),
					gui.column(
						width:       150
						height:      150
						radius:      20
						fill:        true
						color:       gui.Color{255, 100, 100, 200}
						blur_radius: 10 // Soft Rounded Rect
						h_align:     .center
						v_align:     .middle
						content:     [gui.text(text: 'Soft Rect')]
					),
				]
			),
			gui.row(
				spacing: 40
				content: [
					gui.column(
						width:       200
						height:      100
						radius:      10
						fill:        true
						color:       gui.blue
						blur_radius: 50 // Large blur
						h_align:     .center
						v_align:     .middle
						content:     [gui.text(text: 'Heavy Glow')]
					),
				]
			),
		]
	)
}
