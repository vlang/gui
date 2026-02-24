import gui

// Theme Designer v2 — 3-panel MUI-style interactive theme editor.
// Left: navigation, Center: mock app preview, Right: theme editor.

// Layout constants
const window_width = 1400
const window_height = 900
const cp_sv_size = f32(160)
const swatch_w = 36
const swatch_h = 22

// Focus ID blocks
const id_focus_nav_base = u32(10) // 10-13
const id_focus_preset_base = u32(20) // 20-24
const id_focus_color_base = u32(30) // 30-39
const id_focus_style_base = u32(50) // 50-52
const id_focus_type_base = u32(55) // 55
const id_focus_preview_base = u32(100)

// Scroll IDs
const id_scroll_editor = u32(1)
const id_scroll_preview = u32(2)

// Sample table data
const table_data = [
	['Alice Johnson', 'alice@example.com', 'Admin', 'Active'],
	['Bob Smith', 'bob@example.com', 'Editor', 'Active'],
	['Carol White', 'carol@example.com', 'Viewer', 'Inactive'],
	['David Brown', 'david@example.com', 'Editor', 'Active'],
	['Eve Davis', 'eve@example.com', 'Admin', 'Active'],
	['Frank Miller', 'frank@example.com', 'Viewer', 'Pending'],
	['Grace Wilson', 'grace@example.com', 'Editor', 'Active'],
	['Henry Taylor', 'henry@example.com', 'Viewer', 'Inactive'],
]

// Nav page identifiers
const nav_pages = ['dashboard', 'login', 'settings', 'table']
const nav_labels = ['Dashboard', 'Login', 'Settings', 'Data Table']

@[heap]
struct ThemeDesignerState {
pub mut:
	// Navigation
	selected_page string = 'dashboard'
	// Splitter
	split_nav    gui.SplitterState = gui.SplitterState{
		ratio: 0.12
	}
	split_editor gui.SplitterState = gui.SplitterState{
		ratio: 0.70
	}
	// 9 semantic colors + text
	color_background   gui.Color
	color_panel        gui.Color
	color_interior     gui.Color
	color_hover        gui.Color
	color_focus        gui.Color
	color_active       gui.Color
	color_border       gui.Color
	color_border_focus gui.Color
	color_select       gui.Color
	color_text         gui.Color
	// Style
	radius      f32
	size_border f32
	spacing     f32
	font_size   f32
	// Editor
	selected_color string = 'background'
	colors_open    bool   = true
	style_open     bool   = true
	type_open      bool
	preset_gen     int
	// JSON
	json_text string
	// Preview widget state
	login_email    string
	login_password string
	settings_name  string = 'Jane Doe'
	settings_email string = 'jane@example.com'
	settings_notif bool   = true
	settings_auto  bool
	settings_theme string = 'Dark'
	dash_slider    f32    = 65
	search_query   string
}

// ============================================================
// Main + Layout
// ============================================================

