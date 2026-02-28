import gui

// Native Notification
// =============================
// Sends an OS-level notification and shows the result.

@[heap]
struct NotifApp {
mut:
	status string = 'idle'
}

fn main() {
	mut window := gui.window(
		state:   &NotifApp{}
		title:   'Native Notification'
		width:   400
		height:  250
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	state := window.state[NotifApp]()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		spacing: gui.theme().spacing_medium
		padding: gui.theme().padding_medium
		content: [
			gui.text(
				text:       'Native Notification'
				text_style: gui.theme().b2
			),
			gui.text(
				text: 'Click the button to send an OS notification.'
			),
			gui.button(
				content:  [gui.text(text: 'Send Notification')]
				on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
					mut s := w.state[NotifApp]()
					s.status = 'sending...'
					w.update_window()
					w.native_notification(gui.NativeNotificationCfg{
						title:   'Hello from v-gui'
						body:    'Native notifications are working.'
						on_done: fn (r gui.NativeNotificationResult, mut w gui.Window) {
							mut s2 := w.state[NotifApp]()
							s2.status = match r.status {
								.ok { 'delivered' }
								.denied { 'denied: ${r.error_message}' }
								.error { 'error: ${r.error_message}' }
							}
							w.update_window()
						}
					})
				}
			),
			gui.text(text: 'Status: ${state.status}'),
		]
	)
}
