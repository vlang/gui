import gui
import time

@[heap]
struct FormValidationApp {
mut:
	username   string
	email      string
	age_text   string
	age_value  ?f64
	submit_msg string
}

const signup_form_id = 'signup_form'

fn main() {
	mut window := gui.window(
		title:   'Form Validation'
		state:   &FormValidationApp{}
		width:   560
		height:  600
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
			w.set_id_focus(1)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	app := window.state[FormValidationApp]()
	summary := window.form_summary(signup_form_id)
	username_state := window.form_field_state(signup_form_id, 'username') or {
		gui.FormFieldState{}
	}
	email_state := window.form_field_state(signup_form_id, 'email') or { gui.FormFieldState{} }
	age_state := window.form_field_state(signup_form_id, 'age') or { gui.FormFieldState{} }

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		padding: gui.padding_medium
		spacing: gui.spacing_medium
		content: [
			gui.text(text: 'Form Validation Demo', text_style: gui.theme().b2),
			gui.text(text: 'Sync + async validators, touched/dirty state, error slots'),
			gui.form(
				id:                        signup_form_id
				validate_on:               .blur_submit
				block_submit_when_invalid: true
				block_submit_when_pending: true
				error_slot:                form_error_slot
				summary_slot:              form_summary_slot
				pending_slot:              form_pending_slot
				on_submit:                 on_form_submit
				on_reset:                  on_form_reset
				content:                   [
					field_row('Username', gui.input(
						id:                    'username_input'
						id_focus:              1
						width:                 280
						sizing:                gui.fixed_fit
						placeholder:           'Pick a username'
						text:                  app.username
						field_id:              'username'
						form_sync_validators:  [
							gui.FormSyncValidator(username_required_validator),
							gui.FormSyncValidator(username_length_validator),
						]
						form_async_validators: [
							gui.FormAsyncValidator(username_unique_validator),
						]
						on_text_changed:       fn (_ &gui.Layout, text string, mut w gui.Window) {
							w.state[FormValidationApp]().username = text
						}
					)),
					state_row('Username', username_state),
					field_row('Email', gui.input(
						id:                   'email_input'
						id_focus:             2
						width:                280
						sizing:               gui.fixed_fit
						placeholder:          'you@example.com'
						text:                 app.email
						field_id:             'email'
						form_sync_validators: [
							gui.FormSyncValidator(email_required_validator),
							gui.FormSyncValidator(email_format_validator),
						]
						on_text_changed:      fn (_ &gui.Layout, text string, mut w gui.Window) {
							w.state[FormValidationApp]().email = text
						}
					)),
					state_row('Email', email_state),
					field_row('Age', gui.numeric_input(
						id:                   'age_input'
						id_focus:             3
						width:                160
						sizing:               gui.fixed_fit
						decimals:             0
						min:                  0.0
						max:                  130.0
						text:                 app.age_text
						value:                app.age_value
						field_id:             'age'
						form_sync_validators: [
							gui.FormSyncValidator(age_required_validator),
						]
						on_text_changed:      fn (_ &gui.Layout, text string, mut w gui.Window) {
							w.state[FormValidationApp]().age_text = text
						}
						on_value_commit:      fn (_ &gui.Layout, value ?f64, text string, mut w gui.Window) {
							mut app := w.state[FormValidationApp]()
							app.age_value = value
							app.age_text = text
						}
					)),
					state_row('Age', age_state),
				]
			),
			gui.row(
				spacing: gui.spacing_small
				content: [
					gui.button(
						content:  [
							gui.text(text: 'Submit'),
						]
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							w.form_submit(signup_form_id)
						}
					),
					gui.button(
						content:  [
							gui.text(text: 'Reset'),
						]
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							w.form_reset(signup_form_id)
						}
					),
				]
			),
			gui.text(
				text: 'Summary -> valid:${summary.valid} pending:${summary.pending} invalid:${summary.invalid_count}'
			),
			gui.text(text: app.submit_msg),
		]
	)
}

fn field_row(label string, field gui.View) gui.View {
	return gui.row(
		spacing: gui.spacing_small
		v_align: .middle
		content: [
			gui.text(text: label, min_width: 110),
			field,
		]
	)
}

