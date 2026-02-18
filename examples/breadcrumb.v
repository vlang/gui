import gui

// Breadcrumb Widget Demo

const full_path = [
	gui.BreadcrumbItemCfg{
		id:    'home'
		label: 'Home'
		icon:  gui.icon_home
	},
	gui.BreadcrumbItemCfg{
		id:    'docs'
		label: 'Docs'
		icon:  gui.icon_folder
	},
	gui.BreadcrumbItemCfg{
		id:    'guide'
		label: 'Guide'
	},
	gui.BreadcrumbItemCfg{
		id:    'page'
		label: 'Getting Started'
	},
]

@[heap]
struct App {
pub mut:
	// Trail with truncation
	trail_path     []gui.BreadcrumbItemCfg = full_path
	trail_selected string                  = 'page'
	// Content panels
	content_selected string = 'overview'
	// Custom separator
	custom_selected string = 'src'
	light_theme     bool
}

fn main() {
	mut window := gui.window(
		state:   &App{}
		width:   600
		height:  500
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark)
	window.run()
}

fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	app := window.state[App]()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		padding: gui.theme().padding_large
		spacing: gui.theme().spacing_large
		content: [
			gui.row(
				sizing:  gui.fill_fit
				h_align: .end
				content: [theme_button(app)]
			),
			// Trail with truncation + reset
			gui.row(
				sizing:  gui.fill_fit
				v_align: .middle
				spacing: gui.theme().spacing_medium
				content: [
					gui.text(
						text:       'Truncating trail:'
						text_style: gui.theme().b4
					),
					gui.button(
						id_focus: 4
						content:  [gui.text(text: 'Reset')]
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							mut a := w.state[App]()
							a.trail_path = full_path
							a.trail_selected = 'page'
						}
					),
				]
			),
			gui.breadcrumb(
				id:        'trail'
				id_focus:  1
				selected:  app.trail_selected
				items:     app.trail_path
				on_select: fn (id string, mut _e gui.Event, mut w gui.Window) {
					mut a := w.state[App]()
					for i, item in a.trail_path {
						if item.id == id {
							a.trail_path = a.trail_path[..i + 1]
							break
						}
					}
					a.trail_selected = id
				}
			),
			// Breadcrumb with content panels
			gui.text(text: 'With content:', text_style: gui.theme().b4),
			gui.breadcrumb(
				id:        'content'
				id_focus:  2
				sizing:    gui.fill_fill
				selected:  app.content_selected
				items:     [
					gui.breadcrumb_item('overview', 'Overview', [
						gui.column(
							sizing:  gui.fill_fill
							h_align: .center
							v_align: .middle
							content: [gui.text(text: 'Overview panel')]
						)]),
					gui.breadcrumb_item('details', 'Details', [
						gui.column(
							sizing:  gui.fill_fill
							h_align: .center
							v_align: .middle
							content: [gui.text(text: 'Details panel')]
						)]),
					gui.BreadcrumbItemCfg{
						id:       'disabled'
						label:    'Archived'
						disabled: true
						content:  [gui.text(text: 'unreachable')]
					},
					gui.breadcrumb_item('settings', 'Settings', [
						gui.column(
							sizing:  gui.fill_fill
							h_align: .center
							v_align: .middle
							content: [gui.text(text: 'Settings panel')]
						)]),
				]
				on_select: fn (id string, mut _e gui.Event, mut w gui.Window) {
					w.state[App]().content_selected = id
				}
			),
			// Custom separator
			gui.text(text: 'Custom separator:', text_style: gui.theme().b4),
			gui.breadcrumb(
				id:                   'custom'
				id_focus:             3
				separator:            ' ${gui.icon_arrow_right} '
				selected:             app.custom_selected
				text_style_separator: gui.theme().icon4
				items:                [
					gui.BreadcrumbItemCfg{
						id:    'root'
						label: 'project'
					},
					gui.BreadcrumbItemCfg{
						id:    'src'
						label: 'src'
					},
					gui.BreadcrumbItemCfg{
						id:    'main'
						label: 'main.v'
					},
				]
				on_select:            fn (id string, mut _e gui.Event, mut w gui.Window) {
					w.state[App]().custom_selected = id
				}
			),
		]
	)
}

fn theme_button(app &App) gui.View {
	return gui.toggle(
		id_focus:      10
		text_select:   gui.icon_moon
		text_unselect: gui.icon_sunny_o
		text_style:    gui.theme().icon3
		padding:       gui.theme().padding_small
		select:        app.light_theme
		on_click:      fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
			mut a := w.state[App]()
			a.light_theme = !a.light_theme
			w.set_theme(if a.light_theme {
				gui.theme_light
			} else {
				gui.theme_dark
			})
		}
	)
}
