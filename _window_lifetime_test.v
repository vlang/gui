module gui

import gg
import os
import time

const lifetime_payload_len = 2048
const lifetime_rebuild_iterations = 700
const lifetime_memory_max_growth = usize(3 * 1024 * 1024)
const lifetime_persistent_animation_id = 'lifetime_persistent_animation'
const lifetime_hover_animation_id = 'lifetime_hover_animation'
const lifetime_progress_id = 'lifetime_progress'
const lifetime_progress_animation_id = '${lifetime_progress_id}_indefinite'
const lifetime_async_grid_id = 'lifetime_async_grid'
const lifetime_async_list_id = 'lifetime_async_list'
const lifetime_async_form_id = 'lifetime_async_form'
const lifetime_async_form_field_id = 'email'
const lifetime_math_hash = i64(314159)
const lifetime_mermaid_hash = i64(58058)
const lifetime_image_invalid_url = 'http://'
const lifetime_sidebar_id = 'lifetime_sidebar'
const lifetime_debounce_grid_id = 'lifetime_debounce_grid'

struct LifetimeUpdateView implements View {
	seed          int
	add_animation bool
mut:
	content []View
}

struct LifetimeHoverView implements View {
	seed int
mut:
	content []View
}

struct LifetimeSidebarView implements View {
	open       bool
	easing_mix f32
mut:
	content []View
}

@[heap]
struct LifetimeAsyncSourceState {
mut:
	grid_source ?DataGridDataSource
	list_source ?ListBoxDataSource
}

type LifetimeGridFetchFn = fn (GridDataRequest) !GridDataResult

type LifetimeGridMutateFn = fn (GridMutationRequest) !GridMutationResult

type LifetimeListFetchFn = fn (ListBoxDataRequest) !ListBoxDataResult

@[heap]
struct LifetimeCallbackGridSource {
	caps      GridDataCapabilities
	fetch_fn  LifetimeGridFetchFn  @[required]
	mutate_fn LifetimeGridMutateFn @[required]
}

fn (source LifetimeCallbackGridSource) capabilities() GridDataCapabilities {
	return source.caps
}

fn (source LifetimeCallbackGridSource) fetch_data(req GridDataRequest) !GridDataResult {
	return source.fetch_fn(req)
}

fn (mut source LifetimeCallbackGridSource) mutate_data(req GridMutationRequest) !GridMutationResult {
	return source.mutate_fn(req)
}

@[heap]
struct LifetimeCallbackListSource {
	fetch_fn LifetimeListFetchFn @[required]
}

fn (source LifetimeCallbackListSource) fetch_data(req ListBoxDataRequest) !ListBoxDataResult {
	return source.fetch_fn(req)
}

@[heap]
struct LifetimeCrudSaveHarness {
mut:
	ctx             DataGridCrudSaveContext
	rows_change_sum int
	selection_sum   int
	error_sum       int
}

@[heap]
struct LifetimeUpdateState {
mut:
	seed            int
	add_animation   bool
	animation_value int
}

@[heap]
struct LifetimeSidebarState {
mut:
	open       bool
	easing_mix f32
	width      f32
}

@[heap]
struct LifetimeDataGridDebounceState {
mut:
	seed           int
	show           bool
	call_count     int
	callback_value int
	callback_text  string
}

@[heap]
struct LifetimeMouseLockState {
mut:
	cfg MouseLockCfg
}

@[heap]
struct LifetimeAnimationLayoutState {
mut:
	called bool
}

fn make_lifetime_window() Window {
	return Window{
		layout_callback_lifetime: new_layout_callback_lifetime()
		window_size:              gg.Size{
			width:  100
			height: 100
		}
	}
}

fn lifetime_expected(seed int) int {
	return seed + seed + lifetime_payload_len - 1
}

fn make_lifetime_callback_layout(seed int) Layout {
	payload := []int{len: lifetime_payload_len, init: seed + index}
	return Layout{
		shape: &Shape{
			width:  100
			height: 100
			events: &EventHandlers{
				on_click: fn [payload] (_ &Layout, mut e Event, mut _ Window) {
					e.frame_count = u64(payload[0] + payload[payload.len - 1])
					e.is_handled = true
				}
			}
		}
	}
}

fn make_lifetime_hover_animation_layout(seed int) Layout {
	return Layout{
		shape: &Shape{
			width:      100
			height:     100
			shape_clip: gg.Rect{
				x:      0
				y:      0
				width:  100
				height: 100
			}
			events:     &EventHandlers{
				on_hover: fn [seed] (mut _ Layout, mut e Event, mut w Window) {
					if lifetime_hover_animation_id !in w.animations {
						payload := []int{len: lifetime_payload_len, init: seed + index}
						mut state := unsafe { &LifetimeUpdateState(w.state) }
						w.animation_add(mut Animate{
							id:       lifetime_hover_animation_id
							repeat:   true
							callback: fn [payload, mut state] (mut an Animate, mut _ Window) {
								state.animation_value = payload[0] + payload[payload.len - 1]
								an.stopped = true
							}
						})
					}
					e.is_handled = true
				}
			}
		}
	}
}

fn lifetime_update_view_generator(window &Window) View {
	state := unsafe { &LifetimeUpdateState(window.state) }
	return LifetimeUpdateView{
		seed:          state.seed
		add_animation: state.add_animation
	}
}

fn (mut view LifetimeUpdateView) generate_layout(mut w Window) Layout {
	if view.add_animation && lifetime_persistent_animation_id !in w.animations {
		seed := view.seed
		w.animation_add_from_layout(fn [mut w, seed] () {
			mut state := unsafe { &LifetimeUpdateState(w.state) }
			w.animation_add(mut Animate{
				id:       lifetime_persistent_animation_id
				repeat:   true
				callback: fn [mut state, seed] (mut an Animate, mut _ Window) {
					state.animation_value = lifetime_expected(seed)
					an.stopped = true
				}
			})
		}) or { panic(err) }
	}
	return make_lifetime_callback_layout(view.seed)
}

fn lifetime_progress_view_generator(_ &Window) View {
	return progress_bar(
		id:         lifetime_progress_id
		indefinite: true
		width:      100
		height:     16
	)
}

fn lifetime_hover_view_generator(window &Window) View {
	state := unsafe { &LifetimeUpdateState(window.state) }
	return LifetimeHoverView{
		seed: state.seed
	}
}

fn lifetime_zero_window_view_generator(_ &Window) View {
	return LifetimeUpdateView{
		seed: 43
	}
}

fn lifetime_sidebar_view_generator(window &Window) View {
	state := unsafe { &LifetimeSidebarState(window.state) }
	return LifetimeSidebarView{
		open:       state.open
		easing_mix: state.easing_mix
	}
}

fn (mut view LifetimeSidebarView) generate_layout(mut w Window) Layout {
	payload := [view.easing_mix]
	easing := fn [payload] (t f32) f32 {
		return payload[0] * t * t + (1 - payload[0]) * t
	}
	width := sidebar_animated_width(mut w, SidebarCfg{
		id:             lifetime_sidebar_id
		open:           view.open
		width:          100
		tween_duration: 300 * time.millisecond
		tween_easing:   easing
		content:        []View{}
	})
	mut state := unsafe { &LifetimeSidebarState(w.state) }
	state.width = width
	return make_lifetime_callback_layout(44)
}

fn lifetime_grid_columns() []GridColumnCfg {
	return [
		GridColumnCfg{
			id:    'name'
			title: 'Name'
		},
	]
}

fn lifetime_grid_rows() []gui.GridRow {
	return [
		GridRow{
			id:    'row-1'
			cells: {
				'name': 'Alpha'
			}
		},
		GridRow{
			id:    'row-2'
			cells: {
				'name': 'Beta'
			}
		},
	]
}

