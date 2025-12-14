import gui
import encoding.csv
import math

// Showcase
// =============================
// Oh majeuere, dim the lights...

const id_scroll_gallery = 1
const id_scroll_list_box = 2

enum TabItem {
	tab_stock = 1000
	tab_icons
	tab_image
	tab_menus
	tab_dialogs
	tab_tree_view
	tab_text_view
	tab_table_view
}

@[heap]
struct ShowcaseApp {
pub mut:
	light_theme  bool
	selected_tab TabItem = .tab_stock
	// buttons
	button_clicks int
	// inputs
	input_text      string
	input_multiline string = 'Now is the time for all good men to come to the aid of their country'
	// toggles
	select_toggle   bool
	select_checkbox bool
	select_city     string = 'ny'
	select_switch   bool
	// menu
	selected_menu_id string
	search_text      string
	// range sliders
	range_value f32 = 50
	// select
	selected_1 []string
	selected_2 []string
	// tree view
	tree_id string
	// list Box
	list_box_multiple_select bool
	list_box_selected_values []string
	// expand_pad
	open_expand_panel bool
	// Tables
	csv_table TableData
}

@[heap]
struct TableData {
pub mut:
	sort_by  int // 1's based sort column index. -sort_by = descending order, 0 == unsorted
	sorted   [][]string
	unsorted [][]string
}

fn main() {
	mut window := gui.window(
		title:        'Gui Showcase'
		state:        &ShowcaseApp{}
		width:        800
		height:       600
		cursor_blink: true
		on_init:      fn (mut w gui.Window) {
			mut app := w.state[ShowcaseApp]()
			app.csv_table = get_table_data() or { panic(err.msg()) }
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
	mut app := w.state[ShowcaseApp]()
	return gui.column(
		fill:    true
		color:   gui.theme().color_panel
		sizing:  gui.fit_fill
		content: [
			tab_select('Stock', .tab_stock, app),
			tab_select('Icons', .tab_icons, app),
			tab_select('Image', .tab_image, app),
			tab_select('Menus', .tab_menus, app),
			tab_select('Dialogs', .tab_dialogs, app),
			tab_select('Tree View', .tab_tree_view, app),
			tab_select('Text', .tab_text_view, app),
			tab_select('Tables', .tab_table_view, app),
			gui.column(sizing: gui.fit_fill),
			toggle_theme(app),
		]
	)
}

fn gallery(mut w gui.Window) gui.View {
	mut app := w.state[ShowcaseApp]()
	return gui.column(
		id_scroll:       id_scroll_gallery
		scrollbar_cfg_y: &gui.ScrollbarCfg{
			gap_edge: 4
		}
		sizing:          gui.fill_fill
		spacing:         gui.spacing_large * 2
		content:         match app.selected_tab {
			.tab_stock {
				[buttons(w), inputs(w), toggles(w), select_drop_down(w),
					list_box(w), expand_panel(w), progress_bars(w),
					range_sliders(w), pulsars(w)]
			}
			.tab_icons {
				[icons(mut w)]
			}
			.tab_image {
				[image_sample(w)]
			}
			.tab_menus {
				[menus(mut w)]
			}
			.tab_dialogs {
				[dialogs(w)]
			}
			.tab_tree_view {
				[tree_view(mut w)]
			}
			.tab_text_view {
				[text_sizes_weights(w), rich_text_format(w)]
			}
			.tab_table_view {
				[tables(mut w)]
			}
		}
	)
}

fn tab_select(label string, tab_item TabItem, app &ShowcaseApp) gui.View {
	color := if app.selected_tab == tab_item {
		gui.theme().color_active
	} else {
		gui.color_transparent
	}
	return gui.row(
		color:    color
		fill:     app.selected_tab == tab_item
		padding:  gui.theme().padding_small
		content:  [gui.text(text: label, text_style: gui.theme().n2)]
		on_click: fn [tab_item] (_ voidptr, mut e gui.Event, mut w gui.Window) {
			mut app := w.state[ShowcaseApp]()
			app.selected_tab = tab_item
			w.update_view(main_view)
		}
		on_hover: fn (mut layout gui.Layout, mut _ gui.Event, mut w gui.Window) {
			layout.shape.fill = true
			layout.shape.color = gui.theme().color_hover
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
		padding: gui.padding(2, 5, 0, 0)
		sizing:  gui.fill_fit
		content: [
			gui.row(
				height:  1
				sizing:  gui.fill_fit
				fill:    true
				padding: gui.padding_none
				color:   gui.theme().color_active
			),
		]
	)
}

fn toggle_theme(app &ShowcaseApp) gui.View {
	return gui.toggle(
		text_select:   gui.icon_moon
		text_unselect: gui.icon_sunny_o
		text_style:    gui.theme().icon3
		padding:       gui.padding_small
		select:        app.light_theme
		on_click:      fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
			mut app := w.state[ShowcaseApp]()
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
	app := w.state[ShowcaseApp]()
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
						on_click:       fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
							mut app := w.state[ShowcaseApp]()
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

fn button_click(_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
	e.is_handled = true
}

// ==============================================================
// Inputs
// ==============================================================

fn inputs(w &gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
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
						width:           150
						sizing:          gui.fixed_fit
						text:            app.input_text
						padding_border:  gui.padding_one
						placeholder:     'Thin Border...'
						mode:            .single_line
						on_text_changed: text_changed
					),
					gui.input(
						id_focus:        202
						width:           150
						sizing:          gui.fixed_fit
						text:            app.input_text
						padding_border:  gui.padding_two
						placeholder:     'Thicker Border...'
						mode:            .single_line
						on_text_changed: text_changed
					),
					gui.input(
						id_focus:        203
						width:           150
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
						on_text_changed: fn (_ &gui.Layout, s string, mut w gui.Window) {
							mut app := w.state[ShowcaseApp]()
							app.input_multiline = s
						}
					),
				]
			),
		]
	)
}

