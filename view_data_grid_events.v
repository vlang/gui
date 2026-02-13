// Data grid: keyboard/mouse handlers, navigation, pager UI,
// quick filter, column chooser, selection.
module gui

import hash.fnv1a

fn data_grid_quick_filter_row(cfg DataGridCfg) View {
	h := data_grid_quick_filter_height(cfg)
	query_callback := cfg.on_query_change
	query := cfg.query
	value := query.quick_filter
	input_id := '${cfg.id}:quick_filter'
	input_focus_id := fnv1a.sum32_string(input_id)
	matches_text := data_grid_quick_filter_matches_text(cfg)
	clear_disabled := value.len == 0 || query_callback == unsafe { nil }
	return row(
		name:         'data_grid quick filter row'
		height:       h
		sizing:       fill_fixed
		color:        cfg.color_quick_filter
		color_border: cfg.color_border
		size_border:  0
		padding:      padding(0, cfg.padding_cell.right, 0, cfg.padding_cell.left)
		spacing:      6
		v_align:      .middle
		on_click:     fn [input_focus_id] (_ &Layout, mut e Event, mut w Window) {
			if input_focus_id > 0 {
				w.set_id_focus(input_focus_id)
			}
			e.is_handled = true
		}
		content:      [
			input(
				id:                input_id
				id_focus:          input_focus_id
				text:              value
				placeholder:       cfg.quick_filter_placeholder
				sizing:            fill_fill
				padding:           padding_none
				size_border:       0
				radius:            0
				color:             cfg.color_quick_filter
				color_hover:       cfg.color_quick_filter
				color_border:      cfg.color_border
				text_style:        cfg.text_style_filter
				placeholder_style: TextStyle{
					...cfg.text_style_filter
					color: Color{
						r: cfg.text_style_filter.color.r
						g: cfg.text_style_filter.color.g
						b: cfg.text_style_filter.color.b
						a: 140
					}
				}
				on_text_changed:   fn [query, query_callback] (_ &Layout, text string, mut w Window) {
					if query_callback == unsafe { nil } {
						return
					}
					next := GridQueryState{
						sorts:        query.sorts.clone()
						filters:      query.filters.clone()
						quick_filter: text
					}
					mut e := Event{}
					query_callback(next, mut e, mut w)
				}
			),
			text(
				text:       matches_text
				mode:       .single_line
				text_style: data_grid_indicator_text_style(cfg.text_style_filter)
			),
			data_grid_indicator_button('Clear', cfg.text_style_filter, cfg.color_header_hover,
				clear_disabled, 0, fn [query_callback, query, input_focus_id] (_ &Layout, mut e Event, mut w Window) {
				if query_callback == unsafe { nil } {
					return
				}
				next := GridQueryState{
					sorts:        query.sorts.clone()
					filters:      query.filters.clone()
					quick_filter: ''
				}
				query_callback(next, mut e, mut w)
				if input_focus_id > 0 {
					w.set_id_focus(input_focus_id)
				}
				e.is_handled = true
			}),
		]
	)
}

fn data_grid_quick_filter_matches_text(cfg DataGridCfg) string {
	if total := cfg.row_count {
		return 'Matches ${cfg.rows.len}/${total}'
	}
	if data_grid_has_source(cfg) {
		return 'Matches ${cfg.rows.len}/?'
	}
	return 'Matches ${cfg.rows.len}'
}

fn data_grid_column_chooser_row(cfg DataGridCfg, is_open bool, focus_id u32) View {
	on_hidden_columns_change := cfg.on_hidden_columns_change
	has_visibility_callback := on_hidden_columns_change != unsafe { nil }
	chooser_label := if is_open { 'Columns ▼' } else { 'Columns ▶' }
	row_h := if cfg.row_height > 0 {
		cfg.row_height
	} else {
		data_grid_header_height(cfg)
	}
	grid_id := cfg.id
	hidden_column_ids := cfg.hidden_column_ids.clone()
	columns := cfg.columns
	mut content := []View{cap: 2}
	content << row(
		name:    'data_grid column chooser toolbar'
		height:  row_h
		sizing:  fill_fixed
		padding: cfg.padding_filter
		spacing: 6
		v_align: .middle
		content: [
			data_grid_indicator_button(chooser_label, cfg.text_style_filter, cfg.color_header_hover,
				false, 0, fn [grid_id, focus_id] (_ &Layout, mut e Event, mut w Window) {
				data_grid_toggle_column_chooser_open(grid_id, mut w)
				if focus_id > 0 {
					w.set_id_focus(focus_id)
				}
				e.is_handled = true
			}),
		]
	)
	if is_open {
		mut options := []View{cap: columns.len}
		for col in columns {
			if col.id.len == 0 {
				continue
			}
			hidden := hidden_column_ids[col.id]
			col_id := col.id
			options << toggle(
				id:       '${grid_id}:col-chooser:${col.id}'
				label:    col.title
				select:   !hidden
				disabled: !has_visibility_callback
				on_click: fn [on_hidden_columns_change, hidden_column_ids, columns, col_id, focus_id] (_ &Layout, mut e Event, mut w Window) {
					if on_hidden_columns_change == unsafe { nil } {
						return
					}
					next_hidden := data_grid_next_hidden_columns(hidden_column_ids, col_id,
						columns)
					on_hidden_columns_change(next_hidden, mut e, mut w)
					if focus_id > 0 {
						w.set_id_focus(focus_id)
					}
					e.is_handled = true
				}
			)
		}
		content << row(
			name:         'data_grid column chooser options'
			height:       row_h
			sizing:       fill_fixed
			padding:      cfg.padding_filter
			spacing:      8
			color:        color_transparent
			color_border: cfg.color_border
			size_border:  0
			content:      options
		)
	}
	return column(
		name:         'data_grid column chooser row'
		height:       data_grid_column_chooser_height(cfg, is_open)
		sizing:       fill_fixed
		color:        cfg.color_filter
		color_border: cfg.color_border
		size_border:  0
		padding:      padding_none
		spacing:      0
		content:      content
	)
}

