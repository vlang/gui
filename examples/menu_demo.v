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
		width:   400
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
			body(app, window),
		]
	)
}

fn menu(window &gui.Window) gui.View {
	return window.menubar(
		id_menubar: 1
		items:      [
			gui.MenuItemCfg{
				id:      'file'
				text:    'File'
				submenu: [
					gui.MenuItemCfg{
						id:   'new'
						text: 'New'
					},
					gui.MenuItemCfg{
						id:   'open'
						text: 'Open'
					},
				]
			},
			gui.MenuItemCfg{
				id:   'edit'
				text: 'Edit'
			},
			gui.MenuItemCfg{
				id:   'view'
				text: 'View'
			},
			gui.MenuItemCfg{
				id:   'go'
				text: 'Go'
			},
			gui.MenuItemCfg{
				id:   'window'
				text: 'Window'
			},
			gui.MenuItemCfg{
				id:   'help'
				text: 'Help'
			},
		]
	)
}

fn body(app &App, window &gui.Window) gui.View {
	return gui.column(
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
	)
}
