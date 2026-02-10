import gui

// Virtualized List Box Scrolling
// =============================
// Demonstrates list box virtualization with 10,000 items.
// Build with -prod for smooth scrolling and lower frame-time jitter.

@[heap]
struct App {
pub mut:
	items        []gui.ListBoxOption
	selected_ids []string
}

fn main() {
	size := 10_000
	mut items := []gui.ListBoxOption{cap: size}
	for i in 1 .. size + 1 {
		id := '${i:05}'
		items << gui.list_box_option(id, '${id} text list item', id)
	}

	mut window := gui.window(
		width:   240
		height:  420
		state:   &App{
			items: items
		}
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(mut window gui.Window) gui.View {
	app := window.state[App]()
	w, h := window.window_size()
	selected := if app.selected_ids.len > 0 {
		app.selected_ids[0]
	} else {
		'none'
	}

	return gui.column(
		width:   w
		height:  h
		h_align: .center
		sizing:  gui.fixed_fixed
		spacing: gui.spacing_small
		padding: gui.padding(8, 8, 8, 8)
		content: [
			gui.text(text: '10,000-item virtualized list box', text_style: gui.theme().b4),
			gui.text(text: 'Selected id: ${selected}', text_style: gui.theme().n5),
			window.list_box(
				id:           'virtual-listbox-10k'
				id_scroll:    1
				height:       h - 70
				sizing:       gui.fill_fixed
				selected_ids: app.selected_ids
				data:         app.items
				on_select:    fn (ids []string, mut e gui.Event, mut w gui.Window) {
					mut app := w.state[App]()
					app.selected_ids = ids
					e.is_handled = true
				}
			),
		]
	)
}
