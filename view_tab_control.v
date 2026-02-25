module gui

import log

// TabItemCfg configures one tab in a [tab_control](#tab_control).
@[minify]
pub struct TabItemCfg {
pub:
	id       string @[required]
	label    string @[required]
	content  []View
	disabled bool
}

// tab_item is a helper to build [TabItemCfg](#TabItemCfg) values.
pub fn tab_item(id string, label string, content []View) TabItemCfg {
	return TabItemCfg{
		id:      id
		label:   label
		content: content
	}
}

// TabControlCfg configures a [tab_control](#tab_control).
// This is a controlled component: `selected` is owned by app state and updated
// through `on_select`.
@[minify]
pub struct TabControlCfg {
	A11yCfg
pub:
	id                     string       @[required]
	items                  []TabItemCfg @[required]
	selected               string
	on_select              fn (string, mut Event, mut Window) @[required]
	sizing                 Sizing    = fill_fill
	color                  Color     = gui_theme.tab_style.color
	color_border           Color     = gui_theme.tab_style.color_border
	color_header           Color     = gui_theme.tab_style.color_header
	color_header_border    Color     = gui_theme.tab_style.color_header_border
	color_content          Color     = gui_theme.tab_style.color_content
	color_content_border   Color     = gui_theme.tab_style.color_content_border
	color_tab              Color     = gui_theme.tab_style.color_tab
	color_tab_hover        Color     = gui_theme.tab_style.color_tab_hover
	color_tab_focus        Color     = gui_theme.tab_style.color_tab_focus
	color_tab_click        Color     = gui_theme.tab_style.color_tab_click
	color_tab_selected     Color     = gui_theme.tab_style.color_tab_selected
	color_tab_disabled     Color     = gui_theme.tab_style.color_tab_disabled
	color_tab_border       Color     = gui_theme.tab_style.color_tab_border
	color_tab_border_focus Color     = gui_theme.tab_style.color_tab_border_focus
	padding                Padding   = gui_theme.tab_style.padding
	padding_header         Padding   = gui_theme.tab_style.padding_header
	padding_content        Padding   = gui_theme.tab_style.padding_content
	padding_tab            Padding   = gui_theme.tab_style.padding_tab
	size_border            f32       = gui_theme.tab_style.size_border
	size_header_border     f32       = gui_theme.tab_style.size_header_border
	size_content_border    f32       = gui_theme.tab_style.size_content_border
	size_tab_border        f32       = gui_theme.tab_style.size_tab_border
	radius                 f32       = gui_theme.tab_style.radius
	radius_header          f32       = gui_theme.tab_style.radius_header
	radius_content         f32       = gui_theme.tab_style.radius_content
	radius_tab             f32       = gui_theme.tab_style.radius_tab
	radius_tab_border      f32       = gui_theme.tab_style.radius_tab_border
	spacing                f32       = gui_theme.tab_style.spacing
	spacing_header         f32       = gui_theme.tab_style.spacing_header
	text_style             TextStyle = gui_theme.tab_style.text_style
	text_style_selected    TextStyle = gui_theme.tab_style.text_style_selected
	text_style_disabled    TextStyle = gui_theme.tab_style.text_style_disabled
	id_focus               u32
	disabled               bool
	invisible              bool
	reorderable            bool
	on_reorder             fn (string, string, mut Window) = unsafe { nil }
}

// tabs is an alias for [tab_control](#tab_control).
pub fn tabs(cfg TabControlCfg) View {
	return tab_control(cfg)
}

// tabs builds a tab control with drag-reorder support.
pub fn (mut w Window) tabs(cfg TabControlCfg) View {
	return w.tab_control(cfg)
}

// tab_control builds a tab control with drag-reorder support.
pub fn (mut w Window) tab_control(cfg TabControlCfg) View {
	can_reorder := cfg.reorderable && cfg.on_reorder != unsafe { nil }
	if can_reorder {
		mut tab_ids := []string{cap: cfg.items.len}
		for item in cfg.items {
			if !item.disabled {
				tab_ids << item.id
			}
		}
		drag_reorder_ids_meta_set(mut w, cfg.id, tab_ids)
	}
	drag := if can_reorder {
		drag_reorder_get(mut w, cfg.id)
	} else {
		DragReorderState{}
	}
	return tab_control_build(cfg, drag)
}

