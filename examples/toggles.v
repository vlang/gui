import gui

// Toggles
// =============================
// Shows different types of toggle buttons
// - toggle functions as a checkbox in its default mode
// - toggle can also display custom text
// - radio is (will be) a classic round radio button
// - switch is the slide switch

@[heap]
struct ToggleApp {
pub mut:
	light           bool
	select_checkbox bool
	select_toggle   bool
	select_radio    bool
	select_switch   bool
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
				color:   gui.theme().color_interior
				content: [
					gui.toggle(
						id_focus: 100
						label:    'toggle (default)'
						select:   app.select_checkbox
						on_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
							mut app := w.state[ToggleApp]()
							app.select_checkbox = !app.select_checkbox
						}
					),
					gui.toggle(
						id_focus:    200
						label:       'toggle (custom icon)'
						select:      app.select_toggle
						text_select: gui.icon_bug
						text_style:  gui.theme().icon3
						on_click:    fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
							mut app := w.state[ToggleApp]()
							app.select_toggle = !app.select_toggle
						}
					),
					gui.radio(
						id_focus: 300
						label:    'radio button'
						select:   app.select_radio
						on_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
							mut app := w.state[ToggleApp]()
							app.select_radio = !app.select_radio
						}
					),
					gui.switch(
						id_focus: 400
						label:    'switch'
						select:   app.select_switch
						on_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
							mut app := w.state[ToggleApp]()
							app.select_switch = !app.select_switch
						}
					),
				]
			),
		]
	)
}

fn toggle_theme(app &ToggleApp) gui.View {
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
				on_click:      fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
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
