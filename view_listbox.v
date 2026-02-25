module gui

import strings

// ListBoxCfg configures a [list_box](#list_box) view.
// `selected_ids` is a list of selected item ids.
@[minify]
pub struct ListBoxCfg {
	A11yCfg
pub:
	id               string
	sizing           Sizing
	text_style       TextStyle = gui_theme.list_box_style.text_style
	subheading_style TextStyle = gui_theme.list_box_style.subheading_style
	color            Color     = gui_theme.list_box_style.color
	color_hover      Color     = gui_theme.list_box_style.color_hover
	color_border     Color     = gui_theme.list_box_style.color_border
	color_select     Color     = gui_theme.list_box_style.color_select
	padding          Padding   = gui_theme.list_box_style.padding
	selected_ids     []string // selected item ids
	data             []ListBoxOption
	data_source      ?ListBoxDataSource
	source_key       string
	query            string
	loading          bool
	load_error       string
	on_select        fn (ids []string, mut e Event, mut w Window) = unsafe { nil }
	height           f32
	min_width        f32
	max_width        f32
	min_height       f32
	max_height       f32
	radius           f32 = gui_theme.list_box_style.radius
	radius_border    f32 = gui_theme.list_box_style.radius_border
	id_scroll        u32
	multiple         bool // allow multiple selections
	reorderable      bool // enable drag-to-reorder
	on_reorder       fn (string, string, mut Window) = unsafe { nil }
	size_border      f32 = gui_theme.list_box_style.size_border
	id_focus         u32
}

// ListBoxOption is the data for a row in a [list_box](#list_box).
// See [list_box_option](#list_box_option) helper method.
pub struct ListBoxOption {
pub:
	id            string
	name          string
	value         string
	is_subheading bool
}

// ListBoxDataRequest is passed to ListBoxDataSource.fetch_data.
// Reuses GridAbortSignal/GridAbortController from data_source.v
// as shared cancellation primitives.
@[minify]
pub struct ListBoxDataRequest {
pub:
	list_box_id string
	query       string
	signal      &GridAbortSignal = unsafe { nil }
	request_id  u64
}

@[minify]
pub struct ListBoxDataResult {
pub:
	data []ListBoxOption
}

pub interface ListBoxDataSource {
	fetch_data(req ListBoxDataRequest) !ListBoxDataResult
}

@[heap; minify]
pub struct InMemoryListBoxDataSource {
pub mut:
	data []ListBoxOption
pub:
	latency_ms int
}

pub fn (source InMemoryListBoxDataSource) fetch_data(req ListBoxDataRequest) !ListBoxDataResult {
	data_grid_source_sleep_with_abort(req.signal, source.latency_ms)!
	filtered := list_box_source_apply_query(source.data, req.query)
	grid_abort_check(req.signal)!
	return ListBoxDataResult{
		data: filtered
	}
}

pub struct ListBoxSourceStats {
pub:
	loading          bool
	load_error       string
	request_count    int
	cancelled_count  int
	stale_drop_count int
	received_count   int
}

// list_box builds a list box without viewport virtualization.
// Use [Window.list_box](#list_box) for virtualization support.
pub fn list_box(cfg ListBoxCfg) View {
	last := if cfg.data.len > 0 { cfg.data.len - 1 } else { -1 }
	can_reorder := cfg.reorderable && cfg.on_reorder != unsafe { nil }
	return list_box_from_range(0, last, cfg, false, f32(0), DragReorderState{}, can_reorder)
}

// list_box is a convenience view for simple cases. See [ListBoxCfg](#ListBoxCfg).
// Virtualization is enabled only when `id_scroll > 0` and bounded height exists.
pub fn (mut window Window) list_box(cfg ListBoxCfg) View {
	resolved_cfg, _ := list_box_resolve_source_cfg(cfg, mut window)
	can_reorder := resolved_cfg.reorderable && resolved_cfg.on_reorder != unsafe { nil }
	if can_reorder {
		mut item_ids := []string{cap: resolved_cfg.data.len}
		for dat in resolved_cfg.data {
			if !dat.is_subheading {
				item_ids << dat.id
			}
		}
		drag_reorder_ids_meta_set(mut window, resolved_cfg.id, item_ids)
	}
	last_row_idx := resolved_cfg.data.len - 1
	list_height := list_box_height(resolved_cfg)
	virtualize := resolved_cfg.id_scroll > 0 && list_height > 0 && resolved_cfg.data.len > 0
	row_height := if virtualize {
		list_box_estimate_row_height(resolved_cfg, mut window)
	} else {
		f32(0)
	}
	first_visible, last_visible := if virtualize {
		list_box_visible_range(list_height, row_height, resolved_cfg, mut window)
	} else {
		0, last_row_idx
	}

	drag_state := if can_reorder {
		drag_reorder_get(mut window, resolved_cfg.id)
	} else {
		DragReorderState{}
	}
	return list_box_from_range(first_visible, last_visible, resolved_cfg, virtualize,
		row_height, drag_state, can_reorder)
}

