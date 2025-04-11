import gui

struct App {
pub mut:
	light bool
}

fn main() {
	mut window := gui.window(
		state:   &App{}
		width:   300
		height:  300
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.run()
}

fn main_view(window &gui.Window) gui.View {
	app := window.state[App]()
	w, h := window.window_size()
	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		h_align: .center
		v_align: .middle
		content: [
			button_change_theme(app),
			gui.progress_bar(
				height:  2
				sizing:  gui.fill_fixed
				percent: 0.20
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
			gui.row(
				sizing:  gui.fit_fill
				content: [
					gui.progress_bar(
						vertical: true
						sizing:   gui.fixed_fill
						width:    2
						percent:  0.40
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

fn button_change_theme(app &App) gui.View {
	return gui.row(
		h_align: .right
		sizing:  gui.fill_fit
		padding: gui.padding_none
		content: [
			gui.button(
				padding:  gui.padding(1, 5, 1, 5)
				content:  [
					gui.text(
						text: if app.light { '●' } else { '○' }
					),
				]
				on_click: fn (_ &gui.ButtonCfg, _ &gui.Event, mut w gui.Window) bool {
					mut app := w.state[App]()
					app.light = !app.light
					theme := if app.light {
						gui.theme_light
					} else {
						gui.theme_dark
					}
					w.set_theme(theme)
					w.set_id_focus(1)
					return true
				}
			),
		]
	)
}