fn main() {
	mut app := &ThemeDesignerState{}
	apply_cfg_to_state(gui.theme_dark_bordered_cfg, mut app)
	app.json_text = gui.theme_to_json(build_theme_cfg(app))

	mut window := gui.window(
		title:        'Theme Designer'
		state:        app
		width:        window_width
		height:       window_height
		cursor_blink: true
		on_init:      fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(mut window gui.Window) gui.View {
	w, h := window.window_size()
	app := window.state[ThemeDesignerState]()
	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		padding: gui.padding_none
		spacing: 0
		content: [
			gui.splitter(
				id:                    'split_editor'
				id_focus:              1
				sizing:                gui.fill_fill
				orientation:           .horizontal
				ratio:                 app.split_editor.ratio
				collapsed:             app.split_editor.collapsed
				show_collapse_buttons: false
				on_change:             on_editor_split_change
				first:                 gui.SplitterPaneCfg{
					min_size: 400
					content:  [nav_and_preview(mut window)]
				}
				second:                gui.SplitterPaneCfg{
					min_size: 300
					content:  [editor_panel(&window)]
				}
			),
		]
	)
}

fn nav_and_preview(mut window gui.Window) gui.View {
	app := window.state[ThemeDesignerState]()
	return gui.splitter(
		id:                    'split_nav'
		id_focus:              2
		sizing:                gui.fill_fill
		orientation:           .horizontal
		ratio:                 app.split_nav.ratio
		collapsed:             app.split_nav.collapsed
		show_collapse_buttons: false
		on_change:             on_nav_split_change
		first:                 gui.SplitterPaneCfg{
			min_size: 100
			max_size: 220
			content:  [nav_panel(&window)]
		}
		second:                gui.SplitterPaneCfg{
			min_size: 300
			content:  [preview_panel(mut window)]
		}
	)
}

fn on_editor_split_change(ratio f32, collapsed gui.SplitterCollapsed, mut _e gui.Event, mut w gui.Window) {
	mut app := w.state[ThemeDesignerState]()
	app.split_editor = gui.splitter_state_normalize(gui.SplitterState{
		ratio:     ratio
		collapsed: collapsed
	})
}

fn on_nav_split_change(ratio f32, collapsed gui.SplitterCollapsed, mut _e gui.Event, mut w gui.Window) {
	mut app := w.state[ThemeDesignerState]()
	app.split_nav = gui.splitter_state_normalize(gui.SplitterState{
		ratio:     ratio
		collapsed: collapsed
	})
}

// ============================================================
// Helpers
// ============================================================

fn lighten(c gui.Color, amount u8) gui.Color {
	r := if c.r > 255 - amount { u8(255) } else { c.r + amount }
	g := if c.g > 255 - amount { u8(255) } else { c.g + amount }
	b := if c.b > 255 - amount { u8(255) } else { c.b + amount }
	return gui.rgba(r, g, b, c.a)
}

fn darken(c gui.Color, amount u8) gui.Color {
	r := if c.r < amount { u8(0) } else { c.r - amount }
	g := if c.g < amount { u8(0) } else { c.g - amount }
	b := if c.b < amount { u8(0) } else { c.b - amount }
	return gui.rgba(r, g, b, c.a)
}

fn get_color_by_name(app &ThemeDesignerState, name string) gui.Color {
	return match name {
		'background' { app.color_background }
		'panel' { app.color_panel }
		'interior' { app.color_interior }
		'hover' { app.color_hover }
		'focus' { app.color_focus }
		'active' { app.color_active }
		'border' { app.color_border }
		'border_focus' { app.color_border_focus }
		'select' { app.color_select }
		'text' { app.color_text }
		else { app.color_background }
	}
}

fn set_color_by_name(mut app ThemeDesignerState, name string, c gui.Color) {
	match name {
		'background' { app.color_background = c }
		'panel' { app.color_panel = c }
		'interior' { app.color_interior = c }
		'hover' { app.color_hover = c }
		'focus' { app.color_focus = c }
		'active' { app.color_active = c }
		'border' { app.color_border = c }
		'border_focus' { app.color_border_focus = c }
		'select' { app.color_select = c }
		'text' { app.color_text = c }
		else {}
	}
}

fn slider_row(label string, value f32, min f32, max f32, id string,
	id_focus u32, on_change fn (f32, mut gui.Event, mut gui.Window)) gui.View {
	return gui.row(
		sizing:  gui.fill_fit
		padding: gui.padding_none
		v_align: .middle
		spacing: gui.spacing_small
		content: [
			gui.text(text: label, min_width: 60, text_style: gui.theme().n5),
			gui.range_slider(
				id:          id
				id_focus:    id_focus
				value:       value
				min:         min
				max:         max
				round_value: true
				sizing:      gui.fill_fit
				on_change:   on_change
			),
			gui.text(
				text:       '${int(value)}'
				min_width:  28
				text_style: gui.theme().n5
			),
		]
	)
}

// ============================================================
// Theme Build / Apply
// ============================================================

fn build_theme_cfg(app &ThemeDesignerState) gui.ThemeCfg {
	return gui.ThemeCfg{
		name:               'custom'
		color_background:   app.color_background
		color_panel:        app.color_panel
		color_interior:     app.color_interior
		color_hover:        app.color_hover
		color_focus:        app.color_focus
		color_active:       app.color_active
		color_border:       app.color_border
		color_border_focus: app.color_border_focus
		color_select:       app.color_select
		size_border:        app.size_border
		radius:             app.radius
		text_style:         gui.TextStyle{
			color: app.color_text
			size:  app.font_size
		}
	}
}

fn rebuild_and_apply(mut w gui.Window) {
	mut app := w.state[ThemeDesignerState]()
	cfg := build_theme_cfg(app)
	theme := gui.theme_maker(&cfg)
	w.set_theme(theme)
	app.json_text = gui.theme_to_json(cfg)
}

fn apply_cfg_to_state(cfg gui.ThemeCfg, mut app ThemeDesignerState) {
	app.color_background = cfg.color_background
	app.color_panel = cfg.color_panel
	app.color_interior = cfg.color_interior
	app.color_hover = cfg.color_hover
	app.color_focus = cfg.color_focus
	app.color_active = cfg.color_active
	app.color_border = cfg.color_border
	app.color_border_focus = cfg.color_border_focus
	app.color_select = cfg.color_select
	app.color_text = cfg.text_style.color
	app.radius = cfg.radius
	app.size_border = cfg.size_border
	app.font_size = cfg.text_style.size
}

fn apply_theme_to_state(theme gui.Theme, mut app ThemeDesignerState) {
	apply_cfg_to_state(theme.cfg, mut app)
}

fn apply_preset(preset_name string, mut w gui.Window) {
	theme := match preset_name {
		'Dark' { gui.theme_dark }
		'Light' { gui.theme_light }
		'Dark Bordered' { gui.theme_dark_bordered }
		'Light Bordered' { gui.theme_light_bordered }
		'Blue Bordered' { gui.theme_blue_bordered }
		else { gui.theme_dark_bordered }
	}
	w.set_theme(theme)
	mut app := w.state[ThemeDesignerState]()
	apply_theme_to_state(theme, mut app)
	app.json_text = gui.theme_to_json(theme.cfg)
	app.preset_gen++
}

// ============================================================
// Left Panel — Navigation
// ============================================================

fn nav_panel(window &gui.Window) gui.View {
	app := window.state[ThemeDesignerState]()
	mut items := []gui.View{cap: nav_pages.len + 2}
	items << gui.text(
		text:       'Theme Designer'
		text_style: gui.theme().b3
	)
	items << gui.row(height: 8, sizing: gui.fill_fit)
	for i, page in nav_pages {
		selected := app.selected_page == page
		label := nav_labels[i]
		items << gui.button(
			id_focus:     id_focus_nav_base + u32(i)
			sizing:       gui.fill_fit
			padding:      gui.padding(6, 10, 6, 10)
			color:        if selected {
				gui.theme().color_active
			} else {
				gui.theme().color_panel
			}
			color_border: if selected {
				gui.theme().color_select
			} else {
				gui.Color{}
			}
			size_border:  if selected { f32(1) } else { f32(0) }
			radius:       gui.theme().radius_small
			content:      [
				gui.text(
					text:       label
					text_style: if selected {
						gui.theme().b4
					} else {
						gui.theme().n4
					}
				),
			]
			on_click:     fn [page] (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
				mut state := w.state[ThemeDesignerState]()
				state.selected_page = page
			}
		)
	}
	return gui.column(
		sizing:  gui.fill_fill
		padding: gui.padding(10, 10, 10, 10)
		spacing: 4
		color:   gui.theme().color_panel
		content: items
	)
}

// ============================================================
// Center Panel — Preview
// ============================================================

fn preview_panel(mut window gui.Window) gui.View {
	app := window.state[ThemeDesignerState]()
	content := match app.selected_page {
		'login' { page_login(&window) }
		'settings' { page_settings(&window) }
		'table' { page_table(mut window) }
		else { page_dashboard(&window) }
	}
	return gui.column(
		sizing:    gui.fill_fill
		padding:   gui.padding(12, 12, 12, 12)
		spacing:   12
		color:     gui.theme().color_background
		id_scroll: id_scroll_preview
		content:   content
	)
}

// Preview helper: card wrapper
fn preview_card(title string, content []gui.View) gui.View {
	mut items := []gui.View{cap: content.len + 1}
	items << gui.text(text: title, text_style: gui.theme().b3)
	items << content
	return gui.column(
		sizing:       gui.fill_fit
		spacing:      10
		padding:      gui.padding_medium
		color:        gui.theme().color_panel
		color_border: gui.theme().color_border
		size_border:  gui.theme().size_border
		radius:       gui.theme().radius_medium
		content:      items
	)
}

// Preview helper: heading text
fn preview_heading(text string) gui.View {
	return gui.text(text: text, text_style: gui.theme().b2)
}

// ---- Dashboard Page ----

fn page_dashboard(window &gui.Window) []gui.View {
	return [
		preview_heading('Dashboard'),
		// Stat cards row
		gui.row(
			sizing:  gui.fill_fit
			spacing: 10
			content: [
				stat_card('Users', '1,234', '+5.2%'),
				stat_card('Revenue', r'$12.4k', '+8.1%'),
				stat_card('Orders', '456', '+3.7%'),
				stat_card('Growth', '+12.5%', '+2.3%'),
			]
		),
		// Storage card
		preview_card('Storage', [
			gui.row(
				sizing:  gui.fill_fit
				v_align: .middle
				content: [
					gui.text(text: 'Disk Usage'),
					gui.row(sizing: gui.fill_fit),
					gui.text(text: '72%', text_style: gui.theme().n5),
				]
			),
			gui.progress_bar(
				sizing:    gui.fill_fit
				height:    12
				percent:   0.72
				radius:    gui.theme().radius_small
				text_show: false
			),
			gui.row(
				sizing:  gui.fill_fit
				v_align: .middle
				content: [
					gui.text(text: 'Bandwidth'),
					gui.row(sizing: gui.fill_fit),
					gui.text(text: '45%', text_style: gui.theme().n5),
				]
			),
			gui.progress_bar(
				sizing:    gui.fill_fit
				height:    12
				percent:   0.45
				radius:    gui.theme().radius_small
				text_show: false
			),
		]),
		// Activity card
		preview_card('Activity', [
			gui.row(
				sizing:  gui.fill_fit
				v_align: .middle
				spacing: 10
				content: [
					gui.text(text: 'Performance'),
					gui.range_slider(
						id:          'dash_slider'
						id_focus:    id_focus_preview_base
						value:       65
						min:         0
						max:         100
						round_value: true
						sizing:      gui.fill_fit
						on_change:   fn (value f32, mut _ gui.Event, mut w gui.Window) {
							mut state := w.state[ThemeDesignerState]()
							state.dash_slider = value
						}
					),
					gui.text(
						text:       '65%'
						min_width:  35
						text_style: gui.theme().n5
					),
				]
			),
			gui.text(text: 'Recent: 12 new signups today'),
			gui.text(text: 'Pending: 3 orders awaiting review'),
			gui.text(text: 'Completed: 89 tasks this week'),
		]),
	]
}

fn stat_card(title string, value string, change string) gui.View {
	return gui.column(
		sizing:       gui.fill_fit
		spacing:      4
		padding:      gui.padding_medium
		color:        gui.theme().color_panel
		color_border: gui.theme().color_border
		size_border:  gui.theme().size_border
		radius:       gui.theme().radius_medium
		content:      [
			gui.text(text: title, text_style: gui.theme().n5),
			gui.text(text: value, text_style: gui.theme().b2),
			gui.text(text: change, text_style: gui.theme().n5),
		]
	)
}

// ---- Login Page ----

fn page_login(window &gui.Window) []gui.View {
	app := window.state[ThemeDesignerState]()
	return [
		gui.row(sizing: gui.fill_fill),
		gui.row(
			sizing:  gui.fill_fit
			h_align: .center
			content: [
				gui.column(
					width:        360
					sizing:       gui.fixed_fit
					spacing:      12
					padding:      gui.padding_large
					color:        gui.theme().color_panel
					color_border: gui.theme().color_border
					size_border:  gui.theme().size_border
					radius:       gui.theme().radius_large
					h_align:      .center
					content:      [
						gui.text(
							text:       'Welcome Back'
							text_style: gui.theme().b2
						),
						gui.text(
							text:       'Sign in to your account'
							text_style: gui.theme().n5
						),
						gui.row(height: 4, sizing: gui.fill_fit),
						gui.input(
							id_focus:        id_focus_preview_base + 1
							sizing:          gui.fill_fit
							text:            app.login_email
							placeholder:     'Email address'
							on_text_changed: fn (_ &gui.Layout, s string, mut w gui.Window) {
								mut state := w.state[ThemeDesignerState]()
								state.login_email = s
							}
						),
						gui.input(
							id_focus:        id_focus_preview_base + 2
							sizing:          gui.fill_fit
							text:            app.login_password
							placeholder:     'Password'
							is_password:     true
							on_text_changed: fn (_ &gui.Layout, s string, mut w gui.Window) {
								mut state := w.state[ThemeDesignerState]()
								state.login_password = s
							}
						),
						gui.row(
							sizing:  gui.fill_fit
							v_align: .middle
							content: [
								gui.checkbox(
									id:       'remember_me'
									label:    'Remember me'
									id_focus: id_focus_preview_base + 3
									select:   false
									on_click: fn (_ &gui.Layout, mut _ gui.Event, mut _ gui.Window) {
									}
								),
								gui.row(sizing: gui.fill_fit),
								gui.text(
									text:       'Forgot password?'
									text_style: gui.TextStyle{
										...gui.theme().n5
										color: gui.theme().color_select
									}
								),
							]
						),
						gui.button(
							sizing:  gui.fill_fit
							padding: gui.padding(8, 12, 8, 12)
							color:   gui.theme().color_select
							radius:  gui.theme().radius_medium
							content: [
								gui.text(
									text:       'Sign In'
									text_style: gui.TextStyle{
										...gui.theme().b4
										color: gui.rgb(255, 255, 255)
									}
								),
							]
						),
					]
				),
			]
		),
		gui.row(sizing: gui.fill_fill),
	]
}

// ---- Settings Page ----

fn page_settings(window &gui.Window) []gui.View {
	app := window.state[ThemeDesignerState]()
	return [
		preview_heading('Settings'),
		// Profile card
		preview_card('Profile', [
			gui.row(
				sizing:  gui.fill_fit
				v_align: .middle
				spacing: 10
				content: [
					gui.text(text: 'Name', min_width: 60),
					gui.input(
						id_focus:        id_focus_preview_base + 4
						sizing:          gui.fill_fit
						text:            app.settings_name
						on_text_changed: fn (_ &gui.Layout, s string, mut w gui.Window) {
							mut state := w.state[ThemeDesignerState]()
							state.settings_name = s
						}
					),
				]
			),
			gui.row(
				sizing:  gui.fill_fit
				v_align: .middle
				spacing: 10
				content: [
					gui.text(text: 'Email', min_width: 60),
					gui.input(
						id_focus:        id_focus_preview_base + 5
						sizing:          gui.fill_fit
						text:            app.settings_email
						on_text_changed: fn (_ &gui.Layout, s string, mut w gui.Window) {
							mut state := w.state[ThemeDesignerState]()
							state.settings_email = s
						}
					),
				]
			),
		]),
		// Preferences card
		preview_card('Preferences', [
			gui.row(
				sizing:  gui.fill_fit
				v_align: .middle
				content: [
					gui.text(text: 'Notifications'),
					gui.row(sizing: gui.fill_fit),
					gui.toggle(
						id:       'settings_notif'
						select:   app.settings_notif
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							mut state := w.state[ThemeDesignerState]()
							state.settings_notif = !state.settings_notif
						}
					),
				]
			),
			gui.row(
				sizing:  gui.fill_fit
				v_align: .middle
				content: [
					gui.text(text: 'Auto-save'),
					gui.row(sizing: gui.fill_fit),
					gui.switch(
						id:       'settings_auto'
						select:   app.settings_auto
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							mut state := w.state[ThemeDesignerState]()
							state.settings_auto = !state.settings_auto
						}
					),
				]
			),
			gui.row(
				sizing:  gui.fill_fit
				v_align: .middle
				spacing: 10
				content: [
					gui.text(text: 'Theme', min_width: 60),
					window.select(
						id:        'settings_theme'
						id_focus:  id_focus_preview_base + 6
						select:    [app.settings_theme]
						options:   ['Dark', 'Light', 'System']
						sizing:    gui.fill_fit
						on_select: fn (sel []string, mut _ gui.Event, mut w gui.Window) {
							mut state := w.state[ThemeDesignerState]()
							if sel.len > 0 {
								state.settings_theme = sel[0]
							}
						}
					),
				]
			),
		]),
		// Danger zone
		preview_card('Danger Zone', [
			gui.row(
				sizing:  gui.fill_fit
				v_align: .middle
				content: [
					gui.text(text: 'Delete your account permanently'),
					gui.row(sizing: gui.fill_fit),
					gui.button(
						padding:      gui.padding(4, 10, 4, 10)
						color:        gui.rgb(180, 40, 40)
						color_border: gui.rgb(200, 60, 60)
						size_border:  1
						radius:       gui.theme().radius_small
						content:      [
							gui.text(
								text:       'Delete Account'
								text_style: gui.TextStyle{
									...gui.theme().n4
									color: gui.rgb(255, 220, 220)
								}
							),
						]
					),
				]
			),
		]),
		// Save button
		gui.row(
			sizing:  gui.fill_fit
			h_align: .right
			content: [
				gui.button(
					padding: gui.padding(8, 20, 8, 20)
					color:   gui.theme().color_select
					radius:  gui.theme().radius_medium
					content: [
						gui.text(
							text:       'Save Changes'
							text_style: gui.TextStyle{
								...gui.theme().b4
								color: gui.rgb(255, 255, 255)
							}
						),
					]
				),
			]
		),
	]
}

