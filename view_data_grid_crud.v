// Data grid: CRUD operations, toolbar, dirty-state.
module gui

fn data_grid_crud_enabled(cfg DataGridCfg) bool {
	return cfg.show_crud_toolbar
}

fn data_grid_editing_enabled(cfg DataGridCfg) bool {
	return cfg.on_cell_edit != unsafe { nil } || data_grid_crud_enabled(cfg)
}

fn data_grid_crud_has_unsaved(state DataGridCrudState) bool {
	return state.dirty_row_ids.len > 0 || state.draft_row_ids.len > 0
		|| state.deleted_row_ids.len > 0
}

fn data_grid_crud_row_delete_enabled(cfg DataGridCfg, has_source bool, caps GridDataCapabilities) bool {
	if !data_grid_crud_enabled(cfg) || !cfg.allow_delete {
		return false
	}
	if !has_source {
		return true
	}
	return caps.supports_delete
}

// col_ids: pre-sorted column ID list. When non-empty,
// avoids per-row .keys() + .sort() allocations.
fn data_grid_rows_signature(rows []GridRow, col_ids []string) u64 {
	if rows.len == 0 {
		return u64(0)
	}
	mut h := u64(data_grid_fnv64_offset)
	for idx, row in rows {
		if idx > 0 {
			h = data_grid_fnv64_str(h, data_grid_group_sep)
		}
		row_id := data_grid_row_id(row, idx)
		h = data_grid_fnv64_str(h, row_id)
		h = data_grid_fnv64_str(h, data_grid_record_sep)
		keys := if col_ids.len > 0 {
			col_ids
		} else {
			mut k := row.cells.keys()
			k.sort()
			k
		}
		for j, key in keys {
			if j > 0 {
				h = data_grid_fnv64_str(h, data_grid_unit_sep)
			}
			h = data_grid_fnv64_str(h, key)
			h = data_grid_fnv64_byte(h, `=`)
			h = data_grid_fnv64_str(h, row.cells[key] or { '' })
		}
	}
	return h
}

fn data_grid_rows_id_signature(rows []GridRow) u64 {
	if rows.len == 0 {
		return u64(0)
	}
	mut h := u64(data_grid_fnv64_offset)
	for idx, row in rows {
		if idx > 0 {
			h = data_grid_fnv64_str(h, data_grid_group_sep)
		}
		h = data_grid_fnv64_str(h, data_grid_row_id(row, idx))
	}
	return h
}

// CRUD uses a working copy of rows. When no unsaved changes
// exist and the source signature changes, the working copy
// resets to match the new source data. Signature is an
// FNV-1a hash of all row ids + cell values.
fn data_grid_crud_resolve_cfg(cfg DataGridCfg, mut window Window) (DataGridCfg, DataGridCrudState) {
	mut state := window.view_state.data_grid_crud_state.get(cfg.id) or { DataGridCrudState{} }
	// Use precomputed signature from source state when
	// available. In local-rows mode, skip full signature
	// recompute when row count and row-id signature are
	// unchanged.
	mut signature := u64(0)
	if src_state := window.view_state.data_grid_source_state.get(cfg.id) {
		signature = src_state.rows_signature
		state.local_rows_signature_valid = false
		state.local_rows_len = -1
		state.local_rows_id_signature = 0
	} else {
		local_len := cfg.rows.len
		local_id_signature := data_grid_rows_id_signature(cfg.rows)
		if state.local_rows_signature_valid && state.local_rows_len == local_len
			&& state.local_rows_id_signature == local_id_signature {
			signature = state.source_signature
		} else {
			signature = data_grid_rows_signature(cfg.rows, []string{})
			state.local_rows_signature_valid = true
			state.local_rows_len = local_len
			state.local_rows_id_signature = local_id_signature
		}
	}
	has_unsaved := data_grid_crud_has_unsaved(state)
	if (!has_unsaved && (state.source_signature != signature
		|| state.working_rows.len != cfg.rows.len))
		|| (state.working_rows.len == 0 && state.committed_rows.len == 0 && cfg.rows.len > 0) {
		state.committed_rows = cfg.rows.clone()
		state.working_rows = state.committed_rows.clone()
		state.source_signature = signature
		state.dirty_row_ids = map[string]bool{}
		state.draft_row_ids = map[string]bool{}
		state.deleted_row_ids = map[string]bool{}
	}
	window.view_state.data_grid_crud_state.set(cfg.id, state)
	mut load_error := cfg.load_error
	if state.save_error.len > 0 {
		load_error = state.save_error
	}
	return DataGridCfg{
		...cfg
		rows:       state.working_rows.clone()
		load_error: load_error
		loading:    cfg.loading || state.saving
	}, state
}

