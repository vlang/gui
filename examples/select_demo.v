import gui

// Select Demo
// =============================

@[heap]
struct SelectDemoApp {
pub mut:
	selected string = 'pick a state'
}

fn main() {
	mut window := gui.window(
		state:   &SelectDemoApp{}
		width:   300
		height:  300
		on_init: fn (mut w gui.Window) {
			// Call update_view() any where in your
			// business logic to change views.
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

// The view generator set in update_view() is called on
// every user event (mouse move, click, resize, etc.).
fn main_view(mut window gui.Window) gui.View {
	w, h := window.window_size()
	app := window.state[SelectDemoApp]()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		content: [
			gui.row(
				content: [
					gui.select(
						id:        'sel1'
						window:    mut window
						selected:  app.selected
						options:   [
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
							'New',
							'Hampshire',
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
						on_select: fn (s string, mut e gui.Event, mut w gui.Window) {
							mut app_ := w.state[SelectDemoApp]()
							app_.selected = s
							e.is_handled = true
						}
					),
				]
			),
		]
	)
}
