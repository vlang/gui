import gui

// Tooltip Demo
// =============================
// Tooltips can be placed like floating views, because they're floating views.
// Tooltips are can also function as containers and can contain other content.

@[heap]
struct TooltipApp {
}

fn main() {
	mut window := gui.window(
		state:   &TooltipApp{}
		width:   500
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
	// app := window.state[TooltipApp]()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		h_align: .center
		content: [
			gui.text(text: 'Hover over buttons to see tooltips'),
			gui.button(
				tooltip: gui.TooltipCfg{
					text: 'Lorem ipsum dolor sit amet'
				}
				content: [gui.text(text: 'default position')]
			),
		]
	)
}
