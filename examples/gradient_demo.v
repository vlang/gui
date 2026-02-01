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
	// Radial gradient test cases
	radial_square gui.Gradient = gui.Gradient{
		type:  .radial
		stops: [
			gui.GradientStop{
				color: gui.red
				pos:   0.0
			},
			gui.GradientStop{
				color: gui.green
				pos:   0.5
			},
			gui.GradientStop{
				color: gui.blue
				pos:   1.0
			},
		]
	}
	radial_wide   gui.Gradient = gui.Gradient{
		type:  .radial
		stops: [
			gui.GradientStop{
				color: gui.yellow
				pos:   0.0
			},
			gui.GradientStop{
				color: gui.Color{0, 255, 255, 255}
				pos:   1.0
			},
		]
	}
	radial_tall   gui.Gradient = gui.Gradient{
		type:  .radial
		stops: [
			gui.GradientStop{
				color: gui.Color{255, 0, 255, 255}
				pos:   0.0
			},
			gui.GradientStop{
				color: gui.Color{0, 0, 0, 255}
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
	window.set_theme(gui.theme_light_no_padding)
	window.run()
}

fn main_view(mut w gui.Window) gui.View {
	mut app := w.state[GradientDemoApp]()
	ww, wh := w.window_size()

	return gui.column(
		width:           ww
		height:          wh
		sizing:          gui.fixed_fixed
		id_scroll:       1
		scrollbar_cfg_y: &gui.ScrollbarCfg{
			overflow: .auto
		}
		spacing:         40
		padding:         gui.Padding{40, 40, 40, 40}
		h_align:         .center
		content:         [
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
						shadow:   &gui.BoxShadow{
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
			// Radial gradient test section
			gui.text(
				text:       'Radial Gradients'
				text_style: gui.TextStyle{
					size: 30
				}
			),
			gui.row(
				spacing: 40
				content: [
					// Radial on square (200x200)
					gui.column(
						width:    200
						height:   200
						radius:   0
						gradient: &app.radial_square
						h_align:  .center
						v_align:  .middle
						content:  [
							gui.text(
								text:       'Square\n200x200'
								text_style: gui.TextStyle{
									color: gui.white
									align: .center
								}
							),
						]
					),
					// Radial on wide rect (300x100)
					gui.column(
						width:    300
						height:   100
						radius:   0
						gradient: &app.radial_wide
						h_align:  .center
						v_align:  .middle
						content:  [
							gui.text(
								text:       'Wide 300x100'
								text_style: gui.TextStyle{
									color: gui.Color{0, 0, 0, 255}
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
					// Radial on tall rect (100x300)
					gui.column(
						width:    100
						height:   300
						radius:   0
						gradient: &app.radial_tall
						h_align:  .center
						v_align:  .middle
						content:  [
							gui.text(
								text:       'Tall\n100x300'
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