fn data_grid_crud_toolbar_row(cfg DataGridCfg, state DataGridCrudState, caps GridDataCapabilities, has_source bool, focus_id u32) View {
	has_unsaved := data_grid_crud_has_unsaved(state)
	can_create := cfg.allow_create && (!has_source || caps.supports_create)
	can_delete := cfg.allow_delete && (!has_source || caps.supports_delete)
	selected_count := cfg.selection.selected_row_ids.len
	grid_id := cfg.id
	columns := cfg.columns
	selection := cfg.selection
	on_selection_change := cfg.on_selection_change
	data_source := cfg.data_source
	query := cfg.query
	on_crud_error := cfg.on_crud_error
	on_rows_change := cfg.on_rows_change
	dirty_count := state.dirty_row_ids.len
	draft_count := state.draft_row_ids.len
	delete_count := state.deleted_row_ids.len
	status := if state.saving {
		'Saving...'
	} else if state.save_error.len > 0 {
		'Save failed'
	} else if has_unsaved {
		'Draft ${draft_count} Dirty ${dirty_count} Delete ${delete_count}'
	} else {
		'Clean'
	}
	return row(
		name:         'data_grid crud toolbar'
		height:       data_grid_header_height(cfg)
		sizing:       fill_fixed
		color:        cfg.color_filter
		color_border: cfg.color_border
		size_border:  0
		padding:      data_grid_pager_padding(cfg)
		spacing:      6
		v_align:      .middle
		content:      [
			data_grid_indicator_button('Add', cfg.text_style_filter, cfg.color_header_hover,
				!can_create || state.saving, 0, fn [grid_id, columns, on_selection_change, focus_id] (_ &Layout, mut e Event, mut w Window) {
				data_grid_crud_add_row(grid_id, columns, on_selection_change, focus_id, mut
					e, mut w)
			}),
			data_grid_indicator_button('Delete', cfg.text_style_filter, cfg.color_header_hover,
				!can_delete || selected_count == 0 || state.saving, 0, fn [grid_id, selection, on_selection_change, focus_id] (_ &Layout, mut e Event, mut w Window) {
				data_grid_crud_delete_selected(grid_id, selection, on_selection_change,
					focus_id, mut e, mut w)
			}),
			data_grid_indicator_button('Save', cfg.text_style_filter, cfg.color_header_hover,
				!has_unsaved || state.saving, 0, fn [grid_id, data_source, query, on_crud_error, on_rows_change, selection, on_selection_change, focus_id, has_source, caps] (_ &Layout, mut e Event, mut w Window) {
				data_grid_crud_save(DataGridCrudSaveContext{
					grid_id:             grid_id
					data_source:         data_source
					query:               query
					on_crud_error:       on_crud_error
					on_rows_change:      on_rows_change
					selection:           selection
					on_selection_change: on_selection_change
					has_source:          has_source
					caps:                caps
					focus_id:            focus_id
				}, mut e, mut w)
			}),
			data_grid_indicator_button('Cancel', cfg.text_style_filter, cfg.color_header_hover,
				(!has_unsaved && state.save_error.len == 0) || state.saving, 0, fn [grid_id, focus_id] (_ &Layout, mut e Event, mut w Window) {
				data_grid_crud_cancel(grid_id, focus_id, mut e, mut w)
			}),
			row(
				name:    'data_grid crud spacer'
				sizing:  fill_fill
				padding: padding_none
				content: []
			),
			text(
				text:       'Selected ${selected_count}'
				mode:       .single_line
				text_style: data_grid_indicator_text_style(cfg.text_style_filter)
			),
			text(
				text:       status
				mode:       .single_line
				text_style: data_grid_indicator_text_style(cfg.text_style_filter)
			),
		]
	)
}

