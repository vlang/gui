// Data grid: data/group/detail row views, cell editors,
// frozen rows, detail expansion, pagination.
module gui

import time

fn data_grid_group_header_row_view(cfg DataGridCfg, entry DataGridDisplayRow, row_height f32) View {
	depth_pad := f32(entry.group_depth) * data_grid_group_indent_step
	mut label := '${entry.group_col_title}: ${entry.group_value}'
	if cfg.show_group_counts {
		label += ' (${entry.group_count})'
	}
	if entry.aggregate_text.len > 0 {
		label += '  ${entry.aggregate_text}'
	}
	return row(
		name:         'data_grid group header row'
		id:           '${cfg.id}:group:${entry.group_col_id}:${entry.group_value}:${entry.group_depth}'
		height:       row_height
		sizing:       fill_fixed
		color:        cfg.color_filter
		color_border: cfg.color_border
		size_border:  0
		padding:      padding(cfg.padding_cell.top, cfg.padding_cell.right, cfg.padding_cell.bottom,
			cfg.padding_cell.left + depth_pad)
		spacing:      -cfg.size_border
		content:      [
			text(
				text:       label
				mode:       .single_line
				text_style: cfg.text_style_header
			),
		]
	)
}

fn data_grid_detail_row_view(cfg DataGridCfg, row_data GridRow, row_idx int, columns []GridColumnCfg, column_widths map[string]f32, row_height f32, focus_id u32, mut window Window) View {
	if cfg.on_detail_row_view == unsafe { nil } {
		return rectangle(
			name:   'data_grid detail row placeholder'
			height: row_height
			sizing: fill_fixed
			color:  color_transparent
		)
	}
	row_id := data_grid_row_id(row_data, row_idx)
	detail_view := cfg.on_detail_row_view(row_data, mut window)
	return row(
		name:         'data_grid detail row'
		id:           '${cfg.id}:detail:${row_id}'
		height:       row_height
		sizing:       fill_fixed
		color:        cfg.color_background
		color_border: cfg.color_border
		size_border:  0
		padding:      padding(cfg.padding_cell.top, cfg.padding_cell.right, cfg.padding_cell.bottom,
			cfg.padding_cell.left + data_grid_detail_indent())
		spacing:      -cfg.size_border
		content:      [
			row(
				name:         'data_grid detail row content'
				width:        data_grid_columns_total_width(columns, column_widths)
				sizing:       fixed_fill
				padding:      padding_none
				color:        color_transparent
				color_border: color_transparent
				size_border:  0
				content:      [detail_view]
			),
		]
		on_click:     fn [focus_id] (_ &Layout, mut e Event, mut w Window) {
			if focus_id > 0 {
				w.set_id_focus(focus_id)
			}
			e.is_handled = true
		}
	)
}