// ---- Data Table Page ----

fn page_table(mut window gui.Window) []gui.View {
	app := window.state[ThemeDesignerState]()
	mut rows := []gui.TableRowCfg{cap: table_data.len + 1}
	rows << gui.tr([gui.th('Name'), gui.th('Email'), gui.th('Role'),
		gui.th('Status')])
	for row in table_data {
		rows << gui.tr([gui.td(row[0]), gui.td(row[1]), gui.td(row[2]),
			gui.td(row[3])])
	}
	return [
		preview_heading('Data Table'),
		// Toolbar
		gui.row(
			sizing:  gui.fill_fit
			spacing: 8
			v_align: .middle
			content: [
				gui.input(
					id_focus:        id_focus_preview_base + 7
					width:           200
					sizing:          gui.fixed_fit
					text:            app.search_query
					placeholder:     'Search...'
					on_text_changed: fn (_ &gui.Layout, s string, mut w gui.Window) {
						mut state := w.state[ThemeDesignerState]()
						state.search_query = s
					}
				),
				gui.row(sizing: gui.fill_fit),
				gui.button(
					padding: gui.padding(4, 10, 4, 10)
					color:   gui.theme().color_select
					radius:  gui.theme().radius_small
					content: [
						gui.text(
							text:       'Add New'
							text_style: gui.TextStyle{
								...gui.theme().n4
								color: gui.rgb(255, 255, 255)
							}
						),
					]
				),
				gui.button(
					padding:      gui.padding(4, 10, 4, 10)
					color:        gui.theme().color_interior
					color_border: gui.theme().color_border
					size_border:  1
					radius:       gui.theme().radius_small
					content:      [
						gui.text(text: 'Export'),
					]
				),
			]
		),
		// Table
		window.table(
			sizing: gui.fill_fit
			data:   rows
		),
	]
}

