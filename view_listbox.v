module gui

import strings

const list_box_virtual_buffer_rows = 2

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
	return list_box_from_range(0, last, cfg, false, f32(0))
}

// list_box is a convenience view for simple cases. See [ListBoxCfg](#ListBoxCfg).
// Virtualization is enabled only when `id_scroll > 0` and bounded height exists.
pub fn (mut window Window) list_box(cfg ListBoxCfg) View {
	resolved_cfg, _ := list_box_resolve_source_cfg(cfg, mut window)
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

	return list_box_from_range(first_visible, last_visible, resolved_cfg, virtualize,
		row_height)
}

fn list_box_from_range(first_visible int, last_visible int, cfg ListBoxCfg, virtualize bool, row_height f32) View {
	last_row_idx := cfg.data.len - 1
	spacer_row_height := if row_height > 0 {
		row_height
	} else {
		list_box_estimate_row_height_no_window(cfg)
	}
	mut list := []View{cap: (last_visible - first_visible + 1) + 2}

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

	for idx in first_visible .. last_visible + 1 {
		if idx < 0 || idx >= cfg.data.len {
			continue
		}
		list << list_box_item_view(cfg.data[idx], cfg)
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

	// Build value_text and selectable item IDs in one pass.
	mut item_ids := []string{cap: cfg.data.len}
	mut value_builder := strings.new_builder(0)
	for dat in cfg.data {
		if !dat.is_subheading {
			item_ids << dat.id
		}
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
	return column(
		name:         'list_box'
		a11y_role:    .list
		a11y:         list_a11y
		id_focus:     cfg.id_focus
		id_scroll:    cfg.id_scroll
		on_keydown:   fn [list_box_id, item_ids, is_multiple, on_select, selected_ids] (_ &Layout, mut e Event, mut w Window) {
			list_box_on_keydown(list_box_id, item_ids, is_multiple, on_select, selected_ids, mut
				e, mut w)
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

fn list_box_item_view(dat ListBoxOption, cfg ListBoxCfg) View {
	color := if dat.id in cfg.selected_ids {
		cfg.color_select
	} else {
		color_transparent
	}
	is_sub := dat.is_subheading
	mut content := []View{cap: 1}

	if is_sub {
		content << column(
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
	} else {
		content << text(
			text:       dat.name
			mode:       .multiline
			text_style: cfg.text_style
		)
	}

	dat_id := dat.id
	is_multiple := cfg.multiple
	on_select := cfg.on_select
	has_on_select := on_select != unsafe { nil }
	selected_ids := cfg.selected_ids
	color_hover := cfg.color_hover

	item_a11y_state := if dat.id in cfg.selected_ids {
		AccessState.selected
	} else {
		AccessState.none
	}
	return row(
		name:       'list_box option'
		a11y_role:  .list_item
		a11y_label: dat.name
		a11y_state: item_a11y_state
		color:      color
		padding:    padding_two_five
		sizing:     fill_fit
		content:    content
		on_click:   fn [is_multiple, on_select, has_on_select, selected_ids, dat_id, is_sub] (_ voidptr, mut e Event, mut w Window) {
			if has_on_select && !is_sub {
				mut ids := if !is_multiple {
					[dat_id]
				} else if dat_id in selected_ids {
					selected_ids.filter(it != dat_id)
				} else {
					mut a := []string{cap: selected_ids.len + 1}
					a << selected_ids
					a << dat_id
					a
				}
				on_select(ids, mut e, mut w)
			}
		}
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

fn list_box_height(cfg ListBoxCfg) f32 {
	return if cfg.height > 0 { cfg.height } else { cfg.max_height }
}

fn list_box_estimate_row_height(cfg ListBoxCfg, mut window Window) f32 {
	text_h := list_box_font_height(cfg.text_style, mut window)
	sub_h := list_box_font_height(cfg.subheading_style, mut window)
	return f32_max(text_h, sub_h) + padding_two_five.height()
}

fn list_box_estimate_row_height_no_window(cfg ListBoxCfg) f32 {
	return f32_max(cfg.text_style.size, cfg.subheading_style.size) + padding_two_five.height()
}

fn list_box_font_height(style TextStyle, mut window Window) f32 {
	if isnil(window.text_system) {
		return style.size
	}
	vg_cfg := style.to_vglyph_cfg()
	return window.text_system.font_height(vg_cfg) or { style.size }
}

fn list_box_visible_range(list_height f32, row_height f32, cfg ListBoxCfg, mut window Window) (int, int) {
	if cfg.data.len == 0 || row_height <= 0 || list_height <= 0 {
		return 0, -1
	}
	max_idx := cfg.data.len - 1
	scroll_y := -(window.view_state.scroll_y.get(cfg.id_scroll) or { f32(0) })
	first := int_clamp(int(scroll_y / row_height), 0, max_idx)
	visible_rows := int(list_height / row_height) + 1
	mut first_visible := int_max(0, first - list_box_virtual_buffer_rows)
	last_visible := int_min(max_idx, first + visible_rows + list_box_virtual_buffer_rows)
	if first_visible > last_visible {
		first_visible = last_visible
	}
	return first_visible, last_visible
}

pub fn (window &Window) list_box_source_stats(list_box_id string) ListBoxSourceStats {
	if state := window.view_state.list_box_source_state.get(list_box_id) {
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
	mut state := window.view_state.list_box_source_state.get(list_box_id) or { return }
	if state.loading && !isnil(state.active_abort) {
		mut active := state.active_abort
		active.abort()
		state.cancelled_count++
		state.loading = false
	}
	state.request_key = ''
	state.load_error = ''
	window.view_state.list_box_source_state.set(list_box_id, state)
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
	mut state := window.view_state.list_box_source_state.get(cfg.id) or { ListBoxSourceState{} }
	request_key := list_box_source_request_key(cfg)
	if request_key != state.request_key {
		list_box_source_start_request(cfg, request_key, mut state, mut window)
	}
	state.data_dirty = false
	window.view_state.list_box_source_state.set(cfg.id, state)
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
	mut state := window.view_state.list_box_source_state.get(list_box_id) or { return }
	if request_id != state.request_id {
		state.stale_drop_count++
		window.view_state.list_box_source_state.set(list_box_id, state)
		return
	}
	state.loading = false
	state.load_error = ''
	state.has_loaded = true
	state.data = result.data
	state.received_count += result.data.len
	state.data_dirty = true
	state.active_abort = unsafe { nil }
	window.view_state.list_box_source_state.set(list_box_id, state)
	window.update_window()
}

fn list_box_source_apply_error(list_box_id string, request_id u64, err_msg string, mut window Window) {
	mut state := window.view_state.list_box_source_state.get(list_box_id) or { return }
	if request_id != state.request_id {
		state.stale_drop_count++
		window.view_state.list_box_source_state.set(list_box_id, state)
		return
	}
	state.loading = false
	state.load_error = err_msg
	state.active_abort = unsafe { nil }
	window.view_state.list_box_source_state.set(list_box_id, state)
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

// list_box_on_keydown handles keyboard navigation for list box.
fn list_box_on_keydown(list_box_id string, item_ids []string, is_multiple bool, on_select fn ([]string, mut Event, mut Window), selected_ids []string, mut e Event, mut w Window) {
	if item_ids.len == 0 || on_select == unsafe { nil } {
		return
	}
	cur_idx := w.view_state.list_box_focus.get(list_box_id) or { -1 }

	match e.key_code {
		.up {
			next := if cur_idx > 0 { cur_idx - 1 } else { 0 }
			w.view_state.list_box_focus.set(list_box_id, next)
			w.update_window()
			e.is_handled = true
		}
		.down {
			next := if cur_idx < item_ids.len - 1 {
				cur_idx + 1
			} else {
				item_ids.len - 1
			}
			w.view_state.list_box_focus.set(list_box_id, next)
			w.update_window()
			e.is_handled = true
		}
		.enter, .space {
			if cur_idx >= 0 && cur_idx < item_ids.len {
				dat_id := item_ids[cur_idx]
				mut ids := if !is_multiple {
					[dat_id]
				} else if dat_id in selected_ids {
					selected_ids.filter(it != dat_id)
				} else {
					mut a := []string{cap: selected_ids.len + 1}
					a << selected_ids
					a << dat_id
					a
				}
				on_select(ids, mut e, mut w)
			}
			e.is_handled = true
		}
		.home {
			w.view_state.list_box_focus.set(list_box_id, 0)
			w.update_window()
			e.is_handled = true
		}
		.end {
			w.view_state.list_box_focus.set(list_box_id, item_ids.len - 1)
			w.update_window()
			e.is_handled = true
		}
		else {}
	}
}