fn data_grid_crud_toolbar_height(cfg DataGridCfg) f32 {
	return data_grid_header_height(cfg)
}

fn data_grid_crud_default_cells(columns []GridColumnCfg) map[string]string {
	mut cells := map[string]string{}
	for col in columns {
		if col.id.len == 0 {
			continue
		}
		cells[col.id] = col.default_value
	}
	return cells
}

fn data_grid_crud_add_row(grid_id string, columns []GridColumnCfg, on_selection_change fn (sel GridSelection, mut e Event, mut w Window), focus_id u32, mut e Event, mut w Window) {
	mut state := w.view_state.data_grid_crud_state.get(grid_id) or { DataGridCrudState{} }
	state.next_draft_seq++
	draft_id := '__draft_${grid_id}_${state.next_draft_seq}'
	row := GridRow{
		id:    draft_id
		cells: data_grid_crud_default_cells(columns)
	}
	state.working_rows.insert(0, row)
	state.draft_row_ids[draft_id] = true
	state.dirty_row_ids[draft_id] = true
	state.save_error = ''
	w.view_state.data_grid_crud_state.set(grid_id, state)
	data_grid_set_editing_row(grid_id, draft_id, mut w)
	if on_selection_change != unsafe { nil } {
		next := GridSelection{
			anchor_row_id:    draft_id
			active_row_id:    draft_id
			selected_row_ids: {
				draft_id: true
			}
		}
		on_selection_change(next, mut e, mut w)
	}
	if focus_id > 0 {
		w.set_id_focus(focus_id)
	}
	e.is_handled = true
}

fn data_grid_crud_delete_selected(grid_id string, selection GridSelection, on_selection_change fn (sel GridSelection, mut e Event, mut w Window), focus_id u32, mut e Event, mut w Window) {
	if selection.selected_row_ids.len == 0 {
		return
	}
	mut ids := []string{cap: selection.selected_row_ids.len}
	for row_id, selected in selection.selected_row_ids {
		if selected && row_id.len > 0 {
			ids << row_id
		}
	}
	data_grid_crud_delete_rows(grid_id, selection, on_selection_change, ids, focus_id, mut
		e, mut w)
}

fn data_grid_crud_delete_rows(grid_id string, selection GridSelection, on_selection_change fn (sel GridSelection, mut e Event, mut w Window), row_ids []string, focus_id u32, mut e Event, mut w Window) {
	if row_ids.len == 0 {
		return
	}
	mut delete_ids := map[string]bool{}
	for row_id in row_ids {
		id := row_id.trim_space()
		if id.len > 0 {
			delete_ids[id] = true
		}
	}
	if delete_ids.len == 0 {
		return
	}
	mut state := w.view_state.data_grid_crud_state.get(grid_id) or { DataGridCrudState{} }
	mut kept := []GridRow{cap: state.working_rows.len}
	for idx, row in state.working_rows {
		row_id := data_grid_row_id(row, idx)
		if delete_ids[row_id] {
			if state.draft_row_ids[row_id] {
				state.draft_row_ids.delete(row_id)
			} else {
				state.deleted_row_ids[row_id] = true
			}
			state.dirty_row_ids.delete(row_id)
			continue
		}
		kept << row
	}
	state.working_rows = kept
	state.save_error = ''
	w.view_state.data_grid_crud_state.set(grid_id, state)
	editing_row := data_grid_editing_row_id(grid_id, w)
	if editing_row.len > 0 && delete_ids[editing_row] {
		data_grid_clear_editing_row(grid_id, mut w)
	}
	if on_selection_change != unsafe { nil } {
		next_selection := data_grid_selection_remove_ids(selection, delete_ids)
		on_selection_change(next_selection, mut e, mut w)
	}
	if focus_id > 0 {
		w.set_id_focus(focus_id)
	}
	e.is_handled = true
}