// ============================================================
// Right Panel — Theme Editor
// ============================================================

fn editor_panel(window &gui.Window) gui.View {
	app := window.state[ThemeDesignerState]()
	return gui.column(
		sizing:    gui.fill_fill
		color:     gui.theme().color_panel
		padding:   gui.padding_none
		id_scroll: id_scroll_editor
		content:   [
			// Toolbar: presets + load/save
			editor_toolbar(),
			// Colors section
			gui.expand_panel(
				id:        'ep_colors'
				sizing:    gui.fill_fit
				open:      app.colors_open
				on_toggle: fn (mut w gui.Window) {
					mut state := w.state[ThemeDesignerState]()
					state.colors_open = !state.colors_open
				}
				head:      gui.text(text: 'Colors', text_style: gui.theme().b4)
				content:   colors_section(window)
			),
			// Style section
			gui.expand_panel(
				id:        'ep_style'
				sizing:    gui.fill_fit
				open:      app.style_open
				on_toggle: fn (mut w gui.Window) {
					mut state := w.state[ThemeDesignerState]()
					state.style_open = !state.style_open
				}
				head:      gui.text(text: 'Style', text_style: gui.theme().b4)
				content:   style_section(window)
			),
			// Typography section
			gui.expand_panel(
				id:        'ep_type'
				sizing:    gui.fill_fit
				open:      app.type_open
				on_toggle: fn (mut w gui.Window) {
					mut state := w.state[ThemeDesignerState]()
					state.type_open = !state.type_open
				}
				head:      gui.text(text: 'Typography', text_style: gui.theme().b4)
				content:   type_section(window)
			),
			// JSON panel
			json_panel(window),
		]
	)
}

