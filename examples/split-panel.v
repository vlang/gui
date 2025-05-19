import gui

// Split Panel Example
// =============================

@[heap]
struct SplitPanelApp {
pub mut:
	a_width f32
}

fn main() {
	mut window := gui.window(
		state:   &SplitPanelApp{}
		width:   300
		height:  300
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	app := window.state[SplitPanelApp]()

	width := gui.clamp_f32(app.a_width, 10, w - 10)

	return gui.row(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		spacing: 1
		content: [
			gui.column(
				id:     'A'
				width:  width
				fill:   true
				color:  gui.theme().color_2
				sizing: gui.fill_fill
			),
			gui.button(
				width:    10
				sizing:   gui.fit_fill
				padding:  gui.padding_none
				on_click: split_click
			),
			gui.column(
				fill:   true
				color:  gui.theme().color_2
				sizing: gui.fill_fill
			),
		]
	)
}

fn split_click(cfg &gui.ButtonCfg, mut e gui.Event, mut w gui.Window) {
	w.mouse_lock(gui.MouseLockCfg{
		mouse_move: mouse_move
		mouse_up:   fn (node &Layout, mut e Event, mut w Window) {
			w.mouse_unlock()
		}
	})
}

fn mouse_move(node &gui.Layout, mut e gui.Event, mut w gui.Window) {
	if a_node := node.find_node(fn (n &gui.Layout) bool {
		return n.shape.id == 'A'
	})
	{
		app := w.state[SplitPanelApp]()
		app.a_width = a_node.shape.width - e.scroll_x
	}
}