fn data_grid_selection_remove_ids(selection GridSelection, remove_ids map[string]bool) GridSelection {
	mut selected := map[string]bool{}
	for row_id, value in selection.selected_row_ids {
		if value && !remove_ids[row_id] {
			selected[row_id] = true
		}
	}
	mut active := selection.active_row_id
	mut anchor := selection.anchor_row_id
	if remove_ids[active] {
		active = ''
	}
	if remove_ids[anchor] {
		anchor = ''
	}
	return GridSelection{
		anchor_row_id:    anchor
		active_row_id:    active
		selected_row_ids: selected
	}
}

// Diffs working_rows against committed_rows to produce three
// mutation lists: new draft rows (create), dirty non-draft rows
// with per-cell deltas (update), and deleted row IDs.
// committed_map enables O(1) lookup of previous cell values.
fn data_grid_crud_build_payload(state DataGridCrudState) ([]GridRow, []GridRow, []GridCellEdit, []string) {
	mut create_rows := []GridRow{}
	mut update_rows := []GridRow{}
	mut update_edits := []GridCellEdit{}
	mut delete_ids := []string{}
	mut committed_map := map[string]GridRow{}
	for idx, row in state.committed_rows {
		committed_map[data_grid_row_id(row, idx)] = row
	}
	for idx, row in state.working_rows {
		row_id := data_grid_row_id(row, idx)
		if state.draft_row_ids[row_id] {
			create_rows << row
			continue
		}
		if !state.dirty_row_ids[row_id] {
			continue
		}
		update_rows << row
		before := committed_map[row_id] or {
			GridRow{
				id:    row_id
				cells: {}
			}
		}
		mut keys := row.cells.keys()
		for key in before.cells.keys() {
			if key !in keys {
				keys << key
			}
		}
		keys.sort()
		for key in keys {
			next_value := row.cells[key] or { '' }
			prev_value := before.cells[key] or { '' }
			if next_value == prev_value {
				continue
			}
			update_edits << GridCellEdit{
				row_id: row_id
				col_id: key
				value:  next_value
			}
		}
	}
	mut delete_sorted := state.deleted_row_ids.keys()
	delete_sorted.sort()
	delete_ids = unsafe { delete_sorted }
	return create_rows, update_rows, update_edits, delete_ids
}

fn data_grid_crud_replace_created_rows(mut rows []GridRow, create_rows []GridRow, created []GridRow) map[string]string {
	mut replace := map[string]string{}
	if create_rows.len == 0 || created.len == 0 {
		return replace
	}
	mut draft_pos := 0
	for idx, row in rows {
		if draft_pos >= create_rows.len || draft_pos >= created.len {
			break
		}
		draft_id := create_rows[draft_pos].id
		if row.id != draft_id {
			continue
		}
		next_row := created[draft_pos]
		rows[idx] = next_row
		if draft_id.len > 0 && next_row.id.len > 0 {
			replace[draft_id] = next_row.id
		}
		draft_pos++
	}
	return replace
}

fn data_grid_crud_remap_selection(selection GridSelection, on_selection_change fn (sel GridSelection, mut e Event, mut w Window), replace_ids map[string]string, mut e Event, mut w Window) {
	if on_selection_change == unsafe { nil } || replace_ids.len == 0 {
		return
	}
	mut selected := map[string]bool{}
	for row_id, value in selection.selected_row_ids {
		if !value {
			continue
		}
		next_id := replace_ids[row_id] or { row_id }
		selected[next_id] = true
	}
	active := replace_ids[selection.active_row_id] or { selection.active_row_id }
	anchor := replace_ids[selection.anchor_row_id] or { selection.anchor_row_id }
	on_selection_change(GridSelection{
		anchor_row_id:    anchor
		active_row_id:    active
		selected_row_ids: selected
	}, mut e, mut w)
}

