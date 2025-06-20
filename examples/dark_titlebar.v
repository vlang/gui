import gui
import gui.titlebar

@[heap]
struct DropFilesApp {
pub mut:
	dropped_files []string
}

fn main() {
	mut window := gui.window(
		state:    &DropFilesApp{}
		width:    500
		height:   300
		on_init:  fn (mut w gui.Window) {
			w.update_view(main_view)
			$if windows {
				titlebar.prefer_dark_titlebar(nil, true) // todo get handle from window
			}
		}
		on_event: on_event_handler
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	app := window.state[DropFilesApp]()

	mut content := []gui.View{}
	content << gui.text(
		text:       'Drop Files on this Window'
		text_style: gui.theme().b1
	)

	for df in app.dropped_files {
		content << gui.text(text: df)
	}

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		h_align: .center
		v_align: .middle
		content: content
	)
}

fn on_event_handler(mut e gui.Event, mut w gui.Window) {
	if e.typ == .files_dropped {
		mut app := w.state[DropFilesApp]()
		app.dropped_files = w.get_dropped_file_paths()
	}
}
