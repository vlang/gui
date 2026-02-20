module gui

// DialogType configures the type of dialog.
//
// - **message** has a title, body and OK button
// - **confirm** is similar to message but with yes, no buttons
// - **prompt** adds an input field with OK, Cancel buttons
// - **custom** displays the given content.
//
// Future types (TODO):
// - **browse** browser file dialog
// - **save** save file dialog
// - **color** color dialog
// - **date** select date dialog
// - **time** select time dialog
pub enum DialogType as u8 {
	message
	confirm
	prompt
	custom
}

pub const dialog_base_id_focus = 7568971
const reserved_dialog_id = '__dialog_reserved_do_not_use__'

// DialogCfg configures GUI's dialog dialog. [DialogType](#DialogType)
// determines the type of dialog. dialogType.message is the default.
// dialogs are asynchronous. Keyboard/Mouse input is restricted
// to the dialog dialog when visible. **Dialogs do not support floating
// elements**. Invoke dialogs by calling [(Window) dialog](#Window.dialog)
@[minify]
pub struct DialogCfg {
	A11yCfg
mut:
	visible      bool
	old_id_focus u32
pub:
	title        string
	body         string // body text wraps as needed. Newlines supported
	reply        string
	id           string
	color        Color   = gui_theme.dialog_style.color
	color_border Color   = gui_theme.dialog_style.color_border
	padding      Padding = gui_theme.dialog_style.padding
	size_border  f32     = gui_theme.dialog_style.size_border

	title_text_style TextStyle = gui_theme.dialog_style.title_text_style
	text_style       TextStyle = gui_theme.dialog_style.text_style
	custom_content   []View // custom content
	on_ok_yes        fn (mut w Window)       = fn (mut _ Window) {}
	on_cancel_no     fn (mut w Window)       = fn (mut _ Window) {}
	on_reply         fn (string, mut Window) = fn (_ string, mut _ Window) {}
	width            f32
	height           f32
	min_width        f32 = 200
	min_height       f32
	max_width        f32 = 300
	max_height       f32
	radius           f32 = gui_theme.dialog_style.radius
	radius_border    f32 = gui_theme.dialog_style.radius_border
	id_focus         u32 = dialog_base_id_focus
	dialog_type      DialogType
	align_buttons    HorizontalAlign = gui_theme.dialog_style.align_buttons
}

fn dialog_view_generator(cfg DialogCfg) View {
	mut content := []View{cap: 5}
	if cfg.dialog_type != .custom {
		if cfg.title.len > 0 {
			content << text(text: cfg.title, text_style: cfg.title_text_style)
		}
		if cfg.body.len > 0 {
			content << text(text: cfg.body, text_style: cfg.text_style, mode: .multiline)
		}
	}
	content << match cfg.dialog_type {
		.message { message_view(cfg) }
		.confirm { confirm_view(cfg) }
		.prompt { prompt_view(cfg) }
		.custom { cfg.custom_content }
	}
	return column(
		name:             'dialog: ${cfg.dialog_type}'
		id:               reserved_dialog_id
		a11y_role:        .dialog
		a11y_state:       .modal
		a11y_label:       a11y_label(cfg.a11y_label, cfg.title)
		a11y_description: cfg.a11y_description
		float:            true
		float_anchor:     .middle_center
		float_tie_off:    .middle_center
		color:            cfg.color
		color_border:     cfg.color_border
		size_border:      cfg.size_border
		radius:           cfg.radius
		padding:          cfg.padding
		h_align:          .center

		width:      cfg.width
		height:     cfg.height
		min_width:  cfg.min_width
		max_width:  cfg.max_width
		min_height: cfg.min_height
		max_height: cfg.max_height
		on_keydown: dialog_key_down
		content:    content
	)
}

fn message_view(cfg DialogCfg) []View {
	return [
		row(
			name:    'message view'
			sizing:  fill_fit
			h_align: cfg.align_buttons
			padding: padding_none
			content: [
				button(
					id_focus: cfg.id_focus
					content:  [
						text(text: gui_locale.str_ok, text_style: cfg.text_style),
					]
					on_click: fn (_ &Layout, mut e Event, mut w Window) {
						w.set_id_focus(w.dialog_cfg.old_id_focus)
						on_ok_yes := w.dialog_cfg.on_ok_yes
						w.dialog_dismiss()
						on_ok_yes(mut w)
						e.is_handled = true
					}
				),
			]
		),
	]
}