// ---- Toolbar ----

fn editor_toolbar() gui.View {
	return gui.column(
		sizing:  gui.fill_fit
		spacing: 4
		padding: gui.padding(6, 8, 6, 8)
		content: [
			gui.row(
				sizing:  gui.fill_fit
				spacing: 3
				v_align: .middle
				content: [
					preset_button('Drk', 'Dark', id_focus_preset_base),
					preset_button('Lgt', 'Light', id_focus_preset_base + 1),
					preset_button('D+B', 'Dark Bordered', id_focus_preset_base + 2),
					preset_button('L+B', 'Light Bordered', id_focus_preset_base + 3),
					preset_button('Blu', 'Blue Bordered', id_focus_preset_base + 4),
				]
			),
			gui.row(
				sizing:  gui.fill_fit
				spacing: 3
				v_align: .middle
				content: [
					gui.row(sizing: gui.fill_fit),
					load_button(),
					save_button(),
				]
			),
		]
	)
}

fn preset_button(label string, tooltip_text string, id_focus u32) gui.View {
	return gui.button(
		id_focus:     id_focus
		padding:      gui.padding(2, 5, 2, 5)
		color:        gui.theme().color_interior
		color_border: gui.theme().color_border
		size_border:  1
		radius:       gui.radius_small
		tooltip:      &gui.TooltipCfg{
			id:      'preset_${label}'
			content: [gui.text(text: tooltip_text)]
		}
		content:      [gui.text(text: label, text_style: gui.theme().n5)]
		on_click:     fn [tooltip_text] (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
			apply_preset(tooltip_text, mut w)
		}
	)
}

