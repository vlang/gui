import gui

@[heap]
struct GradientDemoApp {
pub mut:
	direction        u8
	grad_blue_purple gui.Gradient = gui.Gradient{
		stops: [
			gui.GradientStop{
				color: gui.blue
				pos:   0.0
			},
			gui.GradientStop{
				color: gui.purple
				pos:   1.0
			},
		]
	}
	grad_red_orange  gui.Gradient = gui.Gradient{
		stops: [
			gui.GradientStop{
				color: gui.red
				pos:   0.0
			},
			gui.GradientStop{
				color: gui.orange
				pos:   1.0
			},
		]
	}
	grad_green_blue  gui.Gradient = gui.Gradient{
		stops: [
			gui.GradientStop{
				color: gui.green
				pos:   0.0
			},
			gui.GradientStop{
				color: gui.blue
				pos:   1.0
			},
		]
	}
}

fn main() {
	mut window := gui.window(
		state:   &GradientDemoApp{}
		title:   'Gradient Demo'
		width:   800
		height:  800
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_light_no_padding) // Dark theme to see white issues better
	window.run()
}

fn main_view(mut w gui.Window) gui.View {
	mut app := w.state[GradientDemoApp]()

	return gui.column(
		sizing:  gui.fit_fit
		spacing: 40
		padding: gui.Padding{40, 40, 40, 40}
		h_align: .center
		content: [
			gui.text(
				text:       'Gradient Fills'
				text_style: gui.TextStyle{
					size: 30
				}
			),
			gui.row(
				spacing: 40
				content: [
					// Card 1: Horizontal Gradient
					gui.column(
						width:    200
						height:   150
						radius:   15
						gradient: &app.grad_blue_purple
						fill:     true
						h_align:  .center
						v_align:  .middle
						content:  [
							gui.text(
								text:       'Linear Horizontal\n(Blue -> Purple)'
								text_style: gui.TextStyle{
									color: gui.white
									align: .center
								}
							),
						]
					),
					// Card 2: Vertical Gradient
					gui.column(
						width:    200
						height:   150
						radius:   15
						gradient: &app.grad_red_orange
						fill:     true
						h_align:  .center
						v_align:  .middle
						content:  [
							gui.text(
								text:       'Linear Horizontal\n(Red -> Orange)'
								text_style: gui.TextStyle{
									color: gui.white
									align: .center
								}
							),
						]
					),
				]
			),
			gui.row(
				spacing: 40
				content: [
					// Card 3: Another one
					gui.column(
						width:    200
						height:   150
						radius:   15
						gradient: &app.grad_green_blue
						fill:     true
						shadow:   gui.BoxShadow{
							blur_radius: 20
							color:       gui.Color{0, 0, 0, 50}
							offset_y:    5
						}
						h_align:  .center
						v_align:  .middle
						content:  [
							gui.text(
								text:       'Gradient + Shadow'
								text_style: gui.TextStyle{
									color: gui.white
									align: .center
								}
							),
						]
					),
				]
			),
		]
	)
}
