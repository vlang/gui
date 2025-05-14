import gui

// Toggles
// =============================

@[heap]
struct ToggleApp {
pub mut:
	light    bool
	selected bool
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
				sizing:  gui.fit_fill
				content: [
					toggle_row('checkbox', gui.toggle(
						selected: app.selected
						on_click: fn (_ &gui.ToggleCfg, mut e gui.Event, mut w gui.Window) {
							mut app := w.state[ToggleApp]()
							app.selected = !app.selected
						}
					)),
				]
			),
		]
	)
}

fn toggle_row(label string, button gui.View) gui.View {
	return gui.row(
		h_align: .center
		v_align: .middle
		sizing:  gui.fill_fit
		color:   gui.theme().color_2
		content: [
			button,
			gui.row(
				padding: gui.padding_none
				content: [gui.text(text: label)]
			),
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
