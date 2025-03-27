import gui
import gx

fn main() {
	mut window := gui.window(
		width:   300
		height:  350
		title:   'test layout'
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
			// w.resize_to_content()
		}
	)
	window.run()
}

fn main_view(mut w gui.Window) gui.View {
	width, height := w.window_size()
	text_style := gx.TextCfg{
		color: gx.dark_blue
		bold:  true
	}

	return gui.row(
		id: 'row'

		width:    width
		height:   height
		sizing:   gui.fixed_fixed
		children: [
			gui.column(
				min_width:  100
				max_width:  150
				max_height: 330
				h_align:    .center
				v_align:    .middle
				color:      gx.dark_gray
				fill:       true
				sizing:     gui.flex_flex
				children:   [gui.text(text: 'Hello', style: text_style)]
			),
			gui.column(
				id:       'green'
				color:    gx.dark_green
				h_align:  .right
				v_align:  .bottom
				fill:     true
				sizing:   gui.flex_flex
				children: [gui.text(text: 'There!', style: text_style)]
			),
		]
	)
}