fn lifetime_list_options() []ListBoxOption {
	return [
		list_box_option('one', 'One', '1'),
		list_box_option('two', 'Two', '2'),
	]
}

type LifetimeFormIssueList = []FormIssue

fn lifetime_form_async_validator(_ FormFieldSnapshot, _ FormSnapshot, signal &GridAbortSignal) !LifetimeFormIssueList {
	time.sleep(40 * time.millisecond)
	if signal.is_aborted() {
		return LifetimeFormIssueList([]FormIssue{})
	}
	return LifetimeFormIssueList([
		FormIssue{
			code: 'async'
			msg:  'async complete'
		},
	])
}

fn lifetime_capturing_form_async_validator(payload []int) FormAsyncValidator {
	return fn [payload] (_ FormFieldSnapshot, _ FormSnapshot, signal &GridAbortSignal) !LifetimeFormIssueList {
		time.sleep(40 * time.millisecond)
		if signal.is_aborted() {
			return LifetimeFormIssueList([]FormIssue{})
		}
		return LifetimeFormIssueList([
			FormIssue{
				code: 'captured_async'
				msg:  '${payload[0] + payload[payload.len - 1]}'
			},
		])
	}
}

fn make_lifetime_form_field_layout(form_id string, field_id string) &Layout {
	parent := &Layout{
		shape: &Shape{
			id: form_layout_id(form_id)
		}
	}
	return &Layout{
		shape:  &Shape{
			id: field_id
		}
		parent: parent
	}
}

fn (mut view LifetimeHoverView) generate_layout(mut _ Window) Layout {
	return make_lifetime_hover_animation_layout(view.seed)
}

fn (mut w Window) rebuild_lifetime_test_layout(seed int) {
	w.layout_callback_lifetime.lifetime.frame(fn [mut w, seed] () {
		layout_clear(mut w.layout)
		w.layout = make_lifetime_callback_layout(seed)
	}) or { panic(err) }
	w.reclaim_old_layout_callbacks()
}

fn (mut w Window) update_lifetime_test_layout(seed int) {
	mut state := unsafe { &LifetimeUpdateState(w.state) }
	state.seed = seed
	w.update()
}

fn collect_and_churn_lifetime_test() {
	gc_collect()
	for _ in 0 .. 1024 {
		unsafe {
			p := malloc(32)
			vmemset(p, 0x55, 32)
		}
	}
	gc_collect()
}

fn lifetime_quick_filter_input_id() string {
	return '${lifetime_debounce_grid_id}:quick_filter'
}

fn lifetime_quick_filter_animation_id() string {
	return '${lifetime_quick_filter_input_id()}:debounce'
}

fn make_lifetime_quick_filter_debounce_layout(seed int) Layout {
	input_id := lifetime_quick_filter_input_id()
	payload := []int{len: lifetime_payload_len, init: seed + index}
	query_callback := fn [payload] (query GridQueryState, mut _ Event, mut w Window) {
		mut state := unsafe { &LifetimeDataGridDebounceState(w.state) }
		state.call_count++
		state.callback_value = payload[0] + payload[payload.len - 1]
		state.callback_text = query.quick_filter
	}
	return Layout{
		shape: &Shape{
			id:     data_grid_quick_filter_debounce_handler_id(input_id)
			events: &EventHandlers{
				on_scroll: fn [input_id, query_callback] (_ &Layout, mut w Window) {
					data_grid_quick_filter_apply_debounce(input_id, query_callback, mut w)
				}
			}
		}
	}
}

fn rebuild_lifetime_quick_filter_debounce_layout(mut w Window, seed int, show bool) {
	w.layout_callback_lifetime.lifetime.frame(fn [mut w, seed, show] () {
		layout_clear(mut w.layout)
		if show {
			w.layout = make_lifetime_quick_filter_debounce_layout(seed)
		} else {
			w.layout = Layout{
				shape: &Shape{
					id: 'lifetime_debounce_grid_gone'
				}
			}
		}
	}) or { panic(err) }
	w.reclaim_old_layout_callbacks()
}

fn start_lifetime_quick_filter_debounce(mut w Window, text string) u64 {
	input_id := lifetime_quick_filter_input_id()
	token := data_grid_quick_filter_set_debounce(input_id, DataGridQuickFilterDebounce{
		sorts:   []GridSort{}
		filters: []GridFilter{}
		text:    text
	}, mut w)
	w.animation_add(mut &Animate{
		id:       lifetime_quick_filter_animation_id()
		delay:    100 * time.millisecond
		callback: fn [input_id, token] (mut _ Animate, mut w Window) {
			data_grid_quick_filter_dispatch_debounce(input_id, token, mut w)
		}
	})
	return token
}

fn lifetime_quick_filter_fallback_animate() Animate {
	return Animate{
		id:       'missing'
		callback: fn (mut _ Animate, mut _ Window) {}
	}
}

fn lifetime_quick_filter_animate(w &Window) Animate {
	animation := w.animations[lifetime_quick_filter_animation_id()] or {
		assert false, 'expected quick filter debounce animation'
		return lifetime_quick_filter_fallback_animate()
	}
	match animation {
		Animate {
			return animation
		}
		else {
			assert false, 'expected Animate debounce'
			return lifetime_quick_filter_fallback_animate()
		}
	}
}

fn lifetime_quick_filter_pending_token(w &Window) u64 {
	pending := state_map_read[string, DataGridQuickFilterDebounce](w, ns_dg_quick_filter_debounce) or {
		assert false, 'expected pending quick filter debounce'
		return 0
	}
	payload := pending.get(lifetime_quick_filter_input_id()) or {
		assert false, 'expected pending quick filter payload'
		return 0
	}
	return payload.token
}

fn lifetime_quick_filter_has_pending(w &Window) bool {
	pending := state_map_read[string, DataGridQuickFilterDebounce](w, ns_dg_quick_filter_debounce) or {
		return false
	}
	return pending.contains(lifetime_quick_filter_input_id())
}

fn run_lifetime_quick_filter_debounce(mut w Window) {
	mut animation := lifetime_quick_filter_animate(&w)
	animation.callback(mut animation, mut w)
}

fn invoke_current_layout_click(mut w Window) int {
	layout := w.layout.find_layout(fn (layout Layout) bool {
		return layout.shape != unsafe { nil } && layout.shape.has_events()
			&& layout.shape.events.on_click != unsafe { nil }
	}) or {
		assert false, 'expected click layout'
		return -1
	}
	mut clickable := layout
	assert !isnil(w.layout.shape)
	mut e := Event{}
	clickable.shape.events.on_click(&clickable, mut e, mut w)
	assert e.is_handled
	return int(e.frame_count)
}

fn wait_for_lifetime_data_grid_source(mut w Window) {
	for _ in 0 .. 40 {
		time.sleep(10 * time.millisecond)
		w.flush_commands()
		stats := w.data_grid_source_stats(lifetime_async_grid_id)
		if !stats.loading && stats.received_count == 2 {
			return
		}
	}
	stats := w.data_grid_source_stats(lifetime_async_grid_id)
	assert false, 'expected async data grid source result, got loading=${stats.loading} received=${stats.received_count} error="${stats.load_error}"'
}

fn wait_for_lifetime_list_box_source(mut w Window) {
	for _ in 0 .. 40 {
		time.sleep(10 * time.millisecond)
		w.flush_commands()
		stats := w.list_box_source_stats(lifetime_async_list_id)
		if !stats.loading && stats.received_count == 2 {
			return
		}
	}
	stats := w.list_box_source_stats(lifetime_async_list_id)
	assert false, 'expected async list box source result, got loading=${stats.loading} received=${stats.received_count} error="${stats.load_error}"'
}

