import gui

// Menu Demo
// =============================

@[heap]
struct App {
pub mut:
	clicks      int
	search_text string
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
	app := window.state[App]()

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
							gui.menu_item_text('here', 'Here'),
							gui.menu_item_text('there', 'There'),
						]
					},
					gui.MenuItemCfg{
						id:      'open'
						text:    'Open'
						submenu: [
							gui.menu_item_text('no_where', 'No Where'),
							gui.menu_item_text('some_where', 'Some Where'),
						]
					},
				]
			},
			gui.MenuItemCfg{
				id:      'edit'
				text:    'Edit'
				submenu: [
					gui.menu_item_text('cut', 'Cut'),
					gui.menu_item_text('copy', 'Copy'),
					gui.menu_item_text('paste', 'Paste'),
					gui.menu_separator(),
					gui.menu_item_text('emoji', 'Emoji & Symbols'),
					gui.menu_item_text('too-long', 'Long menu text item to test line wrappping in menu'),
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
				id:      'help'
				text:    'Help'
				submenu: [
					gui.MenuItemCfg{
						id:          'search'
						padding:     gui.padding_none
						custom_view: gui.input(
							text:            app.search_text
							id_focus:        100
							width:           100
							min_width:       100
							max_width:       100
							sizing:          gui.fixed_fill
							placeholder:     'Search'
							padding:         gui.padding_two_five
							radius:          0
							radius_border:   0
							on_text_changed: fn (_ &gui.InputCfg, s string, mut w gui.Window) {
								mut app := w.state[App]()
								app.search_text = s
							}
						)
					},
					gui.menu_separator(),
					gui.menu_item_text('help-me', 'Help'),
				]
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
