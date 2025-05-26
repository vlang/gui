import gui

// Gallery
// =============================
// Catalog of most of the predefined views available.

const scroll_id = 1
const tab_stock = 1000
const tab_icons = 1001
const tab_image = 1002
const tab_menus = 1003
const tab_dialogs = 1005

@[heap]
struct GalleryApp {
pub mut:
	light_theme  bool
	selected_tab int = tab_stock
	// buttons
	button_clicks int
	// inputs
	input_text      string
	input_multiline string = 'Now is the time for all good men to come to the aid of their country'
	// toggles
	select_toggle   bool
	select_checkbox bool
	select_city     string
	select_switch   bool
	// menu
	selected_menu_id string
	search_text      string
	// range sliders
	range_value f32
	// select
	selected_1 []string
	selected_2 []string
}

fn main() {
	mut window := gui.window(
		title:   'Gallery'
		state:   &GalleryApp{}
		width:   800
		height:  600
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(mut window gui.Window) gui.View {
	w, h := window.window_size()
	return gui.row(
		width:   w
		height:  h
		padding: gui.padding_none
		sizing:  gui.fixed_fixed
		spacing: 0
		content: [
			side_bar(mut window),
			gallery(mut window),
		]
	)
}

fn side_bar(mut w gui.Window) gui.View {
	mut app := w.state[GalleryApp]()
	return gui.column(
		fill:    true
		color:   gui.theme().color_1
		sizing:  gui.fit_fill
		content: [
			tab_select('Stock', tab_stock, app),
			tab_select('Icons', tab_icons, app),
			tab_select('Image', tab_image, app),
			tab_select('Menus', tab_menus, app),
			tab_select('Dialogs', tab_dialogs, app),
			gui.row(sizing: gui.fit_fill),
			toggle_theme(app),
		]
	)
}

fn gallery(mut w gui.Window) gui.View {
	mut app := w.state[GalleryApp]()
	return gui.column(
		id_scroll: scroll_id
		sizing:    gui.fill_fill
		spacing:   gui.spacing_large * 2
		content:   match app.selected_tab {
			tab_stock {
				[buttons(w), inputs(w), toggles(w), progress_bars(w),
					range_sliders(w), select_drop_down(w), text_sizes_weights(w)]
			}
			tab_icons {
				[icons(mut w)]
			}
			tab_image {
				[image_sample(w)]
			}
			tab_menus {
				[menus(w)]
			}
			tab_dialogs {
				[dialogs(w)]
			}
			else {
				[]gui.View{}
			}
		}
	)
}

fn tab_select(label string, id_tab int, app &GalleryApp) gui.View {
	color := if app.selected_tab == id_tab { gui.theme().color_5 } else { gui.color_transparent }
	return gui.row(
		color:     color
		fill:      app.selected_tab == id_tab
		min_width: 75
		max_width: 100
		padding:   gui.theme().padding_small
		content:   [gui.text(text: label, mode: .wrap, text_style: gui.theme().b2)]
		on_click:  fn [id_tab] (_ voidptr, mut e gui.Event, mut w gui.Window) {
			mut app := w.state[GalleryApp]()
			app.selected_tab = id_tab
			w.scroll_vertical_to(scroll_id, 0)
		}
		on_hover:  fn (mut node gui.Layout, mut _ gui.Event, mut w gui.Window) {
			node.shape.fill = true
			node.shape.color = gui.theme().color_3
			w.set_mouse_cursor_pointing_hand()
		}
	)
}

fn view_title(label string) gui.View {
	return gui.column(
		spacing: 0
		sizing:  gui.fill_fit
		padding: gui.padding_none
		content: [
			gui.text(text: label, text_style: gui.theme().b1),
			line(),
		]
	)
}

fn line() gui.View {
	return gui.row(
		height:  1
		sizing:  gui.fill_fit
		fill:    true
		padding: gui.padding_none
		color:   gui.theme().color_5
	)
}

fn toggle_theme(app &GalleryApp) gui.View {
	return gui.toggle(
		text_selected:   gui.icon_moon
		text_unselected: gui.icon_sunny_o
		text_style:      gui.theme().icon3
		padding:         gui.padding_small
		selected:        app.light_theme
		on_click:        fn (_ &gui.ToggleCfg, mut _ gui.Event, mut w gui.Window) {
			mut app := w.state[GalleryApp]()
			app.light_theme = !app.light_theme
			theme := if app.light_theme {
				gui.theme_light_bordered
			} else {
				gui.theme_dark_bordered
			}
			w.set_theme(theme)
		}
	)
}

// ==============================================================
// Buttons
// ==============================================================

fn buttons(w &gui.Window) gui.View {
	app := w.state[GalleryApp]()
	color := if app.light_theme { gui.light_gray } else { gui.dark_blue }
	color_left := if app.light_theme { gui.dark_gray } else { gui.dark_green }
	return gui.column(
		sizing:  gui.fill_fit
		padding: gui.padding_none
		content: [
			view_title('Buttons'),
			gui.row(
				sizing:  gui.fill_fit
				v_align: .bottom
				content: [
					gui.button(
						id_focus:       100
						padding_border: gui.padding_none
						content:        [gui.text(text: 'No Border')]
						on_click:       button_click
					),
					gui.button(
						id_focus:       101
						padding_border: gui.padding_one
						content:        [gui.text(text: 'Thin Border')]
						on_click:       button_click
					),
					gui.button(
						id_focus:       102
						padding_border: gui.padding_two
						content:        [gui.text(text: 'Thicker Border')]
						on_click:       button_click
					),
					gui.button(
						id_focus:       103
						padding_border: gui.padding_three
						fill_border:    false
						content:        [gui.text(text: 'Detached Border')]
						on_click:       button_click
					),
					gui.button(
						id_focus:       104
						padding_border: gui.padding_two
						on_click:       fn (_ &gui.ButtonCfg, mut e gui.Event, mut w gui.Window) {
							mut app := w.state[GalleryApp]()
							app.button_clicks += 1
						}
						content:        [
							gui.column(
								spacing: gui.spacing_small
								padding: gui.padding_none
								h_align: .center
								content: [
									gui.text(
										text:       'Custom Content'
										text_style: gui.theme().n6
									),
									gui.progress_bar(
										color:      color
										color_bar:  color_left
										percent:    (app.button_clicks % 25) / f32(25)
										sizing:     gui.fill_fit
										text_style: gui.theme().m4
										height:     gui.theme().n3.size
									),
								]
							),
						]
					),
				]
			),
		]
	)
}

fn button_click(_ &gui.ButtonCfg, mut e gui.Event, mut w gui.Window) {
	e.is_handled = true
}

// ==============================================================
// Inputs
// ==============================================================

fn inputs(w &gui.Window) gui.View {
	app := w.state[GalleryApp]()
	return gui.column(
		sizing:  gui.fill_fit
		padding: gui.padding_none
		content: [
			view_title('Inputs'),
			gui.row(
				sizing:  gui.fill_fit
				content: [
					gui.input(
						id_focus:        200
						width:           150
						sizing:          gui.fixed_fit
						text:            app.input_text
						padding_border:  gui.padding_none
						placeholder:     'Plain...'
						mode:            .single_line
						on_text_changed: text_changed
					),
					gui.input(
						id_focus:        201
						width:           130
						sizing:          gui.fixed_fit
						text:            app.input_text
						padding_border:  gui.padding_one
						placeholder:     'Thin Border...'
						mode:            .single_line
						on_text_changed: text_changed
					),
					gui.input(
						id_focus:        202
						width:           130
						sizing:          gui.fixed_fit
						text:            app.input_text
						padding_border:  gui.padding_two
						placeholder:     'Thicker Border...'
						mode:            .single_line
						on_text_changed: text_changed
					),
					gui.input(
						id_focus:        203
						width:           130
						sizing:          gui.fixed_fit
						text:            app.input_text
						padding_border:  gui.padding_one
						placeholder:     'Password...'
						is_password:     true
						mode:            .single_line
						on_text_changed: text_changed
					),
				]
			),
			gui.row(
				sizing:  gui.fill_fit
				v_align: .middle
				content: [
					gui.text(text: 'Multiline Text Input:'),
					gui.input(
						id_focus:        204
						width:           300
						sizing:          gui.fixed_fit
						text:            app.input_multiline
						padding_border:  gui.padding_one
						placeholder:     'Multline...'
						mode:            .multiline
						on_text_changed: fn (_ &gui.InputCfg, s string, mut w gui.Window) {
							mut app := w.state[GalleryApp]()
							app.input_multiline = s
						}
					),
				]
			),
		]
	)
}

fn text_changed(_ &gui.InputCfg, s string, mut w gui.Window) {
	mut app := w.state[GalleryApp]()
	app.input_text = s
}

// ==============================================================
// Text Sizes & Weights
// ==============================================================

fn text_sizes_weights(w &gui.Window) gui.View {
	return gui.column(
		sizing:  gui.fill_fit
		padding: gui.padding_none
		content: [
			view_title('Text Sizes & Weights'),
			gui.row(
				sizing:  gui.fill_fit
				content: [
					gui.text(text: 'Theme().n1', text_style: gui.theme().n1),
					gui.text(text: 'Theme().n2', text_style: gui.theme().n2),
					gui.text(text: 'Theme().n3', text_style: gui.theme().n3),
					gui.text(text: 'Theme().n4', text_style: gui.theme().n4),
					gui.text(text: 'Theme().n5', text_style: gui.theme().n5),
					gui.text(text: 'Theme().n6', text_style: gui.theme().n6),
				]
			),
			gui.row(
				sizing:  gui.fill_fit
				content: [
					gui.text(text: 'Theme().b1', text_style: gui.theme().b1),
					gui.text(text: 'Theme().b2', text_style: gui.theme().b2),
					gui.text(text: 'Theme().b3', text_style: gui.theme().b3),
					gui.text(text: 'Theme().b4', text_style: gui.theme().b4),
					gui.text(text: 'Theme().b5', text_style: gui.theme().b5),
					gui.text(text: 'Theme().b6', text_style: gui.theme().b6),
				]
			),
			gui.row(
				sizing:  gui.fill_fit
				content: [
					gui.text(text: 'Theme().i1', text_style: gui.theme().i1),
					gui.text(text: 'Theme().i2', text_style: gui.theme().i2),
					gui.text(text: 'Theme().i3', text_style: gui.theme().i3),
					gui.text(text: 'Theme().i4', text_style: gui.theme().i4),
					gui.text(text: 'Theme().i5', text_style: gui.theme().i5),
					gui.text(text: 'Theme().i6', text_style: gui.theme().i6),
				]
			),
			gui.row(
				sizing:  gui.fill_fit
				content: [
					gui.text(text: 'Theme().m1', text_style: gui.theme().m1),
					gui.text(text: 'Theme().m2', text_style: gui.theme().m2),
					gui.text(text: 'Theme().m3', text_style: gui.theme().m3),
					gui.text(text: 'Theme().m4', text_style: gui.theme().m4),
					gui.text(text: 'Theme().m5', text_style: gui.theme().m5),
					gui.text(text: 'Theme().m6', text_style: gui.theme().m6),
				]
			),
		]
	)
}

// ==============================================================
// Toggles
// ==============================================================

fn toggles(w &gui.Window) gui.View {
	mut app := w.state[GalleryApp]()
	options := [
		gui.radio_option('New York', 'ny'),
		gui.radio_option('Detroit', 'dtw'),
		gui.radio_option('Chicago', 'chi'),
		gui.radio_option('Los Angeles', 'la'),
	]

	return gui.column(
		sizing:  gui.fill_fit
		padding: gui.padding_none
		content: [
			view_title('Toggle, Switch, and Radio Button Group'),
			gui.row(
				content: [
					gui.toggle(
						label:    'toggle (a.k.a. checkbox)'
						selected: app.select_checkbox
						on_click: fn (_ &gui.ToggleCfg, mut e gui.Event, mut w gui.Window) {
							mut app := w.state[GalleryApp]()
							app.select_checkbox = !app.select_checkbox
						}
					),
					gui.toggle(
						label:         'toggle with custom text'
						selected:      app.select_toggle
						text_selected: 'X'
						on_click:      fn (_ &gui.ToggleCfg, mut e gui.Event, mut w gui.Window) {
							mut app := w.state[GalleryApp]()
							app.select_toggle = !app.select_toggle
						}
					),
					gui.switch(
						label:    'switch'
						selected: app.select_switch
						on_click: fn (_ &gui.SwitchCfg, mut e gui.Event, mut w gui.Window) {
							mut app := w.state[GalleryApp]()
							app.select_switch = !app.select_switch
						}
					),
				]
			),
			gui.row(
				content: [
					gui.radio_button_group_column(
						title:     'City Group'
						value:     app.select_city
						options:   options
						on_select: fn [mut app] (value string) {
							app.select_city = value
						}
						window:    w
					),
					// Intentionally using the same data/focus id to show vertical
					// and horizontal side-by-side
					gui.radio_button_group_row(
						title:     'City Group'
						value:     app.select_city
						options:   options
						on_select: fn [mut app] (value string) {
							app.select_city = value
						}
						window:    w
					),
				]
			),
		]
	)
}

// ==============================================================
// Dialogs
// ==============================================================

fn dialogs(w &gui.Window) gui.View {
	return gui.column(
		sizing:  gui.fill_fit
		padding: gui.padding_none
		content: [
			view_title('Dialogs'),
			gui.row(
				sizing:  gui.fill_fit
				content: [
					gui.row(
						padding: gui.padding_none
						content: [
							gui.column(
								padding: gui.padding_none
								content: [
									message_type(),
									confirm_type(),
								]
							),
							gui.column(
								padding: gui.padding_none
								content: [
									prompt_type(),
									custom_type(),
								]
							),
						]
					),
				]
			),
		]
	)
}

fn message_type() gui.View {
	return gui.button(
		id_focus: 1
		sizing:   gui.fill_fit
		content:  [gui.text(text: '.dialog_type == .message')]
		on_click: fn (_ &gui.ButtonCfg, mut _ gui.Event, mut w gui.Window) {
			w.dialog(
				align_buttons: .end
				dialog_type:   .message
				title:         'Title Displays Here'
				body:          '
body text displayes here...

Multi-line text supported.
See DialogCfg for other parameters

Buttons can be left/center/right aligned'.trim_indent()
			)
		}
	)
}

fn confirm_type() gui.View {
	return gui.button(
		id_focus: 2
		sizing:   gui.fill_fit
		content:  [gui.text(text: '.dialog_type == .confirm')]
		on_click: fn (_ &gui.ButtonCfg, mut _ gui.Event, mut w gui.Window) {
			w.dialog(
				dialog_type:  .confirm
				title:        'Destory All Data?'
				body:         'Are you sure?'
				on_ok_yes:    fn (mut w gui.Window) {
					w.dialog(title: 'Clicked Yes')
				}
				on_cancel_no: fn (mut w gui.Window) {
					w.dialog(title: 'Clicked No')
				}
			)
		}
	)
}

fn prompt_type() gui.View {
	return gui.button(
		id_focus: 3
		sizing:   gui.fill_fit
		content:  [gui.text(text: '.dialog_type == .prompt')]
		on_click: fn (_ &gui.ButtonCfg, mut _ gui.Event, mut w gui.Window) {
			w.dialog(
				dialog_type:  .prompt
				title:        'Monty Python Quiz'
				body:         'What is your quest?'
				on_reply:     fn (reply string, mut w gui.Window) {
					w.dialog(title: 'Replied', body: reply)
				}
				on_cancel_no: fn (mut w gui.Window) {
					w.dialog(title: 'Canceled')
				}
			)
		}
	)
}

fn custom_type() gui.View {
	return gui.button(
		id_focus: 4
		sizing:   gui.fill_fit
		content:  [gui.text(text: '.dialog_type == .custom')]
		on_click: fn (_ &gui.ButtonCfg, mut _ gui.Event, mut w gui.Window) {
			w.dialog(
				dialog_type:    .custom
				custom_content: [
					gui.column(
						h_align: .center
						v_align: .middle
						content: [
							gui.text(text: 'Custom Content'),
							gui.button(
								id_focus: gui.dialog_base_id_focus
								content:  [gui.text(text: 'Close Me')]
								on_click: fn (_ &gui.ButtonCfg, mut _ gui.Event, mut w gui.Window) {
									w.dialog_dismiss()
								}
							),
						]
					),
				]
			)
		}
	)
}

// ==============================================================
// Menu
// ==============================================================

fn menus(w &gui.Window) gui.View {
	return gui.column(
		sizing:  gui.fill_fit
		padding: gui.padding_none
		content: [
			view_title('Menus'),
			gui.row(
				sizing:  gui.fill_fit
				content: [menu(w)]
			),
		]
	)
}

fn menu(window &gui.Window) gui.View {
	app := window.state[GalleryApp]()

	return window.menubar(
		id_focus: 500
		action:   fn (id string, mut e gui.Event, mut w gui.Window) {
			mut app := w.state[GalleryApp]()
			app.selected_menu_id = id
		}
		items:    [
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
								mut app := w.state[GalleryApp]()
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

// ==============================================================
// Progress Bars
// ==============================================================

fn progress_bars(w &gui.Window) gui.View {
	return gui.column(
		padding: gui.padding_none
		content: [
			view_title('Progress Bars'),
			gui.row(
				sizing:  gui.fill_fit
				padding: gui.padding_none
				content: [progress_bar_samples(w)]
			),
		]
	)
}

fn progress_bar_samples(w &gui.Window) gui.View {
	tbg1 := if gui.theme().name.starts_with('light') { gui.orange } else { gui.dark_green }
	tbg2 := if gui.theme().name.starts_with('light') { gui.cornflower_blue } else { gui.white }

	return gui.row(
		spacing: gui.theme().spacing_large
		content: [
			gui.column(
				width:   200
				spacing: 20
				sizing:  gui.fit_fill
				content: [
					gui.progress_bar(
						height:          2
						sizing:          gui.fill_fixed
						percent:         0.20
						text_background: tbg1
						text_fill:       true
					),
					gui.progress_bar(
						sizing:  gui.fill_fixed
						percent: 0.40
					),
					gui.progress_bar(
						height:  20
						sizing:  gui.fill_fixed
						percent: 0.60
					),
					gui.progress_bar(
						height:    20
						sizing:    gui.fill_fixed
						percent:   0.80
						text_show: false
					),
				]
			),
			gui.row(
				width:   150
				height:  100
				spacing: 40
				sizing:  gui.fit_fill
				content: [
					gui.progress_bar(
						vertical:        true
						sizing:          gui.fixed_fill
						width:           2
						percent:         0.40
						text_background: tbg2
						text_fill:       false
					),
					gui.progress_bar(
						vertical: true
						sizing:   gui.fixed_fill
						percent:  0.60
					),
					gui.progress_bar(
						vertical: true
						sizing:   gui.fixed_fill
						width:    20
						percent:  0.80
					),
				]
			),
		]
	)
}

// ==============================================================
// Range Sliders
// ==============================================================

fn range_sliders(w &gui.Window) gui.View {
	return gui.column(
		sizing:  gui.fill_fit
		padding: gui.padding_none
		content: [
			view_title('Range Sliders'),
			gui.row(
				sizing:  gui.fill_fit
				content: [range_slider_samples(w)]
			),
		]
	)
}

fn range_slider_samples(w &gui.Window) gui.View {
	app := w.state[GalleryApp]()
	return gui.row(
		sizing:  gui.fill_fill
		content: [
			gui.column(
				width:   200
				content: [
					gui.range_slider(
						id:          'rs1'
						value:       app.range_value
						round_value: true
						sizing:      gui.fill_fit
						on_change:   fn (value f32, mut e gui.Event, mut w gui.Window) {
							mut app := w.state[GalleryApp]()
							app.range_value = value
						}
					),
					gui.text(text: app.range_value.str()),
				]
			),
			gui.column(
				height:  50
				content: [
					gui.range_slider(
						id:          'rs2'
						value:       app.range_value
						round_value: true
						vertical:    true
						sizing:      gui.fit_fill
						on_change:   fn (value f32, mut e gui.Event, mut w gui.Window) {
							mut app := w.state[GalleryApp]()
							app.range_value = value
						}
					),
				]
			),
		]
	)
}

// ==============================================================
// Select
// ==============================================================

fn select_drop_down(w &gui.Window) gui.View {
	return gui.column(
		padding: gui.padding_none
		content: [
			view_title('Select (Drop Down)'),
			gui.row(
				sizing:  gui.fill_fit
				content: [select_samples(w)]
			),
		]
	)
}

fn select_samples(w &gui.Window) gui.View {
	width := 250
	app := w.state[GalleryApp]()
	return gui.row(
		content: [
			gui.select(
				id:              'sel1'
				window:          mut w
				min_width:       width
				max_width:       width
				selected:        app.selected_1
				placeholder:     'Pick one or more states'
				select_multiple: true
				options:         [
					'Alabama',
					'Alaska',
					'Arizona',
					'Arkansas',
					'California',
					'Colorado',
					'Connecticut',
					'Delaware',
					'Florida',
					'Georgia',
					'Hawaii',
					'Idaho',
					'Illinois',
					'Indiana',
					'Iowa',
					'Kansas',
					'Kentucky',
					'Louisiana',
					'Maine',
					'Maryland',
					'Massachusetts',
					'Michigan',
					'Minnesota',
					'Mississippi',
					'Missouri',
					'Montana',
					'Nebraska',
					'Nevada',
					'New Hampshire',
					'New Jersey',
					'New Mexico',
					'New York',
					'North Carolina',
					'North Dakota',
					'Ohio',
					'Oklahoma',
					'Oregon',
					'Pennsylvania',
					'Rhode Island',
					'South Carolina',
					'South Dakota',
					'Tennessee',
					'Texas',
					'Utah',
					'Vermont',
					'Virginia',
					'Washington',
					'West',
					'Virginia',
					'Wisconsin',
					'Wyoming',
				]
				on_select:       fn (s []string, mut e gui.Event, mut w gui.Window) {
					mut app_ := w.state[GalleryApp]()
					app_.selected_1 = s
					e.is_handled = true
				}
			),
			gui.select(
				id:          'sel2'
				window:      mut w
				min_width:   width
				max_width:   width
				selected:    app.selected_2
				placeholder: 'Pick a country'
				options:     [
					'---Africa',
					'Algeria',
					'Angola',
					'Benin',
					'Botswana',
					'Burkina Faso',
					'Burundi',
					'Cabo Verde',
					'Cameroon',
					'Central African Republic',
					'Chad',
					'Comoros',
					'Congo',
					'Democratic Republic of the Congo',
					'Djibouti',
					'Egypt',
					'Equatorial Guinea',
					'Eritrea',
					'Eswatini',
					'Ethiopia',
					'Gabon',
					'Gambia',
					'Ghana',
					'Guinea',
					'Guinea-Bissau',
					'Ivory Coast',
					'Kenya',
					'Lesotho',
					'Liberia',
					'Libya',
					'Madagascar',
					'Malawi',
					'Mali',
					'Mauritania',
					'Mauritius',
					'Morocco',
					'Mozambique',
					'Namibia',
					'Niger',
					'Nigeria',
					'Rwanda',
					'Sao Tome and Principe',
					'Senegal',
					'Seychelles',
					'Sierra Leone',
					'Somalia',
					'South Africa',
					'South Sudan',
					'Sudan',
					'Tanzania',
					'Togo',
					'Tunisia',
					'Uganda',
					'Zambia',
					'Zimbabwe',
					'---Asia',
					'Afghanistan',
					'Armenia',
					'Azerbaijan',
					'Bahrain',
					'Bangladesh',
					'Bhutan',
					'Brunei',
					'Cambodia',
					'China',
					'Cyprus',
					'East Timor',
					'Georgia',
					'India',
					'Indonesia',
					'Iran',
					'Iraq',
					'Israel',
					'Japan',
					'Jordan',
					'Kazakhstan',
					'Kuwait',
					'Kyrgyzstan',
					'Laos',
					'Lebanon',
					'Malaysia',
					'Maldives',
					'Mongolia',
					'Myanmar',
					'Nepal',
					'North Korea',
					'Oman',
					'Pakistan',
					'Palestine',
					'Philippines',
					'Qatar',
					'Russia',
					'Saudi Arabia',
					'Singapore',
					'South Korea',
					'Sri Lanka',
					'Syria',
					'Taiwan',
					'Tajikistan',
					'Thailand',
					'Turkey',
					'Turkmenistan',
					'United Arab Emirates',
					'Uzbekistan',
					'Vietnam',
					'Yemen',
					'---Europe',
					'Albania',
					'Andorra',
					'Austria',
					'Belarus',
					'Belgium',
					'Bosnia and Herzegovina',
					'Bulgaria',
					'Croatia',
					'Czechia',
					'Denmark',
					'Estonia',
					'Finland',
					'France',
					'Germany',
					'Greece',
					'Hungary',
					'Iceland',
					'Ireland',
					'Italy',
					'Kosovo',
					'Latvia',
					'Liechtenstein',
					'Lithuania',
					'Luxembourg',
					'Malta',
					'Moldova',
					'Monaco',
					'Montenegro',
					'Netherlands',
					'North Macedonia',
					'Norway',
					'Poland',
					'Portugal',
					'Romania',
					'San Marino',
					'Serbia',
					'Slovakia',
					'Slovenia',
					'Spain',
					'Sweden',
					'Switzerland',
					'Ukraine',
					'United Kingdom',
					'Vatican City',
					'---North America',
					'Antigua and Barbuda',
					'Bahamas',
					'Barbados',
					'Belize',
					'Canada',
					'Costa Rica',
					'Cuba',
					'Dominica',
					'Dominican Republic',
					'El Salvador',
					'Grenada',
					'Guatemala',
					'Haiti',
					'Honduras',
					'Jamaica',
					'Mexico',
					'Nicaragua',
					'Panama',
					'Saint Kitts and Nevis',
					'Saint Lucia',
					'Saint Vincent and the Grenadines',
					'Trinidad and Tobago',
					'United States',
					'---Oceania',
					'Australia',
					'Fiji',
					'Kiribati',
					'Marshall Islands',
					'Micronesia',
					'Nauru',
					'New Zealand',
					'Palau',
					'Papua New Guinea',
					'Samoa',
					'Solomon Islands',
					'Tonga',
					'Tuvalu',
					'Vanuatu',
					'---South America',
					'Argentina',
					'Bolivia',
					'Brazil',
					'Chile',
					'Colombia',
					'Ecuador',
					'Guyana',
					'Paraguay',
					'Peru',
					'Suriname',
					'Uruguay',
					'Venezuela',
				]
				on_select:   fn (s []string, mut e gui.Event, mut w gui.Window) {
					mut app_ := w.state[GalleryApp]()
					app_.selected_2 = s
					e.is_handled = true
				}
			),
		]
	)
}

// ==============================================================
// Icons
// ==============================================================

fn icons(mut w gui.Window) gui.View {
	return gui.column(
		padding: gui.padding_none
		content: [
			view_title('Icons (Font)'),
			gui.row(
				sizing:  gui.fill_fit
				spacing: 0
				padding: gui.padding_none
				content: [icon_catalog(mut w)]
			),
		]
	)
}

fn icon_catalog(mut w gui.Window) gui.View {
	// find the longest text
	mut longest := f32(0)
	for s in gui.icons_map.keys() {
		longest = f32_max(gui.get_text_width(s, gui.theme().n3, mut w), longest)
	}

	// Break the icons_maps into rows
	chunks := chunk_map(gui.icons_map, 4)
	mut all_icons := []gui.View{}

	// create rows of icons/text
	for chunk in chunks {
		mut icons := []gui.View{}
		for key, val in chunk {
			icons << gui.column(
				min_width: longest
				h_align:   .center
				padding:   gui.padding_none
				content:   [
					gui.text(text: val, text_style: gui.theme().icon1),
					gui.text(text: key),
				]
			)
		}
		all_icons << gui.row(
			spacing: 0
			padding: gui.padding_none
			content: icons
		)
	}

	return gui.column(
		spacing: gui.spacing_large
		sizing:  gui.fill_fill
		padding: gui.padding_none
		content: all_icons
	)
}

// maybe this should be a standard library function?
fn chunk_map[K, V](input map[K]V, chunk_size int) []map[K]V {
	mut chunks := []map[K]V{}
	mut current_chunk := map[K]V{}
	mut count := 0

	for key, value in input {
		current_chunk[key] = value
		count += 1
		if count == chunk_size {
			chunks << current_chunk
			current_chunk = map[K]V{}
			count = 0
		}
	}
	// Add any remaining items as the last chunk
	if current_chunk.len > 0 {
		chunks << current_chunk
	}
	return chunks
}

// ==============================================================
// Image
// ==============================================================

fn image_sample(w &gui.Window) gui.View {
	return gui.column(
		sizing:  gui.fill_fit
		padding: gui.padding_none
		content: [
			view_title('Image'),
			gui.column(
				content: [
					gui.image(file_name: 'sample.jpeg'),
					gui.text(text: 'Pinard Falls, Oregon', text_style: gui.theme().b2),
				]
			),
		]
	)
}
