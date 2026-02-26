import gui

@[heap]
struct DockApp {
pub mut:
	dock_root &gui.DockNode = unsafe { nil }
}

fn main() {
	mut app := &DockApp{}
	app.dock_root = default_layout()

	mut window := gui.window(
		state:   app
		width:   1024
		height:  680
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.run()
}

fn default_layout() &gui.DockNode {
	// IDE-style: explorer left | (editor top / terminal bottom)
	return gui.dock_split('root', .horizontal, 0.22, gui.dock_panel_group('left_group',
		['explorer', 'search'], 'explorer'), gui.dock_split('right_split', .vertical,
		0.65, gui.dock_panel_group('editor_group', ['main_v', 'readme'], 'main_v'), gui.dock_panel_group('bottom_group',
		['terminal', 'output'], 'terminal')))
}

fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	app := window.state[DockApp]()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		padding: gui.padding_none
		spacing: 0
		content: [
			gui.dock_layout(
				id:               'dock'
				root:             app.dock_root
				panels:           [
					gui.DockPanelDef{
						id:      'explorer'
						label:   'Explorer'
						content: [panel_content('Explorer', 'Project files go here.')]
					},
					gui.DockPanelDef{
						id:      'search'
						label:   'Search'
						content: [panel_content('Search', 'Search across files.')]
					},
					gui.DockPanelDef{
						id:      'main_v'
						label:   'main.v'
						content: [panel_content('main.v', 'fn main() {\n    println("hello")\n}')]
					},
					gui.DockPanelDef{
						id:      'readme'
						label:   'README.md'
						content: [panel_content('README.md', '# My Project\nA sample project.')]
					},
					gui.DockPanelDef{
						id:      'terminal'
						label:   'Terminal'
						content: [panel_content('Terminal', '$ v run .\nhello')]
					},
					gui.DockPanelDef{
						id:      'output'
						label:   'Output'
						content: [panel_content('Output', 'Build successful.')]
					},
				]
				on_layout_change: fn (new_root &gui.DockNode, mut w gui.Window) {
					mut app := w.state[DockApp]()
					app.dock_root = unsafe { new_root }
				}
				on_panel_select:  fn (group_id string, panel_id string, mut w gui.Window) {
					mut app := w.state[DockApp]()
					app.dock_root = gui.dock_tree_select_panel(app.dock_root, group_id,
						panel_id)
				}
				on_panel_close:   fn (panel_id string, mut w gui.Window) {
					mut app := w.state[DockApp]()
					app.dock_root = gui.dock_tree_remove_panel(app.dock_root, panel_id)
				}
			),
		]
	)
}

fn panel_content(title string, body string) gui.View {
	return gui.column(
		sizing:  gui.fill_fill
		padding: gui.padding(10, 10, 10, 10)
		spacing: 6
		content: [
			gui.text(text: title, text_style: gui.theme().b2),
			gui.text(text: body, mode: .wrap),
		]
	)
}