fn data_grid_toggle_column_chooser_open(grid_id string, mut w Window) {
	is_open := w.view_state.data_grid_column_chooser_open.get(grid_id) or { false }
	w.view_state.data_grid_column_chooser_open.set(grid_id, !is_open)
}

fn data_grid_column_chooser_height(cfg DataGridCfg, is_open bool) f32 {
	base := if cfg.row_height > 0 {
		cfg.row_height
	} else {
		data_grid_header_height(cfg)
	}
	return if is_open { base * 2 } else { base }
}

fn data_grid_pager_row(cfg DataGridCfg, focus_id u32, page_index int, page_count int, page_start int, page_end int, total_rows int, viewport_h f32, row_height f32, static_top f32, scroll_id u32, data_to_display map[int]int, jump_text string) View {
	on_page_change := cfg.on_page_change
	on_selection_change := cfg.on_selection_change
	rows := cfg.rows
	page_size := cfg.page_size
	has_callback := on_page_change != unsafe { nil }
	is_first := page_index <= 0
	is_last := page_index >= page_count - 1
	page_text := 'Page ${page_index + 1}/${page_count}'
	rows_text := if total_rows == 0 || page_end <= page_start {
		'Rows 0/0'
	} else {
		'Rows ${page_start + 1}-${page_end}/${total_rows}'
	}
	grid_id := cfg.id
	jump_enabled := data_grid_jump_enabled_local(cfg.rows.len, on_selection_change, on_page_change,
		page_size, total_rows)
	jump_ctx := DataGridJumpContext{
		rows:                rows
		on_selection_change: on_selection_change
		on_page_change:      on_page_change
		page_size:           page_size
		total_rows:          total_rows
		page_index:          page_index
		viewport_h:          viewport_h
		row_height:          row_height
		static_top:          static_top
		scroll_id:           scroll_id
		data_to_display:     data_to_display
		grid_id:             grid_id
	}
	jump_input_id := '${grid_id}:jump'
	jump_focus_id := fnv1a.sum32_string(jump_input_id)
	mut content := []View{cap: 9}
	content << data_grid_indicator_button('◀', cfg.text_style_header, cfg.color_header_hover,
		!has_callback || is_first, data_grid_header_control_width + 10, fn [on_page_change, page_index, focus_id] (_ &Layout, mut e Event, mut w Window) {
		if on_page_change == unsafe { nil } {
			return
		}
		next := int_max(0, page_index - 1)
		on_page_change(next, mut e, mut w)
		if focus_id > 0 {
			w.set_id_focus(focus_id)
		}
		e.is_handled = true
	})
	content << text(
		text:       page_text
		mode:       .single_line
		text_style: cfg.text_style_filter
	)
	content << data_grid_indicator_button('▶', cfg.text_style_header, cfg.color_header_hover,
		!has_callback || is_last, data_grid_header_control_width + 10, fn [on_page_change, page_index, page_count, focus_id] (_ &Layout, mut e Event, mut w Window) {
		if on_page_change == unsafe { nil } {
			return
		}
		next := int_min(page_count - 1, page_index + 1)
		on_page_change(next, mut e, mut w)
		if focus_id > 0 {
			w.set_id_focus(focus_id)
		}
		e.is_handled = true
	})
	content << row(
		name:    'data_grid pager spacer'
		sizing:  fill_fill
		padding: padding_none
		content: []
	)
	content << row(
		name:    'data_grid pager rows status'
		sizing:  fit_fill
		padding: padding(0, 6, 0, 0)
		v_align: .middle
		content: [
			text(
				text:       rows_text
				mode:       .single_line
				text_style: data_grid_indicator_text_style(cfg.text_style_filter)
			),
		]
	)
	content << text(
		text:       'Jump'
		mode:       .single_line
		text_style: data_grid_indicator_text_style(cfg.text_style_filter)
	)
	content << input(
		id:              jump_input_id
		id_focus:        jump_focus_id
		text:            jump_text
		placeholder:     '#'
		disabled:        !jump_enabled
		width:           68
		sizing:          fixed_fill
		padding:         padding_none
		size_border:     0
		radius:          0
		color:           cfg.color_filter
		color_hover:     cfg.color_filter
		color_border:    cfg.color_border
		text_style:      cfg.text_style_filter
		on_text_changed: fn [jump_ctx] (_ &Layout, text string, mut w Window) {
			digits := data_grid_jump_digits(text)
			w.view_state.data_grid_jump_input.set(jump_ctx.grid_id, digits)
			mut e := Event{}
			data_grid_submit_local_jump(jump_ctx, mut e, mut w)
		}
		on_enter:        fn [jump_ctx, focus_id] (_ &Layout, mut e Event, mut w Window) {
			data_grid_submit_local_jump(DataGridJumpContext{
				...jump_ctx
				focus_id: focus_id
			}, mut e, mut w)
		}
	)
	return row(
		name:         'data_grid pager row'
		height:       data_grid_pager_height(cfg)
		sizing:       fill_fixed
		color:        cfg.color_filter
		color_border: cfg.color_border
		size_border:  0
		padding:      data_grid_pager_padding(cfg)
		spacing:      6
		v_align:      .middle
		content:      content
	)
}

