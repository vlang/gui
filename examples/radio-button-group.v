import gui

// Radio button group
// =============================
// How to do radio button group with clickable labels and keyboard navigation

@[heap]
struct RadioButtonGroupApp {
pub mut:
	selected_id string = 'ny'
}

fn main() {
	mut window := gui.window(
		state:   &RadioButtonGroupApp{}
		width:   300
		height:  300
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
			gui.column(
				text:    ' Radio Group '
				color:   gui.theme().color_5
				padding: gui.theme().padding_large
				content: [
					radio_label('New York', 'ny', 1, mut app),
					radio_label('Detroit', 'dtw', 2, mut app),
					radio_label('Chicago', 'chi', 3, mut app),
					radio_label('Los Angeles', 'la', 4, mut app),
				]
			),
		]
	)
}

// Simply wrap the radio button and text in a row and add some event handlers.
// In this way, you get total control over the look and feel.
fn radio_label(label string, id string, id_focus u32, mut app RadioButtonGroupApp) gui.View {
	return gui.row(
		id_focus:     id_focus
		radius:       0
		padding:      gui.padding_two_five
		on_click:     fn [mut app, id] (_ voidptr, mut _e gui.Event, mut w gui.Window) {
			app.selected_id = id
		}
		on_char:      fn [mut app, id] (_ voidptr, mut e gui.Event, mut w gui.Window) {
			if e.char_code == ` ` {
				app.selected_id = id
			}
		}
		amend_layout: fn (mut node gui.Layout, mut w gui.Window) {
			// color the rectangle to indicate focus
			if w.is_focus(node.shape.id_focus) {
				node.shape.color = gui.theme().color_5
			}
		}
		on_hover:     fn (mut node gui.Layout, mut _ gui.Event, mut w gui.Window) {
			w.set_mouse_cursor_pointing_hand()
		}
		content:      [
			gui.radio(selected: id == app.selected_id),
			gui.text(text: label),
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
