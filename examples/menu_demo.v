import gui

// Menu Demo
// =============================

@[heap]
struct App {
pub mut:
	clicks           int
	search_text      string
	selected_menu_id string
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
	mut app := window.state[App]()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		spacing: 0
		content: [
			menu(window),
			body(mut app, window),
		]
	)
}

fn menu(window &gui.Window) gui.View {
	app := window.state[App]()

	return window.menubar(
		id_menubar: 1
		action:     fn (id string, mut e gui.Event, mut w gui.Window) {
			mut app := w.state[App]()
			app.selected_menu_id = id
		}
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
							gui.menu_item_text('no-where', 'No Where'),
							gui.menu_item_text('some-where', 'Some Where'),
						]
					},
					gui.menu_separator(),
					gui.menu_item_text('exit', 'Exit'),
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
				id:      'view'
				text:    'View'
				submenu: [
					gui.menu_item_text('zoom-in', 'Zoom In'),
					gui.menu_item_text('zoom-out', 'Zoom Out'),
					gui.menu_item_text('zoom-reset', 'Reset Zoom'),
					gui.menu_separator(),
					gui.menu_item_text('project-panel', 'Project Panel'),
					gui.menu_item_text('outline-panel', 'Outline Panel'),
					gui.menu_item_text('terminal-panel', 'Terminal Panel'),
					gui.menu_separator(),
					gui.menu_item_text('full-screen', 'Enter Full Screen'),
				]
			},
			gui.MenuItemCfg{
				id:      'go'
				text:    'Go'
				submenu: [
					gui.menu_item_text('go-back', 'Back'),
					gui.menu_item_text('go-forward', 'Forward'),
					gui.menu_separator(),
					gui.menu_item_text('go-definition', 'Go to Definition'),
					gui.menu_item_text('go-declaration', 'Go to Declaration'),
					gui.menu_item_text('go-to-moon-alice', 'Go to the Moon Alice'),
				]
			},
			gui.MenuItemCfg{
				id:      'window'
				text:    'Window'
				submenu: [
					gui.menu_item_text('window-fill', 'Fill'),
					gui.menu_item_text('window-center', 'Center'),
					gui.menu_separator(),
					gui.menu_item_text('window-move', 'Move & Resize'),
					gui.menu_item_text('window-full-screen-tile', 'Full Screen Tile'),
				]
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

fn body(mut app App, window &gui.Window) gui.View {
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
			gui.text(text: '') // spacer,,,,,,,,,,,,,,,
			gui.text(
				text:       if app.selected_menu_id.len > 0 {
					'Menu "${app.selected_menu_id}" selected'
				} else {
					''
				}
				text_style: gui_theme.m3
			),
		]
	)
}