fn text_changed(_ &gui.Layout, s string, mut w gui.Window) {
	mut app := w.state[ShowcaseApp]()
	app.input_text = s
}

// ==============================================================
// Toggles
// ==============================================================

fn toggles(w &gui.Window) gui.View {
	mut app := w.state[ShowcaseApp]()
	options := [
		gui.radio_option('New York', 'ny'),
		gui.radio_option('Chicago', 'chi'),
		gui.radio_option('Denver', 'den'),
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
						select:   app.select_checkbox
						on_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
							mut app := w.state[ShowcaseApp]()
							app.select_checkbox = !app.select_checkbox
						}
					),
					gui.toggle(
						label:       'toggle with custom text'
						select:      app.select_toggle
						text_select: 'X'
						text_style:  gui.theme().text_style
						on_click:    fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
							mut app := w.state[ShowcaseApp]()
							app.select_toggle = !app.select_toggle
						}
					),
					gui.switch(
						label:    'switch'
						select:   app.select_switch
						on_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
							mut app := w.state[ShowcaseApp]()
							app.select_switch = !app.select_switch
						}
					),
				]
			),
			gui.row(
				content: [
					gui.radio_button_group_column(
						title:     'Time Zone'
						id_focus:  3000
						value:     app.select_city
						options:   options
						on_select: fn (value string, mut w gui.Window) {
							mut app := w.state[ShowcaseApp]()
							app.select_city = value
						}
					),
					// Intentionally using the same data/focus id to show vertical
					// and horizontal differences side-by-side
					gui.radio_button_group_row(
						title:     'Time Zone'
						id_focus:  3000
						value:     app.select_city
						options:   options
						on_select: fn (value string, mut w gui.Window) {
							mut app := w.state[ShowcaseApp]()
							app.select_city = value
						}
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
		on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
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
		on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
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
		on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
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
		on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
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
								on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
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

fn menus(mut w gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
	return gui.column(
		sizing:  gui.fill_fit
		padding: gui.padding_none
		content: [
			view_title('Menus'),
			gui.column(
				sizing:  gui.fill_fit
				content: [
					menu(mut w),
					gui.text(
						text: if app.selected_menu_id !in ['', 'file', 'edit', 'view', 'go', 'window'] {
							'Selected: "${app.selected_menu_id}"'
						} else {
							''
						}
					),
				]
			),
		]
	)
}

fn menu(mut window gui.Window) gui.View {
	app := window.state[ShowcaseApp]()

	return window.menubar(
		id_focus: 500
		action:   fn (id string, mut e gui.Event, mut w gui.Window) {
			mut app := w.state[ShowcaseApp]()
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
							on_text_changed:   fn (_ &gui.Layout, s string, mut w gui.Window) {
								mut app := w.state[ShowcaseApp]()
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
		sizing:  gui.fill_fit
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

	app := w.state[ShowcaseApp]()
	percent := app.range_value / f32(100)

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
						percent:         percent
						text_background: tbg1
						text_fill:       true
					),
					gui.progress_bar(
						sizing:  gui.fill_fixed
						percent: percent
					),
					gui.progress_bar(
						height:  20
						sizing:  gui.fill_fixed
						percent: percent
					),
					gui.progress_bar(
						height:    20
						sizing:    gui.fill_fixed
						percent:   percent
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
						percent:         percent
						text_background: tbg2
						text_fill:       false
					),
					gui.progress_bar(
						vertical: true
						sizing:   gui.fixed_fill
						percent:  percent
					),
					gui.progress_bar(
						vertical: true
						sizing:   gui.fixed_fill
						width:    20
						percent:  percent
					),
				]
			),
		]
	)
}

// ==============================================================
// List Box
// ==============================================================

fn list_box(w &gui.Window) gui.View {
	return gui.column(
		sizing:  gui.fill_fit
		padding: gui.padding_none
		content: [
			view_title('List Box'),
			gui.row(
				sizing:  gui.fill_fit
				content: [list_box_sample(w)]
			),
		]
	)
}

fn list_box_sample(w &gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
	return gui.row(
		height:  250
		sizing:  gui.fit_fixed
		content: [
			gui.list_box(
				id_scroll: id_scroll_list_box
				multiple:  app.list_box_multiple_select
				selected:  app.list_box_selected_values
				sizing:    gui.fit_fill
				data:      [
					gui.list_box_option('---States', ''),
					gui.list_box_option('Alabama', 'AL'),
					gui.list_box_option('Alaska', 'AK'),
					gui.list_box_option('Arizona', 'AZ'),
					gui.list_box_option('Arkansas', 'AR'),
					gui.list_box_option('California', 'CA'),
					gui.list_box_option('Colorado', 'CO'),
					gui.list_box_option('Connecticut', 'CT'),
					gui.list_box_option('Delaware', 'DE'),
					gui.list_box_option('District of Columbia', 'DC'),
					gui.list_box_option('Florida', 'FL'),
					gui.list_box_option('Georgia', 'GA'),
					gui.list_box_option('Hawaii', 'HI'),
					gui.list_box_option('Idaho', 'ID'),
					gui.list_box_option('Illinois', 'IL'),
					gui.list_box_option('Indiana', 'IN'),
					gui.list_box_option('Iowa', 'IA'),
					gui.list_box_option('Kansas', 'KS'),
					gui.list_box_option('Kentucky', 'KY'),
					gui.list_box_option('Louisiana', 'LA'),
					gui.list_box_option('Maine', 'ME'),
					gui.list_box_option('Maryland', 'MD'),
					gui.list_box_option('Massachusetts', 'MA'),
					gui.list_box_option('Michigan', 'MI'),
					gui.list_box_option('Minnesota', 'MN'),
					gui.list_box_option('Mississippi', 'MS'),
					gui.list_box_option('Missouri', 'MO'),
					gui.list_box_option('Montana', 'MT'),
					gui.list_box_option('Nebraska', 'NE'),
					gui.list_box_option('Nevada', 'NV'),
					gui.list_box_option('New Hampshire', 'NH'),
					gui.list_box_option('New Jersey', 'NJ'),
					gui.list_box_option('New Mexico', 'NM'),
					gui.list_box_option('New York', 'NY'),
					gui.list_box_option('North Carolina', 'NC'),
					gui.list_box_option('North Dakota', 'ND'),
					gui.list_box_option('Ohio', 'OH'),
					gui.list_box_option('Oklahoma', 'OK'),
					gui.list_box_option('Oregon', 'OR'),
					gui.list_box_option('Pennsylvania', 'PA'),
					gui.list_box_option('Rhode Island', 'RI'),
					gui.list_box_option('South Carolina', 'SC'),
					gui.list_box_option('South Dakota', 'SD'),
					gui.list_box_option('Tennessee', 'TN'),
					gui.list_box_option('Texas', 'TX'),
					gui.list_box_option('Utah', 'UT'),
					gui.list_box_option('Vermont', 'VT'),
					gui.list_box_option('Virginia', 'VA'),
					gui.list_box_option('Washington', 'WA'),
					gui.list_box_option('West Virginia', 'WV'),
					gui.list_box_option('Wisconsin', 'WI'),
					gui.list_box_option('Wyoming', 'WY'),
					gui.list_box_option('---Territories', ''),
					gui.list_box_option('American Somoa', 'AS'),
					gui.list_box_option('Guam', 'GU'),
					gui.list_box_option('Northern Mariana Islands', 'MP'),
					gui.list_box_option('Puerto Rico', 'PR'),
					gui.list_box_option('U.S. Virgin Islands', 'VI'),
				]
				on_select: fn (values []string, mut e gui.Event, mut w gui.Window) {
					mut app := w.state[ShowcaseApp]()
					app.list_box_selected_values = values
					e.is_handled = true
				}
			),
			gui.toggle(
				label:    'Multi-Select'
				select:   app.list_box_multiple_select
				on_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
					mut app := w.state[ShowcaseApp]()
					app.list_box_multiple_select = !app.list_box_multiple_select
					app.list_box_selected_values.clear()
				}
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
	app := w.state[ShowcaseApp]()
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
							mut app := w.state[ShowcaseApp]()
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
							mut app := w.state[ShowcaseApp]()
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
		sizing:  gui.fill_fit
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
	app := w.state[ShowcaseApp]()
	return gui.row(
		content: [
			w.select(
				id:              'sel1'
				min_width:       200
				max_width:       200
				select:          app.selected_1
				placeholder:     'Pick one or more'
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
					mut app_ := w.state[ShowcaseApp]()
					app_.selected_1 = s
					e.is_handled = true
				}
			),
			w.select(
				id:          'sel2'
				min_width:   300
				max_width:   300
				select:      app.selected_2
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
					mut app_ := w.state[ShowcaseApp]()
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
		longest = f32_max(gui.get_text_width(s, gui.theme().n4, mut w), longest)
	}

	// Break the icons_maps into rows
	chunks := chunk_map(gui.icons_map, 4)
	mut all_icons := []gui.View{cap: chunks.len}
	unsafe { all_icons.flags.set(.noslices) }

	// create rows of icons/text
	for chunk in chunks {
		mut icons := []gui.View{cap: chunk.len}
		unsafe { icons.flags.set(.noslices) }
		for key, val in chunk {
			icons << gui.column(
				min_width: longest
				h_align:   .center
				padding:   gui.padding_none
				content:   [
					gui.text(text: val, text_style: gui.theme().icon1),
					gui.text(text: key, text_style: gui.theme().n4),
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
	mut chunks := []map[K]V{cap: input.keys().len / chunk_size + 1}
	unsafe { chunks.flags.set(.noslices) }
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

// ==============================================================
// Tree View
// ==============================================================

fn tree_view(mut w gui.Window) gui.View {
	return gui.column(
		padding: gui.padding_none
		sizing:  gui.fill_fill
		content: [
			view_title('TreeView'),
			gui.row(
				sizing:  gui.fill_fit
				spacing: 0
				padding: gui.padding_none
				content: [tree_view_sample(mut w)]
			),
		]
	)
}

fn on_select(id string, mut w gui.Window) {
	mut app := w.state[ShowcaseApp]()
	app.tree_id = id
}

fn tree_view_sample(mut w gui.Window) gui.View {
	mut app := w.state[ShowcaseApp]()
	return gui.column(
		sizing:  gui.fill_fit
		padding: gui.padding_none
		content: [
			gui.text(text: '[ ${app.tree_id} ]'),
			w.tree(
				id:        'animals'
				on_select: on_select
				nodes:     [
					gui.tree_node(
						text:  'Mammals'
						icon:  gui.icon_github_alt
						nodes: [
							gui.tree_node(text: 'Lion'),
							gui.tree_node(text: 'Cat'),
							gui.tree_node(text: 'Human', icon: gui.icon_user),
						]
					),
					gui.tree_node(
						text:  'Birds'
						icon:  gui.icon_twitter
						nodes: [
							gui.tree_node(text: 'Condor'),
							gui.tree_node(
								text:  'Eagle'
								nodes: [
									gui.tree_node(text: 'Bald'),
									gui.tree_node(text: 'Golden'),
									gui.tree_node(text: 'Sea'),
								]
							),
							gui.tree_node(text: 'Parrot', icon: gui.icon_cage),
							gui.tree_node(text: 'Robin'),
						]
					),
					gui.tree_node(
						text:  'Insects'
						icon:  gui.icon_bug
						nodes: [
							gui.tree_node(text: 'Butterfly'),
							gui.tree_node(text: 'House Fly'),
							gui.tree_node(text: 'Locust'),
							gui.tree_node(text: 'Moth'),
						]
					),
				]
			),
		]
	)
}

// ==============================================================
// Expand Panel
// ==============================================================

fn expand_panel(w &gui.Window) gui.View {
	return gui.column(
		padding: gui.padding_none
		sizing:  gui.fill_fill
		content: [
			view_title('Expand Panel'),
			gui.row(
				padding: gui.padding_none
				sizing:  gui.fill_fit
				spacing: 0
				content: [expand_panel_sample(w)]
			),
		]
	)
}

fn expand_panel_sample(w &gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
	return gui.expand_panel(
		open:      app.open_expand_panel
		max_width: 500
		sizing:    gui.fill_fit
		head:      gui.row(
			padding: gui.theme().padding_small
			sizing:  gui.fill_fit
			v_align: .middle
			content: [
				gui.text(text: 'Brazil'),
				gui.row(sizing: gui.fill_fit),
				gui.text(text: 'South America', text_style: gui.theme().n4),
			]
		)
		content:   gui.column(
			sizing:  gui.fill_fit
			padding: gui.padding_small
			content: [
				gui.text(
					text:       brazil_text
					text_style: gui.theme().n4
					mode:       .wrap
				),
			]
		)
		on_toggle: fn (mut w gui.Window) {
			mut app := w.state[ShowcaseApp]()
			app.open_expand_panel = !app.open_expand_panel
		}
	)
}

const brazil_text = 'The word "Brazil" likely comes from the Portuguese word for brazilwood, a tree that once grew plentifully along the Brazilian coast. In Portuguese, brazilwood is called pau-brasil, with the word brasil commonly given the etymology "red like an ember", formed from brasa ("ember") and the suffix -il (from -iculum or -ilium). As brazilwood produces a deep red dye, it was highly valued by the European textile industry and was the earliest commercially exploited product from Brazil. Throughout the 16th century, massive amounts of brazilwood were harvested by indigenous peoples (mostly Tupi) along the Brazilian coast, who sold the timber to European traders (mostly Portuguese, but also French) in return for assorted European consumer goods.'

// ==============================================================
// Pulsars
// ==============================================================

fn pulsars(w &gui.Window) gui.View {
	return gui.column(
		padding: gui.padding_none
		sizing:  gui.fill_fill
		content: [
			view_title('Pulsars'),
			gui.row(
				padding: gui.padding_none
				sizing:  gui.fill_fit
				spacing: 0
				content: [pulsar_samples(w)]
			),
		]
	)
}

fn pulsar_samples(w &gui.Window) gui.View {
	return gui.row(
		content: [
			w.pulsar(),
			w.pulsar(size: 20),
			w.pulsar(size: 30, color: gui.orange),
			w.pulsar(size: 30, icon1: gui.icon_heart, icon2: gui.icon_heart_o, color: gui.red),
			w.pulsar(size: 30, icon1: gui.icon_expand, icon2: gui.icon_compress, color: gui.green),
		]
	)
}

// ==============================================================
// Text Sizes & Weights
// ==============================================================

fn text_sizes_weights(w &gui.Window) gui.View {
	text_style_file := gui.TextStyle{
		...gui.theme().text_style
		color: gui.theme().color_border
	}
	variants := gui.font_variants(gui.theme().text_style)
	return gui.column(
		sizing:  gui.fill_fit
		padding: gui.padding_none
		content: [
			view_title('Text Sizes & Weights'),
			gui.column(
				spacing: 0
				padding: gui.padding_none
				content: [
					gui.text(text: variants.normal, text_style: text_style_file),
					gui.row(
						padding: gui.padding_none
						sizing:  gui.fill_fit
						v_align: .bottom
						content: [
							gui.text(text: 'Theme().n1', text_style: gui.theme().n1),
							gui.text(text: 'Theme().n2', text_style: gui.theme().n2),
							gui.text(text: 'Theme().n3', text_style: gui.theme().n3),
							gui.text(text: 'Theme().n4', text_style: gui.theme().n4),
							gui.text(text: 'Theme().n5', text_style: gui.theme().n5),
							gui.text(text: 'Theme().n6', text_style: gui.theme().n6),
						]
					),
				]
			),
			gui.column(
				spacing: 0
				padding: gui.padding_none
				content: [
					gui.text(text: variants.bold, text_style: text_style_file),
					gui.row(
						padding: gui.padding_none
						sizing:  gui.fill_fit
						v_align: .bottom
						content: [
							gui.text(text: 'Theme().b1', text_style: gui.theme().b1),
							gui.text(text: 'Theme().b2', text_style: gui.theme().b2),
							gui.text(text: 'Theme().b3', text_style: gui.theme().b3),
							gui.text(text: 'Theme().b4', text_style: gui.theme().b4),
							gui.text(text: 'Theme().b5', text_style: gui.theme().b5),
							gui.text(text: 'Theme().b6', text_style: gui.theme().b6),
						]
					),
				]
			),
			gui.column(
				spacing: 0
				padding: gui.padding_none
				content: [
					gui.text(text: variants.italic, text_style: text_style_file),
					gui.row(
						padding: gui.padding_none
						sizing:  gui.fill_fit
						v_align: .bottom
						content: [
							gui.text(text: 'Theme().i1', text_style: gui.theme().i1),
							gui.text(text: 'Theme().i2', text_style: gui.theme().i2),
							gui.text(text: 'Theme().i3', text_style: gui.theme().i3),
							gui.text(text: 'Theme().i4', text_style: gui.theme().i4),
							gui.text(text: 'Theme().i5', text_style: gui.theme().i5),
							gui.text(text: 'Theme().i6', text_style: gui.theme().i6),
						]
					),
				]
			),
			gui.column(
				spacing: 0
				padding: gui.padding_none
				content: [
					gui.text(text: variants.mono, text_style: text_style_file),
					gui.row(
						padding: gui.padding_none
						sizing:  gui.fill_fit
						v_align: .bottom
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
			),
		]
	)
}

// ==============================================================
// Rich Text Format
// ==============================================================
fn rich_text_format(w &gui.Window) gui.View {
	return gui.column(
		padding: gui.padding_none
		sizing:  gui.fill_fill
		content: [
			view_title('Rich Text Format (RTF)'),
			gui.row(
				padding: gui.padding_none
				sizing:  gui.fill_fit
				spacing: 0
				content: [rtf_sample(w)]
			),
		]
	)
}

fn rtf_sample(w &gui.Window) gui.View {
	return gui.column(
		padding: gui.padding_none
		sizing:  gui.fill_fill
		content: [
			gui.rtf(
				mode:  .wrap
				spans: [
					gui.span('Hello', gui.theme().n3),
					gui.span(' RTF ', gui.theme().b3),
					gui.span('World', gui.theme().n3),
					gui.br(),
					gui.br(),
					gui.strike_span('Now is the', gui.theme().n3),
					gui.span(' ', gui.theme().n3),
					gui.span('time', gui.theme().i3),
					gui.span(' for all', gui.theme().n3),
					gui.span(' good men ', gui.TextStyle{
						...gui.theme().n3
						color: gui.green
					}),
					gui.span('to come to the aid of their ', gui.theme().n3),
					gui.uspan('country', gui.theme().b3),
					gui.br(),
					gui.br(),
					gui.span('This is a ', gui.theme().n3),
					gui.hyperlink('hyperlink', 'https://www.example.com', gui.theme().n3),
				]
			),
		]
	)
}

// ==============================================================
// Tables
// ==============================================================
fn tables(mut w gui.Window) gui.View {
	return gui.column(
		padding: gui.padding_none
		sizing:  gui.fill_fill
		content: [
			view_title('Tables'),
			gui.row(
				padding: gui.padding_none
				sizing:  gui.fill_fit
				spacing: 0
				content: [table_samples(mut w)]
			),
		]
	)
}

fn table_samples(mut w gui.Window) gui.View {
	mut app := w.state[ShowcaseApp]()
	return gui.column(
		content: [
			gui.text(text: 'Declarative Layout', text_style: gui.theme().b2),
			w.table(
				text_style_head: gui.theme().b3
				data:            [
					gui.tr([gui.th('First'), gui.th('Last'), gui.th('Email')]),
					gui.tr([gui.td('Matt'), gui.td('Williams'),
						gui.td('non.egestas.a@protonmail.org')]),
					gui.tr([gui.td('Clara'), gui.td('Nelson'),
						gui.td('mauris.sagittis@icloud.net')]),
					gui.tr([gui.td('Frank'), gui.td('Johnson'),
						gui.td('ac.libero.nec@aol.com')]),
					gui.tr([gui.td('Elmer'), gui.td('Fudd'), gui.td('mus@aol.couk')]),
					gui.tr([gui.td('Roy'), gui.td('Rogers'), gui.td('amet.ultricies@yahoo.com')]),
				]
			),
			gui.text(text: ''),
			gui.text(text: 'CSV Data', text_style: gui.theme().b2),
			table_with_sortable_columns(mut app.csv_table, mut w),
			gui.text(text: ''),
		]
	)
}

fn table_with_sortable_columns(mut table_data TableData, mut window gui.Window) gui.View {
	mut table_cfg := gui.table_cfg_from_data(table_data.sorted)
	// Replace with first row with clickable column headers
	mut tds := []gui.TableCellCfg{}
	unsafe { tds.flags.set(.noslices) }
	for idx, cell in table_cfg.data[0].cells {
		tds << gui.TableCellCfg{
			...cell
			value:    match true {
				idx + 1 == table_data.sort_by { cell.value + '  ↓' }
				-(idx + 1) == table_data.sort_by { cell.value + ' ↑' }
				else { cell.value }
			}
			on_click: fn [idx, mut table_data] (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
				table_data.sort_by = match true {
					table_data.sort_by == (idx + 1) { -(idx + 1) }
					table_data.sort_by == -(idx + 1) { 0 }
					else { idx + 1 }
				}
				table_sort(mut table_data)
				e.is_handled = true
			}
		}
	}

	table_cfg.data.delete(0)
	table_cfg.data.insert(0, gui.tr(tds))
	return window.table(table_cfg)
}

fn table_sort(mut table_data TableData) {
	if table_data.sort_by == 0 {
		table_data.sorted = table_data.unsorted
		return
	}
	direction := table_data.sort_by > 0
	idx := math.abs(table_data.sort_by) - 1
	head_row := table_data.sorted[0]
	table_data.sorted.delete(0) // duplicates the array so no clone needed above
	table_data.sorted.sort_with_compare(fn [direction, idx] (mut a []string, mut b []string) int {
		return match true {
			a[idx] < b[idx] && direction { -1 }
			a[idx] > b[idx] && !direction { -1 }
			a[idx] > b[idx] && direction { 1 }
			a[idx] < b[idx] && !direction { 1 }
			else { 0 }
		}
	})
	table_data.sorted.insert(0, head_row)
}

fn get_table_data() !TableData {
	mut table_data := TableData{}
	mut parser := csv.csv_reader_from_string(csv_table_data_source)!
	for y in 0 .. int(parser.rows_count()!) {
		table_data.unsorted << parser.get_row(y)!
	}
	table_data.sorted = table_data.unsorted
	return table_data
}

const csv_table_data_source = 'Name,Phone,Email,Address,Postal Zip,Region
Keelie Snow,1-164-548-3178,erat.vivamus@icloud.net,Ap #414-702 Libero Avenue,698863,Chernivtsi oblast
Anthony Keith,1-918-510-5824,pulvinar.arcu@google.ca,Ap #358-7921 Placerat. Street,S4V 2M4,Leinster
Carissa Larson,1-646-772-7793,enim.gravida@aol.couk,"667-994 Mi, St.",1231,Sardegna
Joseph Herrera,1-746-758-0438,posuere@hotmail.couk,Ap #638-5604 Adipiscing Ave,51262,Pará
Nerea Romero,1-425-458-5525,pretium.neque@google.edu,990-4951 Mauris St.,46317,Junín
Macey Reed,1-175-242-2264,massa.quisque@hotmail.couk,1239 Arcu. Av.,WI1 8TR,Lai Châu
Craig Roach,1-541-688-6830,lorem.sit@hotmail.ca,385-9173 Libero. Rd.,07132,Newfoundland and Labrador
Yardley Barlow,1-648-862-5647,sodales@hotmail.couk,893-8994 Aliquet. St.,97-286,Lambayeque
Shad Whitfield,1-525-513-5416,augue.id.ante@protonmail.org,Ap #560-3609 Lorem Ave,70666,North Jeolla
Eugenia Bell,1-578-560-1252,laoreet.ipsum@icloud.edu,"P.O. Box 922, 5077 Sed Ave",28133,Kon Tum
Nash Hernandez,1-897-393-7624,convallis.convallis.dolor@google.couk,5853 Diam. Rd.,734884,Tasmania
Rinah Woods,1-698-796-5903,dui.nec.urna@icloud.ca,252-4094 Neque. Avenue,17571,Northern Territory
Jescie Beasley,1-264-555-2460,sapien.cursus@google.org,"873-7406 At, Rd.",44324,Gyeonggi
Jordan Harrison,1-627-442-6681,scelerisque.scelerisque@hotmail.net,696-2283 Turpis Rd.,3709,Umbria
Abdul Rowe,1-384-151-2787,ornare.fusce.mollis@hotmail.edu,"Ap #856-6933 Ut, St.",25878,Mississippi
Simone Bullock,1-623-422-9718,sed.facilisis@outlook.couk,2620 Mattis St.,49275,Luxemburg
Lillian Montgomery,1-317-854-9787,ut@outlook.couk,Ap #132-4005 Enim Ave,571928,Leinster
Tanisha Rodriquez,1-217-655-3165,id@aol.couk,"P.O. Box 490, 1311 Et, Road",45133,Chiapas
Alexandra Dyer,1-442-662-6576,amet.consectetuer.adipiscing@protonmail.edu,Ap #474-4869 Malesuada St.,613696,Rajasthan
Gretchen Carr,1-465-576-3555,eu.nibh@yahoo.org,Ap #617-6465 Nascetur Rd.,872532,São Paulo
Patience Cobb,1-833-211-2532,sed@hotmail.couk,1431 Pellentesque Street,644218,Paraná
Jaquelyn Carlson,1-774-851-3274,amet.dapibus@aol.ca,"Ap #529-8389 Lectus, Av.",5680-5371,Central Region
Britanney Silva,1-281-414-9085,nascetur.ridiculus.mus@google.ca,429-6408 Nec Rd.,6132,Vorarlberg
Brennan Hooper,1-534-697-7689,nunc.pulvinar.arcu@aol.edu,Ap #425-8524 Pellentesque. Ave,8834,Morayshire
Eliana Fry,1-822-880-5214,orci.luctus.et@protonmail.edu,351-931 Non St.,731577,Viken
'