fn make_data_grid_on_char(cfg DataGridCfg, columns []GridColumnCfg) fn (&Layout, mut Event, mut Window) {
	rows := cfg.rows
	selection := cfg.selection
	on_copy_rows := cfg.on_copy_rows
	return fn [rows, selection, on_copy_rows, columns] (_ &Layout, mut e Event, mut w Window) {
		if !data_grid_char_is_copy(&e) {
			return
		}
		selected_rows := data_grid_selected_rows(rows, selection)
		if selected_rows.len == 0 {
			return
		}
		mut payload := ''
		if on_copy_rows != unsafe { nil } {
			payload = on_copy_rows(selected_rows, mut e, mut w) or {
				grid_rows_to_tsv(columns, selected_rows)
			}
		} else {
			payload = grid_rows_to_tsv(columns, selected_rows)
		}
		if payload.len == 0 {
			return
		}
		to_clipboard(payload)
		e.is_handled = true
	}
}

fn make_data_grid_on_mouse_move(grid_id string) fn (&Layout, mut Event, mut Window) {
	return fn [grid_id] (layout &Layout, mut e Event, mut w Window) {
		mouse_x := layout.shape.x + e.mouse_x
		mouse_y := layout.shape.y + e.mouse_y
		col_id := data_grid_header_col_under_cursor(layout, grid_id, mouse_x, mouse_y)
		if col_id.len == 0 {
			w.view_state.data_grid_header_hover_col.delete(grid_id)
			return
		}
		w.view_state.data_grid_header_hover_col.set(grid_id, col_id)
	}
}

struct DataGridHeaderKeydownContext {
	grid_id                string
	columns                []GridColumnCfg
	column_order           []string
	hidden_column_ids      map[string]bool
	query                  GridQueryState
	multi_sort             bool
	on_query_change        fn (qs GridQueryState, mut e Event, mut w Window)                = unsafe { nil }
	on_column_order_change fn (order []string, mut e Event, mut w Window)                   = unsafe { nil }
	on_column_pin_change   fn (col_id string, pin GridColumnPin, mut e Event, mut w Window) = unsafe { nil }
	header_focus_base      u32
	col                    GridColumnCfg
	col_idx                int
	col_count              int
	grid_focus_id          u32
}

fn make_data_grid_header_on_keydown(cfg DataGridCfg, col GridColumnCfg, col_idx int, col_count int, grid_focus_id u32) fn (&Layout, mut Event, mut Window) {
	hk := DataGridHeaderKeydownContext{
		grid_id:                cfg.id
		columns:                cfg.columns
		column_order:           cfg.column_order
		hidden_column_ids:      cfg.hidden_column_ids.clone()
		query:                  cfg.query
		multi_sort:             cfg.multi_sort
		on_query_change:        cfg.on_query_change
		on_column_order_change: cfg.on_column_order_change
		on_column_pin_change:   cfg.on_column_pin_change
		header_focus_base:      data_grid_header_focus_base_id(cfg, col_count)
		col:                    col
		col_idx:                col_idx
		col_count:              col_count
		grid_focus_id:          grid_focus_id
	}
	return fn [hk] (_ &Layout, mut e Event, mut w Window) {
		data_grid_header_on_keydown(hk, mut e, mut w)
	}
}