fn wait_for_lifetime_data_grid_source_value(mut w Window, expected string) {
	for _ in 0 .. 40 {
		time.sleep(10 * time.millisecond)
		w.flush_commands()
		state := state_map[string, DataGridSourceState](mut w, ns_dg_source, cap_moderate).get(lifetime_async_grid_id) or {
			continue
		}
		if !state.loading && state.rows.len == 1 {
			got := state.rows[0].cells['name'] or { '' }
			if got == expected {
				return
			}
		}
	}
	state := state_map[string, DataGridSourceState](mut w, ns_dg_source, cap_moderate).get(lifetime_async_grid_id) or {
		DataGridSourceState{}
	}
	got := if state.rows.len > 0 { state.rows[0].cells['name'] or { '' } } else { '' }
	assert false, 'expected async data grid source value "${expected}", got loading=${state.loading} rows=${state.rows.len} value="${got}" error="${state.load_error}"'
}

fn wait_for_lifetime_list_box_source_value(mut w Window, expected string) {
	for _ in 0 .. 40 {
		time.sleep(10 * time.millisecond)
		w.flush_commands()
		state := state_map[string, ListBoxSourceState](mut w, ns_list_box_source, cap_moderate).get(lifetime_async_list_id) or {
			continue
		}
		if !state.loading && state.data.len == 1 && state.data[0].name == expected {
			return
		}
	}
	state := state_map[string, ListBoxSourceState](mut w, ns_list_box_source, cap_moderate).get(lifetime_async_list_id) or {
		ListBoxSourceState{}
	}
	got := if state.data.len > 0 { state.data[0].name } else { '' }
	assert false, 'expected async list box source value "${expected}", got loading=${state.loading} rows=${state.data.len} value="${got}" error="${state.load_error}"'
}

fn wait_for_lifetime_reclaim_pins(mut w Window, expected int) {
	for _ in 0 .. 40 {
		time.sleep(10 * time.millisecond)
		w.flush_commands()
		if w.layout_callback_lifetime.reclaim_pins == expected {
			return
		}
	}
	assert false, 'expected reclaim_pins=${expected}, got ${w.layout_callback_lifetime.reclaim_pins}'
}

fn wait_for_lifetime_crud_save(mut w Window, harness &LifetimeCrudSaveHarness, expected_sum int) {
	for _ in 0 .. 40 {
		time.sleep(10 * time.millisecond)
		w.flush_commands()
		state := state_map[string, DataGridCrudState](mut w, ns_dg_crud, cap_moderate).get(harness.ctx.grid_id) or {
			continue
		}
		if !state.saving && harness.rows_change_sum == expected_sum {
			return
		}
	}
	state := state_map[string, DataGridCrudState](mut w, ns_dg_crud, cap_moderate).get(harness.ctx.grid_id) or {
		DataGridCrudState{}
	}
	assert false, 'expected CRUD save callback sum=${expected_sum}, got saving=${state.saving} rows_sum=${harness.rows_change_sum} error="${state.save_error}"'
}

fn wait_for_lifetime_form_async_validation(mut w Window) {
	for _ in 0 .. 40 {
		time.sleep(10 * time.millisecond)
		w.flush_commands()
		state := w.form_field_state(lifetime_async_form_id, lifetime_async_form_field_id) or {
			continue
		}
		if !state.pending && state.errors.len == 1 && state.errors[0].code == 'async' {
			return
		}
	}
	state := w.form_field_state(lifetime_async_form_id, lifetime_async_form_field_id) or {
		FormFieldState{}
	}
	assert false, 'expected async form validation result, got pending=${state.pending} errors=${state.errors.len}'
}

fn wait_for_lifetime_capturing_form_async_validation(mut w Window, expected_msg string) {
	for _ in 0 .. 40 {
		time.sleep(10 * time.millisecond)
		w.flush_commands()
		state := w.form_field_state(lifetime_async_form_id, lifetime_async_form_field_id) or {
			continue
		}
		if !state.pending && state.errors.len == 1 && state.errors[0].code == 'captured_async'
			&& state.errors[0].msg == expected_msg {
			return
		}
	}
	state := w.form_field_state(lifetime_async_form_id, lifetime_async_form_field_id) or {
		FormFieldState{}
	}
	msg := if state.errors.len > 0 { state.errors[0].msg } else { '' }
	assert false, 'expected capturing async form validation result, got pending=${state.pending} errors=${state.errors.len} msg="${msg}"'
}

fn wait_for_lifetime_math_oversized_error(mut w Window) {
	for _ in 0 .. 40 {
		time.sleep(10 * time.millisecond)
		w.flush_commands()
		entry := w.view_state.diagram_cache.get(lifetime_math_hash) or { continue }
		if entry.state == .error && entry.error == 'LaTeX source too large' {
			return
		}
	}
	entry := w.view_state.diagram_cache.get(lifetime_math_hash) or { DiagramCacheEntry{} }
	assert false, 'expected oversized math error, got state=${entry.state} error="${entry.error}"'
}

fn wait_for_lifetime_mermaid_oversized_error(mut w Window) {
	for _ in 0 .. 40 {
		time.sleep(10 * time.millisecond)
		w.flush_commands()
		entry := w.view_state.diagram_cache.get(lifetime_mermaid_hash) or { continue }
		if entry.state == .error && entry.error == 'Mermaid source too large' {
			return
		}
	}
	entry := w.view_state.diagram_cache.get(lifetime_mermaid_hash) or { DiagramCacheEntry{} }
	assert false, 'expected oversized mermaid error, got state=${entry.state} error="${entry.error}"'
}

fn wait_for_lifetime_image_download_cleanup(mut w Window) {
	for _ in 0 .. 40 {
		time.sleep(10 * time.millisecond)
		w.flush_commands()
		mut downloads := state_map[string, i64](mut w, ns_active_downloads, cap_moderate)
		if !downloads.contains(lifetime_image_invalid_url) {
			return
		}
	}
	mut downloads := state_map[string, i64](mut w, ns_active_downloads, cap_moderate)
	assert false, 'expected image download cleanup, got active=${downloads.len()}'
}

fn start_lifetime_data_grid_source_request(mut w Window, source ?DataGridDataSource) {
	cfg := DataGridCfg{
		id:          lifetime_async_grid_id
		columns:     lifetime_grid_columns()
		data_source: source
		page_limit:  2
	}
	caps := GridDataCapabilities{
		supports_cursor_pagination: true
		row_count_known:            true
	}
	w.layout_callback_lifetime.lifetime.frame(fn [mut w, cfg, caps] () {
		mut state := DataGridSourceState{}
		data_grid_source_start_request(cfg, caps, .cursor, 'lifetime-grid-key', mut state, mut w)
		mut sm := state_map[string, DataGridSourceState](mut w, ns_dg_source, cap_moderate)
		sm.set(lifetime_async_grid_id, state)
	}) or { panic(err) }
}

fn start_lifetime_list_box_source_request(mut w Window, source ?ListBoxDataSource) {
	cfg := ListBoxCfg{
		id:          lifetime_async_list_id
		data_source: source
	}
	w.layout_callback_lifetime.lifetime.frame(fn [mut w, cfg] () {
		mut state := ListBoxSourceState{}
		list_box_source_start_request(cfg, 'lifetime-list-key', mut state, mut w)
		mut sm := state_map[string, ListBoxSourceState](mut w, ns_list_box_source, cap_moderate)
		sm.set(lifetime_async_list_id, state)
	}) or { panic(err) }
}

