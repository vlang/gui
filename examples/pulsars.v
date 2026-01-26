import gui

// Pulsars
// =============================
// pulsar creates a blinking icon

fn main() {
	mut window := gui.window(
		title:        'Pulsars'
		width:        400
		height:       200
		cursor_blink: true // pulsars require the cursor animation
		on_init:      fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(mut window gui.Window) gui.View {
	w, h := window.window_size()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		h_align: .center
		v_align: .middle
		content: [
			gui.text(
				text:       'Pulsars blink to get attention!'
				text_style: gui.theme().b1
			),
			pulsar_samples(mut window),
		]
	)
}

fn pulsar_samples(mut w gui.Window) gui.View {
	pulsar_width := f32(30)
	return gui.row(
		color_border: gui.theme().text_style.color
		padding:      gui.padding_large
		content:      [
			w.pulsar(width: pulsar_width),
			w.pulsar(
				width: pulsar_width
				size:  20
			),
			w.pulsar(
				width: pulsar_width
				size:  30
				color: gui.orange
			),
			w.pulsar(
				width: pulsar_width
				size:  30
				icon1: gui.icon_elipsis_v
				icon2: gui.icon_elipsis_h
				color: gui.royal_blue
			),
			w.pulsar(
				width: pulsar_width
				size:  30
				icon1: gui.icon_heart
				icon2: gui.icon_heart_o
				color: gui.red
			),
			w.pulsar(
				width: pulsar_width
				size:  30
				icon1: gui.icon_expand
				icon2: gui.icon_compress
				color: gui.green
			),
		]
	)
}
