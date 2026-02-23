import gui

@[heap]
struct PaletteApp {
pub mut:
	last_action string
}

fn main() {
	mut window := gui.window(
		title:    'Command Palette Demo'
		state:    &PaletteApp{}
		width:    600
		height:   400
		on_init:  fn (mut w gui.Window) {
			w.update_view(main_view)
		}
		on_event: fn (e &gui.Event, mut w gui.Window) {
			if e.typ == .key_down && e.key_code == .p && e.modifiers.has(.super)
				&& e.modifiers.has(.shift) {
				gui.command_palette_toggle('__cmd_palette__', 5, mut w)
			}
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(mut w gui.Window) gui.View {
	width, height := w.window_size()
	app := w.state[PaletteApp]()
	return gui.column(
		width:   width
		height:  height
		sizing:  gui.fixed_fixed
		padding: gui.padding_medium
		spacing: 10
		content: [
			gui.text(text: 'Press Cmd+Shift+P to open command palette'),
			gui.text(text: 'Last action: ${app.last_action}'),
			w.command_palette(
				id_focus:  5
				id_scroll: 6
				items:     palette_items()
				on_action: fn (id string, mut _ gui.Event, mut w gui.Window) {
					mut app := w.state[PaletteApp]()
					app.last_action = id
				}
			),
		]
	)
}

fn palette_items() []gui.CommandPaletteItem {
	return [
		gui.CommandPaletteItem{
			id:     'file.new'
			label:  'New File'
			detail: 'Ctrl+N'
		},
		gui.CommandPaletteItem{
			id:     'file.open'
			label:  'Open File'
			detail: 'Ctrl+O'
		},
		gui.CommandPaletteItem{
			id:     'file.save'
			label:  'Save'
			detail: 'Ctrl+S'
		},
		gui.CommandPaletteItem{
			id:     'file.save_as'
			label:  'Save As...'
			detail: 'Ctrl+Shift+S'
		},
		gui.CommandPaletteItem{
			id:     'edit.undo'
			label:  'Undo'
			detail: 'Ctrl+Z'
		},
		gui.CommandPaletteItem{
			id:     'edit.redo'
			label:  'Redo'
			detail: 'Ctrl+Shift+Z'
		},
		gui.CommandPaletteItem{
			id:     'edit.cut'
			label:  'Cut'
			detail: 'Ctrl+X'
		},
		gui.CommandPaletteItem{
			id:     'edit.copy'
			label:  'Copy'
			detail: 'Ctrl+C'
		},
		gui.CommandPaletteItem{
			id:     'edit.paste'
			label:  'Paste'
			detail: 'Ctrl+V'
		},
		gui.CommandPaletteItem{
			id:     'edit.find'
			label:  'Find'
			detail: 'Ctrl+F'
		},
		gui.CommandPaletteItem{
			id:     'edit.replace'
			label:  'Find and Replace'
			detail: 'Ctrl+H'
		},
		gui.CommandPaletteItem{
			id:     'view.zoom_in'
			label:  'Zoom In'
			detail: 'Ctrl+='
		},
		gui.CommandPaletteItem{
			id:     'view.zoom_out'
			label:  'Zoom Out'
			detail: 'Ctrl+-'
		},
		gui.CommandPaletteItem{
			id:     'view.sidebar'
			label:  'Toggle Sidebar'
			detail: 'Ctrl+B'
		},
		gui.CommandPaletteItem{
			id:     'view.fullscreen'
			label:  'Toggle Fullscreen'
			detail: 'F11'
		},
		gui.CommandPaletteItem{
			id:     'term.new'
			label:  'New Terminal'
			detail: 'Ctrl+`'
		},
		gui.CommandPaletteItem{
			id:    'term.split'
			label: 'Split Terminal'
		},
		gui.CommandPaletteItem{
			id:    'git.commit'
			label: 'Git: Commit'
		},
		gui.CommandPaletteItem{
			id:    'git.push'
			label: 'Git: Push'
		},
		gui.CommandPaletteItem{
			id:    'git.pull'
			label: 'Git: Pull'
		},
	]
}