fn list_box_from_range(first_visible int, last_visible int, cfg ListBoxCfg, virtualize bool, row_height f32, drag DragReorderState, can_reorder bool) View {
	last_row_idx := cfg.data.len - 1
	spacer_row_height := if row_height > 0 {
		row_height
	} else {
		list_box_estimate_row_height_no_window(cfg)
	}
	dragging := can_reorder && drag.active && !drag.cancelled
	// Build non-subheading item IDs for drag index mapping.
	// item_ids covers ALL items (needed for on_reorder callback).
	// item_layout_ids covers only visible items so that
	// item_mids_from_layouts succeeds for virtualized lists.
	mut item_ids := []string{}
	mut item_layout_ids := []string{}
	mut global_drag_idx_by_row := []int{}
	mut draggable_count := 0
	mut mids_offset := 0
	if can_reorder {
		item_ids = []string{cap: cfg.data.len}
		visible_cap := last_visible - first_visible + 1
		item_layout_ids = []string{cap: visible_cap}
		global_drag_idx_by_row = []int{len: cfg.data.len, init: -1}
		mut found_first_visible := false
		for idx, dat in cfg.data {
			if !dat.is_subheading {
				item_ids << dat.id
				in_visible := idx >= first_visible && idx <= last_visible
				if in_visible {
					item_layout_ids << 'lb_${cfg.id}_${dat.id}'
					if !found_first_visible {
						mids_offset = draggable_count
						found_first_visible = true
					}
				}
				global_drag_idx_by_row[idx] = draggable_count
				draggable_count++
			}
		}
	}
	on_reorder := cfg.on_reorder
	mut list := []View{cap: (last_visible - first_visible + 1) + 4}

	if cfg.loading && cfg.data.len == 0 {
		list << list_box_source_status_row(cfg, gui_locale.str_loading)
	}
	if cfg.load_error.len > 0 && cfg.data.len == 0 {
		list << list_box_source_status_row(cfg, '${gui_locale.str_load_error}: ${cfg.load_error}')
	}

	if virtualize && first_visible > 0 {
		list << rectangle(
			name:   'list_box spacer top'
			color:  color_transparent
			height: f32(first_visible) * spacer_row_height
			sizing: fill_fixed
		)
	}

	mut ghost_content := View(rectangle(RectangleCfg{}))
	for idx in first_visible .. last_visible + 1 {
		if idx < 0 || idx >= cfg.data.len {
			continue
		}
		dat := cfg.data[idx]
		item_drag_idx := if global_drag_idx_by_row.len > 0 {
			global_drag_idx_by_row[idx]
		} else {
			-1
		}
		is_draggable := can_reorder && item_drag_idx >= 0

		// Insert gap spacer at the current drop target.
		if dragging && is_draggable && item_drag_idx == drag.current_index {
			list << drag_reorder_gap_view(drag, .vertical)
		}

		if dragging && is_draggable && item_drag_idx == drag.source_index {
			// Capture content for ghost; skip from normal flow.
			ghost_content = list_box_item_content(dat, cfg)
		} else {
			list << list_box_item_view(dat, cfg, item_drag_idx, item_ids, item_layout_ids,
				mids_offset, on_reorder, can_reorder)
		}
	}
	// Gap at end if dropping past last item.
	if dragging && drag.current_index >= draggable_count {
		list << drag_reorder_gap_view(drag, .vertical)
	}

	if virtualize && last_visible < last_row_idx {
		remaining := last_row_idx - last_visible
		list << rectangle(
			name:   'list_box spacer bottom'
			color:  color_transparent
			height: f32(remaining) * spacer_row_height
			sizing: fill_fixed
		)
	}

	// Append floating ghost during active drag.
	if dragging {
		list << drag_reorder_ghost_view(drag, ghost_content)
	}

	// Build value_text for a11y.
	mut value_builder := strings.new_builder(0)
	for dat in cfg.data {
		if dat.id !in cfg.selected_ids {
			continue
		}
		if value_builder.len > 0 {
			value_builder.write_string(', ')
		}
		value_builder.write_string(dat.name)
	}
	list_label := a11y_label(cfg.a11y_label, cfg.id)
	list_value_text := value_builder.str()
	mut list_a11y := make_a11y_info(list_label, cfg.a11y_description)
	if list_value_text.len > 0 {
		list_a11y = &AccessInfo{
			label:       list_label
			description: cfg.a11y_description
			value_text:  list_value_text
		}
	}
	list_box_id := cfg.id
	is_multiple := cfg.multiple
	on_select := cfg.on_select
	selected_ids := cfg.selected_ids
	reorderable := can_reorder
	return column(
		name:         'list_box'
		a11y_role:    .list
		a11y:         list_a11y
		id_focus:     cfg.id_focus
		id_scroll:    cfg.id_scroll
		on_keydown:   fn [list_box_id, item_ids, is_multiple, on_select, selected_ids, reorderable, on_reorder] (_ &Layout, mut e Event, mut w Window) {
			list_box_on_keydown(list_box_id, item_ids, is_multiple, on_select, selected_ids,
				reorderable, on_reorder, mut e, mut w)
		}
		width:        cfg.max_width
		height:       cfg.height
		min_width:    cfg.min_width
		max_width:    cfg.max_width
		min_height:   cfg.min_height
		max_height:   cfg.max_height
		color:        cfg.color
		color_border: cfg.color_border
		size_border:  cfg.size_border
		radius:       cfg.radius
		padding:      cfg.padding
		sizing:       cfg.sizing
		spacing:      0
		content:      list
	)
}