fn confirm_view(cfg DialogCfg) []View {
	return [
		row(
			name:    'confirm view'
			sizing:  fill_fit
			h_align: cfg.align_buttons
			padding: padding_none
			content: [
				button(
					id_focus: cfg.id_focus + 1
					content:  [
						text(text: gui_locale.str_yes, text_style: cfg.text_style),
					]
					on_click: fn (_ &Layout, mut e Event, mut w Window) {
						w.set_id_focus(w.dialog_cfg.old_id_focus)
						on_ok_yes := w.dialog_cfg.on_ok_yes
						w.dialog_dismiss()
						on_ok_yes(mut w)
						e.is_handled = true
					}
				),
				button(
					id_focus: cfg.id_focus
					content:  [
						text(text: gui_locale.str_no, text_style: cfg.text_style),
					]
					on_click: fn (_ &Layout, mut e Event, mut w Window) {
						w.set_id_focus(w.dialog_cfg.old_id_focus)
						on_cancel_no := w.dialog_cfg.on_cancel_no
						w.dialog_dismiss()
						on_cancel_no(mut w)
						e.is_handled = true
					}
				),
			]
		),
	]
}

fn prompt_view(cfg DialogCfg) []View {
	return [
		input(
			id_focus:        cfg.id_focus
			text:            cfg.reply
			text_style:      cfg.text_style
			sizing:          fill_fit
			on_text_changed: fn (_ &Layout, s string, mut w Window) {
				w.dialog_cfg = DialogCfg{
					...w.dialog_cfg
					reply: s
				}
			}
			on_enter:        fn (_ &Layout, mut e Event, mut w Window) {
				w.set_id_focus(w.dialog_cfg.old_id_focus)
				on_reply := w.dialog_cfg.on_reply
				reply := w.dialog_cfg.reply
				w.dialog_dismiss()
				on_reply(reply, mut w)
				e.is_handled = true
			}
		),
		row(
			name:    'prompt view'
			sizing:  fill_fit
			h_align: cfg.align_buttons
			padding: padding_none
			content: [
				button(
					id_focus: cfg.id_focus + 1
					disabled: cfg.reply.len == 0
					content:  [
						text(text: gui_locale.str_ok, text_style: cfg.text_style),
					]
					on_click: fn (_ &Layout, mut e Event, mut w Window) {
						w.set_id_focus(w.dialog_cfg.old_id_focus)
						on_reply := w.dialog_cfg.on_reply
						reply := w.dialog_cfg.reply
						w.dialog_dismiss()
						on_reply(reply, mut w)
						e.is_handled = true
					}
				),
				button(
					id_focus: cfg.id_focus + 2
					content:  [
						text(text: gui_locale.str_cancel, text_style: cfg.text_style),
					]
					on_click: fn (_ &Layout, mut e Event, mut w Window) {
						w.set_id_focus(w.dialog_cfg.old_id_focus)
						on_cancel_no := w.dialog_cfg.on_cancel_no
						w.dialog_dismiss()
						on_cancel_no(mut w)
						e.is_handled = true
					}
				),
			]
		),
	]
}

fn dialog_key_down(_ voidptr, mut e Event, mut w Window) {
	if e.key_code == .escape {
		on_cancel_no := w.dialog_cfg.on_cancel_no
		w.dialog_dismiss()
		on_cancel_no(mut w)
		e.is_handled = true
		return
	}
	if e.key_code == KeyCode.c && e.modifiers.has_any(.ctrl, .super) {
		mut cpy := w.dialog_cfg.title
		if cpy.len > 0 && w.dialog_cfg.body.len > 0 {
			cpy += '\n' + w.dialog_cfg.body
		}
		to_clipboard(cpy)
		e.is_handled = true
	}
}

// layout_in_dialog_layout is used in views like button watch mouse_moves
// It tests if the given node is a child of the dialog layout.
fn layout_in_dialog_layout(layout &Layout) bool {
	mut in_dialog := false
	mut parent := layout.parent
	for {
		if parent == unsafe { nil } {
			break
		}
		if parent.shape.id == reserved_dialog_id {
			in_dialog = true
			break
		}
		parent = parent.parent
	}
	return in_dialog
}
