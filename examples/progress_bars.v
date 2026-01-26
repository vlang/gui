import gui

// Progress Bars
// =============================
// Not much to say here. They're progress bars, similar to what
// you'll find in other frameworks.

@[heap]
struct ProgressBarsApp {
pub mut:
	light_theme bool
}

fn main() {
	mut window := gui.window(
		state:   &ProgressBarsApp{}
		width:   300
		height:  300
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(window &gui.Window) gui.View {
	app := window.state[ProgressBarsApp]()
	w, h := window.window_size()
	tbg1 := if app.light_theme { gui.orange } else { gui.dark_green }
	tbg2 := if app.light_theme { gui.cornflower_blue } else { gui.white }
	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		h_align: .center
		v_align: .middle
		spacing: gui.theme().spacing_large
		content: [
			toggle_theme(app),
			gui.progress_bar(
				height:          2
				sizing:          gui.fill_fixed
				percent:         0.20
				text_background: tbg1
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
			gui.row(
				spacing: 40
				sizing:  gui.fit_fill
				content: [
					gui.progress_bar(
						vertical:        true
						sizing:          gui.fixed_fill
						width:           2
						percent:         0.40
						text_background: tbg2
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

fn toggle_theme(app &ProgressBarsApp) gui.View {
	return gui.row(
		h_align: .end
		sizing:  gui.fill_fit
		padding: gui.padding_none
		content: [
			gui.toggle(
				text_select:   gui.icon_moon
				text_unselect: gui.icon_sunny_o
				text_style:    gui.theme().icon3
				padding:       gui.theme().padding_small
				select:        app.light_theme
				on_click:      fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
					mut app := w.state[ProgressBarsApp]()
					app.light_theme = !app.light_theme
					theme := if app.light_theme {
						gui.theme_light
					} else {
						gui.theme_dark
					}
					w.set_theme(theme)
				}
			),
		]
	)
}