fn load_button() gui.View {
	return gui.button(
		padding:      gui.padding(2, 5, 2, 5)
		color:        gui.theme().color_interior
		color_border: gui.theme().color_border
		size_border:  1
		radius:       gui.radius_small
		content:      [gui.text(text: 'Load', text_style: gui.theme().n5)]
		on_click:     fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
			w.native_open_dialog(gui.NativeOpenDialogCfg{
				title:   'Load Theme'
				filters: [
					gui.NativeFileFilter{
						name:       'JSON'
						extensions: ['json']
					},
				]
				on_done: fn (result gui.NativeDialogResult, mut w gui.Window) {
					if result.status != .ok || result.paths.len == 0 {
						return
					}
					theme := gui.theme_load(result.paths[0].path) or { return }
					mut app := w.state[ThemeDesignerState]()
					apply_theme_to_state(theme, mut app)
					app.json_text = gui.theme_to_json(theme.cfg)
					app.preset_gen++
					w.set_theme(theme)
				}
			})
		}
	)
}

fn save_button() gui.View {
	return gui.button(
		padding:      gui.padding(2, 5, 2, 5)
		color:        gui.theme().color_interior
		color_border: gui.theme().color_border
		size_border:  1
		radius:       gui.radius_small
		content:      [gui.text(text: 'Save', text_style: gui.theme().n5)]
		on_click:     fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
			w.native_save_dialog(gui.NativeSaveDialogCfg{
				title:             'Save Theme'
				default_name:      'theme.json'
				default_extension: 'json'
				filters:           [
					gui.NativeFileFilter{
						name:       'JSON'
						extensions: ['json']
					},
				]
				on_done:           fn (result gui.NativeDialogResult, mut w gui.Window) {
					if result.status != .ok || result.paths.len == 0 {
						return
					}
					app := w.state[ThemeDesignerState]()
					cfg := build_theme_cfg(app)
					theme := gui.theme_maker(&cfg)
					gui.theme_save(result.paths[0].path, theme) or {}
				}
			})
		}
	)
}

