import gui

// Menu Demo
// =============================

@[heap]
struct App {
pub mut:
	clicks int
}

fn main() {
	mut window := gui.window(
		state:   &App{}
		width:   300
		height:  300
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.run()
}

fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	app := window.state[App]()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		spacing: 0
		content: [
			menu(window),
			gui.column(
				h_align: .center
				padding: gui.padding_none
				sizing:  gui.fill_fill
				content: [
					gui.rectangle(
						height: 40
						fill:   false
						color:  gui.color_transparent
						sizing: gui.fill_fixed
					),
					gui.text(
						text:       'Welcome to GUI'
						text_style: gui.theme().b1
					),
					gui.button(
						id_focus:       1
						padding_border: gui.padding_two
						content:        [gui.text(text: '${app.clicks} Clicks')]
						on_click:       fn (_ &gui.ButtonCfg, mut _ gui.Event, mut w gui.Window) {
							mut app := w.state[App]()
							app.clicks += 1
						}
					),
				]
			),
		]
	)
}

fn menu(window &gui.Window) gui.View {
	return gui.menubar(
		id_menu: 1
		items:   [
			gui.menu_item(id: 'file', text: 'File'),
			gui.menu_item(id: 'edit', text: 'Edit', selected: true),
			gui.menu_item(id: 'view', text: 'View'),
			gui.menu_item(id: 'go', text: 'Go'),
			gui.menu_item(id: 'window', text: 'Window'),
			gui.menu_item(id: 'help', text: 'Help'),
		]
	)
}