fn data_grid_crud_apply_cell_edit(grid_id string, crud_enabled bool, on_cell_edit fn (edit_ GridCellEdit, mut e Event, mut w Window), edit GridCellEdit, mut e Event, mut w Window) {
	if edit.row_id.len == 0 || edit.col_id.len == 0 {
		return
	}
	if crud_enabled {
		mut state := w.view_state.data_grid_crud_state.get(grid_id) or { DataGridCrudState{} }
		for idx, row in state.working_rows {
			if data_grid_row_id(row, idx) != edit.row_id {
				continue
			}
			mut cells := row.cells.clone()
			cells[edit.col_id] = edit.value
			state.working_rows[idx] = GridRow{
				...row
				cells: cells
			}
			state.dirty_row_ids[edit.row_id] = true
			state.save_error = ''
			break
		}
		w.view_state.data_grid_crud_state.set(grid_id, state)
	}
	if on_cell_edit != unsafe { nil } {
		on_cell_edit(edit, mut e, mut w)
	}
}

fn data_grid_crud_cancel(grid_id string, focus_id u32, mut e Event, mut w Window) {
	mut state := w.view_state.data_grid_crud_state.get(grid_id) or { DataGridCrudState{} }
	state.working_rows = state.committed_rows.clone()
	state.dirty_row_ids = map[string]bool{}
	state.draft_row_ids = map[string]bool{}
	state.deleted_row_ids = map[string]bool{}
	state.save_error = ''
	state.saving = false
	w.view_state.data_grid_crud_state.set(grid_id, state)
	data_grid_clear_editing_row(grid_id, mut w)
	if focus_id > 0 {
		w.set_id_focus(focus_id)
	}
	e.is_handled = true
}

struct DataGridCrudSaveContext {
	grid_id             string
	data_source         ?DataGridDataSource
	query               GridQueryState
	on_crud_error       fn (msg string, mut e Event, mut w Window)      = unsafe { nil }
	on_rows_change      fn (rows_ []GridRow, mut e Event, mut w Window) = unsafe { nil }
	selection           GridSelection
	on_selection_change fn (sel GridSelection, mut e Event, mut w Window) = unsafe { nil }
	has_source          bool
	caps                GridDataCapabilities
	focus_id            u32
}