// ---- Colors Section ----

fn colors_section(window &gui.Window) gui.View {
	app := window.state[ThemeDesignerState]()
	sel := app.selected_color
	gen := app.preset_gen
	color := get_color_by_name(app, sel)
	return gui.column(
		sizing:  gui.fill_fit
		spacing: 6
		padding: gui.padding(4, 8, 4, 8)
		content: [
			// Row 1: Bg, Panel, Interior, Hover, Focus
			gui.row(
				sizing:  gui.fill_fit
				spacing: 3
				h_align: .center
				content: [
					swatch_button('Bg', 'background', app.color_background, sel),
					swatch_button('Pnl', 'panel', app.color_panel, sel),
					swatch_button('Int', 'interior', app.color_interior, sel),
					swatch_button('Hvr', 'hover', app.color_hover, sel),
					swatch_button('Fcs', 'focus', app.color_focus, sel),
				]
			),
			// Row 2: Active, Border, BrdFoc, Select, Text
			gui.row(
				sizing:  gui.fill_fit
				spacing: 3
				h_align: .center
				content: [
					swatch_button('Act', 'active', app.color_active, sel),
					swatch_button('Brd', 'border', app.color_border, sel),
					swatch_button('BFc', 'border_focus', app.color_border_focus, sel),
					swatch_button('Sel', 'select', app.color_select, sel),
					swatch_button('Txt', 'text', app.color_text, sel),
				]
			),
			// Color picker
			gui.color_picker(
				id:              'theme_cp_${sel}_${gen}'
				color:           color
				style:           gui.ColorPickerStyle{
					...gui.theme().color_picker_style
					sv_size: cp_sv_size
				}
				on_color_change: fn [sel] (c gui.Color, mut _ gui.Event, mut w gui.Window) {
					mut state := w.state[ThemeDesignerState]()
					set_color_by_name(mut state, sel, c)
					rebuild_and_apply(mut w)
				}
			),
		]
	)
}