fn start_lifetime_capturing_data_grid_source_request(mut w Window, seed int) string {
	expected := '${lifetime_expected(seed)}'
	caps := GridDataCapabilities{
		supports_cursor_pagination: true
		row_count_known:            true
	}
	w.layout_callback_lifetime.lifetime.frame(fn [mut w, seed, caps] () {
		payload := []int{len: lifetime_payload_len, init: seed + index}
		source := DataGridDataSource(&LifetimeCallbackGridSource{
			caps:      caps
			fetch_fn:  fn [payload] (req GridDataRequest) !GridDataResult {
				data_grid_source_sleep_with_abort(req.signal, 40)!
				value := '${payload[0] + payload[payload.len - 1]}'
				return GridDataResult{
					rows:           [
						GridRow{
							id:    'row-${value}'
							cells: {
								'name': value
							}
						},
					]
					row_count:      ?int(1)
					received_count: 1
				}
			}
			mutate_fn: fn (_ GridMutationRequest) !GridMutationResult {
				return error('mutation unavailable')
			}
		})
		cfg := DataGridCfg{
			id:          lifetime_async_grid_id
			columns:     lifetime_grid_columns()
			data_source: source
			page_limit:  2
		}
		mut state := DataGridSourceState{}
		data_grid_source_start_request(cfg, caps, .cursor, 'lifetime-capturing-grid-key', mut
			state, mut w)
		mut sm := state_map[string, DataGridSourceState](mut w, ns_dg_source, cap_moderate)
		sm.set(lifetime_async_grid_id, state)
	}) or { panic(err) }
	return expected
}

fn start_lifetime_capturing_list_box_source_request(mut w Window, seed int) string {
	expected := '${lifetime_expected(seed)}'
	w.layout_callback_lifetime.lifetime.frame(fn [mut w, seed] () {
		payload := []int{len: lifetime_payload_len, init: seed + index}
		source := ListBoxDataSource(&LifetimeCallbackListSource{
			fetch_fn: fn [payload] (req ListBoxDataRequest) !ListBoxDataResult {
				data_grid_source_sleep_with_abort(req.signal, 40)!
				value := '${payload[0] + payload[payload.len - 1]}'
				return ListBoxDataResult{
					data: [
						list_box_option('item-${value}', value, value),
					]
				}
			}
		})
		cfg := ListBoxCfg{
			id:          lifetime_async_list_id
			data_source: source
		}
		mut state := ListBoxSourceState{}
		list_box_source_start_request(cfg, 'lifetime-capturing-list-key', mut state, mut w)
		mut sm := state_map[string, ListBoxSourceState](mut w, ns_list_box_source, cap_moderate)
		sm.set(lifetime_async_list_id, state)
	}) or { panic(err) }
	return expected
}

fn start_lifetime_capturing_crud_save(mut w Window, mut harness &LifetimeCrudSaveHarness, seed int) int {
	grid_id := 'lifetime_crud_grid'
	draft_id := '__draft_${grid_id}_1'
	mut dg_crud := state_map[string, DataGridCrudState](mut w, ns_dg_crud, cap_moderate)
	dg_crud.set(grid_id, DataGridCrudState{
		working_rows:  [
			GridRow{
				id:    draft_id
				cells: {
					'name': 'Draft'
				}
			},
		]
		dirty_row_ids: {
			draft_id: true
		}
		draft_row_ids: {
			draft_id: true
		}
	})
	expected_sum := lifetime_expected(seed)
	caps := GridDataCapabilities{
		supports_create: true
		supports_update: true
		supports_delete: true
		row_count_known: true
	}
	w.layout_callback_lifetime.lifetime.frame(fn [mut harness, seed, grid_id, draft_id, caps] () {
		payload := []int{len: lifetime_payload_len, init: seed + index}
		source := DataGridDataSource(&LifetimeCallbackGridSource{
			caps:      caps
			fetch_fn:  fn (_ GridDataRequest) !GridDataResult {
				return GridDataResult{}
			}
			mutate_fn: fn [payload] (req GridMutationRequest) !GridMutationResult {
				data_grid_source_sleep_with_abort(req.signal, 40)!
				value := '${payload[0] + payload[payload.len - 1]}'
				if req.kind == .create && req.rows.len > 0 {
					return GridMutationResult{
						created:   [
							GridRow{
								id:    'created-${value}'
								cells: req.rows[0].cells.clone()
							},
						]
						row_count: ?int(1)
					}
				}
				return GridMutationResult{
					row_count: ?int(1)
				}
			}
		})
		harness.ctx = DataGridCrudSaveContext{
			grid_id:             grid_id
			data_source:         source
			on_crud_error:       fn [payload, mut harness] (_ string, mut _ Event, mut _ Window) {
				harness.error_sum = payload[0] + payload[payload.len - 1]
			}
			on_rows_change:      fn [payload, mut harness] (_ []gui.GridRow, mut _ Event, mut _ Window) {
				harness.rows_change_sum = payload[0] + payload[payload.len - 1]
			}
			selection:           GridSelection{
				active_row_id:    draft_id
				selected_row_ids: {
					draft_id: true
				}
			}
			on_selection_change: fn [payload, mut harness] (_ GridSelection, mut _ Event, mut _ Window) {
				harness.selection_sum = payload[0] + payload[payload.len - 1]
			}
			has_source:          true
			caps:                caps
		}
	}) or { panic(err) }
	return expected_sum
}

fn start_lifetime_form_async_validation(mut w Window) {
	layout := make_lifetime_form_field_layout(lifetime_async_form_id, lifetime_async_form_field_id)
	form_cfg := FormCfg{
		id:          lifetime_async_form_id
		validate_on: .change
	}
	field_cfg := FormFieldAdapterCfg{
		field_id:             lifetime_async_form_field_id
		value:                'user@example.com'
		async_validators:     [FormAsyncValidator(lifetime_form_async_validator)]
		validate_on_override: .change
	}
	w.layout_callback_lifetime.lifetime.frame(fn [mut w, layout, form_cfg, field_cfg] () {
		w.form_apply_cfg(lifetime_async_form_id, form_cfg)
		w.form_register_field(layout, field_cfg)
		w.form_on_field_event(layout, field_cfg, .change)
	}) or { panic(err) }
}

fn start_lifetime_capturing_form_async_validation(mut w Window, seed int) string {
	layout := make_lifetime_form_field_layout(lifetime_async_form_id, lifetime_async_form_field_id)
	form_cfg := FormCfg{
		id:          lifetime_async_form_id
		validate_on: .change
	}
	expected_msg := '${lifetime_expected(seed)}'
	w.layout_callback_lifetime.lifetime.frame(fn [mut w, layout, form_cfg, seed] () {
		payload := []int{len: lifetime_payload_len, init: seed + index}
		validator := lifetime_capturing_form_async_validator(payload)
		field_cfg := FormFieldAdapterCfg{
			field_id:             lifetime_async_form_field_id
			value:                'user@example.com'
			async_validators:     [validator]
			validate_on_override: .change
		}
		w.form_apply_cfg(lifetime_async_form_id, form_cfg)
		w.form_register_field(layout, field_cfg)
		w.form_on_field_event(layout, field_cfg, .change)
	}) or { panic(err) }
	return expected_msg
}

fn start_lifetime_math_oversized_fetch(mut w Window) {
	latex := 'x'.repeat(max_latex_source_len + 1)
	request_id := u64(1)
	w.view_state.diagram_cache.set(lifetime_math_hash, DiagramCacheEntry{
		state:      .loading
		request_id: request_id
	})
	w.layout_callback_lifetime.lifetime.frame(fn [mut w, latex, request_id] () {
		fetch_math_async(mut w, latex, lifetime_math_hash, request_id, 120, rgba(0, 0, 0, 255))
	}) or { panic(err) }
}

fn start_lifetime_mermaid_oversized_fetch(mut w Window) {
	source := 'a'.repeat(max_mermaid_source_len + 1)
	request_id := u64(1)
	w.view_state.diagram_cache.set(lifetime_mermaid_hash, DiagramCacheEntry{
		state:      .loading
		request_id: request_id
	})
	w.layout_callback_lifetime.lifetime.frame(fn [mut w, source, request_id] () {
		fetch_mermaid_async(mut w, source, lifetime_mermaid_hash, request_id, 100, 255, 255, 255)
	}) or { panic(err) }
}