fn data_grid_header_on_keydown(hk DataGridHeaderKeydownContext, mut e Event, mut w Window) {
	is_ctrl_or_super := e.modifiers.has(.ctrl) || e.modifiers.has(.super)
	is_alt := e.modifiers.has(.alt)
	is_shift := e.modifiers.has(.shift)

	match e.key_code {
		.enter, .space {
			if e.modifiers == .none || e.modifiers == .shift {
				data_grid_header_toggle_sort(hk.query, hk.multi_sort, hk.on_query_change,
					hk.col, mut e, mut w)
			}
			return
		}
		.left, .right {
			if is_ctrl_or_super {
				delta := if e.key_code == .left { -1 } else { 1 }
				data_grid_header_reorder_by_key(hk.columns, hk.column_order, hk.hidden_column_ids,
					hk.on_column_order_change, hk.header_focus_base, hk.col, hk.col_count,
					delta, mut e, mut w)
				return
			}
			if is_alt {
				step := if is_shift {
					data_grid_resize_key_step_large
				} else {
					data_grid_resize_key_step
				}
				delta := if e.key_code == .left { -step } else { step }
				data_grid_header_resize_by_key(hk.grid_id, hk.columns, hk.col, delta, mut
					e, mut w)
				return
			}
			if e.modifiers == .none {
				next_idx := int_clamp(hk.col_idx + if e.key_code == .left { -1 } else { 1 },
					0, hk.col_count - 1)
				if next_idx != hk.col_idx {
					next_focus_id := data_grid_header_focus_id_from_base(hk.header_focus_base,
						hk.col_count, next_idx)
					if next_focus_id > 0 {
						w.set_id_focus(next_focus_id)
					}
					e.is_handled = true
				}
			}
			return
		}
		.p {
			if e.modifiers == .none {
				data_grid_header_pin_by_key(hk.columns, hk.column_order, hk.hidden_column_ids,
					hk.on_column_pin_change, hk.header_focus_base, hk.col, hk.col_count, mut
					e, mut w)
			}
			return
		}
		.escape {
			if e.modifiers == .none {
				if hk.grid_focus_id > 0 {
					w.set_id_focus(hk.grid_focus_id)
				}
				e.is_handled = true
			}
			return
		}
		else {}
	}
}

fn data_grid_header_toggle_sort(query GridQueryState, multi_sort bool, on_query_change fn (qs GridQueryState, mut e Event, mut w Window), col GridColumnCfg, mut e Event, mut w Window) {
	if !col.sortable || on_query_change == unsafe { nil } {
		return
	}
	shift_sort := multi_sort && e.modifiers.has(.shift)
	next := data_grid_toggle_sort(query, col.id, multi_sort, shift_sort)
	on_query_change(next, mut e, mut w)
	e.is_handled = true
}

fn data_grid_header_reorder_by_key(columns []GridColumnCfg, column_order []string, hidden_column_ids map[string]bool, on_column_order_change fn (order []string, mut e Event, mut w Window), header_focus_base u32, col GridColumnCfg, col_count int, delta int, mut e Event, mut w Window) {
	if !col.reorderable || on_column_order_change == unsafe { nil } {
		return
	}
	base_order := data_grid_normalized_column_order(columns, column_order)
	next_order := data_grid_column_order_move(base_order, col.id, delta)
	if next_order == base_order {
		e.is_handled = true
		return
	}
	on_column_order_change(next_order, mut e, mut w)
	next_idx := data_grid_effective_index_for_column_with_order(columns, hidden_column_ids,
		next_order, col.id)
	if next_idx >= 0 {
		next_focus_id := data_grid_header_focus_id_from_base(header_focus_base, col_count,
			next_idx)
		if next_focus_id > 0 {
			w.set_id_focus(next_focus_id)
		}
	}
	e.is_handled = true
}

fn data_grid_header_resize_by_key(grid_id string, columns []GridColumnCfg, col GridColumnCfg, delta f32, mut e Event, mut w Window) {
	if !col.resizable {
		return
	}
	current := data_grid_column_width(grid_id, columns, col, mut w)
	data_grid_set_column_width(grid_id, col, current + delta, mut w)
	e.is_handled = true
}

fn data_grid_header_pin_by_key(columns []GridColumnCfg, column_order []string, hidden_column_ids map[string]bool, on_column_pin_change fn (col_id string, pin GridColumnPin, mut e Event, mut w Window), header_focus_base u32, col GridColumnCfg, col_count int, mut e Event, mut w Window) {
	if on_column_pin_change == unsafe { nil } {
		return
	}
	next_pin := data_grid_column_next_pin(col.pin)
	on_column_pin_change(col.id, next_pin, mut e, mut w)
	next_idx := data_grid_effective_index_for_column_with_pin(columns, column_order, hidden_column_ids,
		col.id, next_pin)
	if next_idx >= 0 {
		next_focus_id := data_grid_header_focus_id_from_base(header_focus_base, col_count,
			next_idx)
		if next_focus_id > 0 {
			w.set_id_focus(next_focus_id)
		}
	}
	e.is_handled = true
}

