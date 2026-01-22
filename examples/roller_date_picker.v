import gui
import time

// Roller Date Picker Example
// ==========================
// Demonstrates the drum/roller-style date picker with independent
// day, month, and year columns.

@[heap]
struct RollerPickerApp {
pub mut:
	date         time.Time = time.now()
	display_mode gui.RollerDatePickerDisplayMode
	light_theme  bool
	long_months  bool
}

fn main() {
	mut window := gui.window(
		state:   &RollerPickerApp{}
		title:   'Roller Date Picker'
		width:   400
		height:  450
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(mut w gui.Window) gui.View {
	width, height := w.window_size()
	app := w.state[RollerPickerApp]()

	return gui.column(
		width:   width
		height:  height
		sizing:  gui.fixed_fixed
		h_align: .center
		spacing: 20
		content: [
			toggle_theme(app),
			gui.roller_date_picker(
				id:            'picker1'
				id_focus:      1
				selected_date: app.date
				display_mode:  app.display_mode
				long_months:   app.long_months
				on_change:     fn (new_date time.Time, mut w gui.Window) {
					mut a := w.state[RollerPickerApp]()
					a.date = new_date
				}
			),
			display_mode_selector(app),
			gui.text(
				text: 'Selected: ${app.date.custom_format('DD MMM YYYY')}'
			),
			gui.text(
				text:       'Scroll over each column or use keyboard:'
				text_style: gui.TextStyle{
					...gui.theme().text_style
					size:  gui.theme().text_style.size - 2
					color: gui.Color{
						...gui.theme().text_style.color
						a: 150
					}
				}
			),
			gui.text(
				text:       'Shift+↑↓ = Day | Alt+↑↓ = Month | ↑↓ = Year'
				text_style: gui.TextStyle{
					...gui.theme().text_style
					size:  gui.theme().text_style.size - 2
					color: gui.Color{
						...gui.theme().text_style.color
						a: 150
					}
				}
			),
		]
	)
}

fn toggle_theme(app &RollerPickerApp) gui.View {
	return gui.row(
		h_align: .end
		sizing:  gui.fill_fit
		padding: gui.padding_none
		spacing: 10
		v_align: .middle
		content: [
			gui.switch(
				label:    'Long'
				select:   app.long_months
				on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
					mut a := w.state[RollerPickerApp]()
					a.long_months = !a.long_months
				}
			),
			gui.rectangle(sizing: gui.fill_fit),
			gui.toggle(
				text_select:   gui.icon_moon
				text_unselect: gui.icon_sunny_o
				text_style:    gui.theme().icon3
				select:        app.light_theme
				padding:       gui.padding_small
				on_click:      fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
					mut a := w.state[RollerPickerApp]()
					theme := match a.light_theme {
						true { gui.theme_dark_bordered }
						else { gui.theme_light_bordered }
					}
					a.light_theme = !a.light_theme
					w.set_theme(theme)
				}
			),
		]
	)
}

fn display_mode_selector(app &RollerPickerApp) gui.View {
	return gui.radio_button_group_row(
		value:     int(app.display_mode).str()
		options:   [
			gui.radio_option('DMY', '0'),
			gui.radio_option('MDY', '1'),
			gui.radio_option('MY', '2'),
			gui.radio_option('Y', '3'),
		]
		on_select: fn (value string, mut w gui.Window) {
			mut a := w.state[RollerPickerApp]()
			a.display_mode = unsafe { gui.RollerDatePickerDisplayMode(value.int()) }
		}
	)
}
