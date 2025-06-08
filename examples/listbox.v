import gui

// List Box Demo
// =============================
// List box is a convienence view for simple cases.
// The same functionality can be done with a column and rows.
// In fact, the implementation is not much more than that.

@[heap]
struct ListBoxApp {
pub mut:
	multiple_select bool
	selected_values []string
}

fn main() {
	mut window := gui.window(
		title:   'List Box Demo'
		state:   &ListBoxApp{}
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
	w, h := window.window_size()
	app := window.state[ListBoxApp]()

	return gui.row(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		content: [
			gui.toggle(
				label:    'Multi-Select'
				select:   app.multiple_select
				on_click: fn (_ &gui.ToggleCfg, mut e gui.Event, mut w gui.Window) {
					mut app := w.state[ListBoxApp]()
					app.multiple_select = !app.multiple_select
					app.selected_values.clear()
				}
			),
			gui.list_box(
				id_scroll: 1
				multiple:  app.multiple_select
				selected:  app.selected_values
				sizing:    gui.fit_fill
				data:      [
					gui.list_box_option('Alabama', 'AL'),
					gui.list_box_option('Alaska', 'AK'),
					gui.list_box_option('Arizona', 'AZ'),
					gui.list_box_option('Arkansas', 'AR'),
					gui.list_box_option('California', 'CA'),
					gui.list_box_option('Colorado', 'CO'),
					gui.list_box_option('Connecticut', 'CT'),
					gui.list_box_option('Delaware', 'DE'),
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
				]
				on_select: fn (values []string, mut e gui.Event, mut w gui.Window) {
					mut app := w.state[ListBoxApp]()
					app.selected_values = values
					e.is_handled = true
				}
			),
		]
	)
}