fn list_box_item_view(dat ListBoxOption, cfg ListBoxCfg, drag_index int, item_ids []string, item_layout_ids []string, mids_offset int, on_reorder fn (string, string, mut Window), can_reorder bool) View {
	color := if dat.id in cfg.selected_ids {
		cfg.color_select
	} else {
		color_transparent
	}
	is_sub := dat.is_subheading
	content := list_box_item_content(dat, cfg)

	dat_id := dat.id
	is_multiple := cfg.multiple
	on_select := cfg.on_select
	has_on_select := on_select != unsafe { nil }
	selected_ids := cfg.selected_ids
	color_hover := cfg.color_hover
	reorderable := can_reorder && !is_sub
	list_box_id := cfg.id

	item_a11y_state := if dat.id in cfg.selected_ids {
		AccessState.selected
	} else {
		AccessState.none
	}
	id_scroll := cfg.id_scroll
	on_click_fn := if reorderable {
		make_list_box_drag_click(list_box_id, dat_id, drag_index, item_ids, on_reorder,
			item_layout_ids, mids_offset, id_scroll, is_multiple, on_select, has_on_select,
			selected_ids)
	} else {
		fn [is_multiple, on_select, has_on_select, selected_ids, dat_id, is_sub] (_ &Layout, mut e Event, mut w Window) {
			if has_on_select && !is_sub {
				ids := list_box_next_selected_ids(selected_ids, dat_id, is_multiple)
				on_select(ids, mut e, mut w)
			}
		}
	}
	return row(
		name:       'list_box option'
		id:         if reorderable { 'lb_${list_box_id}_${dat_id}' } else { '' }
		a11y_role:  .list_item
		a11y_label: dat.name
		a11y_state: item_a11y_state
		color:      color
		padding:    padding_two_five
		sizing:     fill_fit
		content:    [content]
		on_click:   on_click_fn
		on_hover:   fn [has_on_select, color_hover, is_sub] (mut layout Layout, mut e Event, mut w Window) {
			if has_on_select && !is_sub {
				w.set_mouse_cursor_pointing_hand()
				if layout.shape.color == color_transparent {
					layout.shape.color = color_hover
				}
			}
		}
	)
}