fn data_grid_row_view(cfg DataGridCfg, row_data GridRow, row_idx int, columns []GridColumnCfg, column_widths map[string]f32, row_height f32, focus_id u32, editing_row_id string, show_delete_action bool, mut window Window) View {
	row_id := data_grid_row_id(row_data, row_idx)
	is_selected := cfg.selection.selected_row_ids[row_id]
	grid_id := cfg.id
	selection := cfg.selection
	on_selection_change := cfg.on_selection_change
	rows := cfg.rows
	multi_select := cfg.multi_select
	range_select := cfg.range_select
	edit_enabled := data_grid_editing_enabled(cfg)
	editor_focus_base := data_grid_cell_editor_focus_base_id(cfg, columns.len)
	col_count := columns.len
	detail_enabled := cfg.on_detail_row_view != unsafe { nil }
	detail_toggle_enabled := cfg.on_detail_expanded_change != unsafe { nil }
	detail_expanded := data_grid_detail_row_expanded(cfg, row_id)
	is_editing_row := editing_row_id == row_id && edit_enabled
	row_view_id := '${cfg.id}:row:${row_id}'
	cell_id_prefix := '${cfg.id}:cell:${row_id}:'
	delete_action_id := '${cfg.id}:row-delete:${row_id}'
	mut cells := []View{cap: columns.len}
	for col_idx, col in columns {
		value := row_data.cells[col.id] or { '' }
		base_text_style := col.text_style or { cfg.text_style }
		mut text_style := base_text_style
		mut cell_color := color_transparent
		if cfg.on_cell_format != unsafe { nil } {
			cell_format := cfg.on_cell_format(row_data, row_idx, col, value, mut window)
			next_text_style, next_cell_color := data_grid_resolve_cell_format(base_text_style,
				cell_format)
			text_style = next_text_style
			cell_color = next_cell_color
		}
		is_editing_cell := is_editing_row && col.editable
		mut cell_content := []View{cap: 2}
		if col_idx == 0 && detail_enabled {
			cell_content << data_grid_detail_toggle_control(cfg, row_id, detail_expanded,
				detail_toggle_enabled, focus_id)
		}
		if is_editing_cell {
			editor_focus_id := data_grid_cell_editor_focus_id(cfg, columns.len, row_idx,
				col_idx)
			cell_content << data_grid_cell_editor_view(cfg, row_id, row_idx, col, value,
				editor_focus_id, focus_id, mut window)
		} else {
			cell_content << text(
				text:       value
				mode:       .single_line
				text_style: text_style
			)
		}
		cells << row(
			name:         'data_grid cell'
			id:           '${cell_id_prefix}${col.id}'
			width:        data_grid_column_width_for(col, column_widths)
			sizing:       fixed_fill
			padding:      if is_editing_cell { padding_none } else { cfg.padding_cell }
			color:        cell_color
			color_border: cfg.color_border
			size_border:  cfg.size_border
			h_align:      if col_idx == 0 && detail_enabled { .start } else { col.align }
			content:      [
				row(
					name:    'data_grid cell content'
					sizing:  fill_fill
					padding: padding_none
					h_align: if col_idx == 0 && detail_enabled { .start } else { col.align }
					v_align: .middle
					spacing: if is_editing_cell { 0 } else { 4 }
					content: cell_content
				),
			]
		)
	}
	if show_delete_action {
		cells << button(
			id:           delete_action_id
			width:        data_grid_header_control_width + 10
			sizing:       fixed_fill
			padding:      padding_none
			size_border:  0
			radius:       0
			color:        color_transparent
			color_hover:  cfg.color_header_hover
			color_focus:  color_transparent
			color_click:  cfg.color_header_hover
			color_border: cfg.color_border
			on_click:     fn [grid_id, selection, on_selection_change, row_id, focus_id] (_ &Layout, mut e Event, mut w Window) {
				data_grid_crud_delete_rows(grid_id, selection, on_selection_change, [
					row_id,
				], focus_id, mut e, mut w)
			}
			content:      [
				text(
					text:       '×'
					mode:       .single_line
					text_style: data_grid_indicator_text_style(cfg.text_style_filter)
				),
			]
		)
	}

	row_color := if is_selected {
		cfg.color_row_selected
	} else if row_idx % 2 == 1 {
		cfg.color_row_alt
	} else {
		color_transparent
	}
	color_row_hover := cfg.color_row_hover

	return row(
		name:         'data_grid row'
		id:           row_view_id
		height:       row_height
		sizing:       fill_fixed
		color:        row_color
		color_border: cfg.color_border
		size_border:  0
		padding:      padding_none
		spacing:      -cfg.size_border
		on_click:     fn [rows, selection, grid_id, multi_select, range_select, on_selection_change, edit_enabled, editor_focus_base, col_count, row_idx, row_id, focus_id, columns] (_ &Layout, mut e Event, mut w Window) {
			data_grid_row_click(rows, selection, grid_id, multi_select, range_select,
				on_selection_change, edit_enabled, editor_focus_base, col_count, row_idx,
				row_id, focus_id, columns, mut e, mut w)
		}
		on_hover:     fn [color_row_hover, is_selected] (mut layout Layout, mut _ Event, mut w Window) {
			w.set_mouse_cursor_pointing_hand()
			if !is_selected {
				layout.shape.color = color_row_hover
			}
		}
		content:      cells
	)
}

