import gui

// Toggles
// =============================
// Shows different types of toggle buttons
// - togggle functions as a checkbox in its default mode
// - toggle can also display custom text
// - radio is (will be) a classic round radio button
// - switch is the slide switch

@[heap]
struct ToggleApp {
pub mut:
	light             bool
	selected_checkbox bool
	selected_toggle   bool
	selected_radio    bool
}

fn main() {
	mut window := gui.window(
		title:   'Toggles'
		state:   &ToggleApp{}
		width:   300
		height:  300
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	app := window.state[ToggleApp]()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		h_align: .center
		content: [
			toggle_theme(app),
			gui.column(
				color:   gui.theme().color_2
				content: [
					toggle_row('toggle (default)', gui.toggle(
						selected: app.selected_checkbox
						on_click: fn (_ &gui.ToggleCfg, mut e gui.Event, mut w gui.Window) {
							mut app := w.state[ToggleApp]()
							app.selected_checkbox = !app.selected_checkbox
						}
					)),
					toggle_row('toggle (custom text)', gui.toggle(
						text_selected:   'X'
						text_unselected: '○'
						selected:        app.selected_toggle
						on_click:        fn (_ &gui.ToggleCfg, mut e gui.Event, mut w gui.Window) {
							mut app := w.state[ToggleApp]()
							app.selected_toggle = !app.selected_toggle
						}
					)),
					toggle_row('radio button', gui.radio(
						id:       'radio'
						selected: app.selected_radio
						on_click: fn (_ &gui.RadioCfg, mut e gui.Event, mut w gui.Window) {
							mut app := w.state[ToggleApp]()
							app.selected_radio = !app.selected_radio
						}
					)),
					gui.row(
						h_align: .center
						sizing:  gui.fill_fit
						content: [
							gui.text(text: 'todo: switch', text_style: gui.theme().m3),
						]
					),
				]
			),
		]
	)
}

fn toggle_row(label string, button gui.View) gui.View {
	return gui.row(
		h_align: .center
		v_align: .middle
		content: [
			gui.row(
				min_width: 25
				padding:   gui.padding_none
				content:   [button]
			),
			gui.text(text: label),
		]
	)
}

fn toggle_theme(app &ToggleApp) gui.View {
	return gui.row(
		h_align: .right
		sizing:  gui.fill_fit
		padding: gui.padding_none
		content: [
			gui.toggle(
				text_selected:   '☾'
				text_unselected: '○'
				selected:        app.light
				on_click:        fn (_ &gui.ToggleCfg, mut _ gui.Event, mut w gui.Window) {
					mut app := w.state[ToggleApp]()
					app.light = !app.light
					theme := if app.light {
						gui.theme_light_bordered
					} else {
						gui.theme_dark_bordered
					}
					w.set_theme(theme)
				}
			),
		]
	)
}
