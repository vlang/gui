module gui

import hash.fnv1a

const data_grid_virtual_buffer_rows = 2
const data_grid_resize_double_click_frames = u64(24)
const data_grid_resize_handle_width = f32(6)
const data_grid_autofit_padding = f32(18)
const data_grid_indicator_alpha = u8(140)
const data_grid_resize_key_step = f32(8)
const data_grid_resize_key_step_large = f32(24)
const data_grid_header_control_width = f32(12)
const data_grid_header_reorder_spacing = f32(1)
const data_grid_header_label_min_width = f32(24)

pub enum GridSortDir as u8 {
	asc
	desc
}

pub enum GridColumnPin as u8 {
	none
	left
	right
}

@[minify]
pub struct GridSort {
pub:
	col_id string
	dir    GridSortDir = .asc
}

@[minify]
pub struct GridFilter {
pub:
	col_id string
	op     string = 'contains'
	value  string
}

@[minify]
pub struct GridQueryState {
pub mut:
	sorts        []GridSort
	filters      []GridFilter
	quick_filter string
}

@[minify]
pub struct GridSelection {
pub:
	anchor_row_id    string
	active_row_id    string
	selected_row_ids map[string]bool
}

@[minify]
pub struct GridColumnCfg {
pub:
	id          string @[required]
	title       string @[required]
	width       f32             = 120
	min_width   f32             = 60
	max_width   f32             = 600
	resizable   bool            = true
	reorderable bool            = true
	sortable    bool            = true
	filterable  bool            = true
	pin         GridColumnPin   = .none
	align       HorizontalAlign = .start
	text_style  ?TextStyle
}

@[minify]
pub struct GridRow {
pub:
	id    string @[required]
	cells map[string]string
}

@[heap; minify]
pub struct DataGridCfg {
pub:
	id                       string @[required]
	id_focus                 u32
	id_scroll                u32
	columns                  []GridColumnCfg @[required]
	column_order             []string
	rows                     []GridRow @[required]
	query                    GridQueryState
	selection                GridSelection
	multi_sort               bool = true
	multi_select             bool = true
	range_select             bool = true
	show_header              bool = true
	show_filter_row          bool
	show_quick_filter        bool
	quick_filter_placeholder string            = 'Search'
	row_height               f32               = 30
	header_height            f32               = 34
	color_background         Color             = gui_theme.data_grid_style.color_background
	color_header             Color             = gui_theme.data_grid_style.color_header
	color_header_hover       Color             = gui_theme.data_grid_style.color_header_hover
	color_filter             Color             = gui_theme.data_grid_style.color_filter
	color_quick_filter       Color             = gui_theme.data_grid_style.color_quick_filter
	color_row_hover          Color             = gui_theme.data_grid_style.color_row_hover
	color_row_alt            Color             = gui_theme.data_grid_style.color_row_alt
	color_row_selected       Color             = gui_theme.data_grid_style.color_row_selected
	color_border             Color             = gui_theme.data_grid_style.color_border
	color_resize_handle      Color             = gui_theme.data_grid_style.color_resize_handle
	color_resize_active      Color             = gui_theme.data_grid_style.color_resize_active
	padding_cell             Padding           = gui_theme.data_grid_style.padding_cell
	padding_header           Padding           = gui_theme.data_grid_style.padding_header
	padding_filter           Padding           = gui_theme.data_grid_style.padding_filter
	text_style               TextStyle         = gui_theme.data_grid_style.text_style
	text_style_header        TextStyle         = gui_theme.data_grid_style.text_style_header
	text_style_filter        TextStyle         = gui_theme.data_grid_style.text_style_filter
	radius                   f32               = gui_theme.data_grid_style.radius
	size_border              f32               = gui_theme.data_grid_style.size_border
	scrollbar                ScrollbarOverflow = .auto
	sizing                   Sizing            = fill_fill
	width                    f32
	height                   f32
	min_width                f32
	max_width                f32
	min_height               f32
	max_height               f32
	on_query_change          fn (GridQueryState, mut Event, mut Window)        = unsafe { nil }
	on_selection_change      fn (GridSelection, mut Event, mut Window)         = unsafe { nil }
	on_column_order_change   fn ([]string, mut Event, mut Window)              = unsafe { nil }
	on_column_pin_change     fn (string, GridColumnPin, mut Event, mut Window) = unsafe { nil }
	on_copy_rows             fn ([]GridRow, mut Event, mut Window) ?string     = unsafe { nil }
	on_row_activate          fn (GridRow, mut Event, mut Window)               = unsafe { nil }
}

