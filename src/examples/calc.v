import gui
import gx

const bwidth = 30
const bheight = 30
const bpadding = 5

struct AppState {
}

fn main() {
	mut window := gui.window(
		state:    &AppState{}
		width:    255
		height:   350
		title:    'test layout'
		bg_color: gx.rgb(0x30, 0x30, 0x30)
		on_init:  fn (mut w gui.Window) {
			w.update_view(main_view)
			// w.resize_to_content()
		}
	)
	window.run()
}

fn main_view(mut w gui.Window) gui.View {
	row_ops := [
		['C', '%', '^', '÷'],
		['7', '8', '9', '*'],
		['4', '5', '6', '-'],
		['1', '2', '3', '+'],
		['0', '.', '±', '='],
	]

	mut rows := []gui.View{}
	for ops in row_ops {
		rows << gui.row(
			spacing:  5
			padding:  gui.padding_none
			children: get_row(ops)
		)
	}

	return gui.column(
		spacing:  5
		color:    gx.orange
		fill:     true
		padding:  gui.pad_4(10)
		children: rows
	)
}

fn get_row(ops []string) []gui.View {
	mut children := []gui.View{}

	for op in ops {
		children << gui.button(
			text:    op
			width:   bwidth
			height:  bheight
			sizing:  gui.fixed_fixed
			padding: gui.padding_none
		)
	}
	return children
}
