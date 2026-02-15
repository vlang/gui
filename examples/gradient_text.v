import gg
import gui
import vglyph

const rainbow = &vglyph.GradientConfig{
	stops: [
		vglyph.GradientStop{
			color:    gg.Color{255, 0, 0, 255}
			position: 0.0
		},
		vglyph.GradientStop{
			color:    gg.Color{255, 200, 0, 255}
			position: 0.33
		},
		vglyph.GradientStop{
			color:    gg.Color{0, 180, 255, 255}
			position: 0.66
		},
		vglyph.GradientStop{
			color:    gg.Color{180, 0, 255, 255}
			position: 1.0
		},
	]
}

const sunset = &vglyph.GradientConfig{
	stops:     [
		vglyph.GradientStop{
			color:    gg.Color{255, 60, 60, 255}
			position: 0.0
		},
		vglyph.GradientStop{
			color:    gg.Color{255, 140, 50, 255}
			position: 0.33
		},
		vglyph.GradientStop{
			color:    gg.Color{255, 200, 80, 255}
			position: 0.66
		},
		vglyph.GradientStop{
			color:    gg.Color{180, 80, 200, 255}
			position: 1.0
		},
	]
	direction: .vertical
}

@[heap]
fn main() {
	mut window := gui.window(
		width:   800
		height:  500
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
			gui.text(
				text:       'Horizontal Rainbow Gradient'
				text_style: gui.TextStyle{
					...gui.theme().b1
					size:     gui.size_text_x_large
					gradient: rainbow
				}
			),
			gui.text(
				text:       'Vertical Sunset Gradient'
				text_style: gui.TextStyle{
					...gui.theme().b1
					size:     gui.size_text_x_large
					gradient: sunset
				}
			),
			gui.text(
				text:       'Gradient colors interpolate smoothly across ' +
					'the full layout, spanning multiple lines of ' +
					'wrapped text to demonstrate the effect.'
				mode:       .wrap
				text_style: gui.TextStyle{
					...gui.theme().b1
					gradient: rainbow
				}
			),
		]
	)
}