fn start_lifetime_image_invalid_download(mut w Window) {
	w.layout_callback_lifetime.lifetime.frame(fn [mut w] () {
		mut iv := ImageView{
			id:     'lifetime_image'
			src:    lifetime_image_invalid_url
			width:  16
			height: 16
		}
		_ = iv.generate_layout(mut w)
	}) or { panic(err) }
}

fn lifetime_sidebar_anim_id() string {
	return 'sidebar:${lifetime_sidebar_id}'
}

fn lifetime_sidebar_eased(progress f32, mix f32) f32 {
	return mix * progress * progress + (1 - mix) * progress
}

fn advance_lifetime_sidebar_tween(mut w Window, progress f32) {
	mut animation := w.animations[lifetime_sidebar_anim_id()] or {
		assert false, 'expected sidebar tween animation'
		return
	}
	match mut animation {
		TweenAnimation {
			assert animation.from == 0
			assert animation.to == 1
			assert f32_abs(animation.easing(0.5) - f32(0.5)) < f32(0.0001)
			animation.on_value(progress, mut w)
		}
		else {
			assert false, 'expected TweenAnimation'
		}
	}
}

fn lifetime_sidebar_runtime(mut w Window) SidebarRuntimeState {
	mut sm := state_map[string, SidebarRuntimeState](mut w, ns_sidebar, cap_few)
	return sm.get(lifetime_sidebar_id) or {
		assert false, 'expected sidebar runtime'
		return SidebarRuntimeState{}
	}
}

fn test_layout_lifetime_reclaims_old_capturing_callbacks_bounded() {
	mut w := make_lifetime_window()
	baseline := gc_memory_use()

	for i in 0 .. lifetime_rebuild_iterations {
		w.rebuild_lifetime_test_layout(i)
		if i % 50 == 0 {
			collect_and_churn_lifetime_test()
		}
	}
	collect_and_churn_lifetime_test()

	after := gc_memory_use()
	growth := if after > baseline { after - baseline } else { usize(0) }
	assert growth < lifetime_memory_max_growth

	layout_clear(mut w.layout)
	w.dispose_layout_callbacks()
}

fn test_zero_value_window_update_lazy_initializes_layout_lifetime() {
	mut w := Window{}
	w.window_size = gg.Size{
		width:  100
		height: 100
	}
	w.update_view(lifetime_zero_window_view_generator)

	w.update()
	w.update()
	collect_and_churn_lifetime_test()

	assert w.layout_callback_lifetime.initialized
	assert invoke_current_layout_click(mut w) == lifetime_expected(43)

	layout_clear(mut w.layout)
	w.dispose_layout_callbacks()
}

fn test_current_layout_survives_reclaim_one_frame() {
	mut w := make_lifetime_window()

	w.rebuild_lifetime_test_layout(7)
	collect_and_churn_lifetime_test()

	assert invoke_current_layout_click(mut w) == lifetime_expected(7)

	layout_clear(mut w.layout)
	w.dispose_layout_callbacks()
}

fn test_window_update_path_current_layout_survives_reclaim_one_frame() {
	mut state := &LifetimeUpdateState{
		seed: 11
	}
	mut w := make_lifetime_window()
	w.state = state
	w.view_generator = lifetime_update_view_generator

	w.update_lifetime_test_layout(11)
	w.update_lifetime_test_layout(12)
	collect_and_churn_lifetime_test()

	assert invoke_current_layout_click(mut w) == lifetime_expected(12)

	layout_clear(mut w.layout)
	w.dispose_layout_callbacks()
}

fn test_data_grid_quick_filter_debounce_uses_current_callback_after_reclaim() {
	mut state := &LifetimeDataGridDebounceState{
		seed: 51
		show: true
	}
	mut w := make_lifetime_window()
	w.state = state

	rebuild_lifetime_quick_filter_debounce_layout(mut w, state.seed, state.show)
	start_lifetime_quick_filter_debounce(mut w, 'needle')

	state.seed = 73
	rebuild_lifetime_quick_filter_debounce_layout(mut w, state.seed, state.show)
	collect_and_churn_lifetime_test()
	run_lifetime_quick_filter_debounce(mut w)

	assert state.call_count == 1
	assert state.callback_value == lifetime_expected(73)
	assert state.callback_text == 'needle'

	layout_clear(mut w.layout)
	w.animations.delete(lifetime_quick_filter_animation_id())
	w.dispose_layout_callbacks()
}

fn test_data_grid_quick_filter_debounce_stale_callback_keeps_current_payload() {
	mut state := &LifetimeDataGridDebounceState{
		seed: 61
		show: true
	}
	mut w := make_lifetime_window()
	w.state = state

	rebuild_lifetime_quick_filter_debounce_layout(mut w, state.seed, state.show)
	old_token := start_lifetime_quick_filter_debounce(mut w, 'old')
	mut stale_animation := lifetime_quick_filter_animate(&w)

	new_token := start_lifetime_quick_filter_debounce(mut w, 'new')
	assert old_token != new_token

	stale_animation.callback(mut stale_animation, mut w)
	assert state.call_count == 0
	assert lifetime_quick_filter_pending_token(&w) == new_token

	run_lifetime_quick_filter_debounce(mut w)
	assert state.call_count == 1
	assert state.callback_text == 'new'
	assert !lifetime_quick_filter_has_pending(&w)

	layout_clear(mut w.layout)
	w.animations.delete(lifetime_quick_filter_animation_id())
	w.dispose_layout_callbacks()
}

fn test_data_grid_quick_filter_debounce_clears_when_widget_disappears() {
	mut state := &LifetimeDataGridDebounceState{
		seed: 81
		show: true
	}
	mut w := make_lifetime_window()
	w.state = state

	rebuild_lifetime_quick_filter_debounce_layout(mut w, state.seed, state.show)
	start_lifetime_quick_filter_debounce(mut w, 'gone')

	state.show = false
	rebuild_lifetime_quick_filter_debounce_layout(mut w, state.seed, state.show)
	collect_and_churn_lifetime_test()
	run_lifetime_quick_filter_debounce(mut w)

	assert state.call_count == 0
	assert !lifetime_quick_filter_has_pending(&w)

	layout_clear(mut w.layout)
	w.animations.delete(lifetime_quick_filter_animation_id())
	w.dispose_layout_callbacks()
}

fn test_data_grid_source_spawn_created_during_update_survives_layout_reclaim() {
	mut state := &LifetimeAsyncSourceState{}
	state.grid_source = &InMemoryDataSource{
		rows:          lifetime_grid_rows()
		default_limit: 2
		latency_ms:    40
	}
	mut w := make_lifetime_window()

	start_lifetime_data_grid_source_request(mut w, state.grid_source)
	w.reclaim_old_layout_callbacks()
	w.layout_callback_lifetime.lifetime.frame(fn () {}) or { panic(err) }
	w.reclaim_old_layout_callbacks()
	collect_and_churn_lifetime_test()
	wait_for_lifetime_data_grid_source(mut w)

	stats := w.data_grid_source_stats(lifetime_async_grid_id)
	assert stats.request_count == 1
	assert stats.received_count == 2

	layout_clear(mut w.layout)
	w.dispose_layout_callbacks()
}

fn test_list_box_source_spawn_created_during_update_survives_layout_reclaim() {
	mut state := &LifetimeAsyncSourceState{}
	state.list_source = &InMemoryListBoxDataSource{
		data:       lifetime_list_options()
		latency_ms: 40
	}
	mut w := make_lifetime_window()

	start_lifetime_list_box_source_request(mut w, state.list_source)
	w.reclaim_old_layout_callbacks()
	w.layout_callback_lifetime.lifetime.frame(fn () {}) or { panic(err) }
	w.reclaim_old_layout_callbacks()
	collect_and_churn_lifetime_test()
	wait_for_lifetime_list_box_source(mut w)

	stats := w.list_box_source_stats(lifetime_async_list_id)
	assert stats.request_count == 1
	assert stats.received_count == 2

	layout_clear(mut w.layout)
	w.dispose_layout_callbacks()
}

