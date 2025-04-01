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
		width:    w
		height:   h
		h_align:  .center
		v_align:  .middle
		sizing:   gui.fixed_fixed
		children: [
			gui.progress_bar(
				height:  2
				sizing:  gui.flex_fixed
				percent: 0.20
			),
			gui.progress_bar(
				sizing:  gui.flex_fixed
				percent: 0.40
			),
			gui.progress_bar(
				height:  20
				sizing:  gui.flex_fixed
				percent: 0.60
			),
			gui.row(
				sizing:   gui.fit_flex
				children: [
					gui.progress_bar(
						vertical: true
						sizing:   gui.fixed_flex
						width:    2
						percent:  0.40
					),
					gui.progress_bar(
						vertical: true
						sizing:   gui.fixed_flex
						percent:  0.60
					),
					gui.progress_bar(
						vertical: true
						sizing:   gui.fixed_flex
						width:    20
						percent:  0.80
					),
				]
			),
		]
	)
}
