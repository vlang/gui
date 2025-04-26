module gui

// DialogType configures the type of dialog dialog.
//
// - **message** has a title, body and OK button
// - **confirm** is similar to dialog but with yes, no buttons
// - **prompt** adds an input field with OK, Cancel buttons
// - **custom** displays the given content. The given content
// is simply displayed. Custom content provides any needed
// callbacks as the standard ones work only for
// the predfined types. See [DialogCfg](#DialogCfg)
pub enum DialogType {
	message
	confirm
	prompt
	custom
}

const reserved_dialog_id = '__dialog_reserved_do_not_use__'

// DialogCfg configures GUI's dialog dialog. [dialogType](#dialogType)
// determines the type of dialog. dialogType.message is the default.
// dialogs are asychronous. Keyboard/Mouse input is restricted
// to the dialog dialog when visible. **Dialogs do not support floating
// elements**. Invoke dialogs by calling [(Window) dialog](#Window.dialog)
pub struct DialogCfg {
mut:
	visible      bool
	old_id_focus u32
pub:
	dialog_type      DialogType
	id               string
	width            f32
	height           f32
	min_width        f32 = 200
	min_height       f32
	max_width        f32 = 300
	max_height       f32
	title            string
	body             string // body text wraps as needed. Newlines supported
	custom_content   []View // custom content
	reply            string
	id_focus         u32                     = 7568971
	align_buttons    HorizontalAlign         = gui_theme.dialog_style.align_buttons
	color            Color                   = gui_theme.dialog_style.color
	color_border     Color                   = gui_theme.dialog_style.color_border
	fill             bool                    = gui_theme.dialog_style.fill
	fill_border      bool                    = gui_theme.dialog_style.fill_border
	padding          Padding                 = gui_theme.dialog_style.padding
	padding_border   Padding                 = gui_theme.dialog_style.padding_border
	radius           f32                     = gui_theme.dialog_style.radius
	radius_border    f32                     = gui_theme.dialog_style.radius_border
	title_text_style TextStyle               = gui_theme.dialog_style.title_text_style
	text_style       TextStyle               = gui_theme.dialog_style.text_style
	on_ok_yes        fn (mut w Window)       = fn (mut _ Window) {}
	on_cancel_no     fn (mut w Window)       = fn (mut _ Window) {}
	on_reply         fn (string, mut Window) = fn (_ string, mut _ Window) {}
}

fn dialog_view_generator(cfg DialogCfg) View {
	mut content := []View{}
	if cfg.dialog_type != .custom {
		if cfg.title.len > 0 {
			content << text(text: cfg.title, text_style: cfg.title_text_style)
		}
		if cfg.body.len > 0 {
			content << text(text: cfg.body, text_style: cfg.text_style, wrap: true)
		}
	}
	content << match cfg.dialog_type {
		.message { message_view(cfg) }
		.confirm { confirm_view(cfg) }
		.prompt { prompt_view(cfg) }
		.custom { cfg.custom_content }
	}
	return column(
		id:            reserved_dialog_id
		float:         true
		float_anchor:  .middle_center
		float_tie_off: .middle_center
		color:         cfg.color_border
		fill:          cfg.fill_border
		padding:       cfg.padding_border
		width:         cfg.width
		height:        cfg.height
		min_width:     cfg.min_width
		max_width:     cfg.max_width
		min_height:    cfg.min_height
		max_height:    cfg.max_height
		on_keydown:    dialog_key_down
		content:       [
			column(
				h_align: .center
				sizing:  fill_fill
				padding: cfg.padding
				fill:    cfg.fill
				color:   cfg.color
				content: content
			),
		]
	)
}

fn message_view(cfg DialogCfg) []View {
	return [
		row(
			sizing:  fill_fit
			h_align: cfg.align_buttons
			content: [
				button(
					id_focus: cfg.id_focus
					content:  [text(text: 'OK', text_style: cfg.text_style)]
					on_click: fn (_ &ButtonCfg, mut e Event, mut w Window) {
						w.set_id_focus(w.dialog_cfg.old_id_focus)
						on_ok_yes := w.dialog_cfg.on_ok_yes
						w.dialog_cfg = DialogCfg{}
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
			sizing:  fill_fit
			h_align: cfg.align_buttons
			content: [
				button(
					id_focus: cfg.id_focus + 1
					content:  [text(text: 'Yes', text_style: cfg.text_style)]
					on_click: fn (_ &ButtonCfg, mut e Event, mut w Window) {
						w.set_id_focus(w.dialog_cfg.old_id_focus)
						on_ok_yes := w.dialog_cfg.on_ok_yes
						w.dialog_cfg = DialogCfg{}
						on_ok_yes(mut w)
						e.is_handled = true
					}
				),
				button(
					id_focus: cfg.id_focus
					content:  [text(text: 'No', text_style: cfg.text_style)]
					on_click: fn (_ &ButtonCfg, mut e Event, mut w Window) {
						w.set_id_focus(w.dialog_cfg.old_id_focus)
						on_cancel_no := w.dialog_cfg.on_cancel_no
						w.dialog_cfg = DialogCfg{}
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
			on_text_changed: fn (_ &InputCfg, s string, mut w Window) {
				w.dialog_cfg = DialogCfg{
					...w.dialog_cfg
					reply: s
				}
			}
		),
		row(
			sizing:  fill_fit
			h_align: cfg.align_buttons
			content: [
				button(
					id_focus: cfg.id_focus + 1
					disabled: cfg.reply.len == 0
					content:  [text(text: 'OK', text_style: cfg.text_style)]
					on_click: fn (_ &ButtonCfg, mut e Event, mut w Window) {
						w.set_id_focus(w.dialog_cfg.old_id_focus)
						on_reply := w.dialog_cfg.on_reply
						reply := w.dialog_cfg.reply
						w.dialog_cfg = DialogCfg{}
						on_reply(reply, mut w)
						e.is_handled = true
					}
				),
				button(
					id_focus: cfg.id_focus + 2
					content:  [text(text: 'Cancel', text_style: cfg.text_style)]
					on_click: fn (_ &ButtonCfg, mut e Event, mut w Window) {
						w.set_id_focus(w.dialog_cfg.old_id_focus)
						on_cancel_no := w.dialog_cfg.on_cancel_no
						w.dialog_cfg = DialogCfg{}
						on_cancel_no(mut w)
						e.is_handled = true
					}
				),
			]
		),
	]
}

fn dialog_key_down(_ voidptr, mut e Event, mut w Window) {
	if e.key_code == KeyCode.c && (e.modifiers == u32(Modifier.ctrl)
		|| e.modifiers == u32(Modifier.super)) {
		mut cpy := w.dialog_cfg.title
		if cpy.len > 0 && w.dialog_cfg.body.len > 0 {
			cpy += '\n' + w.dialog_cfg.body
		}
		println(cpy)
		to_clipboard(cpy)
		e.is_handled = true
	}
}

// point_in_dialog_layout is used in views like button watch mouse_moves
fn point_in_dialog_layout(node &Layout) bool {
	mut in_dialog := false
	mut parent := node.parent
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
