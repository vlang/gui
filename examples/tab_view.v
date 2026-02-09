import gui

// Tab View

@[heap]
struct TabViewApp {
pub mut:
	selected_tab string = 'tab1'
	light_theme  bool
}

fn main() {
	mut window := gui.window(
		state:   &TabViewApp{}
		width:   440
		height:  340
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_no_padding)
	window.run()
}

fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	app := window.state[TabViewApp]()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		padding: gui.theme().padding_large
		spacing: gui.theme().spacing_medium
		content: [
			gui.row(
				sizing:  gui.fill_fit
				h_align: .end
				content: [theme_button(app)]
			),
			gui.tab_control(
				id:        'example_tabs'
				id_focus:  1
				sizing:    gui.fill_fill
				selected:  app.selected_tab
				items:     [tab_item('tab1', 'Tab 1', 'Overview panel'),
					tab_item('tab2', 'Tab 2', 'Reports panel'),
					tab_item('tab3', 'Tab 3', 'Settings panel'),
					tab_item('tab4', 'Tab 4', 'About panel')]
				on_select: fn (id string, mut _e gui.Event, mut w gui.Window) {
					w.state[TabViewApp]().selected_tab = id
				}
			),
		]
	)
}

fn tab_item(id string, label string, body string) gui.TabItemCfg {
	return gui.tab_item(id, label, [
		gui.column(
			sizing:  gui.fill_fill
			h_align: .center
			v_align: .middle
			content: [gui.text(text: body)]
		),
	])
}

fn theme_button(app &TabViewApp) gui.View {
	return gui.toggle(
		id_focus:      2
		text_select:   gui.icon_moon
		text_unselect: gui.icon_sunny_o
		text_style:    gui.theme().icon3
		padding:       gui.theme().padding_small
		select:        app.light_theme
		on_click:      fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
			mut app := w.state[TabViewApp]()
			app.light_theme = !app.light_theme
			w.set_theme(if app.light_theme {
				gui.theme_light_no_padding
			} else {
				gui.theme_dark_no_padding
			})
		}
	)
}
