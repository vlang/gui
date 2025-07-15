import gui

// Menubar Demo
// =============================
// In this demo, a menubar is placed at the top of the view with some
// submenus and an embedded search box (see Help). Menubar has many
// styling options. The menubar can be styled separately from the
// submenus and menu items as demonstrated here. Menubars are not
// restricted to the top of the window. Menubars can go anywhere in a
// view including floats and dialogs.
//
// Menubars can even be floating elements as demonstrated below.
//
@[heap]
struct MenuApp {
pub mut:
	clicks         int
	search_text    string
	select_menu_id string
	light_theme    bool
}

fn main() {
	mut window := gui.window(
		title:   'Menu Demo'
		state:   &MenuApp{}
		width:   600
		height:  400
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(window &gui.Window) &gui.View {
	w, h := window.window_size()
	mut app := window.state[MenuApp]()

	return gui.column(
		width:   w
		height:  h
		padding: gui.padding_none
		sizing:  gui.fixed_fixed
		spacing: 0
		content: [
			menu(window),
			body(mut app, window),
		]
	)
}

fn menu(window &gui.Window) &gui.View {
	app := window.state[MenuApp]()

	return window.menubar(
		float:          true
		float_anchor:   .top_center
		float_tie_off:  .top_center
		id_focus:       100
		radius:         0
		padding_border: gui.padding_none
		action:         fn (id string, mut e gui.Event, mut w gui.Window) {
			mut app := w.state[MenuApp]()
			app.select_menu_id = id
		}
		items:          [
			gui.MenuItemCfg{
				id:      'file'
				text:    'File'
				submenu: [
					gui.menu_submenu('new', 'New', [
						gui.menu_item_text('here', 'Here'),
						gui.menu_item_text('there', 'There'),
					]),
					gui.menu_submenu('open', 'Open', [
						gui.menu_item_text('no-where', 'No Where'),
						gui.menu_item_text('some-where', 'Some Where'),
						gui.menu_submenu('keep-going', 'Keep Going', [
							gui.menu_item_text('you-are-done', "OK, you're done"),
						]),
					]),
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
					gui.menu_submenu('window-move', 'Move & Resize', [
						gui.menu_subtitle('Halves'),
						gui.menu_item_text('half-left', 'Left'),
						gui.menu_item_text('half-top', 'Top'),
						gui.menu_item_text('half-right', 'Right'),
						gui.menu_item_text('half-bottom', 'Bottom'),
						gui.menu_separator(),
						gui.menu_subtitle('Quarters'),
						gui.menu_item_text('quarter-top-left', 'Top Left'),
						gui.menu_item_text('quarter-top-right', 'Top Right'),
						gui.menu_item_text('quarter-bottom-left', 'Bottom Left'),
						gui.menu_item_text('quarter-bottom-right', 'Bottom Right'),
					]),
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
							text:              app.search_text
							id_focus:          100
							width:             100
							min_width:         100
							max_width:         100
							sizing:            gui.fixed_fill
							placeholder:       'Search'
							padding:           gui.Padding{
								...gui.theme().input_style.padding
								top:    2
								bottom: 2
							}
							radius:            0
							radius_border:     0
							text_style:        gui.theme().menubar_style.text_style
							placeholder_style: gui.theme().menubar_style.text_style
							on_text_changed:   fn (_ &gui.InputCfg, s string, mut w gui.Window) {
								mut app := w.state[MenuApp]()
								app.search_text = s
							}
						)
					},
					gui.menu_separator(),
					gui.menu_item_text('help-me', 'Help'),
				]
			},
			gui.MenuItemCfg{
				id:          'theme'
				padding:     gui.padding_none
				custom_view: toggle_theme(app)
			},
		]
	)
}

fn body(mut app MenuApp, window &gui.Window) &gui.View {
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
					mut app := w.state[MenuApp]()
					app.clicks += 1
				}
			),
			gui.text(text: ''), // spacer
			gui.text(
				text:       if app.select_menu_id.len > 0 {
					'Menu "${app.select_menu_id}" select'
				} else {
					''
				}
				text_style: gui_theme.m3
			),
			gui.text(
				text:       if app.select_menu_id.len > 0 {
					'Search text: "${app.search_text}"'
				} else {
					''
				}
				text_style: gui_theme.m3
			),
		]
	)
}

fn toggle_theme(app &MenuApp) &gui.View {
	return gui.row(
		h_align: .end
		sizing:  gui.fill_fit
		padding: gui.padding_none
		content: [
			gui.toggle(
				text_select:   gui.icon_moon
				text_unselect: gui.icon_sunny_o
				text_style:    gui.theme().icon5
				select:        app.light_theme
				on_click:      fn (_ &gui.ToggleCfg, mut _ gui.Event, mut w gui.Window) {
					mut app := w.state[MenuApp]()
					app.light_theme = !app.light_theme
					theme := if app.light_theme {
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
