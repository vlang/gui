import gui

// Inputs
// =============================
// There is only one input view in Gui. It can function as
// single and multiline and can accept newlines.

@[heap]
struct InputsApp {
pub mut:
	input_a string = 'hello'
	light   bool
}

fn main() {
	mut window := gui.window(
		title:        'Inputs'
		state:        &InputsApp{}
		width:        325
		height:       300
		cursor_blink: true
		on_init:      fn (mut w gui.Window) {
			w.update_view(main_view)
			w.set_id_focus(1)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	app := window.state[InputsApp]()
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
						width:           input_width
						sizing:          gui.fixed_fit
						on_text_changed: fn (_ &gui.InputCfg, s string, mut w gui.Window) {
							mut state := w.state[InputsApp]()
							state.input_a = s
						}
					),
					gui.input(
						id_focus:        2
						text:            app.input_a
						width:           input_width
						sizing:          gui.fixed_fit
						padding_border:  gui.padding_one
						is_password:     true
						on_text_changed: fn (_ &gui.InputCfg, s string, mut w gui.Window) {
							mut state := w.state[InputsApp]()
							state.input_a = s
						}
					),
					gui.input(
						id_focus:        3
						text:            app.input_a
						width:           input_width
						sizing:          gui.fixed_fit
						padding_border:  gui.padding_one
						radius:          0
						radius_border:   0
						on_text_changed: fn (_ &gui.InputCfg, s string, mut w gui.Window) {
							mut state := w.state[InputsApp]()
							state.input_a = s
						}
					),
					gui.input(
						id_focus:        4
						text:            app.input_a
						width:           input_width
						sizing:          gui.fixed_fit
						padding_border:  gui.padding_small
						fill_border:     false
						radius:          0
						radius_border:   0
						on_text_changed: fn (_ &gui.InputCfg, s string, mut w gui.Window) {
							mut state := w.state[InputsApp]()
							state.input_a = s
						}
					),
					gui.input(
						id_focus:        5
						text:            app.input_a
						width:           input_width
						sizing:          gui.fixed_fit
						mode:            .multiline
						on_text_changed: fn (_ &gui.InputCfg, s string, mut w gui.Window) {
							mut state := w.state[InputsApp]()
							state.input_a = s
						}
					),
				]
			),
		]
	)
}

fn button_change_theme(app &InputsApp) gui.View {
	return gui.row(
		h_align: .end
		sizing:  gui.fill_fit
		padding: gui.padding_none
		content: [
			gui.toggle(
				text_select:   gui.icon_moon
				text_unselect: gui.icon_sunny_o
				text_style:    gui.theme().icon3
				padding:       gui.theme().padding_small
				select:        app.light
				on_click:      fn (_ &gui.ToggleCfg, mut _ gui.Event, mut w gui.Window) {
					mut app := w.state[InputsApp]()
					app.light = !app.light
					w.set_theme(if app.light { gui.theme_light } else { gui.theme_dark })
					w.set_id_focus(1)
				}
			),
		]
	)
}
