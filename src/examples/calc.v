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
			padding:  gui.padding_none
			children: get_row(ops)
		)
	}

	return gui.column(
		children: rows
	)
}

fn get_row(ops []string) []gui.View {
	mut children := []gui.View{}

	for op in ops {
		if op == ' ' {
			continue
		}

		children << gui.button(
			text:   op
			sizing: gui.fixed_fixed
			width:  bwidth
			height: bheight
		)
	}
	return children
}