struct DataGridKeydownContext {
	grid_id             string
	rows                []GridRow
	columns             []GridColumnCfg
	selection           GridSelection
	multi_select        bool
	range_select        bool
	on_selection_change fn (sel GridSelection, mut e Event, mut w Window) = unsafe { nil }
	on_row_activate     fn (row GridRow, mut e Event, mut w Window)       = unsafe { nil }
	on_page_change      fn (page int, mut e Event, mut w Window)          = unsafe { nil }
	edit_enabled        bool
	crud_enabled        bool
	page_size           int
	page_index          int
	viewport_h          f32
	page_rows           int
	first_edit_col_idx  int
	editor_focus_base   u32
	col_count           int
	row_height          f32
	static_top          f32
	scroll_id           u32
	page_indices        []int
	frozen_top_ids      map[string]bool
	data_to_display     map[int]int
}

// Keyboard bindings:
// Escape: cancel edit/CRUD. Insert/Delete: CRUD ops.
// F2: start editing. Ctrl+PageUp/Down: page navigation.
// Ctrl+A: select all. Up/Down/Home/End/PageUp/PageDown:
// row navigation with optional Shift for range extend.
// Enter: activate row or commit edit.
fn make_data_grid_on_keydown(cfg DataGridCfg, columns []GridColumnCfg, row_height f32, static_top f32, scroll_id u32, page_indices []int, frozen_top_ids map[string]bool, data_to_display map[int]int) fn (&Layout, mut Event, mut Window) {
	kd := DataGridKeydownContext{
		grid_id:             cfg.id
		rows:                cfg.rows
		columns:             columns
		selection:           cfg.selection
		multi_select:        cfg.multi_select
		range_select:        cfg.range_select
		on_selection_change: cfg.on_selection_change
		on_row_activate:     cfg.on_row_activate
		on_page_change:      cfg.on_page_change
		edit_enabled:        data_grid_editing_enabled(cfg)
		crud_enabled:        data_grid_crud_enabled(cfg)
		page_size:           cfg.page_size
		page_index:          cfg.page_index
		viewport_h:          data_grid_height(cfg)
		page_rows:           data_grid_page_rows(cfg, row_height)
		first_edit_col_idx:  data_grid_first_editable_column_index(cfg, columns)
		editor_focus_base:   data_grid_cell_editor_focus_base_id(cfg, columns.len)
		col_count:           columns.len
		row_height:          row_height
		static_top:          static_top
		scroll_id:           scroll_id
		page_indices:        page_indices
		frozen_top_ids:      frozen_top_ids
		data_to_display:     data_to_display
	}
	return fn [kd] (_ &Layout, mut e Event, mut w Window) {
		data_grid_on_keydown(kd, mut e, mut w)
	}
}

