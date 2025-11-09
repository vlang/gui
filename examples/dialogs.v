import gui

// Dialogs
// =============================
// Demonstrates how to invoke two different styles of dialog boxes.
// As an aside, it shows how easy it is to make a theme.
//
@[heap]
struct DialogsApp {
pub mut:
	light_theme bool
}

fn main() {
	mut window := gui.window(
		state:        &DialogsApp{}
		width:        500
		height:       300
		cursor_blink: true
		on_init:      fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	app := window.state[DialogsApp]()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		h_align: .center
		content: [
			toggle_theme(app),
			gui.column(
				color:   gui.theme().color_active
				padding: gui.theme().padding_large
				content: [
					message_type(),
					confirm_type(),
					prompt_type(),
					custom_type(),
				]
			),
		]
	)
}

fn message_type() gui.View {
	return gui.button(
		id_focus: 1
		sizing:   gui.fill_fit
		content:  [gui.text(text: '.dialog_type == .message')]
		on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
			w.dialog(
				align_buttons: .end
				dialog_type:   .message
				title:         'Title Displays Here'
				body:          '
body text displayes here...

Multi-line text supported.
See DialogCfg for other parameters

Buttons can be left/center/right aligned'.trim_indent()
			)
		}
	)
}

fn confirm_type() gui.View {
	return gui.button(
		id_focus: 2
		sizing:   gui.fill_fit
		content:  [gui.text(text: '.dialog_type == .confirm')]
		on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
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
		on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
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
		on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
			w.dialog(
				dialog_type:    .custom
				custom_content: [
					gui.column(
						h_align: .center
						v_align: .middle
						content: [
							gui.text(text: 'Custom Content'),
							gui.button(
								id_focus: gui.dialog_base_id_focus
								content:  [gui.text(text: 'Close Me')]
								on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
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

fn toggle_theme(app &DialogsApp) gui.View {
	return gui.row(
		h_align: .end
		sizing:  gui.fill_fit
		padding: gui.padding_none
		content: [
			gui.toggle(
				text_select:   gui.icon_moon
				text_unselect: gui.icon_sunny_o
				text_style:    gui.theme().icon3
				padding:       gui.padding_small
				select:        app.light_theme
				on_click:      fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
					mut app := w.state[DialogsApp]()
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