// tab_control creates a tab control with a header row and active content area.
//
// Keyboard behavior (when focused):
// - Left/Up: previous enabled tab
// - Right/Down: next enabled tab
// - Home/End: first/last enabled tab
pub fn tab_control(cfg TabControlCfg) View {
	return tab_control_build(cfg, DragReorderState{})
}

fn tab_control_build(cfg TabControlCfg, drag DragReorderState) View {
	$if !prod {
		tab_warn_duplicate_ids(cfg.id, cfg.items)
	}
	can_reorder := cfg.reorderable && cfg.on_reorder != unsafe { nil }
	tab_nav_ids := cfg.items.map(it.id)
	tab_nav_disabled := cfg.items.map(it.disabled)
	selected_idx := tab_selected_index(tab_nav_ids, tab_nav_disabled, cfg.selected)
	dragging := can_reorder && drag.active && !drag.cancelled
	// Build non-disabled tab IDs for drag index mapping.
	mut tab_ids := []string{}
	mut tab_layout_ids := []string{}
	if can_reorder {
		tab_ids = []string{cap: cfg.items.len}
		tab_layout_ids = []string{cap: cfg.items.len}
		for item in cfg.items {
			if !item.disabled {
				tab_ids << item.id
				tab_layout_ids << tab_button_id(cfg.id, item.id)
			}
		}
	}
	on_reorder := cfg.on_reorder

	mut header_items := []View{cap: cfg.items.len + 2}
	mut ghost_view := View(rectangle(RectangleCfg{}))
	mut drag_idx := 0
	for i, item in cfg.items {
		is_selected := i == selected_idx
		is_disabled := cfg.disabled || item.disabled
		is_draggable := can_reorder && !is_disabled
		item_drag_idx := if is_draggable { drag_idx } else { -1 }

		// Insert gap at current drop target.
		if dragging && is_draggable && drag_idx == drag.current_index {
			header_items << drag_reorder_gap_view(drag, .horizontal)
		}

		tab_color := if is_disabled {
			cfg.color_tab_disabled
		} else if is_selected {
			cfg.color_tab_selected
		} else {
			cfg.color_tab
		}
		hover_color := if is_disabled {
			cfg.color_tab_disabled
		} else if is_selected {
			cfg.color_tab_selected
		} else {
			cfg.color_tab_hover
		}
		focus_color := if is_disabled {
			cfg.color_tab_disabled
		} else if is_selected {
			cfg.color_tab_selected
		} else {
			cfg.color_tab_focus
		}
		click_color := if is_disabled {
			cfg.color_tab_disabled
		} else if is_selected {
			cfg.color_tab_selected
		} else {
			cfg.color_tab_click
		}
		border_color := if is_selected && !is_disabled {
			cfg.color_tab_border_focus
		} else {
			cfg.color_tab_border
		}
		ts := if is_disabled {
			cfg.text_style_disabled
		} else if is_selected {
			cfg.text_style_selected
		} else {
			cfg.text_style
		}
		tab_a11y_state := if is_selected {
			AccessState.selected
		} else {
			AccessState.none
		}
		tab_on_click := if is_draggable {
			make_tab_drag_click(cfg.id, item.id, item_drag_idx, tab_ids, tab_layout_ids,
				on_reorder, cfg.on_select, cfg.id_focus)
		} else {
			make_tab_on_click(cfg.on_select, item.id, cfg.id_focus)
		}

		if dragging && is_draggable && drag_idx == drag.source_index {
			// Capture for ghost; skip from normal flow.
			ghost_view = button(
				id:                 tab_button_id(cfg.id, item.id)
				color:              tab_color
				color_border:       border_color
				color_border_focus: cfg.color_tab_border_focus
				padding:            cfg.padding_tab
				size_border:        cfg.size_tab_border
				radius:             cfg.radius_tab
				content:            [
					text(text: item.label, text_style: ts),
				]
			)
		} else {
			header_items << button(
				id:                 tab_button_id(cfg.id, item.id)
				a11y_role:          .tab_item
				a11y_state:         tab_a11y_state
				a11y_label:         item.label
				color:              tab_color
				color_hover:        hover_color
				color_focus:        focus_color
				color_click:        click_color
				color_border:       border_color
				color_border_focus: cfg.color_tab_border_focus
				padding:            cfg.padding_tab
				size_border:        cfg.size_tab_border
				radius:             cfg.radius_tab
				disabled:           is_disabled
				on_click:           tab_on_click
				content:            [
					text(text: item.label, text_style: ts),
				]
			)
		}

		if is_draggable {
			drag_idx++
		}
	}
	// Gap at end if dropping past last tab.
	if dragging && drag.current_index >= drag_idx {
		header_items << drag_reorder_gap_view(drag, .horizontal)
	}
	// Append floating ghost during active drag.
	if dragging {
		header_items << drag_reorder_ghost_view(drag, ghost_view)
	}

	mut active_content := []View{}
	if selected_idx >= 0 && selected_idx < cfg.items.len {
		active_content = cfg.items[selected_idx].content.clone()
	}

	// Extract only the fields needed by the keydown closure
	// to avoid capturing the entire TabControlCfg struct
	// (conservative GC false retention).
	disabled := cfg.disabled
	selected := cfg.selected
	on_select := cfg.on_select
	id_focus := cfg.id_focus
	reorderable := can_reorder
	tab_id := cfg.id

	return column(
		name:             'tab_control'
		id:               cfg.id
		id_focus:         cfg.id_focus
		a11y_role:        .tab
		a11y_label:       a11y_label(cfg.a11y_label, cfg.id)
		a11y_description: cfg.a11y_description
		sizing:           cfg.sizing
		color:            cfg.color
		color_border:     cfg.color_border
		size_border:      cfg.size_border
		radius:           cfg.radius
		padding:          cfg.padding
		spacing:          cfg.spacing
		disabled:         cfg.disabled
		invisible:        cfg.invisible
		on_keydown:       fn [disabled, tab_nav_ids, tab_nav_disabled, selected, on_select, id_focus, reorderable, on_reorder, tab_id, tab_ids] (_ &Layout, mut e Event, mut w Window) {
			tab_control_on_keydown(disabled, tab_nav_ids, tab_nav_disabled, selected,
				on_select, id_focus, reorderable, on_reorder, tab_id, tab_ids, mut e, mut
				w)
		}
		content:          [
			row(
				name:         'tab_control_header'
				color:        cfg.color_header
				color_border: cfg.color_header_border
				size_border:  cfg.size_header_border
				radius:       cfg.radius_header
				padding:      cfg.padding_header
				spacing:      cfg.spacing_header
				sizing:       fill_fit
				content:      header_items
			),
			column(
				name:         'tab_control_content'
				color:        cfg.color_content
				color_border: cfg.color_content_border
				size_border:  cfg.size_content_border
				radius:       cfg.radius_content
				padding:      cfg.padding_content
				sizing:       fill_fill
				content:      active_content
			),
		]
	)
}

