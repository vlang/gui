import gui

// Tab View
// =============================
// Tab views are a staple of many UI frameworks. Gui does not have one
// mostly because it is super easy to write your own.

@[heap]
struct TabViewApp {
pub mut:
	select_tab  string = 'tab1'
	light_theme bool
}

fn main() {
	mut window := gui.window(
		state:   &TabViewApp{}
		width:   400
		height:  300
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_no_padding)
	window.run()
}

fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	mut app := window.state[TabViewApp]()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		padding: gui.theme().padding_large
		content: [
			gui.column(
				spacing: 0
				sizing:  gui.fill_fill
				content: [
					gui.row(
						sizing:  gui.fill_fit
						h_align: .end
						content: [theme_button(app)]
					),
					gui.row(
						spacing: 0
						content: [app.tab_button(1, 'tab1', 'Tab 1'),
							app.tab_button(2, 'tab2', 'Tab 2'),
							app.tab_button(3, 'tab3', 'Tab 3'),
							app.tab_button(4, 'tab4', 'Tab 4')]
					),
					gui.column(
						sizing:  gui.fill_fill
						h_align: .center
						v_align: .middle
						color:   gui.theme().color_active
						content: [gui.text(text: 'Content for "${app.select_tab}" goes here')]
					),
				]
			),
		]
	)
}

// tab buttons can be anything you want. This one is admittedly simple.
fn (mut app TabViewApp) tab_button(id_focus u32, id string, text string) gui.View {
	color := if app.select_tab == id {
		gui.theme().color_select
	} else {
		gui.theme().color_active
	}
	return gui.button(
		id:             'tab1'
		id_focus:       id_focus
		color_border:   color
		padding:        gui.pad_tblr(4, 10)
		border_width:   1

		content:        [gui.text(text: text, text_style: gui.theme().b4)]
		on_click:       fn [id] (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
			mut tvapp := w.state[TabViewApp]()
			tvapp.select_tab = id
		}
	)
}

fn theme_button(app &TabViewApp) gui.View {
	return gui.toggle(
		id_focus:      3
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
