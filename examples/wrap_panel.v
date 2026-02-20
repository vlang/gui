import gui

// Wrap Panel
// =============================
// Demonstrates the wrap layout which arranges children
// left-to-right, flowing to the next line when the
// container width is exceeded.
//
// Resize the window to see items reflow.

@[heap]
struct WrapApp {
pub mut:
	check_a  bool
	check_b  bool
	switch_a bool
	switch_b bool
	radio    int
}

fn main() {
	mut window := gui.window(
		title:   'Wrap Panel'
		state:   &WrapApp{}
		width:   520
		height:  400
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(mut window gui.Window) gui.View {
	w, h := window.window_size()
	app := window.state[WrapApp]()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		padding: gui.padding(20, 20, 20, 20)
		spacing: 16
		content: [
			gui.text(text: 'Wrap Panel — Mixed Widgets', text_style: gui.theme().b1),
			gui.text(text: 'Resize the window to see items reflow.'),
			gui.wrap(
				width:   w - 40
				sizing:  gui.fixed_fit
				spacing: 8
				content: [
					tag('Checks'),
					gui.checkbox(
						label:    'Alpha'
						select:   app.check_a
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							mut a := w.state[WrapApp]()
							a.check_a = !a.check_a
						}
					),
					gui.checkbox(
						label:    'Beta'
						select:   app.check_b
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							mut a := w.state[WrapApp]()
							a.check_b = !a.check_b
						}
					),
					tag('Switches'),
					gui.switch(
						label:    'Dark mode'
						select:   app.switch_a
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							mut a := w.state[WrapApp]()
							a.switch_a = !a.switch_a
						}
					),
					gui.switch(
						label:    'Auto-save'
						select:   app.switch_b
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							mut a := w.state[WrapApp]()
							a.switch_b = !a.switch_b
						}
					),
					tag('Size'),
					gui.radio(
						label:    'Small'
						select:   app.radio == 0
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							mut a := w.state[WrapApp]()
							a.radio = 0
						}
					),
					gui.radio(
						label:    'Medium'
						select:   app.radio == 1
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							mut a := w.state[WrapApp]()
							a.radio = 1
						}
					),
					gui.radio(
						label:    'Large'
						select:   app.radio == 2
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							mut a := w.state[WrapApp]()
							a.radio = 2
						}
					),
					gui.progress_bar(
						width:   120
						sizing:  gui.fixed_fit
						percent: 0.65
					),
					gui.button(
						content:  [gui.text(text: 'Reset')]
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							mut a := w.state[WrapApp]()
							a.check_a = false
							a.check_b = false
							a.switch_a = false
							a.switch_b = false
							a.radio = 0
						}
					),
				]
			),
		]
	)
}

fn tag(label string) gui.View {
	return gui.row(
		padding: gui.padding(4, 12, 4, 12)
		radius:  12
		color:   gui.theme().color_active
		content: [gui.text(text: label)]
	)
}
