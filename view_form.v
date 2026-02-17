module gui

import log

const form_layout_id_prefix = '__gui_form__:'

pub enum FormValidateOn as u8 {
	inherit
	change
	blur
	blur_submit
	submit
}

pub enum FormIssueKind as u8 {
	error
	warning
}

pub enum FormValidationTrigger as u8 {
	change
	blur
	submit
}

pub struct FormIssue {
pub:
	code string
	msg  string
	kind FormIssueKind = .error
}

pub struct FormFieldSnapshot {
pub:
	form_id  string
	field_id string
	value    string
	touched  bool
	dirty    bool
}

pub struct FormFieldState {
pub:
	value         string
	initial_value string
	touched       bool
	dirty         bool
	pending       bool
	errors        []FormIssue
}

pub struct FormSnapshot {
pub:
	form_id string
	values  map[string]string
	fields  map[string]FormFieldState
}

pub struct FormSummaryState {
pub:
	valid         bool
	pending       bool
	invalid_count int
	pending_count int
	issues        map[string][]FormIssue
}

pub struct FormPendingState {
pub:
	form_id       string
	field_ids     []string
	pending_count int
}

pub struct FormSubmitEvent {
pub:
	form_id string
	values  map[string]string
	valid   bool
	pending bool
	state   FormSummaryState
}

pub struct FormResetEvent {
pub:
	form_id string
	values  map[string]string
}

pub type FormSyncValidator = fn (FormFieldSnapshot, FormSnapshot) []FormIssue

pub type FormAsyncValidator = fn (FormFieldSnapshot, FormSnapshot, &GridAbortSignal) ![]FormIssue

@[minify]
struct FormFieldRuntimeState {
mut:
	value            string
	initial_value    string
	touched          bool
	dirty            bool
	pending          bool
	sync_errors      []FormIssue
	async_errors     []FormIssue
	sync_validators  []FormSyncValidator
	async_validators []FormAsyncValidator
	validate_on      FormValidateOn = .blur_submit
	request_seq      u64
	active_abort     &GridAbortController = unsafe { nil }
	seen_frame       u64
}

@[minify]
struct FormRuntimeState {
mut:
	fields                    map[string]FormFieldRuntimeState
	submit_requested          bool
	reset_requested           bool
	validate_on               FormValidateOn = .blur_submit
	submit_on_enter           bool           = true
	block_submit_when_invalid bool           = true
	block_submit_when_pending bool           = true
	disabled                  bool
}

pub struct FormCfg {
pub:
	id                        string
	content                   []View
	validate_on               FormValidateOn = .blur_submit
	submit_on_enter           bool           = true
	block_submit_when_invalid bool           = true
	block_submit_when_pending bool           = true
	disabled                  bool
	invisible                 bool
	on_submit                 fn (FormSubmitEvent, mut Window) = unsafe { nil }
	on_reset                  fn (FormResetEvent, mut Window)  = unsafe { nil }
	error_slot                fn (string, []FormIssue) View    = unsafe { nil }
	summary_slot              fn (FormSummaryState) View       = unsafe { nil }
	pending_slot              fn (FormPendingState) View       = unsafe { nil }
	sizing                    Sizing
	width                     f32
	height                    f32
	min_width                 f32
	max_width                 f32
	min_height                f32
	max_height                f32
	padding                   Padding = padding_none
	spacing                   f32     = gui_theme.spacing_medium
	color                     Color   = color_transparent
	size_border               f32
	color_border              Color = color_transparent
	radius                    f32
}

@[heap; minify]
struct FormView implements View {
	cfg FormCfg
mut:
	content []View
}