// data_grid renders a controlled, virtualized data grid view.
pub fn (mut window Window) data_grid(cfg DataGridCfg) View {
	focus_id := data_grid_focus_id(cfg)
	scroll_id := data_grid_scroll_id(cfg)
	hovered_col_id := window.view_state.data_grid_header_hover_col.get(cfg.id) or { '' }
	resizing_col_id := data_grid_active_resize_col_id(cfg.id, window)
	row_height := data_grid_row_height(cfg, mut window)
	static_top := data_grid_static_top_height(cfg, row_height)
	grid_height := data_grid_height(cfg)
	virtualize := grid_height > 0 && cfg.rows.len > 0
	scroll_y := if virtualize {
		-(window.view_state.scroll_y.get(scroll_id) or { f32(0) })
	} else {
		f32(0)
	}
	columns := data_grid_effective_columns(cfg)
	focused_col_id := data_grid_header_focused_col_id(cfg, columns, window.id_focus())

	mut column_widths := data_grid_column_widths(cfg, mut window)
	last_row_idx := cfg.rows.len - 1
	first_visible, last_visible := if virtualize {
		data_grid_visible_range_for_scroll(scroll_y, grid_height, row_height, cfg.rows.len,
			static_top, data_grid_virtual_buffer_rows)
	} else {
		0, last_row_idx
	}

	mut rows := []View{cap: cfg.rows.len + 8}
	if cfg.show_quick_filter {
		rows << data_grid_quick_filter_row(cfg)
	}
	if cfg.show_header {
		rows << data_grid_header_row(cfg, columns, column_widths, focus_id, hovered_col_id,
			resizing_col_id, focused_col_id)
	}
	if cfg.show_filter_row {
		rows << data_grid_filter_row(cfg, columns, column_widths)
	}

	if virtualize && first_visible > 0 {
		rows << rectangle(
			name:   'data_grid spacer top'
			color:  color_transparent
			height: f32(first_visible) * row_height
			sizing: fill_fixed
		)
	}

	for row_idx in first_visible .. last_visible + 1 {
		if row_idx < 0 || row_idx >= cfg.rows.len {
			continue
		}
		rows << data_grid_row_view(cfg, cfg.rows[row_idx], row_idx, columns, column_widths,
			row_height, focus_id)
	}

	if virtualize && last_visible < last_row_idx {
		remaining := last_row_idx - last_visible
		rows << rectangle(
			name:   'data_grid spacer bottom'
			color:  color_transparent
			height: f32(remaining) * row_height
			sizing: fill_fixed
		)
	}

	scrollbar_cfg := ScrollbarCfg{
		overflow: cfg.scrollbar
	}
	scroll_body := column(
		name:            'data_grid scroll body'
		id:              '${cfg.id}:scroll'
		id_scroll:       scroll_id
		scrollbar_cfg_x: &scrollbar_cfg
		scrollbar_cfg_y: &scrollbar_cfg
		color:           cfg.color_background
		padding:         data_grid_scroll_padding(cfg)
		spacing:         -cfg.size_border
		sizing:          fill_fill
		content:         rows
	)
	return column(
		name:          'data_grid'
		id:            cfg.id
		id_focus:      focus_id
		on_keydown:    make_data_grid_on_keydown(cfg, row_height, static_top, scroll_id)
		on_char:       make_data_grid_on_char(cfg)
		on_mouse_move: make_data_grid_on_mouse_move(cfg)
		color:         cfg.color_background
		color_border:  cfg.color_border
		size_border:   cfg.size_border
		radius:        cfg.radius
		padding:       padding_none
		spacing:       0
		sizing:        cfg.sizing
		width:         cfg.width
		height:        cfg.height
		min_width:     cfg.min_width
		max_width:     cfg.max_width
		min_height:    cfg.min_height
		max_height:    cfg.max_height
		content:       [scroll_body]
	)
}

fn data_grid_quick_filter_row(cfg DataGridCfg) View {
	h := data_grid_quick_filter_height(cfg)
	query_callback := cfg.on_query_change
	value := cfg.query.quick_filter
	input_id := '${cfg.id}:quick_filter'
	return row(
		name:         'data_grid quick filter row'
		height:       h
		sizing:       fill_fixed
		color:        cfg.color_quick_filter
		color_border: cfg.color_border
		size_border:  0
		padding:      cfg.padding_filter
		spacing:      0
		content:      [
			input(
				id:                input_id
				id_focus:          fnv1a.sum32_string(input_id)
				text:              value
				placeholder:       cfg.quick_filter_placeholder
				sizing:            fill_fill
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
				on_text_changed:   fn [cfg, query_callback] (_ &Layout, text string, mut w Window) {
					if query_callback == unsafe { nil } {
						return
					}
					next := GridQueryState{
						sorts:        cfg.query.sorts.clone()
						filters:      cfg.query.filters.clone()
						quick_filter: text
					}
					mut e := Event{}
					query_callback(next, mut e, mut w)
				}
			),
		]
	)
}

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
		color:        cfg.color_header
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
	return row(
		name:         'data_grid header cell'
		id:           '${cfg.id}:header:${col.id}'
		width:        width
		sizing:       fixed_fill
		padding:      cfg.padding_header
		clip:         true
		color:        color_transparent
		color_border: cfg.color_border
		size_border:  cfg.size_border
		spacing:      0
		on_click:     fn [cfg, col, on_query_change, focus_id, header_focus_id] (_ &Layout, mut e Event, mut w Window) {
			if col.sortable && on_query_change != unsafe { nil } {
				shift_sort := cfg.multi_sort && e.modifiers.has(.shift)
				next := data_grid_toggle_sort(cfg.query, col.id, cfg.multi_sort, shift_sort)
				on_query_change(next, mut e, mut w)
				e.is_handled = true
			}
			if header_focus_id > 0 {
				w.set_id_focus(header_focus_id)
			} else if focus_id > 0 {
				w.set_id_focus(focus_id)
			}
		}
		on_keydown:   make_data_grid_header_on_keydown(cfg, col, col_idx, col_count, focus_id)
		on_hover:     fn [cfg, col] (mut layout Layout, mut _ Event, mut w Window) {
			if col.sortable {
				w.set_mouse_cursor_pointing_hand()
				layout.shape.color = cfg.color_header_hover
			}
		}
		id_focus:     header_focus_id
		content:      content
	)
}