fn data_grid_on_keydown(kd DataGridKeydownContext, mut e Event, mut w Window) {
	if e.modifiers == .none && e.key_code == .escape {
		if data_grid_editing_row_id(kd.grid_id, w).len > 0 {
			data_grid_clear_editing_row(kd.grid_id, mut w)
			e.is_handled = true
			return
		}
		if kd.crud_enabled {
			data_grid_crud_cancel(kd.grid_id, 0, mut e, mut w)
		}
		return
	}
	if kd.crud_enabled && e.modifiers == .none && e.key_code == .insert {
		data_grid_crud_add_row(kd.grid_id, kd.columns, kd.on_selection_change, 0, mut
			e, mut w)
		return
	}
	if kd.crud_enabled && e.modifiers == .none && e.key_code == .delete {
		data_grid_crud_delete_selected(kd.grid_id, kd.selection, kd.on_selection_change,
			0, mut e, mut w)
		return
	}
	if e.modifiers == .none && e.key_code == .f2 {
		if kd.edit_enabled && kd.rows.len > 0 && kd.first_edit_col_idx >= 0 {
			row_idx := data_grid_active_row_index(kd.rows, kd.selection)
			if row_idx >= 0 && row_idx < kd.rows.len {
				r_id := data_grid_row_id(kd.rows[row_idx], row_idx)
				data_grid_set_editing_row(kd.grid_id, r_id, mut w)
				efid := data_grid_editor_focus_id_from_base(kd.editor_focus_base, kd.col_count,
					kd.first_edit_col_idx)
				if efid > 0 {
					w.set_id_focus(efid)
				}
				e.is_handled = true
			}
		}
		return
	}
	if kd.on_page_change != unsafe { nil } && kd.page_size > 0 {
		_, _, pi, pc := data_grid_page_bounds(kd.rows.len, kd.page_size, kd.page_index)
		if pc > 1 {
			if next_pi := data_grid_next_page_index_for_key(pi, pc, &e) {
				if next_pi != pi {
					kd.on_page_change(next_pi, mut e, mut w)
				}
				e.is_handled = true
				return
			}
		}
	}
	if kd.rows.len == 0 {
		return
	}
	visible_indices := data_grid_visible_row_indices(kd.rows.len, kd.page_indices)
	if visible_indices.len == 0 {
		return
	}

	if data_grid_is_select_all_shortcut(&e) && kd.multi_select {
		mut selected := map[string]bool{}
		for idx, row_data in kd.rows {
			selected[data_grid_row_id(row_data, idx)] = true
		}
		next := GridSelection{
			anchor_row_id:    data_grid_row_id(kd.rows[0], 0)
			active_row_id:    data_grid_row_id(kd.rows[kd.rows.len - 1], kd.rows.len - 1)
			selected_row_ids: selected
		}
		data_grid_set_anchor(kd.grid_id, next.anchor_row_id, mut w)
		if kd.on_selection_change != unsafe { nil } {
			kd.on_selection_change(next, mut e, mut w)
		}
		e.is_handled = true
		return
	}

	if e.key_code == .enter {
		if data_grid_editing_row_id(kd.grid_id, w).len > 0 {
			data_grid_clear_editing_row(kd.grid_id, mut w)
			e.is_handled = true
			return
		}
		if kd.on_row_activate == unsafe { nil } {
			return
		}
		idx := data_grid_active_row_index(kd.rows, kd.selection)
		if idx >= 0 && idx < kd.rows.len {
			kd.on_row_activate(kd.rows[idx], mut e, mut w)
			e.is_handled = true
		}
		return
	}

	is_shift := e.modifiers.has(.shift)
	if e.modifiers != .none && !is_shift {
		return
	}

	current := data_grid_active_row_index(kd.rows, kd.selection)
	current_pos := data_grid_index_in_list(visible_indices, current)
	mut visible_pos := if current_pos >= 0 { current_pos } else { 0 }
	mut target_pos := visible_pos

	match e.key_code {
		.up {
			target_pos--
		}
		.down {
			target_pos++
		}
		.home {
			target_pos = 0
		}
		.end {
			target_pos = visible_indices.len - 1
		}
		.page_up {
			target_pos -= kd.page_rows
		}
		.page_down {
			target_pos += kd.page_rows
		}
		else {
			return
		}
	}
	target_pos = int_clamp(target_pos, 0, visible_indices.len - 1)
	target := visible_indices[target_pos]
	if kd.on_selection_change == unsafe { nil } {
		return
	}

	target_id := data_grid_row_id(kd.rows[target], target)
	mut next := GridSelection{}
	if is_shift && kd.multi_select && kd.range_select {
		anchor := data_grid_anchor_row_id_ex(kd.selection, kd.grid_id, kd.rows, mut w,
			target_id)
		start, end := data_grid_range_indices(kd.rows, anchor, target_id)
		mut selected := map[string]bool{}
		if start >= 0 && end >= start {
			for idx in start .. end + 1 {
				selected[data_grid_row_id(kd.rows[idx], idx)] = true
			}
		} else {
			selected[target_id] = true
		}
		next = GridSelection{
			anchor_row_id:    anchor
			active_row_id:    target_id
			selected_row_ids: selected
		}
		data_grid_set_anchor(kd.grid_id, anchor, mut w)
	} else {
		next = GridSelection{
			anchor_row_id:    target_id
			active_row_id:    target_id
			selected_row_ids: {
				target_id: true
			}
		}
		data_grid_set_anchor(kd.grid_id, target_id, mut w)
	}

	kd.on_selection_change(next, mut e, mut w)
	if kd.frozen_top_ids[target_id] {
		e.is_handled = true
		return
	}
	display_idx := kd.data_to_display[target] or { -1 }
	if display_idx < 0 {
		e.is_handled = true
		return
	}
	data_grid_scroll_row_into_view_ex(kd.viewport_h, display_idx, kd.row_height, kd.static_top,
		kd.scroll_id, mut w)
	e.is_handled = true
}

fn data_grid_scroll_row_into_view(cfg DataGridCfg, row_idx int, row_height f32, static_top f32, scroll_id u32, mut w Window) {
	data_grid_scroll_row_into_view_ex(data_grid_height(cfg), row_idx, row_height, static_top,
		scroll_id, mut w)
}

// Computes scroll offset to make a row fully visible. If
// row_top is above the viewport, scroll up to row_top. If
// row_bottom is below viewport, scroll down so row_bottom
// aligns with viewport bottom.
fn data_grid_scroll_row_into_view_ex(viewport_h f32, row_idx int, row_height f32, static_top f32, scroll_id u32, mut w Window) {
	if viewport_h <= 0 || row_height <= 0 {
		return
	}
	current := -(w.view_state.scroll_y.get(scroll_id) or { f32(0) })
	row_top := static_top + f32(row_idx) * row_height
	row_bottom := row_top + row_height
	mut next := current
	if row_top < current {
		next = row_top
	} else if row_bottom > current + viewport_h {
		next = row_bottom - viewport_h
	}
	if next < 0 {
		next = 0
	}
	w.scroll_vertical_to(scroll_id, -next)
}

