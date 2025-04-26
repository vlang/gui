import gui

// Dialogs
// =============================
// Demonstrates how to invoke two different styles of dialog boxes.
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
					dialog_type(),
					confirm_type(),
					prompt_type(),
					custom_type(),
				]
			),
		]
	)
}

fn dialog_type() gui.View {
	return gui.button(
		id_focus: 1
		sizing:   gui.fill_fit
		content:  [gui.text(text: '.dialog_type == .message')]
		on_click: fn (_ &gui.ButtonCfg, mut _ gui.Event, mut w gui.Window) {
			w.dialog(
				dialog_type: .message
				title:       'Title Displays Here'
				body:        '
body text displayes here...

Multi-line and text wrapping supported.
See DialogCfg for other parameters'
			)
		}
	)
}

fn confirm_type() gui.View {
	return gui.button(
		id_focus: 2
		sizing:   gui.fill_fit
		content:  [gui.text(text: '.dialog_type == .confirm')]
		on_click: fn (_ &gui.ButtonCfg, mut _ gui.Event, mut w gui.Window) {
			w.dialog(
				dialog_type:  .confirm
				title:        'Destory All Data?'
				body:         'Are you sure?'
				on_ok_yes:    fn (mut w gui.Window) {
					w.dialog(title: 'Clicked Yes')
				}
				on_cancel_no: fn (mut w gui.Window) {
					w.dialog(title: 'Clicked No')
				}
			)
		}
	)
}

fn prompt_type() gui.View {
	return gui.button(
		id_focus: 3
		sizing:   gui.fill_fit
		content:  [gui.text(text: '.dialog_type == .prompt')]
		on_click: fn (_ &gui.ButtonCfg, mut _ gui.Event, mut w gui.Window) {
			w.dialog(
				dialog_type:  .prompt
				title:        'Monty Python Quiz'
				body:         'What is your quest?'
				on_reply:     fn (reply string, mut w gui.Window) {
					w.dialog(title: 'Replied', body: reply)
				}
				on_cancel_no: fn (mut w gui.Window) {
					w.dialog(title: 'Canceled')
				}
			)
		}
	)
}

fn custom_type() gui.View {
	return gui.button(
		id_focus: 4
		sizing:   gui.fill_fit
		content:  [gui.text(text: '.dialog_type == .custom')]
		on_click: fn (_ &gui.ButtonCfg, mut _ gui.Event, mut w gui.Window) {
			w.dialog(
				dialog_type:    .custom
				custom_content: [
					gui.column(
						h_align: .center
						v_align: .middle
						content: [
							gui.text(text: 'Custom Content'),
							gui.button(
								content:  [gui.text(text: 'Close Me')]
								on_click: fn (_ &gui.ButtonCfg, mut _ gui.Event, mut w gui.Window) {
									w.dialog_dismiss()
								}
							),
						]
					),
				]
			)
		}
	)
}
