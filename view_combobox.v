module gui

// view_combobox.v implements a single-select combobox with
// typeahead filtering. Supports static options or async
// ListBoxDataSource. Force-selection only (no free text).

@[minify]
pub struct ComboboxCfg {
	A11yCfg
pub:
	id                  string @[required]
	value               string // current selection
	placeholder         string
	options             []string           // static mode
	data_source         ?ListBoxDataSource // async mode
	source_key          string
	on_select           fn (string, mut Event, mut Window) @[required]
	text_style          TextStyle = gui_theme.combobox_style.text_style
	placeholder_style   TextStyle = gui_theme.combobox_style.placeholder_style
	color               Color     = gui_theme.combobox_style.color
	color_border        Color     = gui_theme.combobox_style.color_border
	color_border_focus  Color     = gui_theme.combobox_style.color_border_focus
	color_focus         Color     = gui_theme.combobox_style.color_focus
	color_highlight     Color     = gui_theme.combobox_style.color_highlight
	color_hover         Color     = gui_theme.combobox_style.color_hover
	padding             Padding   = gui_theme.combobox_style.padding
	size_border         f32       = gui_theme.combobox_style.size_border
	radius              f32       = gui_theme.combobox_style.radius
	min_width           f32       = gui_theme.combobox_style.min_width
	max_width           f32       = gui_theme.combobox_style.max_width
	max_dropdown_height f32       = 200
	id_focus            u32
	id_scroll           u32
	sizing              Sizing
	disabled            bool
}

// combobox creates a combobox view. Requires mut Window for
// async data source resolution.
pub fn (mut window Window) combobox(cfg ComboboxCfg) View {
	is_open := state_read_or[string, bool](&window, ns_combobox, cfg.id, false)
	query := state_read_or[string, string](&window, ns_combobox_query, cfg.id, '')
	highlighted := state_read_or[string, int](&window, ns_combobox_highlight, cfg.id,
		0)

	// Resolve items: async or static.
	items, loading, load_error := combobox_resolve_items(cfg, query, mut window)

	// Filter static items when query is present and no async source.
	filter_query := if cfg.data_source == none { query } else { '' }
	prepared := list_core_prepare(items, filter_query, highlighted)
	filtered := prepared.items
	filtered_ids := prepared.ids
	hl := prepared.hl

	// Virtualization.
	row_h := list_core_row_height_estimate(cfg.text_style, cfg.padding)
	list_h := cfg.max_dropdown_height
	scroll_y := if cfg.id_scroll > 0 {
		state_read_or[u32, f32](&window, ns_scroll_y, cfg.id_scroll, f32(0))
	} else {
		f32(0)
	}
	first, last := list_core_visible_range(filtered.len, row_h, list_h, scroll_y)

	// Build dropdown content.
	on_select := cfg.on_select
	cfg_id := cfg.id
	core_cfg := ListCoreCfg{
		text_style:      cfg.text_style
		color_highlight: cfg.color_highlight
		color_hover:     cfg.color_hover
		color_selected:  cfg.color_highlight
		padding_item:    cfg.padding
		on_item_click:   fn [on_select, cfg_id] (item_id string, _ int, mut e Event, mut w Window) {
			on_select(item_id, mut e, mut w)
			combobox_close(cfg_id, mut w)
		}
	}

	mut content := []View{cap: 4}

	// Display: input when open, text when closed.
	if is_open {
		content << input(
			id:              cfg.id + '.input'
			id_focus:        cfg.id_focus
			text:            query
			placeholder:     cfg.placeholder
			text_style:      cfg.text_style
			on_text_changed: make_combobox_on_text_changed(cfg.id)
			sizing:          fill_fit
		)
	} else {
		empty := cfg.value.len == 0
		content << text(
			text:       if empty { cfg.placeholder } else { cfg.value }
			text_style: if empty { cfg.placeholder_style } else { cfg.text_style }
			mode:       .single_line
		)
	}

	content << row(
		name:    'combobox spacer'
		sizing:  fill_fill
		padding: padding_none
	)
	content << text(
		text:       if is_open { '▲' } else { '▼' }
		text_style: cfg.text_style
	)

	if is_open {
		mut dropdown_content := []View{cap: 3}
		if loading && filtered.len == 0 {
			dropdown_content << text(
				text:       gui_locale.str_loading
				text_style: cfg.text_style
			)
		} else if load_error.len > 0 && filtered.len == 0 {
			dropdown_content << text(
				text:       load_error
				text_style: cfg.text_style
			)
		} else {
			dropdown_content = list_core_views(filtered, core_cfg, first, last, hl, [],
				row_h)
		}
		content << column(
			name:           'combobox dropdown'
			id:             cfg.id + '.dropdown'
			size_border:    cfg.size_border
			radius:         cfg.radius
			color_border:   cfg.color_border
			color:          cfg.color
			min_height:     50
			max_height:     cfg.max_dropdown_height
			min_width:      cfg.min_width
			max_width:      cfg.max_width
			float:          true
			float_anchor:   .bottom_left
			float_tie_off:  .top_left
			float_offset_y: -cfg.size_border
			id_scroll:      cfg.id_scroll
			padding:        cfg.padding
			spacing:        0
			content:        dropdown_content
		)
	}

	color_focus := cfg.color_focus
	color_border_focus := cfg.color_border_focus
	id_focus := cfg.id_focus

	return row(
		name:         'combobox'
		id:           cfg.id
		id_focus:     id_focus
		a11y_role:    .combo_box
		a11y_label:   a11y_label(cfg.a11y_label, cfg.placeholder)
		color:        cfg.color
		color_border: cfg.color_border
		size_border:  cfg.size_border
		radius:       cfg.radius
		padding:      cfg.padding
		sizing:       cfg.sizing
		min_width:    cfg.min_width
		max_width:    cfg.max_width
		amend_layout: fn [color_focus, color_border_focus] (mut layout Layout, mut w Window) {
			if layout.shape.disabled {
				return
			}
			if w.is_focus(layout.shape.id_focus) {
				layout.shape.color = color_focus
				layout.shape.color_border = color_border_focus
			}
		}
		on_keydown:   make_combobox_on_keydown(cfg.id, on_select, id_focus, filtered_ids)
		on_click:     fn [cfg_id, is_open, id_focus] (_ &Layout, mut e Event, mut w Window) {
			if !is_open {
				combobox_open(cfg_id, id_focus, mut w)
			}
			e.is_handled = true
		}
		content:      content
	)
}