fn test_inline_data_grid_source_callback_is_pinned_until_fetch_completion() {
	mut w := make_lifetime_window()

	expected := start_lifetime_capturing_data_grid_source_request(mut w, 101)
	assert w.layout_callback_lifetime.reclaim_pins == 1
	w.reclaim_old_layout_callbacks()
	assert w.layout_callback_lifetime.reclaim_pins == 1
	w.layout_callback_lifetime.lifetime.frame(fn () {}) or { panic(err) }
	w.reclaim_old_layout_callbacks()
	assert w.layout_callback_lifetime.reclaim_pins == 1
	collect_and_churn_lifetime_test()
	wait_for_lifetime_data_grid_source_value(mut w, expected)
	assert w.layout_callback_lifetime.reclaim_pins == 0

	layout_clear(mut w.layout)
	w.dispose_layout_callbacks()
}

fn test_inline_list_box_source_callback_is_pinned_until_fetch_completion() {
	mut w := make_lifetime_window()

	expected := start_lifetime_capturing_list_box_source_request(mut w, 103)
	assert w.layout_callback_lifetime.reclaim_pins == 1
	w.reclaim_old_layout_callbacks()
	assert w.layout_callback_lifetime.reclaim_pins == 1
	w.layout_callback_lifetime.lifetime.frame(fn () {}) or { panic(err) }
	w.reclaim_old_layout_callbacks()
	assert w.layout_callback_lifetime.reclaim_pins == 1
	collect_and_churn_lifetime_test()
	wait_for_lifetime_list_box_source_value(mut w, expected)
	assert w.layout_callback_lifetime.reclaim_pins == 0

	layout_clear(mut w.layout)
	w.dispose_layout_callbacks()
}

fn test_list_box_source_abort_drains_reclaim_pin() {
	mut w := make_lifetime_window()
	source := ListBoxDataSource(&LifetimeCallbackListSource{
		fetch_fn: fn (req ListBoxDataRequest) !ListBoxDataResult {
			data_grid_source_sleep_with_abort(req.signal, 200)!
			return ListBoxDataResult{}
		}
	})
	cfg := ListBoxCfg{
		id:          lifetime_async_list_id
		data_source: source
	}
	mut state := ListBoxSourceState{}
	list_box_source_start_request(cfg, 'lifetime-list-abort-before-fetch', mut state, mut w)
	mut sm := state_map[string, ListBoxSourceState](mut w, ns_list_box_source, cap_moderate)
	sm.set(lifetime_async_list_id, state)
	assert w.layout_callback_lifetime.reclaim_pins == 1

	mut active := state.active_abort
	active.abort()
	wait_for_lifetime_reclaim_pins(mut w, 0)

	layout_clear(mut w.layout)
	w.dispose_layout_callbacks()
}

fn test_data_grid_crud_save_pins_callbacks_until_completion() {
	mut w := make_lifetime_window()
	mut harness := &LifetimeCrudSaveHarness{}

	expected_sum := start_lifetime_capturing_crud_save(mut w, mut harness, 107)
	mut e := Event{}
	data_grid_crud_save(harness.ctx, mut e, mut w)
	assert e.is_handled
	assert w.layout_callback_lifetime.reclaim_pins == 1
	w.reclaim_old_layout_callbacks()
	assert w.layout_callback_lifetime.reclaim_pins == 1
	w.layout_callback_lifetime.lifetime.frame(fn () {}) or { panic(err) }
	w.reclaim_old_layout_callbacks()
	assert w.layout_callback_lifetime.reclaim_pins == 1
	collect_and_churn_lifetime_test()
	wait_for_lifetime_crud_save(mut w, harness, expected_sum)
	assert w.layout_callback_lifetime.reclaim_pins == 0
	assert harness.rows_change_sum == expected_sum
	assert harness.selection_sum == expected_sum
	assert harness.error_sum == 0

	layout_clear(mut w.layout)
	w.dispose_layout_callbacks()
}

fn test_form_async_validator_spawn_created_during_update_survives_layout_reclaim() {
	mut w := make_lifetime_window()

	start_lifetime_form_async_validation(mut w)
	w.reclaim_old_layout_callbacks()
	w.layout_callback_lifetime.lifetime.frame(fn () {}) or { panic(err) }
	w.reclaim_old_layout_callbacks()
	collect_and_churn_lifetime_test()
	wait_for_lifetime_form_async_validation(mut w)

	state := w.form_field_state(lifetime_async_form_id, lifetime_async_form_field_id) or {
		assert false, 'expected form field state'
		return
	}
	assert state.errors.len == 1
	assert state.errors[0].code == 'async'

	layout_clear(mut w.layout)
	w.dispose_layout_callbacks()
}

fn test_capturing_form_async_validator_created_during_update_survives_layout_reclaim() {
	mut w := make_lifetime_window()

	expected_msg := start_lifetime_capturing_form_async_validation(mut w, 89)
	assert w.layout_callback_lifetime.reclaim_pins == 1
	w.reclaim_old_layout_callbacks()
	assert w.layout_callback_lifetime.reclaim_pins == 1
	w.layout_callback_lifetime.lifetime.frame(fn () {}) or { panic(err) }
	w.reclaim_old_layout_callbacks()
	assert w.layout_callback_lifetime.reclaim_pins == 1
	collect_and_churn_lifetime_test()
	wait_for_lifetime_capturing_form_async_validation(mut w, expected_msg)
	assert w.layout_callback_lifetime.reclaim_pins == 0

	state := w.form_field_state(lifetime_async_form_id, lifetime_async_form_field_id) or {
		assert false, 'expected form field state'
		return
	}
	assert state.errors.len == 1
	assert state.errors[0].code == 'captured_async'
	assert state.errors[0].msg == expected_msg

	layout_clear(mut w.layout)
	w.dispose_layout_callbacks()
}

fn test_math_spawn_created_during_update_survives_layout_reclaim_without_network() {
	mut w := make_lifetime_window()

	start_lifetime_math_oversized_fetch(mut w)
	w.reclaim_old_layout_callbacks()
	w.layout_callback_lifetime.lifetime.frame(fn () {}) or { panic(err) }
	w.reclaim_old_layout_callbacks()
	collect_and_churn_lifetime_test()
	wait_for_lifetime_math_oversized_error(mut w)

	entry := w.view_state.diagram_cache.get(lifetime_math_hash) or {
		assert false, 'expected math cache entry'
		return
	}
	assert entry.state == .error
	assert entry.error == 'LaTeX source too large'

	w.view_state.diagram_cache.clear()
	layout_clear(mut w.layout)
	w.dispose_layout_callbacks()
}

fn test_mermaid_spawn_created_during_update_survives_layout_reclaim() {
	mut w := make_lifetime_window()

	start_lifetime_mermaid_oversized_fetch(mut w)
	w.reclaim_old_layout_callbacks()
	w.layout_callback_lifetime.lifetime.frame(fn () {}) or { panic(err) }
	w.reclaim_old_layout_callbacks()
	collect_and_churn_lifetime_test()
	wait_for_lifetime_mermaid_oversized_error(mut w)

	entry := w.view_state.diagram_cache.get(lifetime_mermaid_hash) or {
		assert false, 'expected mermaid cache entry'
		return
	}
	assert entry.state == .error
	assert entry.error == 'Mermaid source too large'

	w.view_state.diagram_cache.clear()
	layout_clear(mut w.layout)
	w.dispose_layout_callbacks()
}