fn data_grid_resize_handle(cfg DataGridCfg, col GridColumnCfg, focus_id u32) View {
	return row(
		name:     'data_grid resize handle'
		id:       '${cfg.id}:resize:${col.id}'
		width:    data_grid_resize_handle_width
		sizing:   fixed_fill
		padding:  padding_none
		color:    cfg.color_resize_handle
		on_click: fn [cfg, col, focus_id] (layout &Layout, mut e Event, mut w Window) {
			start_x := layout.shape.x + e.mouse_x
			data_grid_start_resize(cfg, col, focus_id, start_x, mut e, mut w)
		}
		on_hover: fn [cfg] (mut layout Layout, mut e Event, mut w Window) {
			w.set_mouse_cursor_ew()
			layout.shape.color = if e.mouse_button == .left {
				cfg.color_resize_active
			} else {
				cfg.color_resize_handle
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
	return row(
		name:    'data_grid reorder controls'
		padding: padding_none
		spacing: data_grid_header_reorder_spacing
		width:   data_grid_header_controls_width(true, false, false)
		sizing:  fixed_fill
		content: [
			data_grid_order_button('◀', cfg.text_style_header, cfg.color_header_hover,
				fn [cfg, col] (mut e Event, mut w Window) {
				if cfg.on_column_order_change == unsafe { nil } {
					e.is_handled = true
					return
				}
				base_order := data_grid_normalized_column_order(cfg)
				next_order := grid_column_order_move(base_order, col.id, -1)
				if next_order == base_order {
					e.is_handled = true
					return
				}
				cfg.on_column_order_change(next_order, mut e, mut w)
				e.is_handled = true
			}),
			data_grid_order_button('▶', cfg.text_style_header, cfg.color_header_hover,
				fn [cfg, col] (mut e Event, mut w Window) {
				if cfg.on_column_order_change == unsafe { nil } {
					e.is_handled = true
					return
				}
				base_order := data_grid_normalized_column_order(cfg)
				next_order := grid_column_order_move(base_order, col.id, 1)
				if next_order == base_order {
					e.is_handled = true
					return
				}
				cfg.on_column_order_change(next_order, mut e, mut w)
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
		on_click:     fn [cfg, col] (_ &Layout, mut e Event, mut w Window) {
			if cfg.on_column_pin_change == unsafe { nil } {
				return
			}
			next_pin := grid_column_next_pin(col.pin)
			cfg.on_column_pin_change(col.id, next_pin, mut e, mut w)
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
	value := grid_query_filter_value(cfg.query, col.id)
	input_id := '${cfg.id}:filter:${col.id}'
	on_query_change := cfg.on_query_change
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
				color:           cfg.color_filter
				color_hover:     cfg.color_filter
				color_border:    cfg.color_border
				text_style:      cfg.text_style_filter
				on_text_changed: fn [cfg, col, on_query_change] (_ &Layout, text string, mut w Window) {
					if on_query_change == unsafe { nil } {
						return
					}
					next := grid_query_set_filter(cfg.query, col.id, text)
					mut e := Event{}
					on_query_change(next, mut e, mut w)
				}
			),
		]
	)
}

fn data_grid_row_view(cfg DataGridCfg, row_data GridRow, row_idx int, columns []GridColumnCfg, column_widths map[string]f32, row_height f32, focus_id u32) View {
	row_id := data_grid_row_id(row_data, row_idx)
	is_selected := cfg.selection.selected_row_ids[row_id]
	mut cells := []View{cap: columns.len}
	for col in columns {
		value := row_data.cells[col.id] or { '' }
		text_style := col.text_style or { cfg.text_style }
		cells << row(
			name:         'data_grid cell'
			id:           '${cfg.id}:cell:${row_id}:${col.id}'
			width:        data_grid_column_width_for(col, column_widths)
			sizing:       fixed_fill
			padding:      cfg.padding_cell
			color:        color_transparent
			color_border: cfg.color_border
			size_border:  cfg.size_border
			h_align:      col.align
			content:      [
				text(
					text:       value
					mode:       .single_line
					text_style: text_style
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

	return row(
		name:         'data_grid row'
		id:           '${cfg.id}:row:${row_id}'
		height:       row_height
		sizing:       fill_fixed
		color:        row_color
		color_border: cfg.color_border
		size_border:  0
		padding:      padding_none
		spacing:      -cfg.size_border
		on_click:     fn [cfg, row_idx, row_id, focus_id] (_ &Layout, mut e Event, mut w Window) {
			data_grid_row_click(cfg, row_idx, row_id, focus_id, mut e, mut w)
		}
		on_hover:     fn [cfg, is_selected] (mut layout Layout, mut _ Event, mut w Window) {
			w.set_mouse_cursor_pointing_hand()
			if !is_selected {
				layout.shape.color = cfg.color_row_hover
			}
		}
		content:      cells
	)
}

fn data_grid_row_click(cfg DataGridCfg, row_idx int, row_id string, focus_id u32, mut e Event, mut w Window) {
	if focus_id > 0 {
		w.set_id_focus(focus_id)
	}
	if cfg.on_selection_change == unsafe { nil } {
		return
	}
	if row_idx < 0 || row_idx >= cfg.rows.len {
		return
	}
	mut next := GridSelection{}
	is_shift := e.modifiers.has(.shift)
	is_toggle := e.modifiers.has(.ctrl) || e.modifiers.has(.super)

	if cfg.multi_select && cfg.range_select && is_shift {
		anchor := data_grid_anchor_row_id(cfg, mut w, row_id)
		start, end := data_grid_range_indices(cfg.rows, anchor, row_id)
		mut selected := map[string]bool{}
		if start >= 0 && end >= start {
			for idx in start .. end + 1 {
				selected[data_grid_row_id(cfg.rows[idx], idx)] = true
			}
		} else {
			selected[row_id] = true
		}
		next = GridSelection{
			anchor_row_id:    anchor
			active_row_id:    row_id
			selected_row_ids: selected
		}
		data_grid_set_anchor(cfg.id, anchor, mut w)
	} else if cfg.multi_select && is_toggle {
		mut selected := cfg.selection.selected_row_ids.clone()
		if selected[row_id] {
			selected.delete(row_id)
		} else {
			selected[row_id] = true
		}
		next = GridSelection{
			anchor_row_id:    row_id
			active_row_id:    row_id
			selected_row_ids: selected
		}
		data_grid_set_anchor(cfg.id, row_id, mut w)
	} else {
		next = GridSelection{
			anchor_row_id:    row_id
			active_row_id:    row_id
			selected_row_ids: {
				row_id: true
			}
		}
		data_grid_set_anchor(cfg.id, row_id, mut w)
	}

	cfg.on_selection_change(next, mut e, mut w)
	e.is_handled = true
}

fn data_grid_start_resize(cfg DataGridCfg, col GridColumnCfg, focus_id u32, start_mouse_x f32, mut e Event, mut w Window) {
	if focus_id > 0 {
		w.set_id_focus(focus_id)
	}
	mut runtime := w.view_state.data_grid_resize_state.get(cfg.id) or { DataGridResizeState{} }
	if runtime.last_click_col_id == col.id && runtime.last_click_frame > 0
		&& e.frame_count - runtime.last_click_frame <= data_grid_resize_double_click_frames {
		fit_width := data_grid_auto_fit_width(cfg, col, mut w)
		data_grid_set_column_width(cfg.id, col, fit_width, mut w)
		runtime.active = false
		runtime.last_click_frame = 0
		runtime.last_click_col_id = ''
		w.view_state.data_grid_resize_state.set(cfg.id, runtime)
		e.is_handled = true
		return
	}

	runtime.active = true
	runtime.col_id = col.id
	runtime.start_mouse_x = start_mouse_x
	runtime.start_width = data_grid_column_width(cfg, col, mut w)
	runtime.last_click_frame = e.frame_count
	runtime.last_click_col_id = col.id
	w.view_state.data_grid_resize_state.set(cfg.id, runtime)

	w.mouse_lock(MouseLockCfg{
		mouse_move: fn [cfg, col] (_ &Layout, mut e Event, mut w Window) {
			data_grid_resize_drag(cfg, col, mut e, mut w)
		}
		mouse_up:   fn [cfg, focus_id] (_ &Layout, mut _ Event, mut w Window) {
			data_grid_end_resize(cfg.id, mut w)
			w.mouse_unlock()
			if focus_id > 0 {
				w.set_id_focus(focus_id)
			}
		}
	})
	e.is_handled = true
}

fn data_grid_resize_drag(cfg DataGridCfg, col GridColumnCfg, mut e Event, mut w Window) {
	mut runtime := w.view_state.data_grid_resize_state.get(cfg.id) or { return }
	if !runtime.active || runtime.col_id != col.id {
		return
	}
	delta := e.mouse_x - runtime.start_mouse_x
	next_width := runtime.start_width + delta
	data_grid_set_column_width(cfg.id, col, next_width, mut w)
	w.set_mouse_cursor_ew()
	e.is_handled = true
}

fn data_grid_end_resize(grid_id string, mut w Window) {
	mut runtime := w.view_state.data_grid_resize_state.get(grid_id) or { return }
	runtime.active = false
	w.view_state.data_grid_resize_state.set(grid_id, runtime)
}

fn data_grid_auto_fit_width(cfg DataGridCfg, col GridColumnCfg, mut w Window) f32 {
	mut longest := text_width(col.title, cfg.text_style_header, mut w)
	style := col.text_style or { cfg.text_style }
	for row in cfg.rows {
		value := row.cells[col.id] or { '' }
		width := text_width(value, style, mut w)
		if width > longest {
			longest = width
		}
	}
	return data_grid_clamp_width(col, longest + cfg.padding_cell.width() + data_grid_autofit_padding)
}

fn make_data_grid_on_char(cfg DataGridCfg) fn (&Layout, mut Event, mut Window) {
	return fn [cfg] (_ &Layout, mut e Event, mut w Window) {
		if !data_grid_char_is_copy(&e) {
			return
		}
		selected_rows := data_grid_selected_rows(cfg.rows, cfg.selection)
		columns := data_grid_effective_columns(cfg)
		if selected_rows.len == 0 {
			return
		}
		mut payload := ''
		if cfg.on_copy_rows != unsafe { nil } {
			payload = cfg.on_copy_rows(selected_rows, mut e, mut w) or {
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

fn make_data_grid_on_mouse_move(cfg DataGridCfg) fn (&Layout, mut Event, mut Window) {
	return fn [cfg] (layout &Layout, mut e Event, mut w Window) {
		mouse_x := layout.shape.x + e.mouse_x
		mouse_y := layout.shape.y + e.mouse_y
		col_id := data_grid_header_col_under_cursor(layout, cfg.id, mouse_x, mouse_y)
		if col_id.len == 0 {
			w.view_state.data_grid_header_hover_col.delete(cfg.id)
			return
		}
		w.view_state.data_grid_header_hover_col.set(cfg.id, col_id)
	}
}

fn make_data_grid_header_on_keydown(cfg DataGridCfg, col GridColumnCfg, col_idx int, col_count int, grid_focus_id u32) fn (&Layout, mut Event, mut Window) {
	return fn [cfg, col, col_idx, col_count, grid_focus_id] (_ &Layout, mut e Event, mut w Window) {
		data_grid_header_on_keydown(cfg, col, col_idx, col_count, grid_focus_id, mut e, mut
			w)
	}
}

fn data_grid_header_on_keydown(cfg DataGridCfg, col GridColumnCfg, col_idx int, col_count int, grid_focus_id u32, mut e Event, mut w Window) {
	is_ctrl_or_super := e.modifiers.has(.ctrl) || e.modifiers.has(.super)
	is_alt := e.modifiers.has(.alt)
	is_shift := e.modifiers.has(.shift)

	match e.key_code {
		.enter, .space {
			if e.modifiers == .none || e.modifiers == .shift {
				data_grid_header_toggle_sort(cfg, col, mut e, mut w)
			}
			return
		}
		.left, .right {
			if is_ctrl_or_super {
				delta := if e.key_code == .left { -1 } else { 1 }
				data_grid_header_reorder_by_key(cfg, col, col_count, delta, mut e, mut
					w)
				return
			}
			if is_alt {
				step := if is_shift {
					data_grid_resize_key_step_large
				} else {
					data_grid_resize_key_step
				}
				delta := if e.key_code == .left { -step } else { step }
				data_grid_header_resize_by_key(cfg, col, delta, mut e, mut w)
				return
			}
			if e.modifiers == .none {
				next_idx := int_clamp(col_idx + if e.key_code == .left { -1 } else { 1 },
					0, col_count - 1)
				if next_idx != col_idx {
					next_focus_id := data_grid_header_focus_id(cfg, col_count, next_idx)
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
				data_grid_header_pin_by_key(cfg, col, col_count, mut e, mut w)
			}
			return
		}
		.escape {
			if e.modifiers == .none {
				if grid_focus_id > 0 {
					w.set_id_focus(grid_focus_id)
				}
				e.is_handled = true
			}
			return
		}
		else {}
	}
}

fn data_grid_header_toggle_sort(cfg DataGridCfg, col GridColumnCfg, mut e Event, mut w Window) {
	if !col.sortable || cfg.on_query_change == unsafe { nil } {
		return
	}
	shift_sort := cfg.multi_sort && e.modifiers.has(.shift)
	next := data_grid_toggle_sort(cfg.query, col.id, cfg.multi_sort, shift_sort)
	cfg.on_query_change(next, mut e, mut w)
	e.is_handled = true
}

fn data_grid_header_reorder_by_key(cfg DataGridCfg, col GridColumnCfg, col_count int, delta int, mut e Event, mut w Window) {
	if !col.reorderable || cfg.on_column_order_change == unsafe { nil } {
		return
	}
	base_order := data_grid_normalized_column_order(cfg)
	next_order := grid_column_order_move(base_order, col.id, delta)
	if next_order == base_order {
		e.is_handled = true
		return
	}
	cfg.on_column_order_change(next_order, mut e, mut w)
	next_idx := data_grid_effective_index_for_column_with_order(cfg, next_order, col.id)
	if next_idx >= 0 {
		next_focus_id := data_grid_header_focus_id(cfg, col_count, next_idx)
		if next_focus_id > 0 {
			w.set_id_focus(next_focus_id)
		}
	}
	e.is_handled = true
}

fn data_grid_header_resize_by_key(cfg DataGridCfg, col GridColumnCfg, delta f32, mut e Event, mut w Window) {
	if !col.resizable {
		return
	}
	current := data_grid_column_width(cfg, col, mut w)
	data_grid_set_column_width(cfg.id, col, current + delta, mut w)
	e.is_handled = true
}

fn data_grid_header_pin_by_key(cfg DataGridCfg, col GridColumnCfg, col_count int, mut e Event, mut w Window) {
	if cfg.on_column_pin_change == unsafe { nil } {
		return
	}
	next_pin := grid_column_next_pin(col.pin)
	cfg.on_column_pin_change(col.id, next_pin, mut e, mut w)
	next_idx := data_grid_effective_index_for_column_with_pin(cfg, col.id, next_pin)
	if next_idx >= 0 {
		next_focus_id := data_grid_header_focus_id(cfg, col_count, next_idx)
		if next_focus_id > 0 {
			w.set_id_focus(next_focus_id)
		}
	}
	e.is_handled = true
}

fn make_data_grid_on_keydown(cfg DataGridCfg, row_height f32, static_top f32, scroll_id u32) fn (&Layout, mut Event, mut Window) {
	return fn [cfg, row_height, static_top, scroll_id] (_ &Layout, mut e Event, mut w Window) {
		if cfg.rows.len == 0 {
			return
		}

		if data_grid_is_select_all_shortcut(&e) && cfg.multi_select {
			mut selected := map[string]bool{}
			for idx, row in cfg.rows {
				selected[data_grid_row_id(row, idx)] = true
			}
			next := GridSelection{
				anchor_row_id:    data_grid_row_id(cfg.rows[0], 0)
				active_row_id:    data_grid_row_id(cfg.rows[cfg.rows.len - 1], cfg.rows.len - 1)
				selected_row_ids: selected
			}
			data_grid_set_anchor(cfg.id, next.anchor_row_id, mut w)
			if cfg.on_selection_change != unsafe { nil } {
				cfg.on_selection_change(next, mut e, mut w)
			}
			e.is_handled = true
			return
		}

		if e.key_code == .enter {
			if cfg.on_row_activate == unsafe { nil } {
				return
			}
			idx := data_grid_active_row_index(cfg.rows, cfg.selection)
			if idx >= 0 && idx < cfg.rows.len {
				cfg.on_row_activate(cfg.rows[idx], mut e, mut w)
				e.is_handled = true
			}
			return
		}

		is_shift := e.modifiers.has(.shift)
		if e.modifiers != .none && !is_shift {
			return
		}

		current := data_grid_active_row_index(cfg.rows, cfg.selection)
		if current < 0 {
			return
		}
		mut target := current
		page_rows := data_grid_page_rows(cfg, row_height)

		match e.key_code {
			.up {
				target--
			}
			.down {
				target++
			}
			.home {
				target = 0
			}
			.end {
				target = cfg.rows.len - 1
			}
			.page_up {
				target -= page_rows
			}
			.page_down {
				target += page_rows
			}
			else {
				return
			}
		}
		target = int_clamp(target, 0, cfg.rows.len - 1)
		if cfg.on_selection_change == unsafe { nil } {
			return
		}

		target_id := data_grid_row_id(cfg.rows[target], target)
		mut next := GridSelection{}
		if is_shift && cfg.multi_select && cfg.range_select {
			anchor := data_grid_anchor_row_id(cfg, mut w, target_id)
			start, end := data_grid_range_indices(cfg.rows, anchor, target_id)
			mut selected := map[string]bool{}
			if start >= 0 && end >= start {
				for idx in start .. end + 1 {
					selected[data_grid_row_id(cfg.rows[idx], idx)] = true
				}
			} else {
				selected[target_id] = true
			}
			next = GridSelection{
				anchor_row_id:    anchor
				active_row_id:    target_id
				selected_row_ids: selected
			}
			data_grid_set_anchor(cfg.id, anchor, mut w)
		} else {
			next = GridSelection{
				anchor_row_id:    target_id
				active_row_id:    target_id
				selected_row_ids: {
					target_id: true
				}
			}
			data_grid_set_anchor(cfg.id, target_id, mut w)
		}

		cfg.on_selection_change(next, mut e, mut w)
		data_grid_scroll_row_into_view(cfg, target, row_height, static_top, scroll_id, mut
			w)
		e.is_handled = true
	}
}

fn data_grid_scroll_row_into_view(cfg DataGridCfg, row_idx int, row_height f32, static_top f32, scroll_id u32, mut w Window) {
	viewport_h := data_grid_height(cfg)
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

// grid_rows_to_tsv converts rows to tab-separated text with a header row.
pub fn grid_rows_to_tsv(columns []GridColumnCfg, rows []GridRow) string {
	if columns.len == 0 {
		return ''
	}
	mut lines := []string{cap: rows.len + 1}
	lines << columns.map(data_grid_tsv_escape(it.title)).join('\t')
	for row in rows {
		mut fields := []string{cap: columns.len}
		for col in columns {
			fields << data_grid_tsv_escape(row.cells[col.id] or { '' })
		}
		lines << fields.join('\t')
	}
	return lines.join('\n')
}

// grid_rows_to_csv converts rows to comma-separated text with a header row.
pub fn grid_rows_to_csv(columns []GridColumnCfg, rows []GridRow) string {
	if columns.len == 0 {
		return ''
	}
	mut lines := []string{cap: rows.len + 1}
	lines << columns.map(data_grid_csv_escape(it.title)).join(',')
	for row in rows {
		mut fields := []string{cap: columns.len}
		for col in columns {
			fields << data_grid_csv_escape(row.cells[col.id] or { '' })
		}
		lines << fields.join(',')
	}
	return lines.join('\n')
}

fn data_grid_tsv_escape(value string) string {
	mut out := value.replace_each(['\r\n', ' ', '\n', ' ', '\r', ' ', '\t', ' '])
	return out.trim_space()
}

fn data_grid_csv_escape(value string) string {
	if value.len == 0 {
		return ''
	}
	needs_quotes := value.contains(',') || value.contains('"') || value.contains('\n')
		|| value.contains('\r')
	if !needs_quotes {
		return value
	}
	escaped := value.replace('"', '""')
	return '"${escaped}"'
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
	return 0
}

fn data_grid_anchor_row_id(cfg DataGridCfg, mut w Window, fallback string) string {
	if cfg.selection.anchor_row_id.len > 0 {
		return cfg.selection.anchor_row_id
	}
	if state := w.view_state.data_grid_range_state.get(cfg.id) {
		if state.anchor_row_id.len > 0 {
			return state.anchor_row_id
		}
	}
	if cfg.selection.active_row_id.len > 0 {
		return cfg.selection.active_row_id
	}
	if cfg.selection.selected_row_ids.len > 0 {
		for idx, row in cfg.rows {
			id := data_grid_row_id(row, idx)
			if cfg.selection.selected_row_ids[id] {
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

fn data_grid_indicator_text_style(base TextStyle) TextStyle {
	return TextStyle{
		...base
		color: data_grid_dim_color(base.color)
	}
}

fn data_grid_dim_color(c Color) Color {
	return Color{
		r: c.r
		g: c.g
		b: c.b
		a: data_grid_indicator_alpha
	}
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

fn data_grid_effective_index_for_column_with_order(cfg DataGridCfg, next_order []string, col_id string) int {
	next_cfg := DataGridCfg{
		...cfg
		column_order: next_order
	}
	cols := data_grid_effective_columns(next_cfg)
	for idx, col in cols {
		if col.id == col_id {
			return idx
		}
	}
	return -1
}

fn data_grid_effective_index_for_column_with_pin(cfg DataGridCfg, col_id string, pin GridColumnPin) int {
	mut next_columns := cfg.columns.clone()
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
	next_cfg := DataGridCfg{
		...cfg
		columns: next_columns
	}
	cols := data_grid_effective_columns(next_cfg)
	for idx, col in cols {
		if col.id == col_id {
			return idx
		}
	}
	return -1
}

struct DataGridHeaderControlState {
mut:
	show_label   bool
	show_reorder bool
	show_pin     bool
	show_resize  bool
}

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

fn data_grid_effective_columns(cfg DataGridCfg) []GridColumnCfg {
	if cfg.columns.len == 0 {
		return []
	}
	order := data_grid_normalized_column_order(cfg)
	cols_by_id := data_grid_columns_by_id(cfg.columns)
	mut ordered := []GridColumnCfg{cap: cfg.columns.len}
	for id in order {
		col := cols_by_id[id] or { continue }
		ordered << col
	}
	return data_grid_partition_pins(ordered)
}

fn data_grid_normalized_column_order(cfg DataGridCfg) []string {
	if cfg.columns.len == 0 {
		return []
	}
	mut seen := map[string]bool{}
	mut order := []string{cap: cfg.columns.len}
	for id in cfg.column_order {
		if id.len == 0 || seen[id] {
			continue
		}
		if cfg.columns.any(it.id == id) {
			seen[id] = true
			order << id
		}
	}
	for col in cfg.columns {
		if col.id.len == 0 || seen[col.id] {
			continue
		}
		seen[col.id] = true
		order << col.id
	}
	return order
}

fn data_grid_columns_by_id(columns []GridColumnCfg) map[string]GridColumnCfg {
	mut res := map[string]GridColumnCfg{}
	for col in columns {
		if col.id.len == 0 {
			continue
		}
		res[col.id] = col
	}
	return res
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

fn grid_column_next_pin(pin GridColumnPin) GridColumnPin {
	return match pin {
		.none { .left }
		.left { .right }
		.right { .none }
	}
}

// grid_column_order_move moves `col_id` in `order` by delta (-1 left, +1 right).
pub fn grid_column_order_move(order []string, col_id string, delta int) []string {
	if order.len == 0 || delta == 0 {
		return order.clone()
	}
	mut idx := -1
	for i, id in order {
		if id == col_id {
			idx = i
			break
		}
	}
	if idx < 0 {
		return order.clone()
	}
	target := int_clamp(idx + delta, 0, order.len - 1)
	if target == idx {
		return order.clone()
	}
	mut next := order.clone()
	value := next[idx]
	next.delete(idx)
	next.insert(target, value)
	return next
}

fn grid_query_set_filter(query GridQueryState, col_id string, value string) GridQueryState {
	mut next := GridQueryState{
		sorts:        query.sorts.clone()
		filters:      query.filters.clone()
		quick_filter: query.quick_filter
	}
	idx := grid_query_filter_index(next.filters, col_id)
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

fn grid_query_filter_index(filters []GridFilter, col_id string) int {
	for idx, filter in filters {
		if filter.col_id == col_id {
			return idx
		}
	}
	return -1
}

fn grid_query_filter_value(query GridQueryState, col_id string) string {
	idx := grid_query_filter_index(query.filters, col_id)
	if idx < 0 {
		return ''
	}
	return query.filters[idx].value
}

fn data_grid_column_widths(cfg DataGridCfg, mut w Window) map[string]f32 {
	mut widths := if cached := w.view_state.data_grid_col_widths.get(cfg.id) {
		cached.widths.clone()
	} else {
		map[string]f32{}
	}
	mut changed := false
	for col in cfg.columns {
		if col.id.len == 0 {
			continue
		}
		base := widths[col.id] or { data_grid_initial_width(col) }
		clamped := data_grid_clamp_width(col, base)
		if widths[col.id] or { f32(-1) } != clamped {
			widths[col.id] = clamped
			changed = true
		}
	}
	for key in widths.keys() {
		if !cfg.columns.any(it.id == key) {
			widths.delete(key)
			changed = true
		}
	}
	if changed || !w.view_state.data_grid_col_widths.contains(cfg.id) {
		w.view_state.data_grid_col_widths.set(cfg.id, &DataGridColWidths{
			widths: widths.clone()
		})
	}
	return widths
}

fn data_grid_column_width(cfg DataGridCfg, col GridColumnCfg, mut w Window) f32 {
	widths := data_grid_column_widths(cfg, mut w)
	return data_grid_column_width_for(col, widths)
}

fn data_grid_column_width_for(col GridColumnCfg, widths map[string]f32) f32 {
	return widths[col.id] or { data_grid_initial_width(col) }
}

fn data_grid_set_column_width(grid_id string, col GridColumnCfg, width f32, mut w Window) {
	mut widths := if cached := w.view_state.data_grid_col_widths.get(grid_id) {
		cached.widths.clone()
	} else {
		map[string]f32{}
	}
	widths[col.id] = data_grid_clamp_width(col, width)
	w.view_state.data_grid_col_widths.set(grid_id, &DataGridColWidths{
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

fn data_grid_row_id(row GridRow, idx int) string {
	if row.id.len > 0 {
		return row.id
	}
	return idx.str()
}

fn data_grid_height(cfg DataGridCfg) f32 {
	if cfg.height > 0 {
		return cfg.height
	}
	if cfg.max_height > 0 {
		return cfg.max_height
	}
	return f32(0)
}

fn data_grid_header_height(cfg DataGridCfg) f32 {
	if cfg.header_height > 0 {
		return cfg.header_height
	}
	return cfg.row_height
}

fn data_grid_filter_height(cfg DataGridCfg) f32 {
	if cfg.row_height > 0 {
		return cfg.row_height
	}
	return data_grid_header_height(cfg)
}

fn data_grid_quick_filter_height(cfg DataGridCfg) f32 {
	if cfg.row_height > 0 {
		return cfg.row_height
	}
	return data_grid_header_height(cfg)
}

fn data_grid_row_height(cfg DataGridCfg, mut window Window) f32 {
	if cfg.row_height > 0 {
		return cfg.row_height
	}
	font_h := window.text_system.font_height(cfg.text_style.to_vglyph_cfg()) or {
		cfg.text_style.size
	}
	return font_h + cfg.padding_cell.height() + cfg.size_border
}

fn data_grid_static_top_height(cfg DataGridCfg, row_height f32) f32 {
	mut top := f32(0)
	if cfg.show_quick_filter {
		top += data_grid_quick_filter_height(cfg)
	}
	if cfg.show_header {
		top += data_grid_header_height(cfg)
	}
	if cfg.show_filter_row {
		top += data_grid_filter_height(cfg)
	}
	if row_height <= 0 {
		return top
	}
	return top
}

fn data_grid_focus_id(cfg DataGridCfg) u32 {
	if cfg.id_focus > 0 {
		return cfg.id_focus
	}
	return fnv1a.sum32_string(cfg.id + ':focus')
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

fn data_grid_scroll_id(cfg DataGridCfg) u32 {
	if cfg.id_scroll > 0 {
		return cfg.id_scroll
	}
	return fnv1a.sum32_string(cfg.id + ':scroll')
}

fn data_grid_visible_range_for_scroll(scroll_y f32, viewport_height f32, row_height f32, row_count int, static_top f32, buffer int) (int, int) {
	if row_count == 0 || row_height <= 0 || viewport_height <= 0 {
		return 0, -1
	}
	mut body_scroll := scroll_y - static_top
	if body_scroll < 0 {
		body_scroll = 0
	}
	first := int(body_scroll / row_height)
	visible_rows := int(viewport_height / row_height) + 1
	mut first_visible := first - buffer
	if first_visible < 0 {
		first_visible = 0
	}
	mut last_visible := first + visible_rows + buffer
	if last_visible > row_count - 1 {
		last_visible = row_count - 1
	}
	if first_visible > last_visible {
		first_visible = last_visible
	}
	return first_visible, last_visible
}