fn data_grid_resolve_cell_format(base TextStyle, format GridCellFormat) (TextStyle, Color) {
	mut text_style := base
	if format.has_text_color {
		text_style = TextStyle{
			...text_style
			color: format.text_color
		}
	}
	mut bg_color := color_transparent
	if format.has_bg_color {
		bg_color = format.bg_color
	}
	return text_style, bg_color
}

fn data_grid_row_click(rows []GridRow, selection GridSelection, grid_id string, multi_select bool, range_select bool, on_selection_change fn (sel GridSelection, mut e Event, mut w Window), edit_enabled bool, editor_focus_base u32, col_count int, row_idx int, row_id string, focus_id u32, columns []GridColumnCfg, mut e Event, mut w Window) {
	if focus_id > 0 {
		w.set_id_focus(focus_id)
	}
	if row_idx < 0 || row_idx >= rows.len {
		return
	}
	if on_selection_change != unsafe { nil } {
		next := data_grid_compute_row_selection(rows, selection, grid_id, multi_select,
			range_select, row_id, mut e, mut w)
		on_selection_change(next, mut e, mut w)
	}
	data_grid_track_row_edit_click(grid_id, edit_enabled, editor_focus_base, col_count,
		columns, row_idx, row_id, focus_id, mut e, mut w)
	e.is_handled = true
}

// Three selection modes:
// - Shift+click: range select from anchor to clicked row
// - Ctrl/Cmd+click: toggle individual row in selection
// - Plain click: single select, replaces entire selection
// Anchor is persisted in view_state to survive re-renders.
fn data_grid_toggle_selected_row_ids(selected_row_ids map[string]bool, row_id string) map[string]bool {
	mut next := map[string]bool{}
	if selected_row_ids[row_id] {
		for selected_id, enabled in selected_row_ids {
			if selected_id != row_id && enabled {
				next[selected_id] = true
			}
		}
		return next
	}
	for selected_id, enabled in selected_row_ids {
		if enabled {
			next[selected_id] = true
		}
	}
	next[row_id] = true
	return next
}

@[inline]
fn data_grid_selection_is_single_row(selected_row_ids map[string]bool, row_id string) bool {
	return row_id.len > 0 && selected_row_ids.len == 1 && selected_row_ids[row_id]
}

fn data_grid_compute_row_selection(rows []GridRow, selection GridSelection, grid_id string, multi_select bool, range_select bool, row_id string, mut e Event, mut w Window) GridSelection {
	is_shift := e.modifiers.has(.shift)
	is_toggle := e.modifiers.has(.ctrl) || e.modifiers.has(.super)

	if multi_select && range_select && is_shift {
		anchor := data_grid_anchor_row_id_ex(selection, grid_id, rows, mut w, row_id)
		start, end := data_grid_range_indices(rows, anchor, row_id)
		mut selected := map[string]bool{}
		if start >= 0 && end >= start {
			for idx in start .. end + 1 {
				selected[data_grid_row_id(rows[idx], idx)] = true
			}
		} else {
			selected[row_id] = true
		}
		data_grid_set_anchor(grid_id, anchor, mut w)
		return GridSelection{
			anchor_row_id:    anchor
			active_row_id:    row_id
			selected_row_ids: selected
		}
	} else if multi_select && is_toggle {
		selected := data_grid_toggle_selected_row_ids(selection.selected_row_ids, row_id)
		data_grid_set_anchor(grid_id, row_id, mut w)
		return GridSelection{
			anchor_row_id:    row_id
			active_row_id:    row_id
			selected_row_ids: selected
		}
	}
	data_grid_set_anchor(grid_id, row_id, mut w)
	if data_grid_selection_is_single_row(selection.selected_row_ids, row_id) {
		return GridSelection{
			anchor_row_id:    row_id
			active_row_id:    row_id
			selected_row_ids: selection.selected_row_ids
		}
	}
	return GridSelection{
		anchor_row_id:    row_id
		active_row_id:    row_id
		selected_row_ids: {
			row_id: true
		}
	}
}

