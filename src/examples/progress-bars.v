import gui

fn main() {
	mut window := gui.window(
		width:   300
		height:  300
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
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
		content: [
			gui.progress_bar(
				height:  2
				sizing:  gui.fill_fixed
				percent: 0.20
			),
			gui.progress_bar(
				sizing:  gui.fill_fixed
				percent: 0.40
			),
			gui.progress_bar(
				height:  20
				sizing:  gui.fill_fixed
				percent: 0.60
			),
			gui.row(
				sizing:  gui.fit_fill
				content: [
					gui.progress_bar(
						vertical: true
						sizing:   gui.fixed_fill
						width:    2
						percent:  0.40
					),
					gui.progress_bar(
						vertical: true
						sizing:   gui.fixed_fill
						percent:  0.60
					),
					gui.progress_bar(
						vertical: true
						sizing:   gui.fixed_fill
						width:    20
						percent:  0.80
					),
				]
			),
		]
	)
}
