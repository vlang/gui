import gui

const color_bg = gui.Color{240, 240, 245, 255}

fn main() {
	mut window := gui.window(
		title:    'Drop Shadow Demo'
		width:    800
		height:   800
		bg_color: color_bg
		on_init:  fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.run()
}

fn main_view(window &gui.Window) gui.View {
	return gui.column(
		sizing:  gui.fit_fit
		spacing: 40
		padding: gui.pad_all(40)
		h_align: .center
		content: [
			gui.text(
				text:       'Drop Shadow Demo'
				text_style: gui.TextStyle{
					size: 30
				}
			),
			gui.row(
				spacing: 40
				content: [
					// Card 1: Soft shadow
					gui.column(
						width:  200
						height: 150
						radius: 10
						color:  gui.black

						shadow:  gui.BoxShadow{
							blur_radius: 10
							offset_y:    4
							color:       gui.Color{0, 0, 0, 30}
						}
						h_align: .center
						v_align: .middle
						content: [
							gui.text(
								text:       'Soft Shadow\n(Blur: 10, OffsetY: 4)'
								text_style: gui.TextStyle{
									color: gui.black
									align: .center
								}
							),
						]
					),
					// Card 2: Hard shadow (Material style)
					gui.column(
						width:  200
						height: 150
						radius: 10
						color:  gui.black

						shadow:  gui.BoxShadow{
							blur_radius: 20
							offset_y:    10
							color:       gui.Color{0, 0, 0, 40}
						}
						h_align: .center
						v_align: .middle
						content: [
							gui.text(
								text:       'Material Elevation\n(Blur: 20, OffsetY: 10)'
								text_style: gui.TextStyle{
									color: gui.black
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
					// Card 3: Colored Glow
					gui.column(
						width:  200
						height: 150
						radius: 10
						color:  gui.black

						shadow:  gui.BoxShadow{
							blur_radius: 30
							color:       gui.Color{100, 100, 255, 100}
						}
						h_align: .center
						v_align: .middle
						content: [
							gui.text(
								text:       'Blue Glow\n(Blur: 30, Color: Blue)'
								text_style: gui.TextStyle{
									color: gui.black
									align: .center
								}
							),
						]
					),
					// Card 4: Offset Shadow
					gui.column(
						width:  200
						height: 150
						radius: 10
						color:  gui.black

						shadow:  gui.BoxShadow{
							blur_radius: 0
							offset_x:    10
							offset_y:    10
							color:       gui.Color{0, 0, 0, 100}
						}
						h_align: .center
						v_align: .middle
						content: [
							gui.text(
								text:       'Hard Offset\n(Blur: 0, X: 10, Y: 10)'
								text_style: gui.TextStyle{
									color: gui.black
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
					// Card 5: Blue Background
					gui.column(
						width:  200
						height: 150
						radius: 10
						color:  gui.light_blue
						fill:   true

						shadow:  gui.BoxShadow{
							blur_radius: 15
							offset_y:    5
							color:       gui.Color{0, 0, 0, 50}
						}
						h_align: .center
						v_align: .middle
						content: [
							gui.text(
								text:       'Blue BG\n(Blur: 15, OffsetY: 5)'
								text_style: gui.TextStyle{
									color: gui.black
									align: .center
								}
							),
						]
					),
					// Card 6: Orange Background
					gui.column(
						width:  200
						height: 150
						radius: 10
						color:  gui.orange
						fill:   true

						shadow:  gui.BoxShadow{
							blur_radius: 20
							offset_y:    8
							color:       gui.Color{0, 0, 0, 60}
						}
						h_align: .center
						v_align: .middle
						content: [
							gui.text(
								text:       'Orange BG\n(Blur: 20, OffsetY: 8)'
								text_style: gui.TextStyle{
									color: gui.black
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