fn data_grid_cell_editor_view(cfg DataGridCfg, row_id string, row_idx int, col GridColumnCfg, value string, editor_focus_id u32, grid_focus_id u32, mut window Window) View {
	editor_id := '${cfg.id}:editor:${row_id}:${col.id}'
	col_id := col.id
	grid_id := cfg.id
	crud_enabled := data_grid_crud_enabled(cfg)
	on_cell_edit := cfg.on_cell_edit
	mut editor := View(invisible_container_view())
	match col.editor {
		.select {
			mut options := col.editor_options.clone()
			if options.len == 0 && value.len > 0 {
				options = [value]
			}
			editor = window.select(
				id:          editor_id
				id_focus:    editor_focus_id
				select:      if value.len > 0 { [value] } else { []string{} }
				options:     options
				sizing:      fill_fill
				padding:     padding_none
				size_border: 0
				radius:      0
				on_select:   fn [grid_id, crud_enabled, on_cell_edit, row_id, row_idx, col_id] (selected []string, mut e Event, mut w Window) {
					next_value := if selected.len > 0 { selected[0] } else { '' }
					if row_id.len > 0 && col_id.len > 0 {
						data_grid_crud_apply_cell_edit(grid_id, crud_enabled, on_cell_edit,
							GridCellEdit{
							row_id:  row_id
							row_idx: row_idx
							col_id:  col_id
							value:   next_value
						}, mut e, mut w)
					}
				}
			)
		}
		.date {
			date := data_grid_parse_editor_date(value)
			editor = window.input_date(
				id:          editor_id
				id_focus:    editor_focus_id
				date:        date
				sizing:      fill_fill
				padding:     padding_none
				size_border: 0
				radius:      0
				on_select:   fn [grid_id, crud_enabled, on_cell_edit, row_id, row_idx, col_id] (dates []time.Time, mut e Event, mut w Window) {
					if dates.len == 0 {
						return
					}
					next_value := dates[0].custom_format('M/D/YYYY')
					if row_id.len > 0 && col_id.len > 0 {
						data_grid_crud_apply_cell_edit(grid_id, crud_enabled, on_cell_edit,
							GridCellEdit{
							row_id:  row_id
							row_idx: row_idx
							col_id:  col_id
							value:   next_value
						}, mut e, mut w)
					}
				}
			)
		}
		.checkbox {
			checked := data_grid_editor_bool_value(value)
			editor_true_value := col.editor_true_value
			editor_false_value := col.editor_false_value
			editor = toggle(
				id:       editor_id
				id_focus: editor_focus_id
				select:   checked
				padding:  padding_none
				on_click: fn [grid_id, crud_enabled, on_cell_edit, row_id, row_idx, col_id, checked, editor_true_value, editor_false_value] (_ &Layout, mut e Event, mut w Window) {
					next_value := if !checked {
						editor_true_value
					} else {
						editor_false_value
					}
					if row_id.len > 0 && col_id.len > 0 {
						data_grid_crud_apply_cell_edit(grid_id, crud_enabled, on_cell_edit,
							GridCellEdit{
							row_id:  row_id
							row_idx: row_idx
							col_id:  col_id
							value:   next_value
						}, mut e, mut w)
					}
					e.is_handled = true
				}
			)
		}
		.text {
			editor = input(
				id:              editor_id
				id_focus:        editor_focus_id
				text:            value
				sizing:          fill_fill
				padding:         padding_none
				size_border:     0
				radius:          0
				on_text_changed: fn [grid_id, crud_enabled, on_cell_edit, row_id, row_idx, col_id] (_ &Layout, text string, mut w Window) {
					if row_id.len > 0 && col_id.len > 0 {
						mut e := Event{}
						data_grid_crud_apply_cell_edit(grid_id, crud_enabled, on_cell_edit,
							GridCellEdit{
							row_id:  row_id
							row_idx: row_idx
							col_id:  col_id
							value:   text
						}, mut e, mut w)
					}
				}
				on_enter:        fn [grid_id, grid_focus_id] (_ &Layout, mut e Event, mut w Window) {
					data_grid_clear_editing_row(grid_id, mut w)
					if grid_focus_id > 0 {
						w.set_id_focus(grid_focus_id)
					}
					e.is_handled = true
				}
			)
		}
	}
	return row(
		name:       'data_grid cell editor'
		id:         '${editor_id}:wrap'
		id_focus:   editor_focus_id
		focus_skip: true
		sizing:     fill_fill
		padding:    padding_none
		spacing:    0
		on_keydown: make_data_grid_editor_on_keydown(cfg.id, grid_focus_id)
		content:    [editor]
	)
}