fn data_grid_next_page_index_for_key(page_index int, page_count int, e &Event) ?int {
	if page_count <= 1 || page_index < 0 || page_index >= page_count {
		return none
	}
	if e.modifiers == .alt {
		return match e.key_code {
			.home { 0 }
			.end { page_count - 1 }
			else { none }
		}
	}
	if !e.modifiers.has_any(.ctrl, .super) || e.modifiers.has(.alt) {
		return none
	}
	return match e.key_code {
		.page_up { int_max(0, page_index - 1) }
		.page_down { int_min(page_count - 1, page_index + 1) }
		else { none }
	}
}

fn data_grid_selected_rows(rows []GridRow, selection GridSelection) []GridRow {
	if selection.selected_row_ids.len == 0 {
		return []
	}
	mut selected := []GridRow{}
	for idx, row in rows {
		if selection.selected_row_ids[data_grid_row_id(row, idx)] {
			selected << row
		}
	}
	return selected
}

fn data_grid_char_is_copy(e &Event) bool {
	return (e.modifiers.has(.ctrl) && e.char_code == ctrl_c)
		|| (e.modifiers.has(.super) && e.char_code == cmd_c)
}

fn data_grid_is_select_all_shortcut(e &Event) bool {
	return (e.modifiers.has(.ctrl) || e.modifiers.has(.super)) && e.key_code == .a
}

fn data_grid_page_rows(cfg DataGridCfg, row_height f32) int {
	if row_height <= 0 {
		return 1
	}
	page := int(data_grid_height(cfg) / row_height)
	return if page < 1 { 1 } else { page }
}

fn data_grid_active_row_index(rows []GridRow, selection GridSelection) int {
	res := data_grid_active_row_index_strict(rows, selection)
	if res >= 0 {
		return res
	}
	if rows.len > 0 {
		return 0
	}
	return -1
}

fn data_grid_active_row_index_strict(rows []GridRow, selection GridSelection) int {
	if rows.len == 0 {
		return -1
	}
	if selection.active_row_id.len > 0 {
		for idx, row in rows {
			if data_grid_row_id(row, idx) == selection.active_row_id {
				return idx
			}
		}
	}
	if selection.selected_row_ids.len > 0 {
		for idx, row in rows {
			if selection.selected_row_ids[data_grid_row_id(row, idx)] {
				return idx
			}
		}
	}
	return -1
}

fn data_grid_row_position_text(cfg DataGridCfg, page_start int, page_end int, total_rows int) string {
	if total_rows <= 0 {
		return 'Row 0 of 0'
	}
	mut row_idx := data_grid_active_row_index_strict(cfg.rows, cfg.selection)
	if row_idx < 0 {
		row_idx = if cfg.page_size > 0 && page_end > page_start { page_start } else { 0 }
	}
	if cfg.page_size > 0 && (row_idx < page_start || row_idx >= page_end) {
		row_idx = if page_end > page_start { page_start } else { 0 }
	}
	row_idx = int_clamp(row_idx, 0, total_rows - 1)
	return 'Row ${row_idx + 1} of ${total_rows}'
}

fn data_grid_jump_enabled_local(rows_len int, on_selection_change fn (sel GridSelection, mut e Event, mut w Window), on_page_change fn (page int, mut e Event, mut w Window), page_size int, total_rows int) bool {
	if total_rows <= 0 || rows_len == 0 {
		return false
	}
	if on_selection_change == unsafe { nil } {
		return false
	}
	if page_size > 0 && on_page_change == unsafe { nil } {
		return false
	}
	return true
}

fn data_grid_jump_digits(text string) string {
	mut digits := []u8{cap: text.len}
	for ch in text.bytes() {
		if ch >= `0` && ch <= `9` {
			digits << ch
		}
	}
	return digits.bytestr()
}

fn data_grid_parse_jump_target(text string, total_rows int) ?int {
	if total_rows <= 0 {
		return none
	}
	digits := data_grid_jump_digits(text)
	if digits.len == 0 {
		return none
	}
	target := digits.int()
	if target <= 0 {
		return none
	}
	return int_clamp(target, 1, total_rows) - 1
}

struct DataGridJumpContext {
	rows                []GridRow
	on_selection_change fn (sel GridSelection, mut e Event, mut w Window) = unsafe { nil }
	on_page_change      fn (page int, mut e Event, mut w Window)          = unsafe { nil }
	page_size           int
	total_rows          int
	page_index          int
	viewport_h          f32
	row_height          f32
	static_top          f32
	scroll_id           u32
	data_to_display     map[int]int
	grid_id             string
	focus_id            u32
}

