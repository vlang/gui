// Data grid: header row, cells, resize/reorder/pin,
// filter row, sort indicators, focus ID management.
module gui

import hash.fnv1a

fn data_grid_header_row(cfg DataGridCfg, columns []GridColumnCfg, column_widths map[string]f32, focus_id u32, hovered_col_id string, resizing_col_id string, focused_col_id string) View {
	mut cells := []View{cap: columns.len}
	for idx, col in columns {
		width := data_grid_column_width_for(col, column_widths)
		show_controls := data_grid_show_header_controls(col.id, hovered_col_id, resizing_col_id,
			focused_col_id)
		cells << data_grid_header_cell(cfg, col, idx, columns.len, width, focus_id, show_controls)
	}
	return row(
		name:         'data_grid header row'
		height:       data_grid_header_height(cfg)
		sizing:       fill_fixed
		color:        color_transparent
		color_border: cfg.color_border
		size_border:  0
		padding:      padding_none
		spacing:      -cfg.size_border
		content:      cells
	)
}

fn data_grid_header_cell(cfg DataGridCfg, col GridColumnCfg, col_idx int, col_count int, width f32, focus_id u32, show_controls bool) View {
	has_reorder := show_controls && cfg.on_column_order_change != unsafe { nil } && col.reorderable
	has_pin := show_controls && cfg.on_column_pin_change != unsafe { nil }
	header_controls := data_grid_header_control_state(width, cfg.padding_header, has_reorder,
		has_pin, show_controls && col.resizable)
	header_focus_id := data_grid_header_focus_id(cfg, col_count, col_idx)
	mut content := []View{cap: 5}
	indicator := data_grid_header_indicator(cfg.query, col.id)
	mut label_content := []View{cap: 2}
	label_content << text(
		text:       col.title
		mode:       .single_line
		text_style: cfg.text_style_header
	)
	if indicator.len > 0 {
		label_content << text(
			text:       indicator
			mode:       .single_line
			text_style: data_grid_indicator_text_style(cfg.text_style_header)
		)
	}
	if header_controls.show_label {
		content << row(
			name:    'data_grid header label'
			sizing:  fill_fill
			clip:    true
			padding: padding_none
			h_align: col.align
			v_align: .middle
			spacing: 6
			content: label_content
		)
	} else {
		content << row(
			name:    'data_grid header spacer'
			sizing:  fill_fill
			padding: padding_none
			content: []
		)
	}
	if header_controls.show_reorder {
		content << data_grid_reorder_controls(cfg, col)
	}
	if header_controls.show_pin {
		content << data_grid_pin_control(cfg, col)
	}
	if header_controls.show_resize {
		content << data_grid_resize_handle(cfg, col, header_focus_id)
	}

	on_query_change := cfg.on_query_change
	query := cfg.query
	multi_sort := cfg.multi_sort
	col_sortable := col.sortable
	col_id := col.id
	color_header_hover := cfg.color_header_hover
	return row(
		name:         'data_grid header cell'
		id:           '${cfg.id}:header:${col.id}'
		width:        width
		sizing:       fixed_fill
		padding:      cfg.padding_header
		clip:         true
		color:        cfg.color_header
		color_border: cfg.color_border
		size_border:  cfg.size_border
		spacing:      0
		on_click:     fn [query, col_id, col_sortable, multi_sort, on_query_change, focus_id, header_focus_id] (_ &Layout, mut e Event, mut w Window) {
			e.is_handled = true
			if col_sortable && on_query_change != unsafe { nil } {
				shift_sort := multi_sort && e.modifiers.has(.shift)
				next := data_grid_toggle_sort(query, col_id, multi_sort, shift_sort)
				on_query_change(next, mut e, mut w)
			}
			if header_focus_id > 0 {
				w.set_id_focus(header_focus_id)
			} else if focus_id > 0 {
				w.set_id_focus(focus_id)
			}
		}
		on_keydown:   make_data_grid_header_on_keydown(cfg, col, col_idx, col_count, focus_id)
		on_hover:     fn [col_sortable, color_header_hover] (mut layout Layout, mut _ Event, mut w Window) {
			if col_sortable {
				w.set_mouse_cursor_pointing_hand()
				layout.shape.color = color_header_hover
			}
		}
		id_focus:     header_focus_id
		content:      content
	)
}

