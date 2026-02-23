import gui

@[heap]
struct ComboboxApp {
pub mut:
	selected string
}

fn main() {
	mut window := gui.window(
		title:   'Combobox Demo'
		state:   &ComboboxApp{}
		width:   400
		height:  300
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(mut w gui.Window) gui.View {
	width, height := w.window_size()
	app := w.state[ComboboxApp]()
	return gui.column(
		width:   width
		height:  height
		sizing:  gui.fixed_fixed
		padding: gui.padding_medium
		spacing: 10
		content: [
			gui.text(text: 'Selected: ${app.selected}'),
			w.combobox(
				id:          'fruit'
				id_focus:    1
				id_scroll:   2
				value:       app.selected
				placeholder: 'Pick a fruit...'
				options:     [
					'Apple',
					'Banana',
					'Cherry',
					'Date',
					'Elderberry',
					'Fig',
					'Grape',
					'Honeydew',
					'Kiwi',
					'Lemon',
					'Mango',
					'Nectarine',
					'Orange',
					'Papaya',
					'Quince',
					'Raspberry',
					'Strawberry',
					'Tangerine',
					'Watermelon',
				]
				on_select:   fn (val string, mut _ gui.Event, mut w gui.Window) {
					mut app := w.state[ComboboxApp]()
					app.selected = val
				}
			),
		]
	)
}