// form creates a form container with runtime validation and submit/reset semantics.
pub fn form(cfg FormCfg) View {
	if cfg.id.len == 0 {
		log.warn('form.id is required for validation runtime; rendering plain column')
		return column(ContainerCfg{
			name:         'form'
			sizing:       cfg.sizing
			width:        cfg.width
			height:       cfg.height
			min_width:    cfg.min_width
			max_width:    cfg.max_width
			min_height:   cfg.min_height
			max_height:   cfg.max_height
			padding:      cfg.padding
			spacing:      cfg.spacing
			color:        cfg.color
			size_border:  cfg.size_border
			color_border: cfg.color_border
			radius:       cfg.radius
			disabled:     cfg.disabled
			invisible:    cfg.invisible
			content:      cfg.content
		})
	}
	return FormView{
		cfg:     cfg
		content: cfg.content.clone()
	}
}

fn (mut fv FormView) generate_layout(mut w Window) Layout {
	cfg := fv.cfg
	form_id := cfg.id
	w.form_apply_cfg(form_id, cfg)

	summary := w.form_summary(form_id)
	pending := w.form_pending_state(form_id)
	mut children := fv.content.clone()

	if cfg.error_slot != unsafe { nil } {
		mut field_ids := summary.issues.keys()
		field_ids.sort()
		for field_id in field_ids {
			issues := summary.issues[field_id] or { []FormIssue{} }
			children << cfg.error_slot(field_id, issues)
		}
	}
	if cfg.summary_slot != unsafe { nil } {
		children << cfg.summary_slot(summary)
	}
	if cfg.pending_slot != unsafe { nil } {
		children << cfg.pending_slot(pending)
	}

	mut inner := column(ContainerCfg{
		name:         'form'
		id:           form_layout_id(form_id)
		sizing:       cfg.sizing
		width:        cfg.width
		height:       cfg.height
		min_width:    cfg.min_width
		max_width:    cfg.max_width
		min_height:   cfg.min_height
		max_height:   cfg.max_height
		padding:      cfg.padding
		spacing:      cfg.spacing
		color:        cfg.color
		size_border:  cfg.size_border
		color_border: cfg.color_border
		radius:       cfg.radius
		disabled:     cfg.disabled
		invisible:    cfg.invisible
		amend_layout: fn [form_id, cfg] (mut _ Layout, mut win Window) {
			frame := u64(win.context().frame)
			win.form_cleanup_stale(form_id, frame)
			win.form_process_requests(form_id, cfg)
		}
		content:      children
	})

	mut layout := inner.generate_layout(mut w)
	fv.content.clear()
	fv.content = []View{}
	for mut child in children {
		layout.children << generate_layout(mut child, mut w)
	}
	return layout
}

struct FormFieldAdapterCfg {
	field_id             string
	value                string
	initial_value        ?string
	sync_validators      []FormSyncValidator
	async_validators     []FormAsyncValidator
	validate_on_override FormValidateOn = .inherit
}

fn form_layout_id(form_id string) string {
	return '${form_layout_id_prefix}${form_id}'
}

fn form_decode_layout_id(layout_id string) string {
	if layout_id.starts_with(form_layout_id_prefix) {
		return layout_id[form_layout_id_prefix.len..]
	}
	return ''
}

fn form_find_ancestor_id(layout &Layout) string {
	if isnil(layout) {
		return ''
	}
	if isnil(layout.shape) {
		if isnil(layout.parent) {
			return ''
		}
		return form_find_ancestor_id(layout.parent)
	}
	form_id := form_decode_layout_id(layout.shape.id)
	if form_id.len > 0 {
		return form_id
	}
	if isnil(layout.parent) {
		return ''
	}
	return form_find_ancestor_id(layout.parent)
}

fn form_should_validate(mode FormValidateOn, trigger FormValidationTrigger) bool {
	return match mode {
		.inherit { trigger in [.blur, .submit] }
		.change { true }
		.blur, .blur_submit { trigger in [.blur, .submit] }
		.submit { trigger == .submit }
	}
}

fn form_resolve_validate_on(override FormValidateOn, fallback FormValidateOn) FormValidateOn {
	if override == .inherit {
		return fallback
	}
	return override
}

fn form_merge_errors(field FormFieldRuntimeState) []FormIssue {
	mut merged := []FormIssue{cap: field.sync_errors.len + field.async_errors.len}
	merged << field.sync_errors
	merged << field.async_errors
	return merged
}

