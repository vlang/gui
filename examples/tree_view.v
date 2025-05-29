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
		height:  300
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
		h_align: .center
		v_align: .middle
		content: [
			gui.text(text: app.tree_id, text_style: gui.theme().b1),
			gui.tree(
				id:        'animals'
				text:      'Animals'
				on_select: on_select
				nodes:     [
					gui.tree_node(
						id:    'mammals'
						text:  'Mammals'
						nodes: [
							gui.tree_node(id: 'lion', text: 'Lion'),
							gui.tree_node(id: 'cat', text: 'Cat'),
							gui.tree_node(id: 'zebra', text: 'Zebra'),
						]
					),
				]
			),
		]
	)
}