fn data_grid_resize_handle(cfg DataGridCfg, col GridColumnCfg, focus_id u32) View {
	grid_id := cfg.id
	columns := cfg.columns
	rows := cfg.rows
	text_style_header := cfg.text_style_header
	text_style := cfg.text_style
	padding_cell := cfg.padding_cell
	color_resize_handle := cfg.color_resize_handle
	color_resize_active := cfg.color_resize_active
	return row(
		name:     'data_grid resize handle'
		id:       '${grid_id}:resize:${col.id}'
		width:    data_grid_resize_handle_width
		sizing:   fixed_fill
		padding:  padding_none
		color:    color_resize_handle
		on_click: fn [grid_id, columns, rows, text_style_header, text_style, padding_cell, col, focus_id] (layout &Layout, mut e Event, mut w Window) {
			start_x := layout.shape.x + e.mouse_x
			data_grid_start_resize(grid_id, columns, rows, text_style_header, text_style,
				padding_cell, col, focus_id, start_x, mut e, mut w)
		}
		on_hover: fn [color_resize_handle, color_resize_active] (mut layout Layout, mut e Event, mut w Window) {
			w.set_mouse_cursor_ew()
			layout.shape.color = if e.mouse_button == .left {
				color_resize_active
			} else {
				color_resize_handle
			}
		}
		content:  [
			rectangle(
				width:  1
				height: 1
				sizing: fill_fill
				color:  color_transparent
			),
		]
	)
}

fn data_grid_reorder_controls(cfg DataGridCfg, col GridColumnCfg) View {
	on_column_order_change := cfg.on_column_order_change
	base_order := data_grid_normalized_column_order(cfg.columns, cfg.column_order)
	col_id := col.id
	return row(
		name:    'data_grid reorder controls'
		padding: padding_none
		spacing: data_grid_header_reorder_spacing
		width:   data_grid_header_controls_width(true, false, false)
		sizing:  fixed_fill
		content: [
			data_grid_order_button('◀', cfg.text_style_header, cfg.color_header_hover,
				fn [on_column_order_change, base_order, col_id] (mut e Event, mut w Window) {
				if on_column_order_change == unsafe { nil } {
					e.is_handled = true
					return
				}
				next_order := data_grid_column_order_move(base_order, col_id, -1)
				if next_order == base_order {
					e.is_handled = true
					return
				}
				on_column_order_change(next_order, mut e, mut w)
				e.is_handled = true
			}),
			data_grid_order_button('▶', cfg.text_style_header, cfg.color_header_hover,
				fn [on_column_order_change, base_order, col_id] (mut e Event, mut w Window) {
				if on_column_order_change == unsafe { nil } {
					e.is_handled = true
					return
				}
				next_order := data_grid_column_order_move(base_order, col_id, 1)
				if next_order == base_order {
					e.is_handled = true
					return
				}
				on_column_order_change(next_order, mut e, mut w)
				e.is_handled = true
			}),
		]
	)
}

fn data_grid_order_button(label string, base_style TextStyle, hover_color Color, cb fn (mut Event, mut Window)) View {
	return button(
		width:        data_grid_header_control_width
		sizing:       fixed_fill
		padding:      padding_none
		size_border:  0
		radius:       0
		color:        color_transparent
		color_hover:  hover_color
		color_focus:  color_transparent
		color_click:  hover_color
		color_border: color_transparent
		on_click:     fn [cb] (_ &Layout, mut e Event, mut w Window) {
			cb(mut e, mut w)
		}
		content:      [
			text(
				text:       label
				mode:       .single_line
				text_style: data_grid_indicator_text_style(base_style)
			),
		]
	)
}

