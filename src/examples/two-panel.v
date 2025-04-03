import gui
import gx

fn main() {
	mut window := gui.window(
		width:   300
		height:  350
		title:   'two panel'
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.run()
}

fn main_view(mut w gui.Window) gui.View {
	width, height := w.window_size()

	return gui.row(
		width:   width
		height:  height
		sizing:  gui.fixed_fixed
		content: [
			gui.column(
				fill:       true
				sizing:     gui.flex_flex
				max_width:  150
				max_height: 330
				h_align:    .center
				v_align:    .middle
				color:      gx.rgb(215, 125, 0)
				content:    [
					gui.text(
						text:     'Hello'
						text_cfg: gx.TextCfg{
							size:  gui.theme().size_text_large
							color: gx.black
						}
					),
				]
			),
			gui.column(
				text:      ' Container Title  '
				sizing:    gui.flex_flex
				h_align:   .right
				v_align:   .bottom
				min_width: 150
				color:     gui.theme().text_style.text_cfg.color
				content:   [
					gui.text(
						text:     'There!'
						text_cfg: gx.TextCfg{
							...gui.theme().text_style.text_cfg
							size: gui.theme().size_text_large
						}
					),
				]
			),
		]
	)
}
