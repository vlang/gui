import gui

// Dialogs
// =============================
// Demonstrates custom dialogs and native file dialogs.
@[heap]
struct DialogsApp {
pub mut:
	light_theme bool
}

fn main() {
	mut window := gui.window(
		state:        &DialogsApp{}
		width:        640
		height:       420
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
				color_border: gui.theme().color_active
				padding:      gui.theme().padding_large
				content:      [
					message_type(),
					confirm_type(),
					prompt_type(),
					custom_type(),
					native_open_type(),
					native_save_type(),
					native_folder_type(),
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

fn native_open_type() gui.View {
	return gui.button(
		id_focus: 5
		sizing:   gui.fill_fit
		content:  [gui.text(text: 'native_open_dialog()')]
		on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
			w.native_open_dialog(
				title:          'Open Files'
				allow_multiple: true
				filters:        [
					gui.NativeFileFilter{
						name:       'Images'
						extensions: ['png', 'jpg', 'jpeg']
					},
					gui.NativeFileFilter{
						name:       'Docs'
						extensions: ['txt', 'md']
					},
				]
				on_done:        fn (result gui.NativeDialogResult, mut w gui.Window) {
					show_native_result('native_open_dialog()', result, mut w)
				}
			)
		}
	)
}

fn native_save_type() gui.View {
	return gui.button(
		id_focus: 6
		sizing:   gui.fill_fit
		content:  [gui.text(text: 'native_save_dialog()')]
		on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
			w.native_save_dialog(
				title:             'Save As'
				default_name:      'untitled'
				default_extension: 'txt'
				filters:           [
					gui.NativeFileFilter{
						name:       'Text'
						extensions: ['txt']
					},
				]
				on_done:           fn (result gui.NativeDialogResult, mut w gui.Window) {
					show_native_result('native_save_dialog()', result, mut w)
				}
			)
		}
	)
}

fn native_folder_type() gui.View {
	return gui.button(
		id_focus: 7
		sizing:   gui.fill_fit
		content:  [gui.text(text: 'native_folder_dialog()')]
		on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
			w.native_folder_dialog(
				title:                  'Choose Folder'
				can_create_directories: true
				on_done:                fn (result gui.NativeDialogResult, mut w gui.Window) {
					show_native_result('native_folder_dialog()', result, mut w)
				}
			)
		}
	)
}

fn show_native_result(kind string, result gui.NativeDialogResult, mut w gui.Window) {
	body := match result.status {
		.ok {
			if result.paths.len == 0 {
				'No paths returned.'
			} else {
				result.paths.join('\n')
			}
		}
		.cancel {
			'Canceled.'
		}
		.error {
			if result.error_code.len > 0 && result.error_message.len > 0 {
				'${result.error_code}: ${result.error_message}'
			} else if result.error_message.len > 0 {
				result.error_message
			} else {
				'Unknown error.'
			}
		}
	}
	w.dialog(title: kind, body: body)
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
