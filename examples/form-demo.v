import gui

// Form Demo
// =============================
// Gui doesn't have a form control or grid layout but it can
// do similar things with simple function.

@[heap]
struct FormDemoApp {
pub mut:
	name    string
	address string
	city    string
}

fn main() {
	mut window := gui.window(
		state:   &FormDemoApp{}
		width:   800
		height:  600
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	mut app := window.state[FormDemoApp]()

	id_focus_name := u32(100)
	id_focus_address := u32(101)
	id_focus_city := u32(102)

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		h_align: .center
		v_align: .middle
		content: [
			gui.column(
				color:   gui.theme().color_border
				content: [
					label_input_row('Name', app.name, id_focus_name, fn [mut app] (s string) {
						app.name = s
					}),
					label_input_row('Address', app.address, id_focus_address, fn [mut app] (s string) {
						app.address = s
					}),
					label_input_row('City', app.city, id_focus_city, fn [mut app] (s string) {
						app.city = s
					}),
				]
			),
		]
	)
}

fn label_input_row(label string, value string, id_focus u32, changed fn (string)) gui.View {
	field_width := 250

	// Use fill_fit to move label and input to outer edges of form
	return gui.row(
		v_align: .middle
		sizing:  gui.fill_fit
		content: [
			gui.text(text: label),
			gui.row(sizing: gui.fill_fit),
			gui.input(
				text:            value
				id_focus:        id_focus
				sizing:          gui.fixed_fit
				width:           field_width
				on_text_changed: fn [changed] (_ &gui.InputCfg, s string, mut w gui.Window) {
					changed(s)
				}
			),
		]
	)
}
