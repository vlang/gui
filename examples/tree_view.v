import gui

// Tree View
// =============================

@[heap]
struct TreeViewApp {
pub mut:
	tree_id string
}

fn main() {
	mut window := gui.window(
		state:   &TreeViewApp{}
		width:   300
		height:  600
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn on_select(id string, mut w gui.Window) {
	mut app := w.state[TreeViewApp]()
	app.tree_id = id
}

fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	app := window.state[TreeViewApp]()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		content: [
			gui.text(text: '[ ${app.tree_id} ]'),
			gui.tree(
				id:        'animals'
				window:    window
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
					gui.tree_node(
						text:  'Insects'
						icon:  gui.icon_bug
						nodes: [
							gui.tree_node(text: 'Butterfly'),
							gui.tree_node(text: 'House Fly'),
							gui.tree_node(text: 'Locust'),
							gui.tree_node(text: 'Moth'),
						]
					),
				]
			),
		]
	)
}
