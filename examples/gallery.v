import gui

// Gallery
// =============================
// WIP

@[heap]
struct GalleryApp {
pub mut:
	light_theme bool
	// buttons
	button_clicks int
	// inputs
	input_text      string
	input_multiline string = 'Now is the time for all good men to come to the aid of their country'
	// toggles
	select_toggle   bool
	select_checkbox bool
	select_radio    string
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

fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	return gui.column(
		width:   w
		height:  h
		padding: gui.padding_none
		sizing:  gui.fixed_fixed
		content: [
			gui.row(
				padding: gui.padding_none
				sizing:  gui.fill_fill
				content: [gallery(window)]
			),
		]
	)
}

fn gallery(w &gui.Window) gui.View {
	mut app := w.state[GalleryApp]()
	return gui.column(
		sizing:  gui.fill_fill
		content: [
			toggle_theme(app),
			gui.column(
				id_scroll: 1
				sizing:    gui.fill_fill
				spacing:   gui.spacing_large * 2
				content:   [
					buttons(w),
					inputs(w),
					toggles(w),
					menus(w),
					dialogs(w),
					progress_bars(w),
					range_sliders(w),
					select_drop_down(w),
					image_sample(w),
					text_sizes_weights(w),
				]
			),
		]
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
	return gui.row(
		h_align: .end
		sizing:  gui.fill_fit
		padding: gui.padding_none
		content: [
			gui.toggle(
				text_selected:   '☾'
				text_unselected: '○'
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
			),
		]
	)
}

// ==============================================================
// Buttons
// ==============================================================

fn buttons(w &gui.Window) gui.View {
	app := w.state[GalleryApp]()
	return gui.column(
		sizing:  gui.fill_fit
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
										color:      gui.blue
										color_bar:  gui.dark_green
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
	return gui.column(
		sizing:  gui.fill_fit
		content: [
			view_title('Toggle, Radio and Switch'),
			gui.row(
				sizing:  gui.fill_fit
				content: [
					toggle_row('toggle (a.k.a. checkbox)', gui.toggle(
						selected: app.select_checkbox
						on_click: fn (_ &gui.ToggleCfg, mut e gui.Event, mut w gui.Window) {
							mut app := w.state[GalleryApp]()
							app.select_checkbox = !app.select_checkbox
						}
					)),
					toggle_row('toggle with custom text', gui.toggle(
						selected:      app.select_toggle
						text_selected: 'X'
						on_click:      fn (_ &gui.ToggleCfg, mut e gui.Event, mut w gui.Window) {
							mut app := w.state[GalleryApp]()
							app.select_toggle = !app.select_toggle
						}
					)),
					gui.column(
						padding: gui.padding_none
						content: [
							toggle_row_radio('radio button A', 'radio_a', gui.radio(
								selected: app.select_radio == 'radio_a'
							)),
							toggle_row_radio('radio button B', 'radio_b', gui.radio(
								selected: app.select_radio == 'radio_b'
							)),
							toggle_row_radio('radio button C', 'radio_c', gui.radio(
								selected: app.select_radio == 'radio_c'
							)),
						]
					),
					toggle_row('switch ', gui.switch(
						selected: app.select_switch
						on_click: fn (_ &gui.SwitchCfg, mut e gui.Event, mut w gui.Window) {
							mut app := w.state[GalleryApp]()
							app.select_switch = !app.select_switch
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
		content: [
			gui.row(
				padding: gui.padding_none
				content: [button]
			),
			gui.text(text: label),
		]
	)
}

fn toggle_row_radio(label string, id string, button gui.View) gui.View {
	return gui.row(
		id:           id
		padding:      gui.padding_none
		h_align:      .center
		v_align:      .middle
		content:      [
			gui.row(
				padding: gui.padding_none
				content: [button]
			),
			gui.text(text: label),
		]
		on_click:     fn (cfg &gui.ContainerCfg, mut e gui.Event, mut w gui.Window) {
			mut app := w.state[GalleryApp]()
			app.select_radio = cfg.id
			e.is_handled = true
		}
		amend_layout: fn (mut node gui.Layout, mut w gui.Window) {
			ctx := w.context()
			if !node.shape.disabled
				&& node.shape.point_in_shape(f32(ctx.mouse_pos_x), f32(ctx.mouse_pos_y))
				&& !w.dialog_is_visible() {
				w.set_mouse_cursor_pointing_hand()
			}
		}
	)
}

// ==============================================================
// Dialogs
// ==============================================================

fn dialogs(w &gui.Window) gui.View {
	return gui.column(
		sizing:  gui.fill_fit
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

Buttons can be left/center/right aligned'
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
	app := w.state[GalleryApp]()
	return gui.row(
		content: [
			gui.select(
				id:              'sel1'
				window:          mut w
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
// Image
// ==============================================================

fn image_sample(w &gui.Window) gui.View {
	return gui.column(
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
