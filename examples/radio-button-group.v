import gui

// Radio button group
// =============================

@[heap]
struct RadioButtonGroupApp {
pub mut:
	selected_value string = 'ny'
}

fn main() {
	mut window := gui.window(
		title:   'Radio Button Groups'
		state:   &RadioButtonGroupApp{}
		width:   600
		height:  400
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
	mut app := window.state[RadioButtonGroupApp]()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		h_align: .center
		spacing: gui.theme().spacing_large
		content: [
			instructions(),
			gui.radio_button_group_row(
				title:     'City Group'
				value:     app.selected_value
				options:   [
					gui.radio_option('New York', 'ny', 1), // label, value, id_focus
					gui.radio_option('Detroit', 'dtw', 2),
					gui.radio_option('Chicago', 'chi', 3),
					gui.radio_option('Los Angeles', 'la', 4),
				]
				on_select: fn [mut app] (value string) {
					app.selected_value = value
				}
				window:    window
			),
			// Intentionally using the same data/focus id to show vertical
			// and horizontal side-by-side
			gui.radio_button_group_column(
				title:     'City Group'
				value:     app.selected_value
				options:   [
					gui.radio_option('New York', 'ny', 1),
					gui.radio_option('Detroit', 'dtw', 2),
					gui.radio_option('Chicago', 'chi', 3),
					gui.radio_option('Los Angeles', 'la', 4),
				]
				on_select: fn [mut app] (value string) {
					app.selected_value = value
				}
				window:    window
			),
		]
	)
}

fn instructions() gui.View {
	return gui.row(
		h_align: .center
		sizing:  gui.fill_fit
		content: [
			gui.column(sizing: gui.fill_fill),
			gui.text(
				text: 'Radio buttons with keyboard navigation. Tab to move focus, space to select or click'
				mode: .wrap
			),
			gui.column(sizing: gui.fill_fill),
		]
	)
}