fn state_row(label string, state gui.FormFieldState) gui.View {
	return gui.text(
		text: '${label} -> touched:${state.touched} dirty:${state.dirty} pending:${state.pending}'
	)
}

fn issue_text(issues []gui.FormIssue) string {
	if issues.len == 0 {
		return ''
	}
	mut parts := []string{cap: issues.len}
	for issue in issues {
		parts << issue.msg
	}
	return parts.join(', ')
}

fn form_error_slot(field_id string, issues []gui.FormIssue) gui.View {
	if issues.len == 0 {
		return gui.text(text: '')
	}
	return gui.text(
		text:       '${field_id}: ${issue_text(issues)}'
		text_style: gui.TextStyle{
			...gui.theme().text_style
			color: gui.rgb(219, 87, 87)
		}
	)
}

fn form_summary_slot(summary gui.FormSummaryState) gui.View {
	if summary.invalid_count == 0 && !summary.pending {
		return gui.text(text: 'No validation errors')
	}
	return gui.text(
		text: 'Validation summary: invalid=${summary.invalid_count}, pending=${summary.pending_count}'
	)
}

fn form_pending_slot(pending gui.FormPendingState) gui.View {
	if pending.pending_count == 0 {
		return gui.text(text: '')
	}
	return gui.text(text: 'Validating fields: ${pending.field_ids.join(', ')}')
}

fn on_form_submit(ev gui.FormSubmitEvent, mut w gui.Window) {
	mut app := w.state[FormValidationApp]()
	app.submit_msg = 'Submitted username=${ev.values['username'] or { '' }}, email=${ev.values['email'] or {
		''
	}}'
}

fn on_form_reset(_ gui.FormResetEvent, mut w gui.Window) {
	mut app := w.state[FormValidationApp]()
	app.username = ''
	app.email = ''
	app.age_text = ''
	app.age_value = none
	app.submit_msg = 'Form reset'
}

fn username_required_validator(field gui.FormFieldSnapshot, _ gui.FormSnapshot) []gui.FormIssue {
	if field.value.trim_space().len == 0 {
		return [gui.FormIssue{
			code: 'required'
			msg:  'username required'
		}]
	}
	return []gui.FormIssue{}
}

fn username_length_validator(field gui.FormFieldSnapshot, _ gui.FormSnapshot) []gui.FormIssue {
	value := field.value.trim_space()
	if value.len > 0 && value.len < 3 {
		return [gui.FormIssue{
			code: 'min_len'
			msg:  'username min length is 3'
		}]
	}
	return []gui.FormIssue{}
}

fn username_unique_validator(field gui.FormFieldSnapshot, _ gui.FormSnapshot, signal &gui.GridAbortSignal) ![]gui.FormIssue {
	for _ in 0 .. 4 {
		if signal.is_aborted() {
			return []gui.FormIssue{}
		}
		time.sleep(75 * time.millisecond)
	}
	name := field.value.trim_space().to_lower()
	if name in ['admin', 'root', 'system'] {
		return [gui.FormIssue{
			code: 'taken'
			msg:  'username already taken'
		}]
	}
	return []gui.FormIssue{}
}

fn email_required_validator(field gui.FormFieldSnapshot, _ gui.FormSnapshot) []gui.FormIssue {
	if field.value.trim_space().len == 0 {
		return [gui.FormIssue{
			code: 'required'
			msg:  'email required'
		}]
	}
	return []gui.FormIssue{}
}

fn email_format_validator(field gui.FormFieldSnapshot, _ gui.FormSnapshot) []gui.FormIssue {
	email := field.value.trim_space()
	if email.len > 0 && !email.contains('@') {
		return [gui.FormIssue{
			code: 'format'
			msg:  'email must contain @'
		}]
	}
	return []gui.FormIssue{}
}

fn age_required_validator(field gui.FormFieldSnapshot, _ gui.FormSnapshot) []gui.FormIssue {
	if field.value.trim_space().len == 0 {
		return [gui.FormIssue{
			code: 'required'
			msg:  'age required'
		}]
	}
	return []gui.FormIssue{}
}