fn make_tab_on_click(on_select fn (string, mut Event, mut Window), id string, id_focus u32) fn (&Layout, mut Event, mut Window) {
	return fn [on_select, id, id_focus] (_ &Layout, mut e Event, mut w Window) {
		on_select(id, mut e, mut w)
		if id_focus > 0 {
			w.set_id_focus(id_focus)
		}
		e.is_handled = true
	}
}

// make_tab_drag_click creates an on_click that initiates
// drag-reorder and also fires tab selection.
fn make_tab_drag_click(control_id string, item_id string,
	drag_index int, tab_ids []string,
	tab_layout_ids []string,
	on_reorder fn (string, string, mut Window),
	on_select fn (string, mut Event, mut Window),
	id_focus u32) fn (&Layout, mut Event, mut Window) {
	return fn [control_id, item_id, drag_index, tab_ids, tab_layout_ids, on_reorder, on_select, id_focus] (layout &Layout, mut e Event, mut w Window) {
		drag_reorder_start(control_id, drag_index, item_id, .horizontal, tab_ids, on_reorder,
			tab_layout_ids, 0, u32(0), layout, e, mut w)
		on_select(item_id, mut e, mut w)
		if id_focus > 0 {
			w.set_id_focus(id_focus)
		}
		e.is_handled = true
	}
}

