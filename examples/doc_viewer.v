import gui

// Doc Viewer
// =============================
// A view to read the embedded markdown doc files. Demonstrates the following:
//
// - multiline text
// - text selection
// - nav selection highlighting
//
// Selection highlighting shows how immediate mode UI's simplify tasks like selection
// highlighting. Notice the code only highlights the selected item. It does not need
// to remember to "unhighlight" previous selection.

const id_scroll_doc_view = 1

struct DocEntry {
	name string
	text string
}

fn doc_entries() []DocEntry {
	return [
		DocEntry{'README.md', $embed_file('../README.md').to_string()},
		DocEntry{'ANIMATIONS.md', $embed_file('../docs/ANIMATIONS.md').to_string()},
		DocEntry{'ARCHITECTURE.md', $embed_file('../docs/ARCHITECTURE.md').to_string()},
		DocEntry{'CONTAINERS.md', $embed_file('../docs/CONTAINERS.md').to_string()},
		DocEntry{'CUSTOM_WIDGETS.md', $embed_file('../docs/CUSTOM_WIDGETS.md').to_string()},
		DocEntry{'DATA_GRID.md', $embed_file('../docs/DATA_GRID.md').to_string()},
		DocEntry{'GET_STARTED.md', $embed_file('../docs/GET_STARTED.md').to_string()},
		DocEntry{'GRADIENTS.md', $embed_file('../docs/GRADIENTS.md').to_string()},
		DocEntry{'LAYOUT_ALGORITHM.md', $embed_file('../docs/LAYOUT_ALGORITHM.md').to_string()},
		DocEntry{'MARKDOWN.md', $embed_file('../docs/MARKDOWN.md').to_string()},
		DocEntry{'NATIVE_DIALOGS.md', $embed_file('../docs/NATIVE_DIALOGS.md').to_string()},
		DocEntry{'PERFORMANCE.md', $embed_file('../docs/PERFORMANCE.md').to_string()},
		DocEntry{'PRINTING.md', $embed_file('../docs/PRINTING.md').to_string()},
		DocEntry{'ROADMAP.md', $embed_file('../docs/ROADMAP.md').to_string()},
		DocEntry{'SHADERS.md', $embed_file('../docs/SHADERS.md').to_string()},
		DocEntry{'SPLITTER.md', $embed_file('../docs/SPLITTER.md').to_string()},
		DocEntry{'SVG.md', $embed_file('../docs/SVG.md').to_string()},
		DocEntry{'TABLES.md', $embed_file('../docs/TABLES.md').to_string()},
	]
}

@[heap]
struct DocViewerApp {
pub mut:
	selected      int
	tab_size      string = '4'
	markdown_mode bool   = true
}

fn main() {
	mut window := gui.window(
		state:        &DocViewerApp{}
		width:        950
		height:       850
		title:        'Doc Viewer'
		cursor_blink: true
		on_init:      fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	app := window.state[DocViewerApp]()

	return gui.row(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		h_align: .center
		v_align: .middle
		content: [
			nav_panel(app.selected, app.markdown_mode, app.tab_size),
			doc_panel(window, app.selected),
		]
	)
}

fn nav_panel(selected int, markdown_mode bool, tab_size string) gui.View {
	mut nav_items := []gui.View{}
	for i, entry in doc_entries() {
		color := if i == selected {
			gui.theme().color_active
		} else {
			gui.color_transparent
		}
		idx := i
		nav_items << gui.row(
			color:    color
			padding:  gui.padding_two_five
			sizing:   gui.fill_fit
			on_click: fn [idx] (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
				mut app := w.state[DocViewerApp]()
				app.selected = idx
				w.scroll_vertical_to(id_scroll_doc_view, 0)
			}
			content:  [
				gui.text(text: entry.name),
			]
			on_hover: fn (mut layout gui.Layout, mut _ gui.Event, mut w gui.Window) {
				w.set_mouse_cursor_pointing_hand()
				layout.shape.color = gui.theme().color_hover
			}
		)
	}

	mut content := []gui.View{}
	content << nav_items
	content << gui.rectangle(
		sizing:       gui.fill_fill
		color_border: gui.color_transparent
	)
	content << tab_stops(tab_size)
	content << gui.toggle(
		label:    'Markdown'
		select:   markdown_mode
		on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
			mut app := w.state[DocViewerApp]()
			app.markdown_mode = !app.markdown_mode
		}
	)

	return gui.column(
		id:      'nav'
		color:   gui.theme().color_panel
		sizing:  gui.fit_fill
		content: content
	)
}

fn tab_stops(tab_size string) gui.View {
	return gui.radio_button_group_row(
		title:     'Tab Size '
		title_bg:  gui.theme().color_panel
		value:     tab_size
		options:   [
			gui.radio_option('2', '2'),
			gui.radio_option('4', '4'),
			gui.radio_option('8', '8'),
		]
		on_select: fn (value string, mut w gui.Window) {
			mut app := w.state[DocViewerApp]()
			app.tab_size = value
		}
	)
}

fn doc_panel(w &gui.Window, selected int) gui.View {
	app := w.state[DocViewerApp]()
	entries := doc_entries()
	text := if selected >= 0 && selected < entries.len {
		entries[selected].text
	} else {
		'select a doc'
	}
	mut content := []gui.View{}
	if app.markdown_mode {
		content = [w.markdown(source: text, mode: .wrap)]
	} else {
		content = [
			gui.View(gui.text(
				id_focus:   1 // enables selectable text
				text:       text
				mode:       .multiline
				tab_size:   app.tab_size.u32()
				text_style: gui.theme().m4
			)),
		]
	}
	return gui.column(
		id:        'doc'
		id_scroll: id_scroll_doc_view
		min_width: 250
		color:     gui.theme().color_panel
		sizing:    gui.fill_fill
		content:   content
	)
}
