import gui

@[heap]
struct GradientDemoApp {
pub mut:
	direction          gui.GradientDirection = .to_bottom
	grad_blue_purple   gui.Gradient
	grad_red_orange    gui.Gradient
	grad_green_blue    gui.Gradient
	grad_radial_square gui.Gradient
	grad_radial_wide   gui.Gradient
	grad_radial_tall   gui.Gradient
}

fn (mut app GradientDemoApp) init_gradients() {
	app.grad_blue_purple = gui.Gradient{
		direction: app.direction
		stops:     [
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
	app.grad_red_orange = gui.Gradient{
		direction: app.direction
		stops:     [
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
	app.grad_green_blue = gui.Gradient{
		direction: app.direction
		stops:     [
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
	app.grad_radial_square = gui.Gradient{
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
	app.grad_radial_wide = gui.Gradient{
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
	app.grad_radial_tall = gui.Gradient{
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

fn direction_name(d gui.GradientDirection) string {
	return match d {
		.to_top { 'to_top' }
		.to_top_right { 'to_top_right' }
		.to_right { 'to_right' }
		.to_bottom_right { 'to_bottom_right' }
		.to_bottom { 'to_bottom' }
		.to_bottom_left { 'to_bottom_left' }
		.to_left { 'to_left' }
		.to_top_left { 'to_top_left' }
	}
}

fn main() {
	mut app := &GradientDemoApp{}
	app.init_gradients()
	mut window := gui.window(
		state:   app
		title:   'Gradient Demo'
		width:   1000
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

	dir_options := [
		gui.radio_option('to_top', 'to_top'),
		gui.radio_option('to_top_right', 'to_top_right'),
		gui.radio_option('to_right', 'to_right'),
		gui.radio_option('to_bottom_right', 'to_bottom_right'),
		gui.radio_option('to_bottom', 'to_bottom'),
		gui.radio_option('to_bottom_left', 'to_bottom_left'),
		gui.radio_option('to_left', 'to_left'),
		gui.radio_option('to_top_left', 'to_top_left'),
	]

	return gui.row(
		width:           ww
		height:          wh
		sizing:          gui.fixed_fixed
		id_scroll:       1
		scrollbar_cfg_y: &gui.ScrollbarCfg{
			overflow: .auto
		}
		spacing:         40
		padding:         gui.Padding{40, 40, 40, 40}
		content:         [
			gui.radio_button_group_column(
				title:        'Direction'
				value:        direction_name(app.direction)
				options:      dir_options
				id_focus:     1
				size_border:  1
				color_border: gui.dark_gray
				on_select:    fn (value string, mut w gui.Window) {
					mut a := w.state[GradientDemoApp]()
					a.direction = match value {
						'to_top' { gui.GradientDirection.to_top }
						'to_top_right' { .to_top_right }
						'to_right' { .to_right }
						'to_bottom_right' { .to_bottom_right }
						'to_bottom' { .to_bottom }
						'to_bottom_left' { .to_bottom_left }
						'to_left' { .to_left }
						'to_top_left' { .to_top_left }
						else { .to_bottom }
					}
					a.init_gradients()
				}
			),
			gui.column(
				spacing: 20
				h_align: .center
				content: [
					gui.text(
						text:       'Linear Gradients'
						text_style: gui.TextStyle{
							size: 30
						}
					),
					gui.column(
						width:    200
						height:   150
						radius:   15
						gradient: &app.grad_blue_purple
						h_align:  .center
						v_align:  .middle
						content:  [
							gui.text(
								text:       'Blue -> Purple'
								text_style: gui.TextStyle{
									color: gui.white
									align: .center
								}
							),
						]
					),
					gui.column(
						width:    200
						height:   150
						radius:   15
						gradient: &app.grad_red_orange
						h_align:  .center
						v_align:  .middle
						content:  [
							gui.text(
								text:       'Red -> Orange'
								text_style: gui.TextStyle{
									color: gui.white
									align: .center
								}
							),
						]
					),
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
			gui.rectangle(
				width:  3
				color:  gui.gray
				sizing: gui.fit_fill
			),
			gui.column(
				spacing: 40
				h_align: .center
				content: [
					gui.text(
						text:       'Radial Gradients'
						text_style: gui.TextStyle{
							size: 30
						}
					),
					gui.row(
						spacing:      30
						color_border: gui.gray
						content:      [
							gui.column(
								width:    100
								height:   300
								radius:   0
								gradient: &app.grad_radial_tall
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
							gui.column(
								width:    200
								height:   200
								radius:   0
								gradient: &app.grad_radial_square
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
						]
					),
					gui.row(
						spacing: 40
						content: [
							gui.column(
								width:    300
								height:   100
								radius:   0
								gradient: &app.grad_radial_wide
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
				]
			),
		]
	)
}
