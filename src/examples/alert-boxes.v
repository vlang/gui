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

fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		h_align: .center
		v_align: .middle
		content: [
			gui.column(
				content: [
					alert_type(),
					confirm_type(),
					prompt_type(),
				]
			),
		]
	)
}

fn alert_type() gui.View {
	return gui.button(
		id_focus: 1
		sizing:   gui.fill_fit
		content:  [gui.text(text: '.alert_type == .message')]
		on_click: fn (_ &gui.ButtonCfg, mut _ gui.Event, mut w gui.Window) {
			w.alert(
				alert_type: .message
				title:      'Title Displays Here'
				body:       '
body text displayes here...

Multi-line and text wrapping supported.
See AlertCfg for other parameters'
			)
		}
	)
}

fn confirm_type() gui.View {
	return gui.button(
		id_focus: 2
		sizing:   gui.fill_fit
		content:  [gui.text(text: '.alert_type == .confirm')]
		on_click: fn (_ &gui.ButtonCfg, mut _ gui.Event, mut w gui.Window) {
			w.alert(
				alert_type:   .confirm
				title:        'Destory All Data?'
				body:         'Are you sure?'
				on_ok_yes:    fn (mut w gui.Window) {
					w.alert(title: 'Clicked Yes')
				}
				on_cancel_no: fn (mut w gui.Window) {
					w.alert(title: 'Clicked No')
				}
			)
		}
	)
}

fn prompt_type() gui.View {
	return gui.button(
		id_focus: 3
		sizing:   gui.fill_fit
		content:  [gui.text(text: '.alert_type == .prompt')]
		on_click: fn (_ &gui.ButtonCfg, mut _ gui.Event, mut w gui.Window) {
			w.alert(
				alert_type:   .prompt
				title:        'Monty Python Quiz'
				body:         'What is your quest?'
				on_reply:     fn (reply string, mut w gui.Window) {
					w.alert(title: 'Replied', body: reply)
				}
				on_cancel_no: fn (mut w gui.Window) {
					w.alert(title: 'Canceled')
				}
			)
		}
	)
}