fn form_to_public_field_state(field FormFieldRuntimeState) FormFieldState {
	return FormFieldState{
		value:         field.value
		initial_value: field.initial_value
		touched:       field.touched
		dirty:         field.dirty
		pending:       field.pending
		errors:        form_merge_errors(field)
	}
}

fn form_state_get(mut w Window, form_id string) FormRuntimeState {
	return w.view_state.form_state.get(form_id) or { FormRuntimeState{} }
}

fn form_state_peek(w &Window, form_id string) FormRuntimeState {
	return w.view_state.form_state.get(form_id) or { FormRuntimeState{} }
}

fn form_state_set(mut w Window, form_id string, state FormRuntimeState) {
	w.view_state.form_state.set(form_id, state)
}

fn form_snapshot_from_state(form_id string, state FormRuntimeState) FormSnapshot {
	mut values := map[string]string{}
	mut fields := map[string]FormFieldState{}
	for field_id, field in state.fields {
		values[field_id] = field.value
		fields[field_id] = form_to_public_field_state(field)
	}
	return FormSnapshot{
		form_id: form_id
		values:  values
		fields:  fields
	}
}

fn form_field_snapshot(form_id string, field_id string, field FormFieldRuntimeState) FormFieldSnapshot {
	return FormFieldSnapshot{
		form_id:  form_id
		field_id: field_id
		value:    field.value
		touched:  field.touched
		dirty:    field.dirty
	}
}

fn form_compute_summary_from_state(state FormRuntimeState) FormSummaryState {
	mut invalid_count := 0
	mut pending_count := 0
	mut issues := map[string][]FormIssue{}
	for field_id, field in state.fields {
		merged := form_merge_errors(field)
		if merged.len > 0 {
			invalid_count++
			issues[field_id] = merged
		}
		if field.pending {
			pending_count++
		}
	}
	return FormSummaryState{
		valid:         invalid_count == 0 && pending_count == 0
		pending:       pending_count > 0
		invalid_count: invalid_count
		pending_count: pending_count
		issues:        issues
	}
}

pub fn (window &Window) form_summary(form_id string) FormSummaryState {
	state := form_state_peek(window, form_id)
	return form_compute_summary_from_state(state)
}

pub fn (window &Window) form_pending_state(form_id string) FormPendingState {
	state := form_state_peek(window, form_id)
	mut ids := []string{}
	for field_id, field in state.fields {
		if field.pending {
			ids << field_id
		}
	}
	ids.sort()
	return FormPendingState{
		form_id:       form_id
		field_ids:     ids
		pending_count: ids.len
	}
}

pub fn (window &Window) form_field_state(form_id string, field_id string) ?FormFieldState {
	state := form_state_peek(window, form_id)
	field := state.fields[field_id] or { return none }
	return form_to_public_field_state(field)
}

pub fn (window &Window) form_field_errors(form_id string, field_id string) []FormIssue {
	if field := window.form_field_state(form_id, field_id) {
		return field.errors
	}
	return []FormIssue{}
}

pub fn (mut window Window) form_submit(form_id string) {
	if form_id.len == 0 {
		return
	}
	mut state := form_state_get(mut window, form_id)
	state.submit_requested = true
	form_state_set(mut window, form_id, state)
	window.update_window()
}

pub fn (mut window Window) form_reset(form_id string) {
	if form_id.len == 0 {
		return
	}
	mut state := form_state_get(mut window, form_id)
	state.reset_requested = true
	form_state_set(mut window, form_id, state)
	window.update_window()
}

fn (mut w Window) form_request_submit_for_layout(layout &Layout) {
	if isnil(layout) || isnil(layout.shape) {
		return
	}
	form_id := form_find_ancestor_id(layout)
	if form_id.len == 0 {
		return
	}
	state := form_state_get(mut w, form_id)
	if !state.submit_on_enter {
		return
	}
	w.form_submit(form_id)
}

