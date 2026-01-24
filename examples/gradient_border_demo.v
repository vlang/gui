import gui

fn main() {
	mut window := gui.window(
		title:   'Gradient Borders Demo'
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
				text:       'Gradient Borders'
				text_style: gui.TextStyle{
					size: 30
				}
			),
			gui.row(
				spacing: 40
				content: [
					gui.column(
						width:           200
						height:          100
						radius:          10
						fill:            false // Hollow, just border
						border_gradient: &gui.Gradient{
							stops: [
								gui.GradientStop{
									color: gui.red
									pos:   0.0
								},
								gui.GradientStop{
									color: gui.blue
									pos:   1.0
								},
							]
						}
						h_align:         .center
						v_align:         .middle
						content:         [
							gui.text(text: 'Linear Border'),
						]
					),
					gui.column(
						width:           150
						height:          150
						radius:          75 // Circle
						fill:            false
						border_gradient: &gui.Gradient{
							stops: [
								gui.GradientStop{
									color: gui.green
									pos:   0.0
								},
								gui.GradientStop{
									color: gui.purple
									pos:   1.0
								},
							]
						}
						h_align:         .center
						v_align:         .middle
						content:         [
							gui.text(text: 'Circle Border'),
						]
					),
				]
			),
		]
	)
}
