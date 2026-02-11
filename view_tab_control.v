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
@[heap; minify]
pub struct TabControlCfg {
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
}

// tabs is an alias for [tab_control](#tab_control).
pub fn tabs(cfg TabControlCfg) View {
	return tab_control(cfg)
}

// tab_control creates a tab control with a header row and active content area.
//
// Keyboard behavior (when focused):
// - Left/Up: previous enabled tab
// - Right/Down: next enabled tab
// - Home/End: first/last enabled tab
pub fn tab_control(cfg TabControlCfg) View {
	$if !prod {
		tab_warn_duplicate_ids(cfg.id, cfg.items)
	}
	selected_idx := tab_selected_index(cfg.items, cfg.selected)

	mut header_items := []View{cap: cfg.items.len}
	for i, item in cfg.items {
		is_selected := i == selected_idx
		is_disabled := cfg.disabled || item.disabled
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
		header_items << button(
			id:                 tab_button_id(cfg.id, item.id)
			color:              tab_color
			color_hover:        hover_color
			color_focus:        focus_color
			color_click:        click_color
			color_border:       border_color
			color_border_focus: cfg.color_tab_border_focus
			padding:            cfg.padding_tab
			size_border:        cfg.size_tab_border
			radius:             cfg.radius_tab
			radius_border:      cfg.radius_tab_border
			disabled:           is_disabled
			on_click:           make_tab_on_click(cfg.on_select, item.id, cfg.id_focus)
			content:            [
				text(
					text:       item.label
					text_style: ts
				),
			]
		)
	}

	mut active_content := []View{}
	if selected_idx >= 0 && selected_idx < cfg.items.len {
		active_content = cfg.items[selected_idx].content.clone()
	}

	// Extract only the fields needed by the keydown closure
	// to avoid capturing the entire TabControlCfg struct
	// (conservative GC false retention).
	disabled := cfg.disabled
	items := cfg.items
	selected := cfg.selected
	on_select := cfg.on_select
	id_focus := cfg.id_focus

	return column(
		name:         'tab_control'
		id:           cfg.id
		id_focus:     cfg.id_focus
		sizing:       cfg.sizing
		color:        cfg.color
		color_border: cfg.color_border
		size_border:  cfg.size_border
		radius:       cfg.radius
		padding:      cfg.padding
		spacing:      cfg.spacing
		disabled:     cfg.disabled
		invisible:    cfg.invisible
		on_keydown:   fn [disabled, items, selected, on_select, id_focus] (_ &Layout, mut e Event, mut w Window) {
			tab_control_on_keydown(disabled, items, selected, on_select, id_focus, mut
				e, mut w)
		}
		content:      [
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

fn tab_control_on_keydown(disabled bool, items []TabItemCfg, selected string, on_select fn (string, mut Event, mut Window), id_focus u32, mut e Event, mut w Window) {
	if disabled || items.len == 0 || e.modifiers != .none {
		return
	}

	selected_idx := tab_selected_index(items, selected)
	mut target_idx := -1
	match e.key_code {
		.left, .up {
			target_idx = if selected_idx >= 0 {
				tab_prev_enabled_index(items, selected_idx)
			} else {
				tab_last_enabled_index(items)
			}
		}
		.right, .down {
			target_idx = if selected_idx >= 0 {
				tab_next_enabled_index(items, selected_idx)
			} else {
				tab_first_enabled_index(items)
			}
		}
		.home {
			target_idx = tab_first_enabled_index(items)
		}
		.end {
			target_idx = tab_last_enabled_index(items)
		}
		.enter, .space {
			target_idx = if selected_idx >= 0 {
				selected_idx
			} else {
				tab_first_enabled_index(items)
			}
		}
		else {
			return
		}
	}

	if target_idx < 0 || target_idx >= items.len {
		return
	}

	target_id := items[target_idx].id
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

fn tab_selected_index(items []TabItemCfg, selected string) int {
	if selected.len > 0 {
		for idx, item in items {
			if item.id == selected && !item.disabled {
				return idx
			}
		}
	}
	return tab_first_enabled_index(items)
}

fn tab_first_enabled_index(items []TabItemCfg) int {
	for idx, item in items {
		if !item.disabled {
			return idx
		}
	}
	return -1
}

fn tab_last_enabled_index(items []TabItemCfg) int {
	for i := items.len - 1; i >= 0; i-- {
		if !items[i].disabled {
			return i
		}
	}
	return -1
}

fn tab_next_enabled_index(items []TabItemCfg, selected_idx int) int {
	if items.len == 0 {
		return -1
	}
	mut idx := if selected_idx < 0 || selected_idx >= items.len {
		-1
	} else {
		selected_idx
	}
	for _ in 0 .. items.len {
		idx = (idx + 1 + items.len) % items.len
		if !items[idx].disabled {
			return idx
		}
	}
	return -1
}

fn tab_prev_enabled_index(items []TabItemCfg, selected_idx int) int {
	if items.len == 0 {
		return -1
	}
	mut idx := if selected_idx < 0 || selected_idx >= items.len {
		0
	} else {
		selected_idx
	}
	for _ in 0 .. items.len {
		idx = (idx - 1 + items.len) % items.len
		if !items[idx].disabled {
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