fn data_grid_pin_control(cfg DataGridCfg, col GridColumnCfg) View {
	label := match col.pin {
		.none { '•' }
		.left { '↤' }
		.right { '↦' }
	}
	on_column_pin_change := cfg.on_column_pin_change
	col_id := col.id
	col_pin := col.pin
	return button(
		width:        data_grid_header_control_width
		padding:      padding_none
		sizing:       fixed_fill
		size_border:  0
		radius:       0
		color:        color_transparent
		color_hover:  cfg.color_header_hover
		color_focus:  color_transparent
		color_click:  cfg.color_header_hover
		color_border: color_transparent
		on_click:     fn [on_column_pin_change, col_id, col_pin] (_ &Layout, mut e Event, mut w Window) {
			if on_column_pin_change == unsafe { nil } {
				return
			}
			next_pin := data_grid_column_next_pin(col_pin)
			on_column_pin_change(col_id, next_pin, mut e, mut w)
			e.is_handled = true
		}
		content:      [
			text(
				text:       label
				mode:       .single_line
				text_style: data_grid_indicator_text_style(cfg.text_style_header)
			),
		]
	)
}

fn data_grid_filter_row(cfg DataGridCfg, columns []GridColumnCfg, column_widths map[string]f32) View {
	mut cells := []View{cap: columns.len}
	for col in columns {
		cells << data_grid_filter_cell(cfg, col, data_grid_column_width_for(col, column_widths))
	}
	return row(
		name:         'data_grid filter row'
		height:       data_grid_filter_height(cfg)
		sizing:       fill_fixed
		color:        cfg.color_filter
		color_border: cfg.color_border
		size_border:  0
		padding:      cfg.padding_filter
		spacing:      -cfg.size_border
		content:      cells
	)
}

fn data_grid_filter_cell(cfg DataGridCfg, col GridColumnCfg, width f32) View {
	query := cfg.query
	value := data_grid_query_filter_value(query, col.id)
	input_id := '${cfg.id}:filter:${col.id}'
	on_query_change := cfg.on_query_change
	col_id := col.id
	return row(
		name:         'data_grid filter cell'
		id:           '${cfg.id}:filter_cell:${col.id}'
		width:        width
		sizing:       fixed_fill
		padding:      cfg.padding_filter
		color:        color_transparent
		color_border: cfg.color_border
		size_border:  cfg.size_border
		spacing:      0
		content:      [
			input(
				id:              input_id
				id_focus:        fnv1a.sum32_string(input_id)
				text:            value
				placeholder:     if col.filterable { 'Filter' } else { '' }
				disabled:        !col.filterable || on_query_change == unsafe { nil }
				sizing:          fill_fill
				padding:         padding_none
				size_border:     0
				radius:          0
				color:           cfg.color_filter
				color_hover:     cfg.color_filter
				color_border:    cfg.color_border
				text_style:      cfg.text_style_filter
				on_text_changed: fn [on_query_change, query, col_id] (_ &Layout, text string, mut w Window) {
					if on_query_change == unsafe { nil } {
						return
					}
					next := data_grid_query_set_filter(query, col_id, text)
					mut e := Event{}
					on_query_change(next, mut e, mut w)
				}
			),
		]
	)
}

