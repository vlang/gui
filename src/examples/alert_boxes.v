import gui

// Alert Boxes
// =============================
// Demonstrates how to invoke two different styles of alert boxes.
// As an aside, it shows how easy it is to make a theme.

fn main() {
	mut window := gui.window(
		width:   500
		height:  300
		on_init: fn (mut w gui.Window) {
			// Call update_view() any where in your
			// business logic to change views.
			w.update_view(main_view)
		}
	)
	// Add some borders to views that support them
	theme := gui.theme_maker(gui.ThemeCfg{
		...gui.theme_dark_cfg
		padding_border: gui.padding_two
	})
	window.set_theme(theme)
	window.run()
}

// The view generator set in update_view() is called on
// every user event (mouse move, click, resize, etc.).
fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		h_align: .center
		v_align: .middle
		content: [
			gui.text(
				text:       'Click Button for Message'
				text_style: gui.theme().m2
			),
			gui.button(
				id_focus: 1
				content:  [gui.text(text: 'Click Me')]
				on_click: fn (_ &gui.ButtonCfg, mut _ gui.Event, mut w gui.Window) {
					w.alert(
						alert_type:   .confirm
						title:        'Title Here'
						body:         '
Content goes here...

Multi-line and text wrapping supported.
See MsgBoxCfg for other parameters'
						on_ok_yes:    fn (mut w gui.Window) {
							w.alert(title: 'Clicked Yes')
						}
						on_cancel_no: fn (mut w gui.Window) {
							w.alert(title: 'Clicked No')
						}
					)
				}
			),
		]
	)
}