fn data_grid_crud_save(ctx DataGridCrudSaveContext, mut e Event, mut w Window) {
	grid_id := ctx.grid_id
	mut state := w.view_state.data_grid_crud_state.get(grid_id) or { DataGridCrudState{} }
	if state.saving || !data_grid_crud_has_unsaved(state) {
		return
	}
	create_rows, update_rows, update_edits, delete_ids := data_grid_crud_build_payload(state)
	snapshot_rows := state.committed_rows.clone()
	state.saving = true
	state.save_error = ''
	w.view_state.data_grid_crud_state.set(grid_id, state)
	mut has_row_count := false
	mut row_count_value := 0
	mut replace_ids := map[string]string{}
	if ctx.has_source {
		mut source := ctx.data_source or {
			state.saving = false
			state.save_error = 'grid: data source unavailable'
			w.view_state.data_grid_crud_state.set(grid_id, state)
			return
		}

		if create_rows.len > 0 {
			if !ctx.caps.supports_create {
				data_grid_crud_restore_on_error(grid_id, ctx.on_crud_error, mut e, mut
					w, snapshot_rows, 'grid: create not supported')
				return
			}
			res_create := source.mutate_data(GridMutationRequest{
				grid_id: grid_id
				kind:    .create
				query:   ctx.query
				rows:    create_rows
			}) or {
				data_grid_crud_restore_on_error(grid_id, ctx.on_crud_error, mut e, mut
					w, snapshot_rows, err.msg())
				return
			}
			replace_ids = data_grid_crud_replace_created_rows(mut state.working_rows,
				create_rows, res_create.created)
			if count := res_create.row_count {
				has_row_count = true
				row_count_value = count
			}
		}
		if update_edits.len > 0 {
			if !ctx.caps.supports_update {
				data_grid_crud_restore_on_error(grid_id, ctx.on_crud_error, mut e, mut
					w, snapshot_rows, 'grid: update not supported')
				return
			}
			res_update := source.mutate_data(GridMutationRequest{
				grid_id: grid_id
				kind:    .update
				query:   ctx.query
				rows:    update_rows
				edits:   update_edits
			}) or {
				data_grid_crud_restore_on_error(grid_id, ctx.on_crud_error, mut e, mut
					w, snapshot_rows, err.msg())
				return
			}
			if count := res_update.row_count {
				has_row_count = true
				row_count_value = count
			}
		}
		if delete_ids.len > 0 {
			if !ctx.caps.supports_delete {
				data_grid_crud_restore_on_error(grid_id, ctx.on_crud_error, mut e, mut
					w, snapshot_rows, 'grid: delete not supported')
				return
			}
			res_delete := source.mutate_data(GridMutationRequest{
				grid_id: grid_id
				kind:    .delete
				query:   ctx.query
				row_ids: delete_ids
			}) or {
				data_grid_crud_restore_on_error(grid_id, ctx.on_crud_error, mut e, mut
					w, snapshot_rows, err.msg())
				return
			}
			if count := res_delete.row_count {
				has_row_count = true
				row_count_value = count
			}
		}
		data_grid_crud_remap_selection(ctx.selection, ctx.on_selection_change, replace_ids, mut
			e, mut w)
	}
	state.committed_rows = state.working_rows.clone()
	state.dirty_row_ids = map[string]bool{}
	state.draft_row_ids = map[string]bool{}
	state.deleted_row_ids = map[string]bool{}
	state.saving = false
	state.save_error = ''
	state.source_signature = data_grid_rows_signature(state.committed_rows, []string{})
	w.view_state.data_grid_crud_state.set(grid_id, state)
	data_grid_clear_editing_row(grid_id, mut w)
	rows_copy := state.working_rows.clone()
	if ctx.on_rows_change != unsafe { nil } {
		ctx.on_rows_change(rows_copy, mut e, mut w)
	}
	if ctx.has_source {
		if has_row_count {
			data_grid_source_apply_local_mutation(grid_id, rows_copy, ?int(row_count_value), mut
				w)
		} else {
			data_grid_source_apply_local_mutation(grid_id, rows_copy, none, mut w)
		}
		data_grid_source_force_refetch(grid_id, mut w)
	}
	if ctx.focus_id > 0 {
		w.set_id_focus(ctx.focus_id)
	}
	e.is_handled = true
}

fn data_grid_crud_restore_on_error(grid_id string, on_crud_error fn (msg string, mut e Event, mut w Window), mut e Event, mut w Window, snapshot_rows []GridRow, err_msg string) {
	// Re-fetch authoritative state from view_state to avoid
	// overwriting edits made between snapshot and error.
	mut state := w.view_state.data_grid_crud_state.get(grid_id) or { DataGridCrudState{} }
	// snapshot_rows is already a clone; assign directly for
	// committed, clone once for working to avoid sharing.
	state.committed_rows = snapshot_rows
	state.working_rows = snapshot_rows.clone()
	state.dirty_row_ids = map[string]bool{}
	state.draft_row_ids = map[string]bool{}
	state.deleted_row_ids = map[string]bool{}
	state.saving = false
	state.save_error = err_msg
	state.source_signature = data_grid_rows_signature(state.committed_rows, []string{})
	w.view_state.data_grid_crud_state.set(grid_id, state)
	data_grid_clear_editing_row(grid_id, mut w)
	// Refetch source data to stay in sync after partial
	// mutation failure (create may have succeeded before
	// update/delete failed).
	data_grid_source_force_refetch(grid_id, mut w)
	if on_crud_error != unsafe { nil } {
		on_crud_error(err_msg, mut e, mut w)
	}
}