// list_box_item_content builds the inner content view for a
// listbox item (text or subheading).
fn list_box_item_content(dat ListBoxOption, cfg ListBoxCfg) View {
	if dat.is_subheading {
		return column(
			spacing: 1
			padding: padding_none
			sizing:  fill_fit
			content: [
				text(
					text:       dat.name
					text_style: cfg.subheading_style
				),
				row(
					padding: padding_none
					sizing:  fill_fit
					content: [
						rectangle(
							width:  1
							height: 1
							sizing: fill_fit
							color:  cfg.subheading_style.color
						),
					]
				),
			]
		)
	}
	return text(
		text:       dat.name
		mode:       .multiline
		text_style: cfg.text_style
	)
}

// make_list_box_drag_click creates an on_click handler that
// initiates drag-reorder or falls back to selection.
fn make_list_box_drag_click(list_box_id string, dat_id string,
	drag_index int, item_ids []string,
	on_reorder fn (string, string, mut Window),
	item_layout_ids []string,
	mids_offset int,
	id_scroll u32,
	is_multiple bool,
	on_select fn ([]string, mut Event, mut Window),
	has_on_select bool,
	selected_ids []string) fn (&Layout, mut Event, mut Window) {
	return fn [list_box_id, dat_id, drag_index, item_ids, on_reorder, item_layout_ids, mids_offset, id_scroll, is_multiple, on_select, has_on_select, selected_ids] (layout &Layout, mut e Event, mut w Window) {
		drag_reorder_start(list_box_id, drag_index, dat_id, .vertical, item_ids, on_reorder,
			item_layout_ids, mids_offset, id_scroll, layout, e, mut w)
		// Set keyboard focus index so Alt+Arrow works after click.
		mut lbf := state_map[string, int](mut w, ns_list_box_focus, cap_moderate)
		lbf.set(list_box_id, drag_index)
		// Also fire selection.
		if has_on_select {
			ids := list_box_next_selected_ids(selected_ids, dat_id, is_multiple)
			on_select(ids, mut e, mut w)
		}
	}
}

fn list_box_next_selected_ids(selected_ids []string, dat_id string, is_multiple bool) []string {
	if !is_multiple {
		return [dat_id]
	}
	if dat_id in selected_ids {
		mut next := []string{cap: int_max(0, selected_ids.len - 1)}
		for id in selected_ids {
			if id != dat_id {
				next << id
			}
		}
		return next
	}
	mut next := []string{cap: selected_ids.len + 1}
	next << selected_ids
	next << dat_id
	return next
}

fn list_box_height(cfg ListBoxCfg) f32 {
	return if cfg.height > 0 { cfg.height } else { cfg.max_height }
}

fn list_box_estimate_row_height(cfg ListBoxCfg, mut window Window) f32 {
	text_h := list_box_font_height(cfg.text_style, mut window)
	sub_h := list_box_font_height(cfg.subheading_style, mut window)
	return f32_max(text_h, sub_h) + padding_two_five.height()
}

fn list_box_estimate_row_height_no_window(cfg ListBoxCfg) f32 {
	h1 := list_core_row_height_estimate(cfg.text_style, padding_two_five)
	h2 := list_core_row_height_estimate(cfg.subheading_style, padding_two_five)
	return f32_max(h1, h2)
}

fn list_box_font_height(style TextStyle, mut window Window) f32 {
	if isnil(window.text_system) {
		return style.size
	}
	vg_cfg := style.to_vglyph_cfg()
	return window.text_system.font_height(vg_cfg) or { style.size }
}

fn list_box_visible_range(list_height f32, row_height f32, cfg ListBoxCfg, mut window Window) (int, int) {
	mut sy := state_map[u32, f32](mut window, ns_scroll_y, cap_scroll)
	scroll_y := sy.get(cfg.id_scroll) or { f32(0) }
	return list_core_visible_range(cfg.data.len, row_height, list_height, scroll_y)
}

pub fn (window &Window) list_box_source_stats(list_box_id string) ListBoxSourceStats {
	sm := state_map_read[string, ListBoxSourceState](window, ns_list_box_source) or {
		return ListBoxSourceStats{}
	}
	if state := sm.get(list_box_id) {
		return ListBoxSourceStats{
			loading:          state.loading
			load_error:       state.load_error
			request_count:    state.request_count
			cancelled_count:  state.cancelled_count
			stale_drop_count: state.stale_drop_count
			received_count:   state.received_count
		}
	}
	return ListBoxSourceStats{}
}

