import gui
import time

// Toast Notifications
// =============================
// Demonstrates toast severities, action buttons, dismiss,
// stacking, and auto-dismiss behavior.

@[heap]
struct ToastApp {
}

fn main() {
	mut window := gui.window(
		state:   &ToastApp{}
		title:   'Toast Notifications'
		width:   500
		height:  400
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		h_align: .center
		v_align: .top
		spacing: gui.theme().spacing_medium
		content: [
			gui.text(text: 'Toast Notifications', text_style: gui.theme().b2),
			gui.row(
				color:       gui.color_transparent
				size_border: 0
				spacing:     gui.theme().spacing_medium
				content:     [
					gui.button(
						content:  [gui.text(text: 'Info')]
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							w.toast(gui.ToastCfg{
								title:    'Info'
								body:     'Informational message.'
								severity: .info
							})
						}
					),
					gui.button(
						content:  [gui.text(text: 'Success')]
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							w.toast(gui.ToastCfg{
								title:    'Saved'
								body:     'Document saved successfully.'
								severity: .success
							})
						}
					),
					gui.button(
						content:  [gui.text(text: 'Warning')]
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							w.toast(gui.ToastCfg{
								title:    'Warning'
								body:     'Disk space running low.'
								severity: .warning
							})
						}
					),
					gui.button(
						content:  [gui.text(text: 'Error')]
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							w.toast(gui.ToastCfg{
								title:    'Error'
								body:     'Connection failed. Retry?'
								severity: .error
								duration: 5 * time.second
							})
						}
					),
				]
			),
			gui.row(
				color:       gui.color_transparent
				size_border: 0
				spacing:     gui.theme().spacing_medium
				content:     [
					gui.button(
						content:  [gui.text(text: 'With Action')]
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							w.toast(gui.ToastCfg{
								title:        'Deleted'
								body:         'Item removed.'
								severity:     .info
								action_label: 'Undo'
								on_action:    fn (mut w gui.Window) {
									w.toast(gui.ToastCfg{
										title:    'Undone'
										body:     'Item restored.'
										severity: .success
									})
								}
							})
						}
					),
					gui.button(
						content:  [gui.text(text: 'No Title')]
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							w.toast(gui.ToastCfg{
								body:     'Body-only toast notification.'
								severity: .info
							})
						}
					),
					gui.button(
						content:  [gui.text(text: 'Dismiss All')]
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							w.toast_dismiss_all()
						}
					),
				]
			),
			gui.text(
				text:       'Hover a toast to pause auto-dismiss.'
				text_style: gui.TextStyle{
					...gui.theme().n4
					color: gui.theme().color_active
				}
			),
		]
	)
}