fn tab_control_on_keydown(disabled bool, tab_nav_ids []string, tab_nav_disabled []bool, selected string, on_select fn (string, mut Event, mut Window), id_focus u32, reorderable bool, on_reorder fn (string, string, mut Window), tab_id string, tab_ids []string, mut e Event, mut w Window) {
	// Escape cancels active drag.
	if reorderable && drag_reorder_escape(tab_id, e.key_code, mut w) {
		e.is_handled = true
		return
	}
	// Alt+Left/Right keyboard reorder (non-disabled tabs only).
	if !disabled && reorderable && on_reorder != unsafe { nil } {
		sel_tab_idx := tab_ids.index(selected)
		if sel_tab_idx >= 0
			&& drag_reorder_keyboard_move(e.key_code, e.modifiers, .horizontal, sel_tab_idx, tab_ids, on_reorder, mut w) {
			e.is_handled = true
			return
		}
	}

	if disabled || tab_nav_ids.len == 0 || e.modifiers != .none {
		return
	}

	selected_idx := tab_selected_index(tab_nav_ids, tab_nav_disabled, selected)
	mut target_idx := -1
	match e.key_code {
		.left, .up {
			target_idx = if selected_idx >= 0 {
				tab_prev_enabled_index(tab_nav_disabled, selected_idx)
			} else {
				tab_last_enabled_index(tab_nav_disabled)
			}
		}
		.right, .down {
			target_idx = if selected_idx >= 0 {
				tab_next_enabled_index(tab_nav_disabled, selected_idx)
			} else {
				tab_first_enabled_index(tab_nav_disabled)
			}
		}
		.home {
			target_idx = tab_first_enabled_index(tab_nav_disabled)
		}
		.end {
			target_idx = tab_last_enabled_index(tab_nav_disabled)
		}
		.enter, .space {
			target_idx = if selected_idx >= 0 {
				selected_idx
			} else {
				tab_first_enabled_index(tab_nav_disabled)
			}
		}
		else {
			return
		}
	}

	if target_idx < 0 || target_idx >= tab_nav_ids.len {
		return
	}

	target_id := tab_nav_ids[target_idx]
	if target_id.len == 0 {
		return
	}

	// Enter/Space re-fires on_select even on current tab.
	if target_id != selected || e.key_code in [.enter, .space] {
		on_select(target_id, mut e, mut w)
	}
	if id_focus > 0 {
		w.set_id_focus(id_focus)
	}
	e.is_handled = true
}

fn tab_selected_index(ids []string, disabled []bool, selected string) int {
	if selected.len > 0 {
		for idx, id in ids {
			if id == selected && !disabled[idx] {
				return idx
			}
		}
	}
	return tab_first_enabled_index(disabled)
}

fn tab_first_enabled_index(disabled []bool) int {
	for idx, d in disabled {
		if !d {
			return idx
		}
	}
	return -1
}

fn tab_last_enabled_index(disabled []bool) int {
	for i := disabled.len - 1; i >= 0; i-- {
		if !disabled[i] {
			return i
		}
	}
	return -1
}

fn tab_next_enabled_index(disabled []bool, selected_idx int) int {
	if disabled.len == 0 {
		return -1
	}
	mut idx := if selected_idx < 0 || selected_idx >= disabled.len {
		-1
	} else {
		selected_idx
	}
	for _ in 0 .. disabled.len {
		idx = (idx + 1 + disabled.len) % disabled.len
		if !disabled[idx] {
			return idx
		}
	}
	return -1
}

fn tab_prev_enabled_index(disabled []bool, selected_idx int) int {
	if disabled.len == 0 {
		return -1
	}
	mut idx := if selected_idx < 0 || selected_idx >= disabled.len {
		0
	} else {
		selected_idx
	}
	for _ in 0 .. disabled.len {
		idx = (idx - 1 + disabled.len) % disabled.len
		if !disabled[idx] {
			return idx
		}
	}
	return -1
}

fn tab_button_id(control_id string, tab_id string) string {
	return '${control_id}:tab:${tab_id}'
}

fn tab_warn_duplicate_ids(control_id string, items []TabItemCfg) {
	mut seen := map[string]bool{}
	for item in items {
		if item.id.len == 0 {
			log.warn('tab_control("${control_id}") has an item with empty id')
			continue
		}
		if item.id in seen {
			log.warn('tab_control("${control_id}") duplicate tab id "${item.id}"')
			continue
		}
		seen[item.id] = true
	}
}
