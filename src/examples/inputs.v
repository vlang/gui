import gui

@[heap]
struct App {
pub mut:
	input_a string = 'hello'
	light   bool
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
		sizing:  gui.fixed_fixed
		spacing: gui.spacing_medium
		h_align: .center
		v_align: .middle
		content: [
			gui.column(
				content: [
					button_change_theme(app),
					gui.input(
						id_focus:        1
						text:            app.input_a
						placeholder:     'type here...'
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
						is_password:     true
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
					gui.input(
						id_focus:        5
						text:            app.input_a
						min_width:       input_width
						max_width:       input_width
						wrap:            true
						on_text_changed: fn (_ &gui.InputCfg, s string, mut w gui.Window) {
							mut state := w.state[App]()
							state.input_a = s
						}
					),
				]
			),
		]
	)
}

fn button_change_theme(app &App) gui.View {
	return gui.row(
		h_align: .right
		sizing:  gui.fill_fit
		padding: gui.padding_none
		content: [
			gui.button(
				padding:  gui.padding(1, 5, 1, 5)
				content:  [
					gui.text(
						text: if app.light { '●' } else { '○' }
					),
				]
				on_click: fn (_ &gui.ButtonCfg, mut _ gui.Event, mut w gui.Window) {
					mut app := w.state[App]()
					app.light = !app.light
					w.set_theme(if app.light { gui.theme_light } else { gui.theme_dark })
					w.set_id_focus(1)
				}
			),
		]
	)
}
