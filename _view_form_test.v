module gui

fn form_required_validator(field FormFieldSnapshot, _ FormSnapshot) []FormIssue {
	if field.value.trim_space().len == 0 {
		return [FormIssue{
			code: 'required'
			msg:  'required'
		}]
	}
	return []FormIssue{}
}

fn form_async_noop_validator(_ FormFieldSnapshot, _ FormSnapshot, _ &GridAbortSignal) ![]FormIssue {
	return []FormIssue{}
}

fn make_form_test_layout(form_id string) &Layout {
	parent := &Layout{
		shape: &Shape{
			id: form_layout_id(form_id)
		}
	}
	child := &Layout{
		shape:  &Shape{
			id: 'field'
		}
		parent: parent
	}
	return child
}

fn test_form_change_validation_and_dirty_state() {
	mut w := Window{}
	layout := make_form_test_layout('signup')
	w.form_apply_cfg('signup', FormCfg{
		id:          'signup'
		validate_on: .change
	})
	w.form_register_field(layout, FormFieldAdapterCfg{
		field_id:             'name'
		value:                ''
		sync_validators:      [FormSyncValidator(form_required_validator)]
		validate_on_override: .change
	})
	w.form_on_field_event(layout, FormFieldAdapterCfg{
		field_id:             'name'
		value:                ''
		sync_validators:      [FormSyncValidator(form_required_validator)]
		validate_on_override: .change
	}, .change)
	state := w.form_field_state('signup', 'name') or { panic('missing field state') }
	assert state.dirty == false
	assert state.touched == false
	assert state.errors.len == 1
}

fn test_form_blur_sets_touched_and_validates() {
	mut w := Window{}
	layout := make_form_test_layout('profile')
	w.form_apply_cfg('profile', FormCfg{
		id:          'profile'
		validate_on: .blur_submit
	})
	w.form_register_field(layout, FormFieldAdapterCfg{
		field_id:        'email'
		value:           ''
		sync_validators: [FormSyncValidator(form_required_validator)]
	})
	w.form_on_field_event(layout, FormFieldAdapterCfg{
		field_id:        'email'
		value:           ''
		sync_validators: [FormSyncValidator(form_required_validator)]
	}, .blur)
	state := w.form_field_state('profile', 'email') or { panic('missing field state') }
	assert state.touched
	assert state.errors.len == 1
}

fn test_form_submit_blocks_invalid() {
	mut w := Window{}
	layout := make_form_test_layout('checkout')
	mut submit_count := 0
	cfg := FormCfg{
		id:                        'checkout'
		validate_on:               .submit
		block_submit_when_invalid: true
		on_submit:                 fn [mut submit_count] (_ FormSubmitEvent, mut _ Window) {
			submit_count++
		}
	}
	w.form_apply_cfg('checkout', cfg)
	w.form_register_field(layout, FormFieldAdapterCfg{
		field_id:        'zip'
		value:           ''
		sync_validators: [FormSyncValidator(form_required_validator)]
	})
	w.form_submit('checkout')
	w.form_process_requests('checkout', cfg)
	assert submit_count == 0
	summary := w.form_summary('checkout')
	assert summary.invalid_count == 1
}

fn test_form_submit_request_from_layout() {
	mut w := Window{}
	layout := make_form_test_layout('login')
	w.form_apply_cfg('login', FormCfg{
		id:              'login'
		submit_on_enter: true
	})
	w.form_request_submit_for_layout(layout)
	state := form_state_peek(w, 'login')
	assert state.submit_requested
}

fn test_form_submit_request_processed_once() {
	mut w := Window{}
	layout := make_form_test_layout('once')
	cfg := FormCfg{
		id: 'once'
	}
	w.form_apply_cfg('once', cfg)
	w.form_register_field(layout, FormFieldAdapterCfg{
		field_id:         'username'
		value:            'alice'
		async_validators: [FormAsyncValidator(form_async_noop_validator)]
	})
	w.form_submit('once')
	w.form_process_requests('once', cfg)
	state_first := form_state_peek(w, 'once')
	field_first := state_first.fields['username'] or { panic('missing form field state') }
	w.form_process_requests('once', cfg)
	state_second := form_state_peek(w, 'once')
	field_second := state_second.fields['username'] or { panic('missing form field state') }
	assert !state_second.submit_requested
	assert field_first.request_seq == 1
	assert field_second.request_seq == 1
}
