import gui
import gx

const bwidth = 30
const bheight = 30
const bpadding = 5

struct AppState {
pub mut:
	total f64
}

fn main() {
	mut window := gui.window(
		state:    &AppState{}
		width:    156
		height:   224
		title:    'Calculator'
		bg_color: gx.rgb(0x30, 0x30, 0x30)
		on_init:  fn (mut w gui.Window) {
			w.update_view(main_view)
			// w.resize_to_content()
		}
	)
	window.run()
}

fn main_view(mut w gui.Window) gui.View {
	app_state := w.state[AppState]()

	row_ops := [
		['C', '%', '^', '÷'],
		['7', '8', '9', '*'],
		['4', '5', '6', '-'],
		['1', '2', '3', '+'],
		['0', '.', '±', '='],
	]

	mut panel := []gui.View{}

	panel << gui.row(
		color:    gx.black
		h_align:  .right
		padding:  gui.pad_4(5)
		sizing:   gui.flex_fit
		children: [
			gui.text(
				text:  app_state.total.str()
				style: gx.TextCfg{
					size: 20
				}
			),
		]
	)

	for ops in row_ops {
		panel << gui.row(
			spacing:  5
			padding:  gui.padding_none
			children: get_row(ops)
		)
	}

	return gui.column(
		radius:   0
		spacing:  5
		color:    gx.rgb(215, 125, 0)
		fill:     true
		padding:  gui.pad_4(10)
		children: panel
	)
}

fn get_row(ops []string) []gui.View {
	mut children := []gui.View{}

	for op in ops {
		children << gui.button(
			text:    op
			width:   bwidth
			height:  bheight
			h_align: .center
			v_align: .middle
			sizing:  gui.fixed_fixed
			padding: gui.padding_none
		)
	}
	return children
}