pub fn (mut window Window) list_box_source_force_refetch(list_box_id string) {
	list_box_source_force_refetch(list_box_id, mut window)
}

fn list_box_source_force_refetch(list_box_id string, mut window Window) {
	mut sm := state_map[string, ListBoxSourceState](mut window, ns_list_box_source, cap_moderate)
	mut state := sm.get(list_box_id) or { return }
	if state.loading && !isnil(state.active_abort) {
		mut active := state.active_abort
		active.abort()
		state.cancelled_count++
		state.loading = false
	}
	state.request_key = ''
	state.load_error = ''
	sm.set(list_box_id, state)
	window.update_window()
}

fn list_box_source_status_row(cfg ListBoxCfg, message string) View {
	return row(
		name:    'list_box source status row'
		sizing:  fill_fit
		padding: padding_two_five
		content: [
			text(
				text:       message
				mode:       .single_line
				text_style: cfg.text_style
			),
		]
	)
}

fn list_box_has_source(cfg ListBoxCfg) bool {
	return cfg.data_source != none
}

fn list_box_resolve_source_cfg(cfg ListBoxCfg, mut window Window) (ListBoxCfg, bool) {
	if !list_box_has_source(cfg) {
		return cfg, false
	}
	if cfg.id.len == 0 {
		load_error := if cfg.load_error.len > 0 {
			cfg.load_error
		} else {
			'id is required when data_source is set'
		}
		return ListBoxCfg{
			...cfg
			data:       []ListBoxOption{}
			loading:    false
			load_error: load_error
		}, true
	}
	state := list_box_source_resolve_state(cfg, mut window)
	data := if state.data_dirty { state.data.clone() } else { state.data }
	load_error := if cfg.load_error.len > 0 { cfg.load_error } else { state.load_error }
	return ListBoxCfg{
		...cfg
		data:       data
		loading:    cfg.loading || state.loading
		load_error: load_error
	}, true
}

fn list_box_source_resolve_state(cfg ListBoxCfg, mut window Window) ListBoxSourceState {
	mut sm := state_map[string, ListBoxSourceState](mut window, ns_list_box_source, cap_moderate)
	mut state := sm.get(cfg.id) or { ListBoxSourceState{} }
	request_key := list_box_source_request_key(cfg)
	if request_key != state.request_key {
		list_box_source_start_request(cfg, request_key, mut state, mut window)
	}
	state.data_dirty = false
	sm.set(cfg.id, state)
	return state
}

fn list_box_source_request_key(cfg ListBoxCfg) string {
	return 'k:${cfg.id}|q:${cfg.query}|s:${cfg.source_key}'
}

fn list_box_source_start_request(cfg ListBoxCfg, request_key string, mut state ListBoxSourceState, mut window Window) {
	source := cfg.data_source or { return }
	if state.loading && !isnil(state.active_abort) {
		mut active := state.active_abort
		active.abort()
		state.cancelled_count++
	}
	controller := new_grid_abort_controller()
	next_request_id := state.request_id + 1
	req := ListBoxDataRequest{
		list_box_id: cfg.id
		query:       cfg.query
		signal:      controller.signal
		request_id:  next_request_id
	}
	state.loading = true
	state.load_error = ''
	state.request_id = next_request_id
	state.request_key = request_key
	state.active_abort = controller
	state.request_count++
	list_box_id := cfg.id
	spawn fn [source, req, list_box_id, next_request_id] (mut w Window) {
		result := source.fetch_data(req) or {
			if req.signal.is_aborted() {
				return
			}
			err_msg := err.msg()
			w.queue_command(fn [list_box_id, next_request_id, err_msg] (mut w Window) {
				list_box_source_apply_error(list_box_id, next_request_id, err_msg, mut
					w)
			})
			return
		}
		if req.signal.is_aborted() {
			return
		}
		w.queue_command(fn [list_box_id, next_request_id, result] (mut w Window) {
			list_box_source_apply_success(list_box_id, next_request_id, result, mut w)
		})
	}(mut window)
}