fn combobox_open(id string, id_focus u32, mut w Window) {
	mut ss := state_map[string, bool](mut w, ns_combobox, cap_moderate)
	ss.set(id, true)
	mut sq := state_map[string, string](mut w, ns_combobox_query, cap_moderate)
	sq.set(id, '')
	mut sh := state_map[string, int](mut w, ns_combobox_highlight, cap_moderate)
	sh.set(id, 0)
	if id_focus > 0 {
		w.set_id_focus(id_focus)
	}
	w.update_window()
}

fn combobox_close(id string, mut w Window) {
	mut ss := state_map[string, bool](mut w, ns_combobox, cap_moderate)
	ss.set(id, false)
	mut sq := state_map[string, string](mut w, ns_combobox_query, cap_moderate)
	sq.set(id, '')
	mut sh := state_map[string, int](mut w, ns_combobox_highlight, cap_moderate)
	sh.set(id, 0)
	w.update_window()
}

fn make_combobox_on_text_changed(cfg_id string) fn (&Layout, string, mut Window) {
	return fn [cfg_id] (_ &Layout, new_text string, mut w Window) {
		mut sq := state_map[string, string](mut w, ns_combobox_query, cap_moderate)
		sq.set(cfg_id, new_text)
		mut sh := state_map[string, int](mut w, ns_combobox_highlight, cap_moderate)
		sh.set(cfg_id, 0)
		w.update_window()
	}
}

fn make_combobox_on_keydown(cfg_id string, on_select fn (string, mut Event, mut Window), id_focus u32, filtered_ids []string) fn (mut Layout, mut Event, mut Window) {
	return fn [cfg_id, on_select, id_focus, filtered_ids] (mut _ Layout, mut e Event, mut w Window) {
		combobox_on_keydown(cfg_id, on_select, id_focus, filtered_ids, mut e, mut w)
	}
}

fn combobox_on_keydown(cfg_id string, on_select fn (string, mut Event, mut Window), id_focus u32, filtered_ids []string, mut e Event, mut w Window) {
	mut ss := state_map[string, bool](mut w, ns_combobox, cap_moderate)
	is_open := ss.get(cfg_id) or { false }

	if !is_open {
		if e.key_code in [.space, .enter, .up, .down] {
			combobox_open(cfg_id, id_focus, mut w)
			e.is_handled = true
		}
		return
	}

	if e.key_code == .escape || e.key_code == .tab {
		combobox_close(cfg_id, mut w)
		e.is_handled = true
		return
	}

	item_count := filtered_ids.len
	mut sh := state_map[string, int](mut w, ns_combobox_highlight, cap_moderate)
	cur := sh.get(cfg_id) or { 0 }
	action := list_core_navigate(e.key_code, item_count, cur)

	if action == .select_item {
		if cur >= 0 && cur < item_count {
			on_select(filtered_ids[cur], mut e, mut w)
			combobox_close(cfg_id, mut w)
		}
		e.is_handled = true
		return
	}
	next, changed := list_core_apply_nav(action, cur, item_count)
	if changed {
		sh.set(cfg_id, next)
		w.update_window()
		e.is_handled = true
	}
}

fn combobox_resolve_items(cfg ComboboxCfg, query string, mut window Window) ([]ListCoreItem, bool, string) {
	if cfg.data_source != none {
		// Async path: reuse listbox source machinery.
		lb_cfg := ListBoxCfg{
			id:          cfg.id
			data_source: cfg.data_source
			source_key:  cfg.source_key
			query:       query
		}
		resolved, _ := list_box_resolve_source_cfg(lb_cfg, mut window)
		mut items := []ListCoreItem{cap: resolved.data.len}
		for opt in resolved.data {
			items << list_box_option_to_core(opt)
		}
		return items, resolved.loading, resolved.load_error
	}
	// Static path: convert options to core items.
	mut items := []ListCoreItem{cap: cfg.options.len}
	for opt in cfg.options {
		items << ListCoreItem{
			id:    opt
			label: opt
		}
	}
	return items, false, ''
}
