import gui

@[heap]
struct ShadowDemoApp {
pub mut:
	light_theme bool = true
}

fn main() {
	mut window := gui.window(
		state:   &ShadowDemoApp{}
		title:   'Drop Shadow Demo'
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
	app := w.state[ShadowDemoApp]()

	return gui.column(
		sizing:  gui.fit_fit
		spacing: 40
		padding: gui.Padding{10, 40, 40, 40}
		h_align: .center
		content: [
			gui.row(
				padding: gui.padding_none
				content: [
					gui.text(
						text:       'Drop Shadow Demo'
						text_style: gui.TextStyle{
							size: 30
						}
					),
					gui.rectangle(width: 100),
					app.toggle_theme(),
				]
			),
			gui.row(
				spacing: 40
				content: [
					// Card 1: Soft shadow
					gui.column(
						width:   200
						height:  150
						radius:  10
						color:   gui.black
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
						width:   200
						height:  150
						radius:  10
						color:   gui.black
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
						width:   200
						height:  150
						radius:  10
						color:   gui.black
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
						width:   200
						height:  150
						radius:  10
						color:   gui.black
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
						width:   200
						height:  150
						radius:  10
						color:   gui.light_blue
						fill:    true
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
						width:   200
						height:  150
						radius:  10
						color:   gui.orange
						fill:    true
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

fn (app &ShadowDemoApp) toggle_theme() gui.View {
	return gui.row(
		h_align: .end
		sizing:  gui.fill_fit
		padding: gui.padding_none
		spacing: 10
		v_align: .middle
		content: [
			gui.toggle(
				text_select:   gui.icon_moon
				text_unselect: gui.icon_sunny_o
				text_style:    gui.theme().icon3
				select:        app.light_theme
				padding:       gui.padding_small
				on_click:      fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
					mut a := w.state[ShadowDemoApp]()
					theme := match a.light_theme {
						true { gui.theme_dark_no_padding }
						else { gui.theme_light_no_padding }
					}
					a.light_theme = !a.light_theme
					w.set_theme(theme)
				}
			),
		]
	)
}