fn test_image_download_spawn_created_during_layout_survives_reclaim_without_network() {
	mut w := make_lifetime_window()

	start_lifetime_image_invalid_download(mut w)
	mut downloads := state_map[string, i64](mut w, ns_active_downloads, cap_moderate)
	assert downloads.contains(lifetime_image_invalid_url)
	w.reclaim_old_layout_callbacks()
	w.layout_callback_lifetime.lifetime.frame(fn () {}) or { panic(err) }
	w.reclaim_old_layout_callbacks()
	collect_and_churn_lifetime_test()
	wait_for_lifetime_image_download_cleanup(mut w)

	layout_clear(mut w.layout)
	w.dispose_layout_callbacks()
}

fn test_persistent_animation_created_during_update_survives_reclaim() {
	mut state := &LifetimeUpdateState{
		seed:          21
		add_animation: true
	}
	mut w := make_lifetime_window()
	w.state = state
	w.view_generator = lifetime_update_view_generator

	w.update_lifetime_test_layout(21)
	w.update_lifetime_test_layout(22)
	collect_and_churn_lifetime_test()

	mut animation := w.animations[lifetime_persistent_animation_id] or {
		assert false, 'expected persistent animation'
		return
	}
	match mut animation {
		Animate {
			animation.callback(mut animation, mut w)
		}
		else {
			assert false, 'expected Animate'
		}
	}

	assert state.animation_value == lifetime_expected(21)

	layout_clear(mut w.layout)
	array_clear(mut w.renderers)
	w.animations.delete(lifetime_persistent_animation_id)
	w.dispose_layout_callbacks()
}

fn test_sidebar_custom_tween_easing_created_during_layout_survives_reclaim() {
	mut state := &LifetimeSidebarState{
		easing_mix: 0.5
	}
	mut w := make_lifetime_window()
	w.state = state
	w.view_generator = lifetime_sidebar_view_generator

	w.update()
	state.open = true
	w.update()
	advance_lifetime_sidebar_tween(mut w, 0.5)
	w.reclaim_old_layout_callbacks()
	w.layout_callback_lifetime.lifetime.frame(fn () {}) or { panic(err) }
	w.reclaim_old_layout_callbacks()
	collect_and_churn_lifetime_test()
	w.update()

	want := f32(100) * lifetime_sidebar_eased(0.5, state.easing_mix)
	assert f32_abs(state.width - want) < f32(0.0001)

	w.animations.delete(lifetime_sidebar_anim_id())
	layout_clear(mut w.layout)
	w.dispose_layout_callbacks()
}

fn test_sidebar_tween_interrupt_close_starts_from_resolved_visual_fraction() {
	mut state := &LifetimeSidebarState{
		easing_mix: 0.5
	}
	mut w := make_lifetime_window()
	w.state = state
	w.view_generator = lifetime_sidebar_view_generator

	w.update()
	state.open = true
	w.update()
	advance_lifetime_sidebar_tween(mut w, 0.5)
	w.update()

	mid_frac := lifetime_sidebar_eased(0.5, state.easing_mix)
	assert f32_abs(state.width - f32(100) * mid_frac) < f32(0.0001)

	state.open = false
	w.update()

	rt := lifetime_sidebar_runtime(mut w)
	assert rt.tween_active
	assert f32_abs(rt.tween_progress) < f32(0.0001)
	assert f32_abs(rt.tween_from - mid_frac) < f32(0.0001)
	assert f32_abs(rt.tween_to) < f32(0.0001)
	assert f32_abs(state.width - f32(100) * mid_frac) < f32(0.0001)

	advance_lifetime_sidebar_tween(mut w, 0.5)
	w.update()
	want := f32(100) * lerp(mid_frac, 0, lifetime_sidebar_eased(0.5, state.easing_mix))
	assert f32_abs(state.width - want) < f32(0.0001)

	w.animations.delete(lifetime_sidebar_anim_id())
	layout_clear(mut w.layout)
	w.dispose_layout_callbacks()
}

fn test_indefinite_progress_animation_created_during_layout_survives_reclaim() {
	mut w := make_lifetime_window()
	w.view_generator = lifetime_progress_view_generator

	w.update()
	w.update()
	collect_and_churn_lifetime_test()

	mut animation := w.animations[lifetime_progress_animation_id] or {
		assert false, 'expected progress animation'
		return
	}
	match mut animation {
		KeyframeAnimation {
			animation.on_value(0.625, mut w)
		}
		else {
			assert false, 'expected KeyframeAnimation'
		}
	}

	progress := state_map[string, f32](mut w, ns_progress, cap_moderate).get(lifetime_progress_id) or {
		f32(-1)
	}
	assert progress == f32(0.625)

	layout_clear(mut w.layout)
	array_clear(mut w.renderers)
	w.animations.delete(lifetime_progress_animation_id)
	w.dispose_layout_callbacks()
}

fn test_persistent_animation_created_during_hover_survives_layout_reclaim() {
	mut state := &LifetimeUpdateState{
		seed: 37
	}
	mut w := make_lifetime_window()
	w.state = state
	w.view_generator = lifetime_hover_view_generator
	w.ui = &gg.Context{
		mouse_pos_x: 10
		mouse_pos_y: 10
		width:       100
		height:      100
	}

	w.update_lifetime_test_layout(37)
	w.update_lifetime_test_layout(38)
	w.update_lifetime_test_layout(39)
	collect_and_churn_lifetime_test()

	mut animation := w.animations[lifetime_hover_animation_id] or {
		assert false, 'expected hover animation'
		return
	}
	match mut animation {
		Animate {
			animation.callback(mut animation, mut w)
		}
		else {
			assert false, 'expected Animate'
		}
	}

	assert state.animation_value == lifetime_expected(37)

	layout_clear(mut w.layout)
	array_clear(mut w.renderers)
	w.animations.delete(lifetime_hover_animation_id)
	w.dispose_layout_callbacks()
}

fn test_layout_lifetime_cleanup_disposes_after_frames() {
	mut w := make_lifetime_window()
	for i in 0 .. 8 {
		w.rebuild_lifetime_test_layout(i)
	}
	layout_clear(mut w.layout)
	array_clear(mut w.renderers)
	w.dispose_layout_callbacks()
	w.dispose_layout_callbacks()
	w.reclaim_old_layout_callbacks()
	collect_and_churn_lifetime_test()
	assert true
}

fn test_mouse_lock_callback_created_during_frame_survives_layout_reclaim() {
	mut w := make_lifetime_window()
	mut state := &LifetimeMouseLockState{}
	w.layout_callback_lifetime.lifetime.frame(fn [mut state] () {
		payload := []int{len: lifetime_payload_len, init: 31 + index}
		state.cfg = MouseLockCfg{
			mouse_move: fn [payload] (_ &Layout, mut e Event, mut _ Window) {
				e.frame_count = u64(payload[0] + payload[payload.len - 1])
				e.is_handled = true
			}
		}
	}) or { panic(err) }
	w.mouse_lock(state.cfg)
	assert w.layout_callback_lifetime.reclaim_pins == 1

	for i in 0 .. 32 {
		w.rebuild_lifetime_test_layout(i)
		assert w.layout_callback_lifetime.reclaim_pins == 1
	}
	collect_and_churn_lifetime_test()

	mut e := Event{}
	mouse_move_handler(w.layout, mut e, mut w)
	assert e.is_handled
	assert int(e.frame_count) == lifetime_expected(31)

	w.mouse_unlock()
	assert w.layout_callback_lifetime.reclaim_pins == 0
	layout_clear(mut w.layout)
	w.dispose_layout_callbacks()
}

