import gui
import time

// Date and Time inputs/pickers
// =============================

@[heap]
struct DateTimeApp {
pub mut:
	date        time.Time = time.now()
	light_theme bool
}

fn main() {
	mut window := gui.window(
		state:   &DateTimeApp{}
		title:   'Date/Time Pickers'
		width:   600
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
	app := window.state[DateTimeApp]()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		content: [
			toggle_theme(app),
			window.input_date(
				id:        'e1'
				date:      app.date
				id_focus:  1
				on_select: fn (times []time.Time, mut e gui.Event, mut w gui.Window) {
					mut app := w.state[DateTimeApp]()
					app.date = times[0]
					e.is_handled = true
				}
			),
		]
	)
}

fn toggle_theme(app &DateTimeApp) gui.View {
	return gui.row(
		h_align: .end
		sizing:  gui.fill_fit
		padding: gui.padding_none
		content: [
			gui.toggle(
				text_select:   gui.icon_moon
				text_unselect: gui.icon_sunny_o
				text_style:    gui.theme().icon3
				select:        app.light_theme
				padding:       gui.padding_small
				on_click:      fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
					mut app := w.state[DateTimeApp]()
					theme := match app.light_theme {
						true { gui.theme_dark_bordered }
						else { gui.theme_light_bordered }
					}
					app.light_theme = !app.light_theme
					w.set_theme(theme)
				}
			),
		]
	)
}
