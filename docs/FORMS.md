# Forms

`form` adds form-level validation runtime for field widgets.

Current adapters:
- `input`
- `numeric_input`

## Features

- Sync validators
- Async validators with stale-result drop and abort signaling
- Field state: `touched`, `dirty`, `pending`, `errors`
- Form summary: valid/pending/invalid counts
- Slots: `error_slot`, `summary_slot`, `pending_slot`
- Submit/reset APIs: `window.form_submit(id)`, `window.form_reset(id)`

## Quick Example

```v ignore
import gui
import time

@[heap]
struct App {
mut:
	username string
}

fn main() {
	mut window := gui.window(
		state: &App{}
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.run()
}

fn main_view(window &gui.Window) gui.View {
	app := window.state[App]()
	return gui.form(
		id:          'signup'
		validate_on: .blur_submit
		content:     [
			gui.input(
				id_focus:              1
				field_id:              'username'
				text:                  app.username
				form_sync_validators:  [gui.FormSyncValidator(required_username)]
				form_async_validators: [gui.FormAsyncValidator(unique_username)]
				on_text_changed:       fn (_ &gui.Layout, text string, mut w gui.Window) {
					w.state[App]().username = text
				}
			),
		]
		error_slot: fn (field_id string, issues []gui.FormIssue) gui.View {
			if issues.len == 0 {
				return gui.text(text: '')
			}
			return gui.text(text: '${field_id}: ${issues[0].msg}')
		}
	)
}

fn required_username(field gui.FormFieldSnapshot, _ gui.FormSnapshot) []gui.FormIssue {
	if field.value.trim_space().len == 0 {
		return [gui.FormIssue{code: 'required', msg: 'username required'}]
	}
	return []gui.FormIssue{}
}

fn unique_username(field gui.FormFieldSnapshot, _ gui.FormSnapshot,
	signal &gui.GridAbortSignal) ![]gui.FormIssue {
	for _ in 0 .. 4 {
		if signal.is_aborted() {
			return []gui.FormIssue{}
		}
		time.sleep(75 * time.millisecond)
	}
	if field.value.to_lower() in ['admin', 'root'] {
		return [gui.FormIssue{code: 'taken', msg: 'username taken'}]
	}
	return []gui.FormIssue{}
}
```

## API

### `gui.form(cfg FormCfg) View`

Key `FormCfg` fields:
- `id string`: required for persistent runtime identity.
- `content []View`: field widgets and custom views.
- `validate_on FormValidateOn`: default validation trigger.
- `submit_on_enter bool`: submit request on Enter from adapted input fields.
- `block_submit_when_invalid bool`
- `block_submit_when_pending bool`
- `on_submit fn (FormSubmitEvent, mut Window)`
- `on_reset fn (FormResetEvent, mut Window)`
- `error_slot fn (string, []FormIssue) View`
- `summary_slot fn (FormSummaryState) View`
- `pending_slot fn (FormPendingState) View`

### Field adapter fields

Available on `input` and `numeric_input`:
- `field_id string`
- `form_sync_validators []FormSyncValidator`
- `form_async_validators []FormAsyncValidator`
- `form_validate_on FormValidateOn` (`.inherit` uses form default)
- `form_initial_value ?string`

### Window helpers

- `window.form_submit(form_id)`
- `window.form_reset(form_id)`
- `window.form_summary(form_id)`
- `window.form_field_state(form_id, field_id)`
- `window.form_field_errors(form_id, field_id)`
- `window.form_pending_state(form_id)`

## Notes

- Fields register automatically when rendered inside a `form` subtree.
- `field_id` must be set for a field to participate in form runtime.
- Async validator errors map to `FormIssue{ code: 'async_error', kind: .error }`.