fn data_grid_start_resize(grid_id string, columns []GridColumnCfg, rows []GridRow, text_style_header TextStyle, text_style TextStyle, padding_cell Padding, col GridColumnCfg, focus_id u32, start_mouse_x f32, mut e Event, mut w Window) {
	if focus_id > 0 {
		w.set_id_focus(focus_id)
	}
	mut runtime := w.view_state.data_grid_resize_state.get(grid_id) or { DataGridResizeState{} }
	if runtime.last_click_col_id == col.id && runtime.last_click_frame > 0
		&& e.frame_count - runtime.last_click_frame <= data_grid_resize_double_click_frames {
		fit_width := data_grid_auto_fit_width(rows, text_style_header, text_style, padding_cell,
			col, mut w)
		data_grid_set_column_width(grid_id, col, fit_width, mut w)
		runtime.active = false
		runtime.last_click_frame = 0
		runtime.last_click_col_id = ''
		w.view_state.data_grid_resize_state.set(grid_id, runtime)
		e.is_handled = true
		return
	}

	runtime.active = true
	runtime.col_id = col.id
	runtime.start_mouse_x = start_mouse_x
	runtime.start_width = data_grid_column_width(grid_id, columns, col, mut w)
	runtime.last_click_frame = e.frame_count
	runtime.last_click_col_id = col.id
	w.view_state.data_grid_resize_state.set(grid_id, runtime)

	w.mouse_lock(MouseLockCfg{
		mouse_move: fn [grid_id, col] (_ &Layout, mut e Event, mut w Window) {
			data_grid_resize_drag(grid_id, col, mut e, mut w)
		}
		mouse_up:   fn [grid_id, focus_id] (_ &Layout, mut _ Event, mut w Window) {
			data_grid_end_resize(grid_id, mut w)
			w.mouse_unlock()
			if focus_id > 0 {
				w.set_id_focus(focus_id)
			}
		}
	})
	e.is_handled = true
}

fn data_grid_resize_drag(grid_id string, col GridColumnCfg, mut e Event, mut w Window) {
	mut runtime := w.view_state.data_grid_resize_state.get(grid_id) or { return }
	if !runtime.active || runtime.col_id != col.id {
		return
	}
	delta := e.mouse_x - runtime.start_mouse_x
	next_width := runtime.start_width + delta
	data_grid_set_column_width(grid_id, col, next_width, mut w)
	w.set_mouse_cursor_ew()
	e.is_handled = true
}

fn data_grid_end_resize(grid_id string, mut w Window) {
	mut runtime := w.view_state.data_grid_resize_state.get(grid_id) or { return }
	runtime.active = false
	w.view_state.data_grid_resize_state.set(grid_id, runtime)
}

fn data_grid_auto_fit_width(rows []GridRow, text_style_header TextStyle, text_style TextStyle, padding_cell Padding, col GridColumnCfg, mut w Window) f32 {
	mut longest := text_width(col.title, text_style_header, mut w)
	style := col.text_style or { text_style }
	sample := if rows.len > data_grid_autofit_max_rows {
		rows[..data_grid_autofit_max_rows]
	} else {
		rows
	}
	for row in sample {
		value := row.cells[col.id] or { '' }
		width := text_width(value, style, mut w)
		if width > longest {
			longest = width
		}
	}
	return data_grid_clamp_width(col, longest + padding_cell.width() + data_grid_autofit_padding)
}

fn data_grid_header_indicator(query GridQueryState, col_id string) string {
	idx := data_grid_sort_index(query.sorts, col_id)
	if idx < 0 {
		return ''
	}
	sort := query.sorts[idx]
	dir := if sort.dir == .asc { '▲' } else { '▼' }
	if query.sorts.len > 1 {
		return '${idx + 1}${dir}'
	}
	return dir
}

fn data_grid_active_resize_col_id(grid_id string, window &Window) string {
	if runtime := window.view_state.data_grid_resize_state.get(grid_id) {
		if runtime.active {
			return runtime.col_id
		}
	}
	return ''
}

fn data_grid_header_focus_base_id(cfg DataGridCfg, col_count int) u32 {
	if col_count <= 0 {
		return 0
	}
	span := u32(col_count)
	body := data_grid_focus_id(cfg)
	if body <= max_u32 - span {
		return body + 1
	}
	if body > span {
		return body - span
	}
	return 1
}

fn data_grid_header_focus_id(cfg DataGridCfg, col_count int, col_idx int) u32 {
	if col_count <= 0 || col_idx < 0 || col_idx >= col_count {
		return 0
	}
	base := data_grid_header_focus_base_id(cfg, col_count)
	return base + u32(col_idx)
}

