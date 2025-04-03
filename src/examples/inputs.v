import gui

struct App {
pub mut:
	input_a string = 'hello'
}

fn main() {
	mut window := gui.window(
		title:   'Inputs'
		state:   &App{}
		width:   325
		height:  300
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
			w.set_id_focus(1)
		}
	)
	window.run()
}

fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	app := window.state[App]()
	input_width := 125

	return gui.column(
		width:   w
		height:  h
		spacing: 10
		h_align: .center
		v_align: .middle
		sizing:  gui.fixed_fixed
		content: [
			gui.input(
				id_focus:        1
				text:            app.input_a
				min_width:       input_width
				max_width:       input_width
				on_text_changed: fn (_ &gui.InputCfg, s string, mut w gui.Window) {
					mut state := w.state[App]()
					state.input_a = s
				}
			),
			gui.input(
				id_focus:        2
				text:            app.input_a
				min_width:       input_width
				max_width:       input_width
				padding_border:  gui.pad_4(1)
				on_text_changed: fn (_ &gui.InputCfg, s string, mut w gui.Window) {
					mut state := w.state[App]()
					state.input_a = s
				}
			),
			gui.input(
				id_focus:        3
				text:            app.input_a
				min_width:       input_width
				max_width:       input_width
				padding_border:  gui.padding_one
				radius:          0
				radius_border:   0
				on_text_changed: fn (_ &gui.InputCfg, s string, mut w gui.Window) {
					mut state := w.state[App]()
					state.input_a = s
				}
			),
			gui.input(
				id_focus:        4
				text:            app.input_a
				min_width:       input_width
				max_width:       input_width
				padding_border:  gui.padding_small
				fill_border:     false
				radius:          0
				radius_border:   0
				on_text_changed: fn (_ &gui.InputCfg, s string, mut w gui.Window) {
					mut state := w.state[App]()
					state.input_a = s
				}
			),
		]
	)
}
