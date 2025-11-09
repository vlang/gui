import gui

// Form Demo
// =============================
// Gui doesn't have a form control or grid layout but it can
// do similar things with simple function.

@[heap]
struct FormDemoApp {
pub mut:
	name    string
	address string
	city    string
	state   string
	zip     string
}

fn main() {
	mut window := gui.window(
		state:   &FormDemoApp{}
		width:   800
		height:  600
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

const id_focus_name = u32(100)
const id_focus_address = u32(101)
const id_focus_city = u32(102)
const id_focus_state = u32(103)
const id_focus_zip = u32(104)

fn main_view(mut window gui.Window) gui.View {
	w, h := window.window_size()
	mut app := window.state[FormDemoApp]()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		h_align: .center
		content: [
			gui.column(
				color:   gui.theme().color_border
				content: [
					label_input_row('Name', app.name, id_focus_name, fn [mut app] (s string) {
						app.name = s
					}),
					label_input_row('Address', app.address, id_focus_address, fn [mut app] (s string) {
						app.address = s
					}),
					label_input_row('City', app.city, id_focus_city, fn [mut app] (s string) {
						app.city = s
					}),
					gui.row(
						h_align: .end
						sizing:  gui.fill_fit
						padding: gui.padding_none
						content: [select_state(app.state, mut window)]
					),
					gui.row(
						h_align: .end
						v_align: .middle
						sizing:  gui.fill_fit
						padding: gui.padding_none
						content: [gui.text(text: 'Zip'),
							gui.input(
								text:            app.zip
								id_focus:        id_focus_zip
								sizing:          gui.fixed_fit
								width:           100
								on_text_changed: fn (_ &gui.Layout, s string, mut w gui.Window) {
									mut app := w.state[FormDemoApp]()
									app.zip = s
								}
							)]
					),
					gui.text(text: ''),
					gui.row(
						h_align: .end
						sizing:  gui.fill_fit
						padding: gui.padding_none
						content: [gui.button(content: [gui.text(text: 'Cancel')]),
							gui.button(content: [gui.text(text: 'OK')])]
					),
				]
			),
		]
	)
}

fn label_input_row(label string, value string, id_focus u32, changed fn (string)) gui.View {
	field_width := 250

	// Use fill_fit to move label and input to outer edges of form
	return gui.row(
		padding: gui.padding_none
		v_align: .middle
		sizing:  gui.fill_fit
		content: [
			gui.row(sizing: gui.fill_fit, padding: gui.padding_none),
			gui.text(text: label),
			gui.input(
				text:            value
				id_focus:        id_focus
				sizing:          gui.fixed_fit
				width:           field_width
				on_text_changed: fn [changed] (_ &gui.Layout, s string, mut w gui.Window) {
					changed(s)
				}
			),
		]
	)
}

fn select_state(state string, mut window gui.Window) gui.View {
	field_width := 150
	return window.select(
		id:          'select_state'
		id_focus:    id_focus_state
		min_width:   field_width
		max_width:   field_width
		select:      [state]
		placeholder: 'State'
		options:     [
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
		on_select:   fn (s []string, mut e gui.Event, mut w gui.Window) {
			mut app := w.state[FormDemoApp]()
			app.state = s[0]
			e.is_handled = true
		}
	)
}