fn (mut w Window) form_apply_cfg(form_id string, cfg FormCfg) {
	mut state := form_state_get(mut w, form_id)
	state.validate_on = cfg.validate_on
	state.submit_on_enter = cfg.submit_on_enter
	state.block_submit_when_invalid = cfg.block_submit_when_invalid
	state.block_submit_when_pending = cfg.block_submit_when_pending
	state.disabled = cfg.disabled
	form_state_set(mut w, form_id, state)
}

fn (mut w Window) form_cleanup_stale(form_id string, frame u64) {
	mut state := form_state_get(mut w, form_id)
	if state.fields.len == 0 {
		return
	}
	mut stale := []string{}
	for field_id, field in state.fields {
		if field.seen_frame != frame {
			stale << field_id
		}
	}
	if stale.len == 0 {
		return
	}
	for field_id in stale {
		mut field := state.fields[field_id] or { continue }
		if field.pending && !isnil(field.active_abort) {
			mut active := field.active_abort
			active.abort()
		}
		state.fields.delete(field_id)
	}
	form_state_set(mut w, form_id, state)
}

fn (mut w Window) form_register_field(layout &Layout, cfg FormFieldAdapterCfg) {
	if cfg.field_id.len == 0 {
		return
	}
	form_id := form_find_ancestor_id(layout)
	if form_id.len == 0 {
		return
	}
	mut state := form_state_get(mut w, form_id)
	mut field := state.fields[cfg.field_id] or { FormFieldRuntimeState{} }
	had_field := cfg.field_id in state.fields
	if !had_field {
		field.initial_value = cfg.initial_value or { cfg.value }
	}
	field.value = cfg.value
	field.dirty = field.value != field.initial_value
	field.sync_validators = cfg.sync_validators.clone()
	field.async_validators = cfg.async_validators.clone()
	field.validate_on = form_resolve_validate_on(cfg.validate_on_override, state.validate_on)
	field.seen_frame = u64(w.context().frame)
	state.fields[cfg.field_id] = field
	form_state_set(mut w, form_id, state)
}

fn (mut w Window) form_on_field_event(layout &Layout, cfg FormFieldAdapterCfg, trigger FormValidationTrigger) {
	if cfg.field_id.len == 0 {
		return
	}
	form_id := form_find_ancestor_id(layout)
	if form_id.len == 0 {
		return
	}
	w.form_on_field_event_for_form(form_id, cfg, trigger)
}

fn (mut w Window) form_on_field_event_for_form(form_id string, cfg FormFieldAdapterCfg, trigger FormValidationTrigger) {
	mut state := form_state_get(mut w, form_id)
	mut field := state.fields[cfg.field_id] or {
		FormFieldRuntimeState{
			value:         cfg.value
			initial_value: cfg.initial_value or { cfg.value }
		}
	}
	field.value = cfg.value
	field.dirty = field.value != field.initial_value
	field.sync_validators = cfg.sync_validators.clone()
	field.async_validators = cfg.async_validators.clone()
	field.validate_on = form_resolve_validate_on(cfg.validate_on_override, state.validate_on)
	field.seen_frame = u64(w.context().frame)
	if trigger in [.blur, .submit] {
		field.touched = true
	}

	if !form_should_validate(field.validate_on, trigger) {
		state.fields[cfg.field_id] = field
		form_state_set(mut w, form_id, state)
		return
	}

	field.sync_errors.clear()
	if field.sync_validators.len > 0 {
		state.fields[cfg.field_id] = field
		snapshot := form_snapshot_from_state(form_id, state)
		mut current := state.fields[cfg.field_id] or { FormFieldRuntimeState{} }
		field_snapshot := form_field_snapshot(form_id, cfg.field_id, current)
		for validator in current.sync_validators {
			issues := validator(field_snapshot, snapshot)
			if issues.len > 0 {
				current.sync_errors << issues
			}
		}
		field = current
	}

	if field.pending && !isnil(field.active_abort) {
		mut active := field.active_abort
		active.abort()
	}
	field.pending = false
	field.async_errors.clear()
	field.active_abort = unsafe { nil }

	if field.async_validators.len > 0 {
		field.pending = true
		field.request_seq++
		request_id := field.request_seq
		controller := new_grid_abort_controller()
		field.active_abort = controller
		state.fields[cfg.field_id] = field
		snapshot := form_snapshot_from_state(form_id, state)
		field_snapshot := form_field_snapshot(form_id, cfg.field_id, field)
		validators := field.async_validators.clone()
		signal := controller.signal
		field_id := cfg.field_id
		spawn fn [validators, field_snapshot, snapshot, signal, form_id, field_id, request_id] (mut win Window) {
			mut issues := []FormIssue{}
			for validator in validators {
				if signal.is_aborted() {
					return
				}
				result := validator(field_snapshot, snapshot, signal) or {
					issues << FormIssue{
						code: 'async_error'
						msg:  err.msg()
						kind: .error
					}
					continue
				}
				if result.len > 0 {
					issues << result
				}
			}
			if signal.is_aborted() {
				return
			}
			win.queue_command(fn [form_id, field_id, request_id, issues] (mut win Window) {
				win.form_apply_async_result(form_id, field_id, request_id, issues)
			})
		}(mut w)
	} else {
		field.pending = false
		field.active_abort = unsafe { nil }
		state.fields[cfg.field_id] = field
	}

	form_state_set(mut w, form_id, state)
}

