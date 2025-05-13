import gui
import os

// Doc Viewer
// =============================

@[heap]
struct App {
pub mut:
	doc_file string
}

fn main() {
	mut window := gui.window(
		state:   &App{}
		width:   850
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
	mut app := window.state[App]()

	return gui.row(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		h_align: .center
		v_align: .middle
		content: [
			app.nav(window),
			app.doc(window),
		]
	)
}

fn (mut app App) nav(w &gui.Window) gui.View {
	files := os.ls('../doc') or { [] }
	doc_files := files.filter(os.file_ext(it) == '.md').sorted()

	mut nav_files := []gui.View{}
	for doc_file in doc_files {
		color := if doc_file == app.doc_file { gui.theme().color_5 } else { gui.color_transparent }
		nav_files << gui.row(
			fill:     true
			color:    color
			padding:  gui.padding_two_five
			sizing:   gui.fill_fit
			on_click: fn [doc_file] (_ &gui.ContainerCfg, mut _ gui.Event, mut win gui.Window) {
				mut app := win.state[App]()
				app.doc_file = doc_file
			}
			content:  [
				gui.text(text: doc_file),
			]
		)
	}

	return gui.column(
		id:      'nav'
		fill:    true
		color:   gui.theme().color_1
		sizing:  gui.fit_fill
		content: nav_files
	)
}

fn (mut app App) doc(w &gui.Window) gui.View {
	text := os.read_file(os.join_path('../doc', app.doc_file)) or { 'no doc file' }
	return gui.column(
		id:        'doc'
		id_scroll: 1
		min_width: 250
		fill:      true
		color:     gui.theme().color_1
		sizing:    gui.fill_fill
		content:   [
			gui.text(
				text:        text
				mode:        .multiline
				keep_spaces: true
				text_style:  gui.theme().m4
			),
		]
	)
}
