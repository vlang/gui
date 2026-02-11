import gui

@[heap]
struct NumericInputApp {
mut:
	en_text  string = '1,234.50'
	en_value ?f64   = 1234.5
	de_text  string = '1.234,50'
	de_value ?f64   = 1234.5
}

fn main() {
	mut window := gui.window(
		title:   'Numeric Input'
		state:   &NumericInputApp{}
		width:   300
		height:  280
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
			w.set_id_focus(1)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	app := window.state[NumericInputApp]()
	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		padding: gui.padding_medium
		spacing: gui.spacing_medium
		content: [
			gui.text(text: 'Locale: en_US'),
			gui.numeric_input(
				id:                 'num_en'
				id_focus:           1
				text:               app.en_text
				value:              app.en_value
				decimals:           2
				min:                0.0
				max:                10000.0
				size_border:        1.5
				color_border:       gui.rgb(160, 160, 160)
				color_border_focus: gui.rgb(81, 165, 255)
				padding:            gui.padding_two_four
				width:              220
				sizing:             gui.fixed_fit
				on_text_changed:    fn (_ &gui.Layout, text string, mut w gui.Window) {
					mut state := w.state[NumericInputApp]()
					state.en_text = text
				}
				on_value_commit:    fn (_ &gui.Layout, value ?f64, text string, mut w gui.Window) {
					mut state := w.state[NumericInputApp]()
					state.en_value = value
					state.en_text = text
				}
			),
			gui.text(text: 'Committed value: ${numeric_value_text(app.en_value)}'),
			gui.text(text: 'Locale: de_DE'),
			gui.numeric_input(
				id:                 'num_de'
				id_focus:           2
				text:               app.de_text
				value:              app.de_value
				decimals:           2
				locale:             gui.NumericLocaleCfg{
					decimal_sep: `,`
					group_sep:   `.`
				}
				size_border:        1.5
				color_border:       gui.rgb(160, 160, 160)
				color_border_focus: gui.rgb(81, 165, 255)
				padding:            gui.padding_two_four
				width:              220
				sizing:             gui.fixed_fit
				on_text_changed:    fn (_ &gui.Layout, text string, mut w gui.Window) {
					mut state := w.state[NumericInputApp]()
					state.de_text = text
				}
				on_value_commit:    fn (_ &gui.Layout, value ?f64, text string, mut w gui.Window) {
					mut state := w.state[NumericInputApp]()
					state.de_value = value
					state.de_text = text
				}
			),
			gui.text(text: 'Committed value: ${numeric_value_text(app.de_value)}'),
		]
	)
}

fn numeric_value_text(value ?f64) string {
	if parsed := value {
		return '${parsed:.2f}'
	}
	return 'none'
}