fn list_box_source_apply_success(list_box_id string, request_id u64, result ListBoxDataResult, mut window Window) {
	mut sm := state_map[string, ListBoxSourceState](mut window, ns_list_box_source, cap_moderate)
	mut state := sm.get(list_box_id) or { return }
	if request_id != state.request_id {
		state.stale_drop_count++
		sm.set(list_box_id, state)
		return
	}
	state.loading = false
	state.load_error = ''
	state.has_loaded = true
	state.data = result.data
	state.received_count += result.data.len
	state.data_dirty = true
	state.active_abort = unsafe { nil }
	sm.set(list_box_id, state)
	window.update_window()
}

fn list_box_source_apply_error(list_box_id string, request_id u64, err_msg string, mut window Window) {
	mut sm := state_map[string, ListBoxSourceState](mut window, ns_list_box_source, cap_moderate)
	mut state := sm.get(list_box_id) or { return }
	if request_id != state.request_id {
		state.stale_drop_count++
		sm.set(list_box_id, state)
		return
	}
	state.loading = false
	state.load_error = err_msg
	state.active_abort = unsafe { nil }
	sm.set(list_box_id, state)
	window.update_window()
}

fn list_box_source_apply_query(options []ListBoxOption, query string) []ListBoxOption {
	needle := query.trim_space().to_lower()
	if needle.len == 0 {
		return options
	}
	return options.filter(list_box_source_option_matches_query(it, needle))
}

fn list_box_source_option_matches_query(option ListBoxOption, needle string) bool {
	return grid_contains_lower(option.id, needle) || grid_contains_lower(option.name, needle)
		|| grid_contains_lower(option.value, needle)
}

// list_box_option is a helper method to construct [ListBoxOption](#ListBoxOption).
// It can allow specifying an option on a single line.
pub fn list_box_option(id string, name string, value string) ListBoxOption {
	return ListBoxOption{
		id:    id
		name:  name
		value: value
	}
}

// list_box_subheading is a helper method for list box heading rows.
pub fn list_box_subheading(id string, title string) ListBoxOption {
	return ListBoxOption{
		id:            id
		name:          title
		is_subheading: true
	}
}

// list_box_option_to_core converts a ListBoxOption to ListCoreItem.
fn list_box_option_to_core(opt ListBoxOption) ListCoreItem {
	return ListCoreItem{
		id:            opt.id
		label:         opt.name
		detail:        opt.value
		is_subheading: opt.is_subheading
	}
}

// list_box_on_keydown handles keyboard navigation for list box.
fn list_box_on_keydown(list_box_id string, item_ids []string, is_multiple bool, on_select fn ([]string, mut Event, mut Window), selected_ids []string, reorderable bool, on_reorder fn (string, string, mut Window), mut e Event, mut w Window) {
	// Escape cancels active drag.
	if reorderable && drag_reorder_escape(list_box_id, e.key_code, mut w) {
		e.is_handled = true
		return
	}
	// Alt+Up/Down keyboard reorder.
	if reorderable && on_reorder != unsafe { nil } {
		mut lbf := state_map[string, int](mut w, ns_list_box_focus, cap_moderate)
		cur := lbf.get(list_box_id) or { -1 }
		if cur >= 0
			&& drag_reorder_keyboard_move(e.key_code, e.modifiers, .vertical, cur, item_ids, on_reorder, mut w) {
			// Update focus index to follow the moved item.
			new_idx := int_clamp(if e.key_code == .up { cur - 1 } else { cur + 1 }, 0,
				item_ids.len - 1)
			lbf.set(list_box_id, new_idx)
			e.is_handled = true
			return
		}
	}
	if item_ids.len == 0 || on_select == unsafe { nil } {
		return
	}
	// Space also selects in listbox context.
	action := if e.key_code == .space {
		ListCoreAction.select_item
	} else {
		list_core_navigate(e.key_code, item_ids.len, 0)
	}
	if action == .none {
		return
	}
	mut lbf := state_map[string, int](mut w, ns_list_box_focus, cap_moderate)
	cur_idx := lbf.get(list_box_id) or { -1 }

	if action == .select_item {
		if cur_idx >= 0 && cur_idx < item_ids.len {
			dat_id := item_ids[cur_idx]
			ids := list_box_next_selected_ids(selected_ids, dat_id, is_multiple)
			on_select(ids, mut e, mut w)
		}
		e.is_handled = true
		return
	}
	next, changed := list_core_apply_nav(action, cur_idx, item_ids.len)
	if changed {
		lbf.set(list_box_id, next)
		w.update_window()
	}
	e.is_handled = true
}