fn make_data_grid_editor_on_keydown(grid_id string, grid_focus_id u32) fn (&Layout, mut Event, mut Window) {
	return fn [grid_id, grid_focus_id] (_ &Layout, mut e Event, mut w Window) {
		if e.modifiers != .none || e.key_code != .escape {
			return
		}
		data_grid_clear_editing_row(grid_id, mut w)
		if grid_focus_id > 0 {
			w.set_id_focus(grid_focus_id)
		}
		e.is_handled = true
	}
}

fn data_grid_track_row_edit_click(grid_id string, edit_enabled bool, editor_focus_base u32, col_count int, columns []GridColumnCfg, row_idx int, row_id string, grid_focus_id u32, mut e Event, mut w Window) {
	if !edit_enabled || data_grid_has_keyboard_modifiers(&e) {
		return
	}
	first_col_idx := data_grid_first_editable_column_index_ex(columns)
	if first_col_idx < 0 {
		return
	}
	mut dg_es := state_map[string, DataGridEditState](mut w, ns_dg_edit, cap_moderate)
	mut state := dg_es.get(grid_id) or { DataGridEditState{} }
	is_double_click := state.last_click_row_id == row_id && state.last_click_frame > 0
		&& e.frame_count - state.last_click_frame <= data_grid_edit_double_click_frames
	if is_double_click {
		state.editing_row_id = row_id
		state.last_click_row_id = ''
		state.last_click_frame = 0
		dg_es.set(grid_id, state)
		editor_focus_id := data_grid_editor_focus_id_from_base(editor_focus_base, col_count,
			first_col_idx)
		if editor_focus_id > 0 {
			w.set_id_focus(editor_focus_id)
		} else if grid_focus_id > 0 {
			w.set_id_focus(grid_focus_id)
		}
		return
	}
	if state.editing_row_id.len > 0 && state.editing_row_id != row_id {
		state.editing_row_id = ''
	}
	state.last_click_row_id = row_id
	state.last_click_frame = e.frame_count
	dg_es.set(grid_id, state)
}

fn data_grid_has_keyboard_modifiers(e &Event) bool {
	return e.modifiers.has_any(.shift, .ctrl, .alt, .super)
}

fn data_grid_start_edit_active_row(cfg DataGridCfg, mut e Event, mut w Window) {
	if !data_grid_editing_enabled(cfg) || cfg.rows.len == 0 {
		return
	}
	columns := data_grid_effective_columns(cfg.columns, cfg.column_order, cfg.hidden_column_ids)
	first_col_idx := data_grid_first_editable_column_index(cfg, columns)
	if first_col_idx < 0 {
		return
	}
	row_idx := data_grid_active_row_index(cfg.rows, cfg.selection)
	if row_idx < 0 || row_idx >= cfg.rows.len {
		return
	}
	row_id := data_grid_row_id(cfg.rows[row_idx], row_idx)
	data_grid_set_editing_row(cfg.id, row_id, mut w)
	editor_focus_id := data_grid_cell_editor_focus_id(cfg, columns.len, row_idx, first_col_idx)
	if editor_focus_id > 0 {
		w.set_id_focus(editor_focus_id)
	}
	e.is_handled = true
}