fn test_mouse_lock_unlock_during_handler_defers_reclaim_pin_release() {
	mut w := make_lifetime_window()
	mut state := &LifetimeMouseLockState{}
	w.layout_callback_lifetime.lifetime.frame(fn [mut state] () {
		payload := []int{len: lifetime_payload_len, init: 43 + index}
		state.cfg = MouseLockCfg{
			mouse_up: fn [payload] (_ &Layout, mut e Event, mut w Window) {
				w.mouse_unlock()
				assert w.layout_callback_lifetime.reclaim_pins == 1
				assert w.view_state.mouse_lock_release_pending == 1
				w.reclaim_old_layout_callbacks()
				w.layout_callback_lifetime.lifetime.frame(fn () {}) or { panic(err) }
				w.reclaim_old_layout_callbacks()
				collect_and_churn_lifetime_test()
				e.frame_count = u64(payload[0] + payload[payload.len - 1])
				e.is_handled = true
			}
		}
	}) or { panic(err) }
	w.mouse_lock(state.cfg)
	assert w.layout_callback_lifetime.reclaim_pins == 1

	mut e := Event{}
	mouse_up_handler(w.layout, mut e, mut w)
	assert e.is_handled
	assert int(e.frame_count) == lifetime_expected(43)
	assert w.layout_callback_lifetime.reclaim_pins == 0
	assert w.view_state.mouse_lock_release_pending == 0

	layout_clear(mut w.layout)
	w.dispose_layout_callbacks()
}

fn test_mouse_lock_replacement_and_double_unlock_balance_reclaim_pins() {
	mut w := make_lifetime_window()
	w.mouse_lock(MouseLockCfg{})
	assert w.layout_callback_lifetime.reclaim_pins == 0

	w.mouse_lock(MouseLockCfg{
		mouse_move: fn (_ &Layout, mut e Event, mut _ Window) {
			e.frame_count = 1
			e.is_handled = true
		}
	})
	assert w.layout_callback_lifetime.reclaim_pins == 1

	w.mouse_lock(MouseLockCfg{
		mouse_move: fn (_ &Layout, mut e Event, mut _ Window) {
			e.frame_count = 2
			e.is_handled = true
		}
	})
	assert w.layout_callback_lifetime.reclaim_pins == 1

	w.mouse_lock(MouseLockCfg{})
	assert w.layout_callback_lifetime.reclaim_pins == 0
	w.mouse_unlock()
	assert w.layout_callback_lifetime.reclaim_pins == 0
	w.dispose_layout_callbacks()
}

fn test_mouse_lock_zero_value_window_balances_reclaim_pins() {
	mut w := Window{}
	w.mouse_lock(MouseLockCfg{
		mouse_move: fn (_ &Layout, mut e Event, mut _ Window) {
			e.is_handled = true
		}
	})
	assert w.layout_callback_lifetime.reclaim_pins == 1
	assert w.layout_callback_lifetime.initialized
	assert w.mouse_is_locked()

	w.mouse_unlock()
	assert w.layout_callback_lifetime.reclaim_pins == 0
	assert !w.mouse_is_locked()

	w.mouse_unlock()
	assert w.layout_callback_lifetime.reclaim_pins == 0
	assert !w.mouse_is_locked()
}

fn test_animation_add_from_layout_zero_value_window_initializes_lifetime() {
	mut w := Window{}
	mut state := &LifetimeAnimationLayoutState{}
	w.animation_add_from_layout(fn [mut state] () {
		state.called = true
	}) or { panic(err) }

	assert w.layout_callback_lifetime.initialized
	assert state.called
	w.dispose_layout_callbacks()
}

fn test_mouse_lock_unlock_after_dispose_pending_releases_lifetime() {
	mut w := make_lifetime_window()
	w.mouse_lock(MouseLockCfg{
		mouse_move: fn (_ &Layout, mut e Event, mut _ Window) {
			e.is_handled = true
		}
	})
	assert w.layout_callback_lifetime.reclaim_pins == 1

	w.dispose_layout_callbacks()
	assert w.layout_callback_lifetime.reclaim_pins == 1
	assert w.layout_callback_lifetime.dispose_pending
	assert !w.layout_callback_lifetime.disposed

	w.mouse_unlock()
	assert w.layout_callback_lifetime.reclaim_pins == 0
	assert !w.layout_callback_lifetime.dispose_pending
	assert w.layout_callback_lifetime.disposed

	w.mouse_lock(MouseLockCfg{
		mouse_move: fn (_ &Layout, mut e Event, mut _ Window) {
			e.is_handled = true
		}
	})
	assert !w.mouse_is_locked()
	assert w.layout_callback_lifetime.reclaim_pins == 0

	w.mouse_unlock()
	assert w.layout_callback_lifetime.reclaim_pins == 0
}

fn test_mouse_lock_replacement_during_dispatch_keeps_new_lock_pinned() {
	mut w := make_lifetime_window()
	w.mouse_lock(MouseLockCfg{
		mouse_move: fn (_ &Layout, mut e Event, mut w Window) {
			w.mouse_lock(MouseLockCfg{
				mouse_up: fn (_ &Layout, mut e Event, mut _ Window) {
					e.frame_count = 2
					e.is_handled = true
				}
			})
			e.frame_count = 1
			e.is_handled = true
		}
	})
	assert w.layout_callback_lifetime.reclaim_pins == 1

	mut move_event := Event{}
	mouse_move_handler(w.layout, mut move_event, mut w)
	assert move_event.is_handled
	assert move_event.frame_count == 1
	assert w.layout_callback_lifetime.reclaim_pins == 1
	assert w.view_state.mouse_lock_release_pending == 0

	mut up_event := Event{}
	mouse_up_handler(w.layout, mut up_event, mut w)
	assert up_event.is_handled
	assert up_event.frame_count == 2
	w.mouse_unlock()
	assert w.layout_callback_lifetime.reclaim_pins == 0
	w.mouse_unlock()
	assert w.layout_callback_lifetime.reclaim_pins == 0

	layout_clear(mut w.layout)
	w.dispose_layout_callbacks()
}

fn test_mouse_lock_clear_view_state_during_dispatch_defers_pin_release() {
	mut w := make_lifetime_window()
	w.mouse_lock(MouseLockCfg{
		mouse_up: fn (_ &Layout, mut e Event, mut w Window) {
			w.clear_view_state()
			assert w.layout_callback_lifetime.reclaim_pins == 1
			assert w.view_state.mouse_lock_release_pending == 1
			e.is_handled = true
		}
	})
	assert w.layout_callback_lifetime.reclaim_pins == 1

	mut e := Event{}
	mouse_up_handler(w.layout, mut e, mut w)
	assert e.is_handled
	assert w.layout_callback_lifetime.reclaim_pins == 0
	assert w.view_state.mouse_lock_release_pending == 0

	w.dispose_layout_callbacks()
}

fn test_animation_add_from_layout_is_public_fallible_api() {
	$if windows {
		return
	}
	tmp_dir := os.join_path(os.temp_dir(), 'gui_animation_layout_api_${os.getpid()}')
	os.rmdir_all(tmp_dir) or {}
	os.mkdir_all(tmp_dir) or { panic(err) }
	defer {
		os.rmdir_all(tmp_dir) or {}
	}

	repo_dir := os.dir(@FILE)
	os.symlink(repo_dir, os.join_path(tmp_dir, 'gui')) or { panic(err) }
	source_path := os.join_path(tmp_dir, 'main.v')
	source := 'import gui\n\n' + 'fn main() {\n' + '\tmut w := gui.Window{}\n' +
		'\tw.animation_add_from_layout(fn [mut w] () {\n' + '\t\tw.animation_add(mut gui.Animate{\n' + "\t\t\tid:       'external_layout_animation'\n" + '\t\t\tcallback: fn (mut _ gui.Animate, mut _ gui.Window) {}\n' +
		'\t\t})\n' + '\t}) or { panic(err) }\n' + '}\n'
	os.write_file(source_path, source) or { panic(err) }

	cmd := '${os.quoted_path(@VEXE)} -path "${tmp_dir}|@vlib|@vmodules" -check ${os.quoted_path(source_path)}'
	res := os.execute(cmd)
	assert res.exit_code == 0, res.output
}
