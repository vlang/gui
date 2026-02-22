module gui

import time

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

fn form_async_fail_validator(_ FormFieldSnapshot, _ FormSnapshot, _ &GridAbortSignal) ![]FormIssue {
	return error('internal-validator-detail')
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

fn test_form_state_set_eviction_aborts_pending_requests() {
	mut w := Window{}
	_ = state_map[string, FormRuntimeState](mut w, ns_form, 1)
	mut controller := new_grid_abort_controller()
	form_state_set(mut w, 'first', FormRuntimeState{
		fields: {
			'email': FormFieldRuntimeState{
				pending:      true
				active_abort: controller
			}
		}
	})
	form_state_set(mut w, 'second', FormRuntimeState{})
	assert controller.signal.is_aborted()
}

fn test_form_cleanup_stale_aborts_pending_field() {
	mut w := Window{}
	mut controller := new_grid_abort_controller()
	form_state_set(mut w, 'profile', FormRuntimeState{
		fields: {
			'email': FormFieldRuntimeState{
				pending:      true
				active_abort: controller
				seen_frame:   1
			}
		}
	})
	w.form_cleanup_stale('profile', 2)
	state := form_state_peek(w, 'profile')
	assert controller.signal.is_aborted()
	assert state.fields.len == 0
}

fn test_form_reset_clears_pending_and_errors() {
	mut w := Window{}
	cfg := FormCfg{
		id: 'reset'
	}
	mut controller := new_grid_abort_controller()
	form_state_set(mut w, 'reset', FormRuntimeState{
		reset_requested: true
		fields:          {
			'email': FormFieldRuntimeState{
				value:         'bad'
				initial_value: 'seed'
				dirty:         true
				touched:       true
				pending:       true
				sync_errors:   [
					FormIssue{
						code: 'required'
						msg:  'required'
					},
				]
				async_errors:  [FormIssue{
					code: 'async'
					msg:  'bad'
				}]
				active_abort:  controller
			}
		}
	})
	w.form_process_requests('reset', cfg)
	state := form_state_peek(w, 'reset')
	field := state.fields['email'] or { panic('missing form field state') }
	assert controller.signal.is_aborted()
	assert field.value == 'seed'
	assert !field.dirty
	assert !field.touched
	assert !field.pending
	assert field.sync_errors.len == 0
	assert field.async_errors.len == 0
	assert isnil(field.active_abort)
}

fn test_form_async_validator_error_message_is_sanitized() {
	mut w := Window{}
	layout := make_form_test_layout('async_msg')
	w.form_apply_cfg('async_msg', FormCfg{
		id:          'async_msg'
		validate_on: .change
	})
	w.form_register_field(layout, FormFieldAdapterCfg{
		field_id:             'email'
		value:                'user@example.com'
		async_validators:     [FormAsyncValidator(form_async_fail_validator)]
		validate_on_override: .change
	})
	w.form_on_field_event(layout, FormFieldAdapterCfg{
		field_id:             'email'
		value:                'user@example.com'
		async_validators:     [FormAsyncValidator(form_async_fail_validator)]
		validate_on_override: .change
	}, .change)
	for _ in 0 .. 40 {
		w.flush_commands()
		issues := w.form_field_errors('async_msg', 'email')
		if issues.len > 0 {
			assert issues[0].code == 'async_error'
			assert issues[0].msg == form_async_issue_msg
			assert !issues[0].msg.contains('internal-validator-detail')
			return
		}
		time.sleep(5 * time.millisecond)
	}
	assert false
}
