import gui
import gx

fn main() {
	mut window := gui.window(
		width:   300
		height:  350
		title:   'two panel'
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
			// w.resize_to_content()
		}
	)
	window.run()
}

fn main_view(mut w gui.Window) gui.View {
	width, height := w.window_size()

	return gui.row(
		width:    width
		height:   height
		sizing:   gui.fixed_fixed
		children: [
			gui.column(
				max_width:  150
				max_height: 330
				h_align:    .center
				v_align:    .middle
				color:      gx.rgb(215, 125, 0)
				fill:       true
				sizing:     gui.flex_flex
				children:   [
					gui.text(
						text:  'Hello'
						style: gx.TextCfg{
							...gui.theme().text_cfg
							size:  gui.theme().size_text_large
							color: gx.black
						}
					),
				]
			),
			gui.column(
				id:        'orange'
				text:      ' Container Title  '
				color:     gui.theme().text_cfg.color
				h_align:   .right
				v_align:   .bottom
				min_width: 150
				sizing:    gui.flex_flex
				children:  [
					gui.text(
						text:  'There!'
						style: gx.TextCfg{
							...gui.theme().text_cfg
							size: gui.theme().size_text_large
						}
					),
				]
			),
		]
	)
}