fn data_grid_first_editable_column_index(cfg DataGridCfg, columns []GridColumnCfg) int {
	if !data_grid_editing_enabled(cfg) {
		return -1
	}
	return data_grid_first_editable_column_index_ex(columns)
}

fn data_grid_first_editable_column_index_ex(columns []GridColumnCfg) int {
	for idx, col in columns {
		if col.editable {
			return idx
		}
	}
	return -1
}

// Focus ID allocation: grid_focus_id is the base. Header
// cells get IDs [base+1 .. base+col_count]. Editor cells
// start at base+col_count+1, indexed by column only (not
// row) because only one row is editable at a time.
fn data_grid_cell_editor_focus_base_id(cfg DataGridCfg, col_count int) u32 {
	if col_count <= 0 {
		return 0
	}
	header_base := data_grid_header_focus_base_id(cfg, col_count)
	if header_base == 0 {
		return 0
	}
	if header_base > max_u32 - u32(col_count) {
		return 0
	}
	return header_base + u32(col_count)
}

fn data_grid_cell_editor_focus_id(cfg DataGridCfg, col_count int, row_idx int, col_idx int) u32 {
	if col_count <= 0 || row_idx < 0 || col_idx < 0 || col_idx >= col_count {
		return 0
	}
	base := data_grid_cell_editor_focus_base_id(cfg, col_count)
	if base == 0 {
		return 0
	}
	// Editor focus ids are column-scoped because only one row is editable at a
	// time. Keeping ids independent of row index preserves focus while sorting.
	cell_offset := u64(col_idx)
	if cell_offset > u64(max_u32 - base) {
		return 0
	}
	return base + u32(cell_offset)
}

fn data_grid_editor_focus_id_from_base(base u32, col_count int, col_idx int) u32 {
	if base == 0 || col_count <= 0 || col_idx < 0 || col_idx >= col_count {
		return 0
	}
	cell_offset := u64(col_idx)
	if cell_offset > u64(max_u32 - base) {
		return 0
	}
	return base + u32(cell_offset)
}

fn data_grid_editing_row_id(grid_id string, mut w Window) string {
	if state := state_map[string, DataGridEditState](mut w, ns_dg_edit, cap_moderate).get(grid_id) {
		return state.editing_row_id
	}
	return ''
}

fn data_grid_set_editing_row(grid_id string, row_id string, mut w Window) {
	mut dg_es := state_map[string, DataGridEditState](mut w, ns_dg_edit, cap_moderate)
	mut state := dg_es.get(grid_id) or { DataGridEditState{} }
	state.editing_row_id = row_id
	dg_es.set(grid_id, state)
}

fn data_grid_clear_editing_row(grid_id string, mut w Window) {
	mut dg_es := state_map[string, DataGridEditState](mut w, ns_dg_edit, cap_moderate)
	mut state := dg_es.get(grid_id) or { DataGridEditState{} }
	state.editing_row_id = ''
	dg_es.set(grid_id, state)
}

fn data_grid_has_row_id(rows []GridRow, row_id string) bool {
	if row_id.len == 0 {
		return false
	}
	for idx, row in rows {
		if data_grid_row_id(row, idx) == row_id {
			return true
		}
	}
	return false
}

fn data_grid_editor_bool_value(value string) bool {
	match value.trim_space().to_lower() {
		'1', 'true', 'yes', 'y', 'on' { return true }
		else { return false }
	}
}

