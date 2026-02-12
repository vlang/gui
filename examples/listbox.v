import gui

// List Box Demo
// =============================
// List box is a convenience view for simple cases.
// The same functionality can be done with a column and rows.
// In fact, the implementation is not much more than that.

const list_box_demo_id = 'states_source'

@[heap]
struct ListBoxApp {
pub mut:
	multiple_select bool
	selected_ids    []string
	query           string
	source          ?gui.ListBoxDataSource
}

fn main() {
	mut window := gui.window(
		title:   'List Box with Data Source'
		state:   &ListBoxApp{}
		width:   400
		height:  300
		on_init: fn (mut w gui.Window) {
			mut app := w.state[ListBoxApp]()
			app.source = &gui.InMemoryListBoxDataSource{
				data:       list_box_demo_data()
				latency_ms: 180
			}
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(mut window gui.Window) gui.View {
	w, h := window.window_size()
	app := window.state[ListBoxApp]()

	return gui.row(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		content: [
			window.list_box(
				id:           list_box_demo_id
				id_scroll:    1
				min_height:   250
				max_height:   250
				min_width:    220
				multiple:     app.multiple_select
				selected_ids: app.selected_ids
				sizing:       gui.fit_fill
				data_source:  app.source

				on_select: fn (ids []string, mut e gui.Event, mut w gui.Window) {
					mut app := w.state[ListBoxApp]()
					app.selected_ids = ids
					e.is_handled = true
				}
			),
			gui.toggle(
				label:    'Multi-Select'
				select:   app.multiple_select
				on_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
					mut app := w.state[ListBoxApp]()
					app.multiple_select = !app.multiple_select
					app.selected_ids.clear()
				}
			),
		]
	)
}

fn list_box_demo_data() []gui.ListBoxOption {
	return [
		gui.list_box_subheading('states-header', 'States'),
		gui.list_box_option('AL', 'Alabama', 'AL'),
		gui.list_box_option('AK', 'Alaska', 'AK'),
		gui.list_box_option('AZ', 'Arizona', 'AZ'),
		gui.list_box_option('AR', 'Arkansas', 'AR'),
		gui.list_box_option('CA', 'California', 'CA'),
		gui.list_box_option('CO', 'Colorado', 'CO'),
		gui.list_box_option('CT', 'Connecticut', 'CT'),
		gui.list_box_option('DE', 'Delaware', 'DE'),
		gui.list_box_option('DC', 'District of Columbia', 'DC'),
		gui.list_box_option('FL', 'Florida', 'FL'),
		gui.list_box_option('GA', 'Georgia', 'GA'),
		gui.list_box_option('HI', 'Hawaii', 'HI'),
		gui.list_box_option('ID', 'Idaho', 'ID'),
		gui.list_box_option('IL', 'Illinois', 'IL'),
		gui.list_box_option('IN', 'Indiana', 'IN'),
		gui.list_box_option('IA', 'Iowa', 'IA'),
		gui.list_box_option('KS', 'Kansas', 'KS'),
		gui.list_box_option('KY', 'Kentucky', 'KY'),
		gui.list_box_option('LA', 'Louisiana', 'LA'),
		gui.list_box_option('ME', 'Maine', 'ME'),
		gui.list_box_option('MD', 'Maryland', 'MD'),
		gui.list_box_option('MA', 'Massachusetts', 'MA'),
		gui.list_box_option('MI', 'Michigan', 'MI'),
		gui.list_box_option('MN', 'Minnesota', 'MN'),
		gui.list_box_option('MS', 'Mississippi', 'MS'),
		gui.list_box_option('MO', 'Missouri', 'MO'),
		gui.list_box_option('MT', 'Montana', 'MT'),
		gui.list_box_option('NE', 'Nebraska', 'NE'),
		gui.list_box_option('NV', 'Nevada', 'NV'),
		gui.list_box_option('NH', 'New Hampshire', 'NH'),
		gui.list_box_option('NJ', 'New Jersey', 'NJ'),
		gui.list_box_option('NM', 'New Mexico', 'NM'),
		gui.list_box_option('NY', 'New York', 'NY'),
		gui.list_box_option('NC', 'North Carolina', 'NC'),
		gui.list_box_option('ND', 'North Dakota', 'ND'),
		gui.list_box_option('OH', 'Ohio', 'OH'),
		gui.list_box_option('OK', 'Oklahoma', 'OK'),
		gui.list_box_option('OR', 'Oregon', 'OR'),
		gui.list_box_option('PA', 'Pennsylvania', 'PA'),
		gui.list_box_option('RI', 'Rhode Island', 'RI'),
		gui.list_box_option('SC', 'South Carolina', 'SC'),
		gui.list_box_option('SD', 'South Dakota', 'SD'),
		gui.list_box_option('TN', 'Tennessee', 'TN'),
		gui.list_box_option('TX', 'Texas', 'TX'),
		gui.list_box_option('UT', 'Utah', 'UT'),
		gui.list_box_option('VT', 'Vermont', 'VT'),
		gui.list_box_option('VA', 'Virginia', 'VA'),
		gui.list_box_option('WA', 'Washington', 'WA'),
		gui.list_box_option('WV', 'West Virginia', 'WV'),
		gui.list_box_option('WI', 'Wisconsin', 'WI'),
		gui.list_box_option('WY', 'Wyoming', 'WY'),
		gui.list_box_subheading('territories-header', 'Territories'),
		gui.list_box_option('AS', 'American Samoa', 'AS'),
		gui.list_box_option('GU', 'Guam', 'GU'),
		gui.list_box_option('MP', 'Northern Mariana Islands', 'MP'),
		gui.list_box_option('PR', 'Puerto Rico', 'PR'),
		gui.list_box_option('VI', 'U.S. Virgin Islands', 'VI'),
	]
}
