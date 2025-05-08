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
	window.set_theme(gui.theme_dark_bordered)
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
						id:      'new'
						text:    'New'
						submenu: [
							gui.MenuItemCfg{
								id:   'here'
								text: 'Here'
							},
							gui.MenuItemCfg{
								id:   'there'
								text: 'There'
							},
						]
					},
					gui.MenuItemCfg{
						id:      'open'
						text:    'Open'
						submenu: [
							gui.MenuItemCfg{
								id:   'no_where'
								text: 'No Where'
							},
							gui.MenuItemCfg{
								id:   'some_where'
								text: 'Some Where'
							},
						]
					},
				]
			},
			gui.MenuItemCfg{
				id:      'edit'
				text:    'Edit'
				submenu: [
					gui.MenuItemCfg{
						id:   'cut'
						text: 'Cut'
					},
					gui.MenuItemCfg{
						id:   'copy'
						text: 'Copy'
					},
					gui.MenuItemCfg{
						id:   'paste'
						text: 'Paste'
					},
					gui.MenuItemCfg{
						id:        ''
						separator: true
					},
					gui.MenuItemCfg{
						id:   'find'
						text: 'Find'
					},
					gui.MenuItemCfg{
						id:        ''
						separator: true
					},
					gui.MenuItemCfg{
						id:   'emoji'
						text: 'Emoji & Symbols'
					},
					gui.MenuItemCfg{
						id:   'too-long'
						text: 'Long menu text item to test line wrappping in menu'
					},
				]
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
				id_focus: 1
				content:  [gui.text(text: '${app.clicks} Clicks')]
				on_click: fn (_ &gui.ButtonCfg, mut _ gui.Event, mut w gui.Window) {
					mut app := w.state[App]()
					app.clicks += 1
				}
			),
		]
	)
}