fn data_grid_header_focus_id_from_base(base u32, col_count int, col_idx int) u32 {
	if base == 0 || col_count <= 0 || col_idx < 0 || col_idx >= col_count {
		return 0
	}
	return base + u32(col_idx)
}

fn data_grid_header_focus_index(cfg DataGridCfg, col_count int, focus_id u32) int {
	if col_count <= 0 || focus_id == 0 {
		return -1
	}
	base := data_grid_header_focus_base_id(cfg, col_count)
	if focus_id < base {
		return -1
	}
	idx := int(focus_id - base)
	if idx < 0 || idx >= col_count {
		return -1
	}
	return idx
}

fn data_grid_header_focused_col_id(cfg DataGridCfg, columns []GridColumnCfg, focus_id u32) string {
	idx := data_grid_header_focus_index(cfg, columns.len, focus_id)
	if idx < 0 || idx >= columns.len {
		return ''
	}
	return columns[idx].id
}

fn data_grid_show_header_controls(col_id string, hovered_col_id string, resizing_col_id string, focused_col_id string) bool {
	return col_id.len > 0
		&& (col_id == hovered_col_id || col_id == resizing_col_id || col_id == focused_col_id)
}

fn data_grid_header_col_under_cursor(layout &Layout, grid_id string, mouse_x f32, mouse_y f32) string {
	prefix := '${grid_id}:header:'
	if cell := layout.find_layout(fn [prefix, mouse_x, mouse_y] (n Layout) bool {
		return n.shape.id.starts_with(prefix) && n.shape.point_in_shape(mouse_x, mouse_y)
	})
	{
		return data_grid_header_col_id_from_layout_id(grid_id, cell.shape.id)
	}
	return ''
}

fn data_grid_header_col_id_from_layout_id(grid_id string, layout_id string) string {
	prefix := '${grid_id}:header:'
	if !layout_id.starts_with(prefix) {
		return ''
	}
	return layout_id[prefix.len..]
}

struct DataGridHeaderControlState {
mut:
	show_label   bool
	show_reorder bool
	show_pin     bool
	show_resize  bool
}

// Progressive disclosure: header controls (reorder, pin,
// resize) shown only if they fit. Controls are dropped in
// priority order (pin, reorder, resize). Label is hidden
// if controls alone exceed width, then restored if dropping
// controls freed enough space.
fn data_grid_header_control_state(width f32, padding Padding, has_reorder bool, has_pin bool, has_resize bool) DataGridHeaderControlState {
	available := f32_max(0, width - padding.width())
	mut state := DataGridHeaderControlState{
		show_label:   true
		show_reorder: has_reorder
		show_pin:     has_pin
		show_resize:  has_resize
	}
	mut controls_width := data_grid_header_controls_width(state.show_reorder, state.show_pin,
		state.show_resize)
	if available < controls_width + data_grid_header_label_min_width {
		state.show_label = false
	}
	if state.show_pin && available < controls_width {
		state.show_pin = false
		controls_width = data_grid_header_controls_width(state.show_reorder, state.show_pin,
			state.show_resize)
	}
	if state.show_reorder && available < controls_width {
		state.show_reorder = false
		controls_width = data_grid_header_controls_width(state.show_reorder, state.show_pin,
			state.show_resize)
	}
	if state.show_resize && available < controls_width {
		state.show_resize = false
		controls_width = data_grid_header_controls_width(state.show_reorder, state.show_pin,
			state.show_resize)
	}
	if available >= controls_width + data_grid_header_label_min_width {
		state.show_label = true
	}
	return state
}

fn data_grid_header_controls_width(show_reorder bool, show_pin bool, show_resize bool) f32 {
	mut width := f32(0)
	if show_reorder {
		width += data_grid_header_control_width * 2 + data_grid_header_reorder_spacing
	}
	if show_pin {
		width += data_grid_header_control_width
	}
	if show_resize {
		width += data_grid_resize_handle_width
	}
	return width
}