fn swatch_button(label string, swatch_name string, color gui.Color,
	selected string) gui.View {
	is_selected := swatch_name == selected
	return gui.column(
		h_align: .center
		spacing: 2
		padding: gui.padding_none
		content: [
			gui.button(
				width:        swatch_w
				height:       swatch_h
				sizing:       gui.fixed_fixed
				padding:      gui.padding_none
				color:        color
				color_border: if is_selected {
					gui.theme().color_select
				} else {
					gui.theme().color_border
				}
				size_border:  if is_selected { f32(2) } else { f32(1) }
				radius:       gui.radius_small
				on_click:     fn [swatch_name] (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
					mut state := w.state[ThemeDesignerState]()
					state.selected_color = swatch_name
				}
			),
			gui.text(text: label, text_style: gui.theme().n6),
		]
	)
}

// ---- Style Section ----

fn style_section(window &gui.Window) gui.View {
	app := window.state[ThemeDesignerState]()
	return gui.column(
		sizing:  gui.fill_fit
		spacing: 4
		padding: gui.padding(4, 8, 4, 8)
		content: [
			slider_row('Radius', app.radius, 0, 20, 'style_radius', id_focus_style_base,
				fn (value f32, mut _ gui.Event, mut w gui.Window) {
				mut state := w.state[ThemeDesignerState]()
				state.radius = value
				rebuild_and_apply(mut w)
			}),
			slider_row('Border', app.size_border, 0, 5, 'style_border', id_focus_style_base + 1,
				fn (value f32, mut _ gui.Event, mut w gui.Window) {
				mut state := w.state[ThemeDesignerState]()
				state.size_border = value
				rebuild_and_apply(mut w)
			}),
			slider_row('Spacing', app.spacing, 0, 30, 'style_spacing', id_focus_style_base + 2,
				fn (value f32, mut _ gui.Event, mut w gui.Window) {
				mut state := w.state[ThemeDesignerState]()
				state.spacing = value
				rebuild_and_apply(mut w)
			}),
		]
	)
}

// ---- Typography Section ----

fn type_section(window &gui.Window) gui.View {
	app := window.state[ThemeDesignerState]()
	return gui.column(
		sizing:  gui.fill_fit
		spacing: 4
		padding: gui.padding(4, 8, 4, 8)
		content: [
			slider_row('Font Size', app.font_size, 10, 32, 'font_size', id_focus_type_base,
				fn (value f32, mut _ gui.Event, mut w gui.Window) {
				mut state := w.state[ThemeDesignerState]()
				state.font_size = value
				rebuild_and_apply(mut w)
			}),
		]
	)
}

// ---- JSON Panel ----

fn json_panel(window &gui.Window) gui.View {
	app := window.state[ThemeDesignerState]()
	return gui.column(
		sizing:  gui.fill_fit
		spacing: 4
		padding: gui.padding(6, 8, 6, 8)
		content: [
			gui.text(text: 'Theme JSON', text_style: gui.theme().b4),
			gui.input(
				id_focus:        id_focus_preview_base + 10
				sizing:          gui.fill_fit
				height:          200
				mode:            .multiline
				text:            app.json_text
				text_style:      gui.theme().m5
				on_text_changed: fn (_ &gui.Layout, s string, mut w gui.Window) {
					mut state := w.state[ThemeDesignerState]()
					state.json_text = s
					theme := gui.theme_parse(s) or { return }
					apply_theme_to_state(theme, mut state)
					state.preset_gen++
					w.set_theme(theme)
				}
			),
		]
	)
}
