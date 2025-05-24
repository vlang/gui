import gui

// Select Demo
// =============================
// Select drop-downs are relatively straight-forward to use.
// They are unusual in that an ID and Window referenece are required.

@[heap]
struct SelectDemoApp {
pub mut:
	selected_1  []string
	selected_2  []string
	light_theme bool
}

fn main() {
	mut window := gui.window(
		title:   'Select Demo'
		state:   &SelectDemoApp{}
		width:   300
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
	app := window.state[SelectDemoApp]()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		content: [
			toggle_theme(app),
			gui.row(
				content: [
					gui.select(
						id:              'sel1'
						max_width:       200
						window:          mut window
						selected:        app.selected_1
						placeholder:     'Pick one or more states'
						select_multiple: true
						options:         [
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
						on_select:       fn (s []string, mut e gui.Event, mut w gui.Window) {
							mut app := w.state[SelectDemoApp]()
							app.selected_1 = s
							e.is_handled = true
						}
					),
				]
			),
			gui.row(
				content: [
					gui.select(
						id:          'sel2'
						window:      mut window
						selected:    app.selected_2
						placeholder: 'Pick a country'
						options:     [
							'---Africa',
							'Algeria',
							'Angola',
							'Benin',
							'Botswana',
							'Burkina Faso',
							'Burundi',
							'Cabo Verde',
							'Cameroon',
							'Central African Republic',
							'Chad',
							'Comoros',
							'Congo',
							'Democratic Republic of the Congo',
							'Djibouti',
							'Egypt',
							'Equatorial Guinea',
							'Eritrea',
							'Eswatini',
							'Ethiopia',
							'Gabon',
							'Gambia',
							'Ghana',
							'Guinea',
							'Guinea-Bissau',
							'Ivory Coast',
							'Kenya',
							'Lesotho',
							'Liberia',
							'Libya',
							'Madagascar',
							'Malawi',
							'Mali',
							'Mauritania',
							'Mauritius',
							'Morocco',
							'Mozambique',
							'Namibia',
							'Niger',
							'Nigeria',
							'Rwanda',
							'Sao Tome and Principe',
							'Senegal',
							'Seychelles',
							'Sierra Leone',
							'Somalia',
							'South Africa',
							'South Sudan',
							'Sudan',
							'Tanzania',
							'Togo',
							'Tunisia',
							'Uganda',
							'Zambia',
							'Zimbabwe',
							'---Asia',
							'Afghanistan',
							'Armenia',
							'Azerbaijan',
							'Bahrain',
							'Bangladesh',
							'Bhutan',
							'Brunei',
							'Cambodia',
							'China',
							'Cyprus',
							'East Timor',
							'Georgia',
							'India',
							'Indonesia',
							'Iran',
							'Iraq',
							'Israel',
							'Japan',
							'Jordan',
							'Kazakhstan',
							'Kuwait',
							'Kyrgyzstan',
							'Laos',
							'Lebanon',
							'Malaysia',
							'Maldives',
							'Mongolia',
							'Myanmar',
							'Nepal',
							'North Korea',
							'Oman',
							'Pakistan',
							'Palestine',
							'Philippines',
							'Qatar',
							'Russia',
							'Saudi Arabia',
							'Singapore',
							'South Korea',
							'Sri Lanka',
							'Syria',
							'Taiwan',
							'Tajikistan',
							'Thailand',
							'Turkey',
							'Turkmenistan',
							'United Arab Emirates',
							'Uzbekistan',
							'Vietnam',
							'Yemen',
							'---Europe',
							'Albania',
							'Andorra',
							'Austria',
							'Belarus',
							'Belgium',
							'Bosnia and Herzegovina',
							'Bulgaria',
							'Croatia',
							'Czechia',
							'Denmark',
							'Estonia',
							'Finland',
							'France',
							'Germany',
							'Greece',
							'Hungary',
							'Iceland',
							'Ireland',
							'Italy',
							'Kosovo',
							'Latvia',
							'Liechtenstein',
							'Lithuania',
							'Luxembourg',
							'Malta',
							'Moldova',
							'Monaco',
							'Montenegro',
							'Netherlands',
							'North Macedonia',
							'Norway',
							'Poland',
							'Portugal',
							'Romania',
							'San Marino',
							'Serbia',
							'Slovakia',
							'Slovenia',
							'Spain',
							'Sweden',
							'Switzerland',
							'Ukraine',
							'United Kingdom',
							'Vatican City',
							'---North America',
							'Antigua and Barbuda',
							'Bahamas',
							'Barbados',
							'Belize',
							'Canada',
							'Costa Rica',
							'Cuba',
							'Dominica',
							'Dominican Republic',
							'El Salvador',
							'Grenada',
							'Guatemala',
							'Haiti',
							'Honduras',
							'Jamaica',
							'Mexico',
							'Nicaragua',
							'Panama',
							'Saint Kitts and Nevis',
							'Saint Lucia',
							'Saint Vincent and the Grenadines',
							'Trinidad and Tobago',
							'United States',
							'---Oceania',
							'Australia',
							'Fiji',
							'Kiribati',
							'Marshall Islands',
							'Micronesia',
							'Nauru',
							'New Zealand',
							'Palau',
							'Papua New Guinea',
							'Samoa',
							'Solomon Islands',
							'Tonga',
							'Tuvalu',
							'Vanuatu',
							'---South America',
							'Argentina',
							'Bolivia',
							'Brazil',
							'Chile',
							'Colombia',
							'Ecuador',
							'Guyana',
							'Paraguay',
							'Peru',
							'Suriname',
							'Uruguay',
							'Venezuela',
						]
						on_select:   fn (s []string, mut e gui.Event, mut w gui.Window) {
							mut app_ := w.state[SelectDemoApp]()
							app_.selected_2 = s
							e.is_handled = true
						}
					),
				]
			),
		]
	)
}

fn toggle_theme(app &SelectDemoApp) gui.View {
	return gui.row(
		h_align: .end
		sizing:  gui.fill_fit
		padding: gui.padding_none
		content: [
			gui.toggle(
				text_selected:   gui.icon_moon
				text_unselected: gui.icon_sunny_o
				text_style:      gui.theme().icon3
				padding:         gui.theme().padding_small
				selected:        app.light_theme
				on_click:        fn (_ &gui.ToggleCfg, mut _ gui.Event, mut w gui.Window) {
					mut app := w.state[SelectDemoApp]()
					app.light_theme = !app.light_theme
					theme := if app.light_theme {
						gui.theme_light_bordered
					} else {
						gui.theme_dark_bordered
					}
					w.set_theme(theme)
				}
			),
		]
	)
}