fn data_grid_parse_editor_date(value string) time.Time {
	trimmed := value.trim_space()
	if trimmed.len == 0 {
		return time.now()
	}
	if parsed := time.parse_format(trimmed, 'M/D/YYYY') {
		return parsed
	}
	if parsed := time.parse(trimmed) {
		return parsed
	}
	if parsed := time.parse_rfc3339(trimmed) {
		return parsed
	}
	return time.now()
}

fn data_grid_detail_toggle_control(cfg DataGridCfg, row_id string, expanded bool, enabled bool, focus_id u32) View {
	label := if expanded { '▼' } else { '▶' }
	style := data_grid_indicator_text_style(cfg.text_style)
	on_detail_expanded_change := cfg.on_detail_expanded_change
	detail_toggle_id := '${cfg.id}:detail_toggle:${row_id}'
	if !enabled {
		return row(
			name:    'data_grid detail toggle'
			width:   data_grid_header_control_width
			sizing:  fixed_fill
			padding: padding_none
			content: [
				text(
					text:       label
					mode:       .single_line
					text_style: style
				),
			]
		)
	}
	return button(
		id:           detail_toggle_id
		width:        data_grid_header_control_width
		sizing:       fixed_fill
		padding:      padding_none
		size_border:  0
		radius:       0
		color:        color_transparent
		color_hover:  cfg.color_row_hover
		color_focus:  color_transparent
		color_click:  cfg.color_row_hover
		color_border: color_transparent
		on_click:     data_grid_make_detail_toggle_on_click(on_detail_expanded_change,
			cfg.detail_expanded_row_ids, row_id, focus_id)
		content:      [
			text(
				text:       label
				mode:       .single_line
				text_style: style
			),
		]
	)
}

fn data_grid_make_detail_toggle_on_click(on_detail_expanded_change fn (next map[string]bool, mut e Event, mut w Window), detail_expanded_row_ids map[string]bool, row_id string, focus_id u32) fn (&Layout, mut Event, mut Window) {
	return fn [on_detail_expanded_change, detail_expanded_row_ids, row_id, focus_id] (_ &Layout, mut e Event, mut w Window) {
		if row_id.len == 0 || on_detail_expanded_change == unsafe { nil } {
			return
		}
		next := data_grid_next_detail_expanded_map(detail_expanded_row_ids, row_id)
		on_detail_expanded_change(next, mut e, mut w)
		if focus_id > 0 {
			w.set_id_focus(focus_id)
		}
		e.is_handled = true
	}
}

fn data_grid_detail_row_expanded(cfg DataGridCfg, row_id string) bool {
	return row_id.len > 0 && cfg.detail_expanded_row_ids[row_id]
}

fn data_grid_next_detail_expanded_map(expanded map[string]bool, row_id string) map[string]bool {
	mut next := expanded.clone()
	if row_id.len == 0 {
		return next
	}
	if next[row_id] {
		next.delete(row_id)
	} else {
		next[row_id] = true
	}
	return next
}

fn data_grid_detail_indent() f32 {
	return data_grid_header_control_width + data_grid_detail_indent_gap
}

fn data_grid_scroll_padding(cfg DataGridCfg) Padding {
	if cfg.scrollbar == .hidden {
		return padding_none
	}
	return padding(0, data_grid_scroll_gutter(), 0, 0)
}

fn data_grid_scroll_gutter() f32 {
	style := gui_theme.scrollbar_style
	return style.size + style.gap_edge + style.gap_end
}

fn data_grid_frozen_top_zone(cfg DataGridCfg, row_views []View, zone_height f32, total_width f32, scroll_x f32) View {
	return row(
		name:         'data_grid frozen top zone'
		height:       zone_height
		sizing:       fill_fixed
		clip:         true
		color:        cfg.color_background
		color_border: cfg.color_border
		size_border:  0
		padding:      data_grid_scroll_padding(cfg)
		spacing:      0
		content:      [
			column(
				name:         'data_grid frozen top content'
				x:            scroll_x
				width:        total_width
				sizing:       fixed_fill
				color:        color_transparent
				color_border: color_transparent
				size_border:  0
				padding:      padding_none
				spacing:      0
				content:      row_views
			),
		]
	)
}

