import gui

// Drag-to-Reorder Demo
// Tests: ListBox, TabControl, Tree drag reorder.
// - Drag items past 5px threshold to reorder
// - Alt+Up/Down (list/tree) or Alt+Left/Right (tabs)
// - Escape cancels active drag
// - Subheadings / disabled tabs are not draggable

@[heap]
struct App {
pub mut:
	items    []gui.ListBoxOption
	selected []string
	tabs     []gui.TabItemCfg
	tab_sel  string = 'a'
	nodes    []gui.TreeNodeCfg
}

fn main() {
	mut window := gui.window(
		title:   'Drag Reorder Demo'
		width:   700
		height:  500
		state:   &App{
			items: demo_items()
			tabs:  demo_tabs()
			nodes: demo_nodes()
		}
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(mut w gui.Window) gui.View {
	width, height := w.window_size()
	app := w.state[App]()

	return gui.row(
		width:   width
		height:  height
		sizing:  gui.fixed_fixed
		padding: gui.pad_all(10)
		spacing: 10
		content: [
			gui.column(
				sizing:  gui.fit_fill
				spacing: 4
				content: [
					gui.text(text: 'ListBox (drag or Alt+Up/Down)'),
					w.list_box(
						id:           'demo_lb'
						id_scroll:    1
						min_width:    180
						max_height:   400
						selected_ids: app.selected
						data:         app.items
						reorderable:  true
						on_reorder:   fn (old_idx int, new_idx int, mut w gui.Window) {
							mut a := w.state[App]()
							item := a.items[old_idx]
							a.items.delete(old_idx)
							a.items.insert(new_idx, item)
						}
						on_select:    fn (ids []string, mut e gui.Event, mut w gui.Window) {
							mut a := w.state[App]()
							a.selected = ids
						}
					),
				]
			),
			gui.column(
				sizing:  gui.fill_fill
				spacing: 4
				content: [
					gui.text(text: 'TabControl (drag or Alt+Left/Right)'),
					w.tab_control(
						id:          'demo_tc'
						items:       app.tabs
						selected:    app.tab_sel
						reorderable: true
						on_select:   fn (id string, mut e gui.Event, mut w gui.Window) {
							mut a := w.state[App]()
							a.tab_sel = id
						}
						on_reorder:  fn (old_idx int, new_idx int, mut w gui.Window) {
							mut a := w.state[App]()
							item := a.tabs[old_idx]
							a.tabs.delete(old_idx)
							a.tabs.insert(new_idx, item)
						}
					),
					gui.text(text: 'Tree (drag or Alt+Up/Down)'),
					w.tree(
						id:          'demo_tree'
						id_scroll:   2
						id_focus:    10
						max_height:  200
						nodes:       app.nodes
						reorderable: true
						on_select:   fn (id string, mut w gui.Window) {}
						on_reorder:  fn (old_idx int, new_idx int, mut w gui.Window) {
							mut a := w.state[App]()
							node := a.nodes[old_idx]
							a.nodes.delete(old_idx)
							a.nodes.insert(new_idx, node)
						}
					),
				]
			),
		]
	)
}

fn demo_items() []gui.ListBoxOption {
	return [
		gui.list_box_subheading('h1', 'Fruits'),
		gui.list_box_option('apple', 'Apple', ''),
		gui.list_box_option('banana', 'Banana', ''),
		gui.list_box_option('cherry', 'Cherry', ''),
		gui.list_box_option('date', 'Date', ''),
		gui.list_box_option('elderberry', 'Elderberry', ''),
		gui.list_box_option('fig', 'Fig', ''),
		gui.list_box_option('grape', 'Grape', ''),
		gui.list_box_subheading('h2', 'Vegetables'),
		gui.list_box_option('artichoke', 'Artichoke', ''),
		gui.list_box_option('broccoli', 'Broccoli', ''),
		gui.list_box_option('carrot', 'Carrot', ''),
	]
}

fn demo_tabs() []gui.TabItemCfg {
	return [
		gui.TabItemCfg{
			id:      'a'
			label:   'Alpha'
			content: [gui.text(text: 'Alpha content')]
		},
		gui.TabItemCfg{
			id:      'b'
			label:   'Beta'
			content: [gui.text(text: 'Beta content')]
		},
		gui.TabItemCfg{
			id:      'c'
			label:   'Gamma'
			content: [gui.text(text: 'Gamma content')]
		},
		gui.TabItemCfg{
			id:      'd'
			label:   'Delta'
			content: [gui.text(text: 'Delta content')]
		},
		gui.TabItemCfg{
			id:       'e'
			label:    'Disabled'
			disabled: true
			content:  [gui.text(text: 'N/A')]
		},
	]
}

fn demo_nodes() []gui.TreeNodeCfg {
	return [
		gui.TreeNodeCfg{
			id:    'src'
			text:  'src'
			nodes: [
				gui.TreeNodeCfg{
					id:   'main.v'
					text: 'main.v'
				},
				gui.TreeNodeCfg{
					id:   'util.v'
					text: 'util.v'
				},
			]
		},
		gui.TreeNodeCfg{
			id:    'docs'
			text:  'docs'
			nodes: [
				gui.TreeNodeCfg{
					id:   'readme'
					text: 'README.md'
				},
			]
		},
		gui.TreeNodeCfg{
			id:   'tests'
			text: 'tests'
		},
		gui.TreeNodeCfg{
			id:   'build'
			text: 'build'
		},
		gui.TreeNodeCfg{
			id:   'assets'
			text: 'assets'
		},
	]
}