fn (mut w Window) form_apply_async_result(form_id string, field_id string, request_id u64, issues []FormIssue) {
	mut state := form_state_get(mut w, form_id)
	mut field := state.fields[field_id] or { return }
	if request_id != field.request_seq {
		return
	}
	field.pending = false
	field.active_abort = unsafe { nil }
	field.async_errors = issues.clone()
	state.fields[field_id] = field
	form_state_set(mut w, form_id, state)
	w.update_window()
}

fn (mut w Window) form_process_requests(form_id string, cfg FormCfg) {
	mut state := form_state_get(mut w, form_id)
	mut state_changed := false
	if state.disabled {
		state.submit_requested = false
		state.reset_requested = false
		form_state_set(mut w, form_id, state)
		return
	}

	if state.reset_requested {
		mut values := map[string]string{}
		for field_id, mut field in state.fields {
			if field.pending && !isnil(field.active_abort) {
				mut active := field.active_abort
				active.abort()
			}
			field.value = field.initial_value
			field.dirty = false
			field.touched = false
			field.pending = false
			field.sync_errors.clear()
			field.async_errors.clear()
			field.active_abort = unsafe { nil }
			state.fields[field_id] = field
			values[field_id] = field.initial_value
		}
		state.reset_requested = false
		state_changed = true
		form_state_set(mut w, form_id, state)
		if cfg.on_reset != unsafe { nil } {
			cfg.on_reset(FormResetEvent{
				form_id: form_id
				values:  values
			}, mut w)
		}
	}

	if !state.submit_requested {
		return
	}

	state.submit_requested = false
	state_changed = true
	form_state_set(mut w, form_id, state)
	mut field_ids := state.fields.keys()
	field_ids.sort()
	for field_id in field_ids {
		field := state.fields[field_id] or { continue }
		w.form_on_field_event_for_form(form_id, FormFieldAdapterCfg{
			field_id:             field_id
			value:                field.value
			initial_value:        field.initial_value
			sync_validators:      field.sync_validators
			async_validators:     field.async_validators
			validate_on_override: field.validate_on
		}, .submit)
		state = form_state_get(mut w, form_id)
	}

	summary := form_compute_summary_from_state(state)
	blocked_invalid := state.block_submit_when_invalid && summary.invalid_count > 0
	blocked_pending := state.block_submit_when_pending && summary.pending
	if !blocked_invalid && !blocked_pending && cfg.on_submit != unsafe { nil } {
		cfg.on_submit(FormSubmitEvent{
			form_id: form_id
			values:  form_snapshot_from_state(form_id, state).values
			valid:   summary.valid
			pending: summary.pending
			state:   summary
		}, mut w)
	}
	form_state_set(mut w, form_id, state)
	if state_changed {
		w.update_window()
	}
}
