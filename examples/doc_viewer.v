import gui
import os

// Doc Viewer
// =============================
// A view to read the markdown doc files in the ../doc folder. Demonstrates the following:
//
// - multiline text
// - text selection
// - nav selection highlighting
//
// Selection highlighting shows how immediate mode UI's simplify tasks like selection
// highlighting. Notice the code only highlights the selected item. It does not need
// to remember to "unhighlight" previous selection.

const id_scroll_doc_view = 1

@[heap]
struct DocViewerApp {
pub mut:
	doc_file string
	tab_size string = '4'
}

fn main() {
	mut window := gui.window(
		state:   &DocViewerApp{}
		width:   950
		height:  850
		title:   'Doc Viewer'
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	mut app := window.state[DocViewerApp]()

	return gui.row(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		h_align: .center
		v_align: .middle
		content: [
			app.nav_panel(window),
			app.doc_panel(window),
		]
	)
}

fn (mut app DocViewerApp) nav_panel(w &gui.Window) gui.View {
	files := os.ls('../doc') or { [] }
	doc_files := files.filter(os.file_ext(it) == '.md').sorted()

	mut nav_files := []gui.View{}
	for doc_file in doc_files {
		// Change background color of current selection. No need
		// to remember the old selection to unhighlight.
		color := if doc_file == app.doc_file {
			gui.theme().color_active
		} else {
			gui.color_transparent
		}
		nav_files << gui.row(
			fill:     true
			color:    color
			padding:  gui.padding_two_five
			sizing:   gui.fill_fit
			on_click: fn [doc_file] (_ &gui.ContainerCfg, mut _ gui.Event, mut win gui.Window) {
				mut app := win.state[DocViewerApp]()
				app.doc_file = doc_file
				win.scroll_vertical_to(id_scroll_doc_view, 0)
			}
			content:  [
				gui.text(text: doc_file),
			]
			on_hover: fn (mut node gui.Layout, mut e gui.Event, mut w gui.Window) {
				w.set_mouse_cursor_pointing_hand()
				node.shape.color = gui.theme().color_hover
			}
		)
	}

	mut content := []gui.View{}
	content << nav_files
	content << gui.rectangle(sizing: gui.fill_fill, color: gui.color_transparent)
	content << tab_stops(w)

	return gui.column(
		id:      'nav'
		fill:    true
		color:   gui.theme().color_panel
		sizing:  gui.fit_fill
		content: content
	)
}

fn tab_stops(w &gui.Window) gui.View {
	app := w.state[DocViewerApp]()
	return gui.radio_button_group_row(
		title:     'Tab Size '
		value:     app.tab_size
		options:   [
			gui.radio_option('2', '2'),
			gui.radio_option('4', '4'),
			gui.radio_option('8', '8'),
		]
		on_select: fn (value string, mut win gui.Window) {
			mut app := win.state[DocViewerApp]()
			app.tab_size = value
		}
	)
}

fn (mut app DocViewerApp) doc_panel(w &gui.Window) gui.View {
	text := os.read_file(os.join_path('../doc', app.doc_file)) or { 'select a doc' }
	return gui.column(
		id:        'doc'
		id_scroll: id_scroll_doc_view
		min_width: 250
		fill:      true
		color:     gui.theme().color_panel
		sizing:    gui.fill_fill
		content:   [
			gui.text(
				id_focus:   1 // enables selectable text
				text:       text
				mode:       .multiline
				tab_size:   app.tab_size.u32()
				text_style: gui.theme().m4
			),
		]
	)
}
