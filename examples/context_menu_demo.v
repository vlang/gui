import gui

// Context Menu Demo
// =============================
// Gui does not have a specific "context menu" like other frameworks.
// Instead, use a floating menu and attach it to the view that will
// host the context menu. In this way, one has complete control on
// the triggering and hiding events, as well as the position of the
// context menu.

const id_focus_context_menu = 100

@[heap]
struct ContextMenuApp {
pub mut:
	select_menu_id    string
	show_context_menu bool
}

fn main() {
	mut window := gui.window(
		state:   &ContextMenuApp{}
		width:   400
		height:  300
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(mut window gui.Window) gui.View {
	w, h := window.window_size()
	app := window.state[ContextMenuApp]()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		h_align: .center
		content: [
			gui.column(
				content: [
					gui.text(text: 'clicked: ${app.select_menu_id}'),
					gui.text(
						text:       'Right click on text'
						text_style: gui.theme().b1
					),
					window.menu(
						// ---------------------------------
						// hide/show controlled by app state
						// ---------------------------------
						invisible: !app.show_context_menu
						// -------------------------------
						// context menu is a floating menu
						// -------------------------------
						float:         true
						float_anchor:  .bottom_left
						float_tie_off: .top_left
						id_focus:      id_focus_context_menu
						items:         [
							gui.menu_item_text('here', 'Here'),
							gui.menu_item_text('there', 'There'),
							gui.menu_item_text('no-where', 'No Where'),
							gui.menu_item_text('some-where', 'Some Where'),
							gui.menu_submenu('keep-going', 'Keep Going', [
								gui.menu_item_text('you-are-done', "OK, you're done"),
							]),
							gui.menu_separator(),
							gui.menu_item_text('exit', 'Exit'),
						]
						action:        fn (id string, mut e gui.Event, mut w gui.Window) {
							mut app := w.state[ContextMenuApp]()
							app.select_menu_id = id
							app.show_context_menu = false
						}
					),
				]
				// ---------------------------------------------------------
				// Activate the menu as required. Not limited to right-click
				// ---------------------------------------------------------
				on_any_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
					mut app := w.state[ContextMenuApp]()
					if e.mouse_button == .right {
						app.show_context_menu = true
						w.set_id_focus(id_focus_context_menu)
						e.is_handled = true
					}
				}
			),
		]
		// ------------------------------------------
		// Clicking anywhere else closes context menu
		// ------------------------------------------
		on_click: fn (_ voidptr, mut e gui.Event, mut w gui.Window) {
			mut app := w.state[ContextMenuApp]()
			app.show_context_menu = false
			e.is_handled = true
		}
	)
}