fn data_grid_frozen_top_views(cfg DataGridCfg, frozen_top_indices []int, columns []GridColumnCfg, column_widths map[string]f32, row_height f32, focus_id u32, editing_row_id string, show_delete_action bool, mut window Window) ([]View, int) {
	if frozen_top_indices.len == 0 {
		return []View{}, 0
	}
	mut views := []View{cap: frozen_top_indices.len * 2}
	mut display_rows := 0
	for row_idx in frozen_top_indices {
		if row_idx < 0 || row_idx >= cfg.rows.len {
			continue
		}
		row_data := cfg.rows[row_idx]
		row_id := data_grid_row_id(row_data, row_idx)
		views << data_grid_row_view(cfg, row_data, row_idx, columns, column_widths, row_height,
			focus_id, editing_row_id, show_delete_action, mut window)
		display_rows++
		if cfg.on_detail_row_view != unsafe { nil } && data_grid_detail_row_expanded(cfg, row_id) {
			views << data_grid_detail_row_view(cfg, row_data, row_idx, columns, column_widths,
				row_height, focus_id, mut window)
			display_rows++
		}
	}
	return views, display_rows
}

fn data_grid_frozen_top_id_set(cfg DataGridCfg) map[string]bool {
	mut out := map[string]bool{}
	for row_id in cfg.frozen_top_row_ids {
		trimmed := row_id.trim_space()
		if trimmed.len == 0 {
			continue
		}
		out[trimmed] = true
	}
	return out
}

fn data_grid_split_frozen_top_indices(cfg DataGridCfg, row_indices []int) ([]int, []int) {
	visible_indices := data_grid_visible_row_indices(cfg.rows.len, row_indices)
	frozen_ids := data_grid_frozen_top_id_set(cfg)
	if visible_indices.len == 0 || frozen_ids.len == 0 {
		return []int{}, visible_indices.clone()
	}
	mut frozen_top := []int{cap: visible_indices.len}
	mut body := []int{cap: visible_indices.len}
	mut seen := map[string]bool{}
	for row_idx in visible_indices {
		if row_idx < 0 || row_idx >= cfg.rows.len {
			continue
		}
		row_id := data_grid_row_id(cfg.rows[row_idx], row_idx)
		if row_id.len > 0 && frozen_ids[row_id] && !seen[row_id] {
			seen[row_id] = true
			frozen_top << row_idx
			continue
		}
		body << row_idx
	}
	return frozen_top, body
}

fn data_grid_page_bounds(total_rows int, page_size_ int, requested_page int) (int, int, int, int) {
	if total_rows <= 0 {
		return 0, 0, 0, 1
	}
	if page_size_ <= 0 {
		return 0, total_rows, 0, 1
	}
	page_size := int_min(page_size_, total_rows)
	page_count := int_max(1, int((total_rows + page_size - 1) / page_size))
	page_index := int_clamp(requested_page, 0, page_count - 1)
	start := page_index * page_size
	end := int_min(total_rows, start + page_size)
	return start, end, page_index, page_count
}

fn data_grid_page_row_indices(start int, end int) []int {
	if end <= start || start < 0 {
		return []
	}
	mut indices := []int{cap: end - start}
	for idx in start .. end {
		indices << idx
	}
	return indices
}

fn data_grid_visible_row_indices(row_count int, page_indices []int) []int {
	if page_indices.len > 0 {
		return page_indices
	}
	return data_grid_page_row_indices(0, int_max(0, row_count))
}

fn data_grid_index_in_list(values []int, target int) int {
	for idx, value in values {
		if value == target {
			return idx
		}
	}
	return -1
}
