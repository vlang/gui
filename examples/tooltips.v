import gui

// Tooltip Demo
// =============================
// Tooltips can be placed like floating views, because they're floating views.
// Id's are only need if tooltips have the same content.

@[heap]
struct TooltipApp {
mut:
	light_theme bool
}

fn main() {
	mut window := gui.window(
		title:   'Tooltip Demo'
		state:   &TooltipApp{}
		width:   500
		height:  500
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(window &gui.Window) &gui.View {
	w, h := window.window_size()
	app := window.state[TooltipApp]()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		h_align: .center
		content: [
			gui.column(
				h_align: .center
				content: [
					toggle_theme(app),
					gui.text(text: 'Hover over buttons to see tooltips'),
					gui.button(
						sizing:  gui.fill_fit
						tooltip: gui.TooltipCfg{
							content: [gui.text(text: 'Lorem ipsum dolor sit amet')]
						}
						content: [gui.text(text: 'default position')]
					),
					gui.button(
						sizing:  gui.fill_fit
						tooltip: gui.TooltipCfg{
							content: [gui.text(text: 'Lorem ipsum dolor sit amet')]
							anchor:  .top_center
							tie_off: .bottom_left
						}
						content: [gui.text(text: 'top right')]
					),
					gui.button(
						sizing:  gui.fill_fit
						tooltip: gui.TooltipCfg{
							content: [gui.text(text: 'Lorem ipsum dolor sit amet')]
							anchor:  .top_left
							tie_off: .bottom_center
						}
						content: [gui.text(text: 'top left')]
					),
					gui.button(
						sizing:  gui.fill_fit
						tooltip: gui.TooltipCfg{
							content: [gui.text(text: 'Lorem ipsum dolor sit amet')]
							anchor:  .bottom_left
							tie_off: .top_center
						}
						content: [gui.text(text: 'bottom left')]
					),
					gui.button(
						sizing:  gui.fill_fit
						tooltip: gui.TooltipCfg{
							content: [
								gui.column(
									padding: gui.padding_none
									content: [
										gui.text(text: 'Brazil', text_style: gui.theme().b3),
										gui.text(
											text: 'A country in South America\n' +
												'with rain forests and rivers.'
											mode: .multiline
										),
									]
								),
							]
						}
						content: [
							gui.text(text: 'complex content'),
						]
					),
				]
			),
		]
	)
}

fn toggle_theme(app &TooltipApp) &gui.View {
	return gui.row(
		h_align: .end
		sizing:  gui.fill_fit
		padding: gui.padding_none
		content: [
			gui.toggle(
				text_select:   gui.icon_moon
				text_unselect: gui.icon_sunny_o
				text_style:    gui.theme().icon3
				select:        app.light_theme
				padding:       gui.padding_small
				on_click:      fn (_ &gui.ToggleCfg, mut _ gui.Event, mut w gui.Window) {
					mut app := w.state[TooltipApp]()
					app.light_theme = !app.light_theme
					theme := if app.light_theme {
						gui.theme_light_bordered
					} else {
						gui.theme_dark_bordered
					}
					w.set_theme(theme)
				}
			),
		]
	)
}
