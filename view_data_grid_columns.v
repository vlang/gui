// Data grid: column order, visibility, pinning, width,
// sort/filter query.
module gui

fn data_grid_effective_index_for_column_with_order(columns []GridColumnCfg, hidden_column_ids map[string]bool, next_order []string, col_id string) int {
	cols := data_grid_effective_columns(columns, next_order, hidden_column_ids)
	for idx, col in cols {
		if col.id == col_id {
			return idx
		}
	}
	return -1
}

fn data_grid_effective_index_for_column_with_pin(columns []GridColumnCfg, column_order []string, hidden_column_ids map[string]bool, col_id string, pin GridColumnPin) int {
	mut next_columns := columns.clone()
	for idx, col in next_columns {
		if col.id != col_id {
			continue
		}
		next_columns[idx] = GridColumnCfg{
			...col
			pin: pin
		}
		break
	}
	cols := data_grid_effective_columns(next_columns, column_order, hidden_column_ids)
	for idx, col in cols {
		if col.id == col_id {
			return idx
		}
	}
	return -1
}

fn data_grid_visible_column_count(columns []GridColumnCfg, hidden map[string]bool) int {
	mut count := 0
	for col in columns {
		if col.id.len == 0 || hidden[col.id] {
			continue
		}
		count++
	}
	return count
}

fn data_grid_next_hidden_columns(hidden map[string]bool, col_id string, columns []GridColumnCfg) map[string]bool {
	mut next := hidden.clone()
	if col_id.len == 0 {
		return next
	}
	if next[col_id] {
		next.delete(col_id)
		return next
	}
	visible_count := data_grid_visible_column_count(columns, next)
	if visible_count <= 1 {
		return next
	}
	next[col_id] = true
	return next
}

// Resolves final visible column list: apply column_order
// (fallback to declaration order), filter hidden columns,
// ensure at least one column remains, then partition into
// [left-pinned, unpinned, right-pinned].
fn data_grid_effective_columns(columns []GridColumnCfg, column_order []string, hidden_column_ids map[string]bool) []GridColumnCfg {
	if columns.len == 0 {
		return []
	}
	order, cols_by_id := data_grid_column_order_and_map(columns, column_order)
	mut ordered := []GridColumnCfg{cap: columns.len}
	for id in order {
		if hidden_column_ids[id] {
			continue
		}
		col := cols_by_id[id] or { continue }
		ordered << col
	}
	if ordered.len == 0 {
		for id in order {
			col := cols_by_id[id] or { continue }
			ordered << col
			break
		}
	}
	return data_grid_partition_pins(ordered)
}

fn data_grid_normalized_column_order(columns []GridColumnCfg, column_order []string) []string {
	if columns.len == 0 {
		return []
	}
	mut col_ids := map[string]bool{}
	for col in columns {
		if col.id.len > 0 {
			col_ids[col.id] = true
		}
	}
	mut seen := map[string]bool{}
	mut order := []string{cap: columns.len}
	for id in column_order {
		if id.len == 0 || seen[id] {
			continue
		}
		if col_ids[id] {
			seen[id] = true
			order << id
		}
	}
	for col in columns {
		if col.id.len == 0 || seen[col.id] {
			continue
		}
		seen[col.id] = true
		order << col.id
	}
	return order
}

// Single-pass construction of both the normalized column
// order list and the id→column map. Avoids iterating
// columns twice (once for order, once for map).
fn data_grid_column_order_and_map(columns []GridColumnCfg, column_order []string) ([]string, map[string]GridColumnCfg) {
	mut by_id := map[string]GridColumnCfg{}
	mut col_ids := map[string]bool{}
	for col in columns {
		if col.id.len > 0 {
			col_ids[col.id] = true
			by_id[col.id] = col
		}
	}
	mut seen := map[string]bool{}
	mut order := []string{cap: columns.len}
	for id in column_order {
		if id.len == 0 || seen[id] {
			continue
		}
		if col_ids[id] {
			seen[id] = true
			order << id
		}
	}
	for col in columns {
		if col.id.len == 0 || seen[col.id] {
			continue
		}
		seen[col.id] = true
		order << col.id
	}
	return order, by_id
}

fn data_grid_partition_pins(columns []GridColumnCfg) []GridColumnCfg {
	mut left := []GridColumnCfg{}
	mut center := []GridColumnCfg{}
	mut right := []GridColumnCfg{}
	for col in columns {
		match col.pin {
			.left { left << col }
			.right { right << col }
			.none { center << col }
		}
	}
	mut merged := []GridColumnCfg{cap: columns.len}
	merged << left
	merged << center
	merged << right
	return merged
}

fn data_grid_column_next_pin(pin GridColumnPin) GridColumnPin {
	return match pin {
		.none { .left }
		.left { .right }
		.right { .none }
	}
}

// data_grid_column_order_move moves `col_id` in `order` by delta (-1 left, +1 right).
pub fn data_grid_column_order_move(order []string, col_id string, delta int) []string {
	if order.len == 0 || delta == 0 {
		return order
	}
	mut idx := -1
	for i, id in order {
		if id == col_id {
			idx = i
			break
		}
	}
	if idx < 0 {
		return order
	}
	target := int_clamp(idx + delta, 0, order.len - 1)
	if target == idx {
		return order
	}
	mut next := order.clone()
	value := next[idx]
	next.delete(idx)
	next.insert(target, value)
	return next
}