fn data_grid_submit_local_jump(ctx DataGridJumpContext, mut e Event, mut w Window) {
	if !data_grid_jump_enabled_local(ctx.rows.len, ctx.on_selection_change, ctx.on_page_change,
		ctx.page_size, ctx.total_rows) {
		return
	}
	jump_text := w.view_state.data_grid_jump_input.get(ctx.grid_id) or { '' }
	target_idx := data_grid_parse_jump_target(jump_text, ctx.total_rows) or { return }
	w.view_state.data_grid_jump_input.set(ctx.grid_id, '${target_idx + 1}')
	data_grid_jump_to_local_row(ctx, target_idx, mut e, mut w)
	if ctx.focus_id > 0 {
		w.set_id_focus(ctx.focus_id)
	}
	e.is_handled = true
}

// Navigates to a specific row by index. If the target is
// on a different page, stores a pending jump and triggers a
// page change; on the next frame, the pending jump is
// applied as a scroll. If on current page, scrolls
// immediately.
fn data_grid_jump_to_local_row(ctx DataGridJumpContext, target_idx int, mut e Event, mut w Window) {
	if target_idx < 0 || target_idx >= ctx.rows.len {
		return
	}
	target_row_id := data_grid_row_id(ctx.rows[target_idx], target_idx)
	if ctx.on_selection_change != unsafe { nil } {
		next := GridSelection{
			anchor_row_id:    target_row_id
			active_row_id:    target_row_id
			selected_row_ids: {
				target_row_id: true
			}
		}
		ctx.on_selection_change(next, mut e, mut w)
		data_grid_set_anchor(ctx.grid_id, target_row_id, mut w)
	}
	if ctx.page_size > 0 {
		if ctx.on_page_change == unsafe { nil } {
			return
		}
		target_page := target_idx / ctx.page_size
		if target_page != ctx.page_index {
			w.view_state.data_grid_pending_jump_row.set(ctx.grid_id, target_idx)
			ctx.on_page_change(target_page, mut e, mut w)
			return
		}
	}
	w.view_state.data_grid_pending_jump_row.delete(ctx.grid_id)
	display_idx := ctx.data_to_display[target_idx] or { -1 }
	if display_idx < 0 {
		return
	}
	data_grid_scroll_row_into_view_ex(ctx.viewport_h, display_idx, ctx.row_height, ctx.static_top,
		ctx.scroll_id, mut w)
}

fn data_grid_apply_pending_local_jump_scroll(cfg DataGridCfg, viewport_h f32, row_height f32, static_top f32, scroll_id u32, data_to_display map[int]int, mut w Window) {
	target_idx := w.view_state.data_grid_pending_jump_row.get(cfg.id) or { return }
	if target_idx < 0 || target_idx >= cfg.rows.len {
		w.view_state.data_grid_pending_jump_row.delete(cfg.id)
		return
	}
	display_idx := data_to_display[target_idx] or {
		w.view_state.data_grid_pending_jump_row.delete(cfg.id)
		return
	}
	if display_idx < 0 {
		w.view_state.data_grid_pending_jump_row.delete(cfg.id)
		return
	}
	data_grid_scroll_row_into_view_ex(viewport_h, display_idx, row_height, static_top,
		scroll_id, mut w)
	w.view_state.data_grid_pending_jump_row.delete(cfg.id)
}

fn data_grid_anchor_row_id(cfg DataGridCfg, mut w Window, fallback string) string {
	return data_grid_anchor_row_id_ex(cfg.selection, cfg.id, cfg.rows, mut w, fallback)
}

fn data_grid_anchor_row_id_ex(selection GridSelection, grid_id string, rows []GridRow, mut w Window, fallback string) string {
	if selection.anchor_row_id.len > 0 {
		return selection.anchor_row_id
	}
	if state := w.view_state.data_grid_range_state.get(grid_id) {
		if state.anchor_row_id.len > 0 {
			return state.anchor_row_id
		}
	}
	if selection.active_row_id.len > 0 {
		return selection.active_row_id
	}
	if selection.selected_row_ids.len > 0 {
		for idx, row in rows {
			id := data_grid_row_id(row, idx)
			if selection.selected_row_ids[id] {
				return id
			}
		}
	}
	return fallback
}

fn data_grid_set_anchor(grid_id string, anchor string, mut w Window) {
	w.view_state.data_grid_range_state.set(grid_id, DataGridRangeState{
		anchor_row_id: anchor
	})
}

fn data_grid_range_indices(rows []GridRow, a string, b string) (int, int) {
	mut a_idx := -1
	mut b_idx := -1
	for idx, row in rows {
		id := data_grid_row_id(row, idx)
		if id == a {
			a_idx = idx
		}
		if id == b {
			b_idx = idx
		}
	}
	if a_idx < 0 || b_idx < 0 {
		return -1, -1
	}
	if a_idx <= b_idx {
		return a_idx, b_idx
	}
	return b_idx, a_idx
}
