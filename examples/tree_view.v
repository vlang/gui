import gui
import time

// Tree View — basic, virtualized, and lazy-loading demos.

@[heap]
struct TreeViewApp {
pub mut:
	selected_id string
	lazy_nodes  map[string][]gui.TreeNodeCfg
}

fn main() {
	mut window := gui.window(
		state:   &TreeViewApp{}
		width:   400
		height:  700
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn on_select(id string, mut w gui.Window) {
	mut app := w.state[TreeViewApp]()
	app.selected_id = id
}

fn on_lazy_load(tree_id string, node_id string, mut w gui.Window) {
	// Simulate async fetch: spawn a thread that sleeps then
	// delivers children via queue_command.
	spawn fn [tree_id, node_id] (mut w gui.Window) {
		time.sleep(800 * time.millisecond)
		children := match node_id {
			'remote_a' {
				[
					gui.tree_node(text: 'alpha.txt'),
					gui.tree_node(text: 'beta.txt'),
					gui.tree_node(text: 'gamma.txt'),
				]
			}
			'remote_b' {
				[
					gui.tree_node(text: 'one.rs'),
					gui.tree_node(text: 'two.rs'),
				]
			}
			else {
				[gui.tree_node(text: '(empty)')]
			}
		}
		w.queue_command(fn [node_id, children] (mut w gui.Window) {
			mut app := w.state[TreeViewApp]()
			app.lazy_nodes[node_id] = children
			w.update_window()
		})
	}(mut w)
}

fn main_view(mut window gui.Window) gui.View {
	w, h := window.window_size()
	app := window.state[TreeViewApp]()

	// Build lazy subtree nodes from loaded data.
	remote_a_nodes := app.lazy_nodes['remote_a'] or { []gui.TreeNodeCfg{} }
	remote_b_nodes := app.lazy_nodes['remote_b'] or { []gui.TreeNodeCfg{} }

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		content: [
			gui.text(text: 'selected: ${app.selected_id}'),
			gui.text(text: 'Basic tree'),
			window.tree(
				id:        'animals'
				on_select: on_select
				nodes:     [
					gui.tree_node(
						text:  'Mammals'
						icon:  gui.icon_github_alt
						nodes: [
							gui.tree_node(text: 'Lion'),
							gui.tree_node(text: 'Cat'),
							gui.tree_node(text: 'Human', icon: gui.icon_user),
						]
					),
					gui.tree_node(
						text:  'Birds'
						icon:  gui.icon_twitter
						nodes: [
							gui.tree_node(text: 'Condor'),
							gui.tree_node(
								text:  'Eagle'
								nodes: [
									gui.tree_node(text: 'Bald'),
									gui.tree_node(text: 'Golden'),
									gui.tree_node(text: 'Sea'),
								]
							),
							gui.tree_node(text: 'Parrot', icon: gui.icon_cage),
							gui.tree_node(text: 'Robin'),
						]
					),
				]
			),
			gui.text(text: 'Virtualized tree (scroll)'),
			window.tree(
				id:         'big_tree'
				on_select:  on_select
				id_scroll:  1
				max_height: 200
				nodes:      make_big_tree()
			),
			gui.text(text: 'Lazy-loading tree'),
			window.tree(
				id:           'lazy_tree'
				on_select:    on_select
				on_lazy_load: on_lazy_load
				nodes:        [
					gui.TreeNodeCfg{
						id:    'remote_a'
						text:  'Remote folder A'
						icon:  gui.icon_folder
						lazy:  true
						nodes: remote_a_nodes
					},
					gui.TreeNodeCfg{
						id:    'remote_b'
						text:  'Remote folder B'
						icon:  gui.icon_folder
						lazy:  true
						nodes: remote_b_nodes
					},
					gui.tree_node(text: 'Local item'),
				]
			),
		]
	)
}

fn make_big_tree() []gui.TreeNodeCfg {
	mut nodes := []gui.TreeNodeCfg{cap: 20}
	for i in 0 .. 20 {
		mut children := []gui.TreeNodeCfg{cap: 10}
		for j in 0 .. 10 {
			children << gui.tree_node(text: 'Item ${i}-${j}')
		}
		nodes << gui.TreeNodeCfg{
			text:  'Group ${i}'
			icon:  gui.icon_folder
			nodes: children
		}
	}
	return nodes
}