fn data_grid_toggle_sort(query GridQueryState, col_id string, multi_sort bool, append bool) GridQueryState {
	mut next := GridQueryState{
		sorts:        query.sorts.clone()
		filters:      query.filters.clone()
		quick_filter: query.quick_filter
	}
	idx := data_grid_sort_index(next.sorts, col_id)
	mut new_dir := GridSortDir.asc
	mut remove := false
	if idx >= 0 {
		if next.sorts[idx].dir == .asc {
			new_dir = .desc
		} else {
			remove = true
		}
	}
	if append && multi_sort {
		if idx >= 0 {
			if remove {
				next.sorts.delete(idx)
			} else {
				next.sorts[idx] = GridSort{
					col_id: col_id
					dir:    new_dir
				}
			}
		} else {
			next.sorts << GridSort{
				col_id: col_id
				dir:    .asc
			}
		}
		return next
	}
	if idx >= 0 {
		if remove {
			next.sorts = []
		} else {
			next.sorts = [GridSort{
				col_id: col_id
				dir:    new_dir
			}]
		}
	} else {
		next.sorts = [GridSort{
			col_id: col_id
			dir:    .asc
		}]
	}
	return next
}

fn data_grid_sort_index(sorts []GridSort, col_id string) int {
	for idx, sort in sorts {
		if sort.col_id == col_id {
			return idx
		}
	}
	return -1
}

fn data_grid_query_set_filter(query GridQueryState, col_id string, value string) GridQueryState {
	mut next := GridQueryState{
		sorts:        query.sorts.clone()
		filters:      query.filters.clone()
		quick_filter: query.quick_filter
	}
	idx := data_grid_query_filter_index(next.filters, col_id)
	trimmed := value.trim_space()
	if trimmed.len == 0 {
		if idx >= 0 {
			next.filters.delete(idx)
		}
		return next
	}
	if idx >= 0 {
		next.filters[idx] = GridFilter{
			col_id: col_id
			op:     next.filters[idx].op
			value:  value
		}
	} else {
		next.filters << GridFilter{
			col_id: col_id
			op:     'contains'
			value:  value
		}
	}
	return next
}

fn data_grid_query_filter_index(filters []GridFilter, col_id string) int {
	for idx, filter in filters {
		if filter.col_id == col_id {
			return idx
		}
	}
	return -1
}

fn data_grid_query_filter_value(query GridQueryState, col_id string) string {
	idx := data_grid_query_filter_index(query.filters, col_id)
	if idx < 0 {
		return ''
	}
	return query.filters[idx].value
}

// Resolves column widths from cached view_state, falling
// back to column config defaults. Clamps each width to
// [min_width, max_width]. Prunes stale entries for removed
// columns. Writes back to cache only if changed.
fn data_grid_column_widths(grid_id string, columns []GridColumnCfg, mut w Window) map[string]f32 {
	mut dg_cw := state_map[string, &DataGridColWidths](mut w, ns_dg_col_widths, cap_moderate)
	cached_ptr := dg_cw.get(grid_id) or { &DataGridColWidths{} }

	// Detect if any column needs a width refresh
	mut changed := !dg_cw.contains(grid_id)
	mut active_ids := map[string]bool{}
	if !changed {
		for col in columns {
			if col.id.len == 0 {
				continue
			}
			active_ids[col.id] = true
			cached := cached_ptr.widths[col.id] or { f32(-1) }
			if cached == f32(-1) {
				changed = true
				break
			}
			clamped := data_grid_clamp_width(col, cached)
			if cached != clamped {
				changed = true
				break
			}
		}
		if !changed {
			for key in cached_ptr.widths.keys() {
				if !active_ids[key] {
					changed = true
					break
				}
			}
		}
	}

	if !changed {
		return cached_ptr.widths
	}

	// Rebuild the map only when changes are detected
	mut widths := map[string]f32{}
	for col in columns {
		if col.id.len == 0 {
			continue
		}
		base := cached_ptr.widths[col.id] or { data_grid_initial_width(col) }
		widths[col.id] = data_grid_clamp_width(col, base)
	}

	dg_cw.set(grid_id, &DataGridColWidths{
		widths: widths
	})
	return widths
}

fn data_grid_column_width(grid_id string, columns []GridColumnCfg, col GridColumnCfg, mut w Window) f32 {
	widths := data_grid_column_widths(grid_id, columns, mut w)
	return data_grid_column_width_for(col, widths)
}

fn data_grid_column_width_for(col GridColumnCfg, widths map[string]f32) f32 {
	return widths[col.id] or { data_grid_initial_width(col) }
}

fn data_grid_set_column_width(grid_id string, col GridColumnCfg, width f32, mut w Window) {
	mut dg_cw := state_map[string, &DataGridColWidths](mut w, ns_dg_col_widths, cap_moderate)
	mut widths := if cached := dg_cw.get(grid_id) {
		cached.widths.clone()
	} else {
		map[string]f32{}
	}
	widths[col.id] = data_grid_clamp_width(col, width)
	dg_cw.set(grid_id, &DataGridColWidths{
		widths: widths
	})
}

fn data_grid_initial_width(col GridColumnCfg) f32 {
	base := if col.width > 0 { col.width } else { f32(120) }
	return data_grid_clamp_width(col, base)
}

fn data_grid_clamp_width(col GridColumnCfg, width f32) f32 {
	mut min_width := if col.min_width > 0 { col.min_width } else { f32(60) }
	mut max_width := if col.max_width > 0 { col.max_width } else { f32(600) }
	if max_width < min_width {
		max_width = min_width
	}
	if min_width < 1 {
		min_width = 1
	}
	return f32_clamp(width, min_width, max_width)
}

fn data_grid_columns_total_width(columns []GridColumnCfg, column_widths map[string]f32) f32 {
	mut total := f32(0)
	for col in columns {
		total += data_grid_column_width_for(col, column_widths)
	}
	return total
}
