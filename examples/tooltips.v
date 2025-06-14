import gui

// Tooltip Demo
// =============================
// Tooltips can be placed like floating views, because they're floating views.
// Id's are only need if tooltips have the same text.

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
			gui.column(
				h_align: .center
				content: [
					gui.text(text: 'Hover over buttons to see tooltips'),
					gui.button(
						sizing:  gui.fill_fit
						tooltip: gui.TooltipCfg{
							id:   '1'
							text: 'Lorem ipsum dolor sit amet'
						}
						content: [gui.text(text: 'default position')]
					),
					gui.button(
						sizing:  gui.fill_fit
						tooltip: gui.TooltipCfg{
							id:      '2'
							text:    'Lorem ipsum dolor sit amet'
							anchor:  .top_center
							tie_off: .bottom_left
						}
						content: [gui.text(text: 'top right')]
					),
					gui.button(
						sizing:  gui.fill_fit
						tooltip: gui.TooltipCfg{
							id:      '3'
							text:    'Lorem ipsum dolor sit amet'
							anchor:  .top_left
							tie_off: .bottom_center
						}
						content: [gui.text(text: 'top left')]
					),
					gui.button(
						sizing:  gui.fill_fit
						tooltip: gui.TooltipCfg{
							id:      '4'
							text:    'Lorem ipsum dolor sit amet'
							anchor:  .bottom_left
							tie_off: .top_center
						}
						content: [gui.text(text: 'bottom left')]
					),
				]
			),
		]
	)
}
