module gui

import log

// BreadcrumbItemCfg configures one item in a [breadcrumb](#breadcrumb).
@[minify]
pub struct BreadcrumbItemCfg {
pub:
	id       string @[required]
	label    string @[required]
	icon     string
	content  []View
	disabled bool
}

// breadcrumb_item is a helper to build [BreadcrumbItemCfg](#BreadcrumbItemCfg) values.
pub fn breadcrumb_item(id string, label string, content []View) BreadcrumbItemCfg {
	return BreadcrumbItemCfg{
		id:      id
		label:   label
		content: content
	}
}

// BreadcrumbCfg configures a [breadcrumb](#breadcrumb).
// Controlled component: `selected` is owned by app state and updated
// through `on_select`.
@[minify]
pub struct BreadcrumbCfg {
pub:
	id                   string              @[required]
	items                []BreadcrumbItemCfg @[required]
	selected             string
	on_select            fn (string, mut Event, mut Window) @[required]
	separator            string    = gui_theme.breadcrumb_style.separator
	sizing               Sizing    = fill_fit
	color                Color     = gui_theme.breadcrumb_style.color
	color_border         Color     = gui_theme.breadcrumb_style.color_border
	color_trail          Color     = gui_theme.breadcrumb_style.color_trail
	color_crumb          Color     = gui_theme.breadcrumb_style.color_crumb
	color_crumb_hover    Color     = gui_theme.breadcrumb_style.color_crumb_hover
	color_crumb_click    Color     = gui_theme.breadcrumb_style.color_crumb_click
	color_crumb_selected Color     = gui_theme.breadcrumb_style.color_crumb_selected
	color_crumb_disabled Color     = gui_theme.breadcrumb_style.color_crumb_disabled
	color_content        Color     = gui_theme.breadcrumb_style.color_content
	color_content_border Color     = gui_theme.breadcrumb_style.color_content_border
	padding              Padding   = gui_theme.breadcrumb_style.padding
	padding_trail        Padding   = gui_theme.breadcrumb_style.padding_trail
	padding_crumb        Padding   = gui_theme.breadcrumb_style.padding_crumb
	padding_content      Padding   = gui_theme.breadcrumb_style.padding_content
	radius               f32       = gui_theme.breadcrumb_style.radius
	radius_crumb         f32       = gui_theme.breadcrumb_style.radius_crumb
	radius_content       f32       = gui_theme.breadcrumb_style.radius_content
	spacing              f32       = gui_theme.breadcrumb_style.spacing
	spacing_trail        f32       = gui_theme.breadcrumb_style.spacing_trail
	size_border          f32       = gui_theme.breadcrumb_style.size_border
	size_content_border  f32       = gui_theme.breadcrumb_style.size_content_border
	text_style           TextStyle = gui_theme.breadcrumb_style.text_style
	text_style_selected  TextStyle = gui_theme.breadcrumb_style.text_style_selected
	text_style_disabled  TextStyle = gui_theme.breadcrumb_style.text_style_disabled
	text_style_separator TextStyle = gui_theme.breadcrumb_style.text_style_separator
	text_style_icon      TextStyle = gui_theme.breadcrumb_style.text_style_icon
	id_focus             u32
	disabled             bool
	invisible            bool
	a11y_label           string // override label for screen readers
	a11y_description     string // extended help text
}

// breadcrumb creates a breadcrumb navigation control.
//
// Each item can optionally carry content views; when present, the
// active item's content is displayed below the trail.
//
// Keyboard behavior (when focused):
// - Left: previous enabled item
// - Right: next enabled item
// - Home/End: first/last enabled item
// - Enter/Space: re-fire on_select for current item
pub fn breadcrumb(cfg BreadcrumbCfg) View {
	$if !prod {
		bc_warn_duplicate_ids(cfg.id, cfg.items)
	}
	selected_idx := bc_selected_index(cfg.items, cfg.selected)

	mut trail_items := []View{cap: cfg.items.len * 2}
	has_content := bc_has_any_content(cfg.items)

	for i, item in cfg.items {
		if i > 0 {
			trail_items << text(
				text:       cfg.separator
				text_style: cfg.text_style_separator
			)
		}

		is_selected := i == selected_idx
		is_disabled := cfg.disabled || item.disabled
		ts := if is_disabled {
			cfg.text_style_disabled
		} else if is_selected {
			cfg.text_style_selected
		} else {
			cfg.text_style
		}
		crumb_color := if is_disabled {
			cfg.color_crumb_disabled
		} else if is_selected {
			cfg.color_crumb_selected
		} else {
			cfg.color_crumb
		}

		mut crumb_content := []View{cap: 2}
		if item.icon.len > 0 {
			crumb_content << text(
				text:       item.icon
				text_style: cfg.text_style_icon
			)
		}
		crumb_content << text(
			text:       item.label
			text_style: ts
		)

		hover_color := if is_disabled {
			cfg.color_crumb_disabled
		} else if is_selected {
			cfg.color_crumb_selected
		} else {
			cfg.color_crumb_hover
		}
		click_color := if is_disabled {
			cfg.color_crumb_disabled
		} else if is_selected {
			cfg.color_crumb_selected
		} else {
			cfg.color_crumb_click
		}

		on_click_fn := if is_disabled {
			unsafe { nil }
		} else {
			make_bc_on_click(cfg.on_select, item.id, cfg.id_focus)
		}
		on_hover_fn := if is_disabled {
			unsafe { nil }
		} else {
			make_bc_on_hover(hover_color, click_color)
		}

		trail_items << row(
			id:       bc_crumb_id(cfg.id, item.id)
			color:    crumb_color
			padding:  cfg.padding_crumb
			radius:   cfg.radius_crumb
			disabled: is_disabled
			on_click: on_click_fn
			on_hover: on_hover_fn
			spacing:  cfg.spacing_trail
			content:  crumb_content
		)
	}

	mut outer_content := []View{cap: 2}
	outer_content << row(
		name:    'breadcrumb_trail'
		color:   cfg.color_trail
		padding: cfg.padding_trail
		spacing: cfg.spacing_trail
		sizing:  fill_fit
		v_align: .middle
		content: trail_items
	)

	if has_content && selected_idx >= 0 && selected_idx < cfg.items.len {
		active_content := cfg.items[selected_idx].content.clone()
		outer_content << column(
			name:         'breadcrumb_content'
			color:        cfg.color_content
			color_border: cfg.color_content_border
			size_border:  cfg.size_content_border
			radius:       cfg.radius_content
			padding:      cfg.padding_content
			sizing:       fill_fill
			content:      active_content
		)
	}

	// Extract fields for closure capture (avoid capturing full cfg).
	disabled := cfg.disabled
	items := cfg.items
	selected := cfg.selected
	on_select := cfg.on_select
	id_focus := cfg.id_focus

	return column(
		name:             'breadcrumb'
		id:               cfg.id
		id_focus:         cfg.id_focus
		a11y_role:        .toolbar
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
		on_keydown:       fn [disabled, items, selected, on_select, id_focus] (_ &Layout, mut e Event, mut w Window) {
			bc_on_keydown(disabled, items, selected, on_select, id_focus, mut e, mut w)
		}
		content:          outer_content
	)
}

fn make_bc_on_click(on_select fn (string, mut Event, mut Window), id string, id_focus u32) fn (&Layout, mut Event, mut Window) {
	return fn [on_select, id, id_focus] (_ &Layout, mut e Event, mut w Window) {
		on_select(id, mut e, mut w)
		if id_focus > 0 {
			w.set_id_focus(id_focus)
		}
		e.is_handled = true
	}
}

fn make_bc_on_hover(hover_color Color, click_color Color) fn (mut Layout, mut Event, mut Window) {
	return fn [hover_color, click_color] (mut layout Layout, mut e Event, mut w Window) {
		if layout.shape.disabled || !layout.shape.has_events()
			|| layout.shape.events.on_click == unsafe { nil } {
			return
		}
		w.set_mouse_cursor_pointing_hand()
		layout.shape.color = hover_color
		if e.mouse_button == .left {
			layout.shape.color = click_color
		}
	}
}

fn bc_on_keydown(disabled bool, items []BreadcrumbItemCfg, selected string, on_select fn (string, mut Event, mut Window), id_focus u32, mut e Event, mut w Window) {
	if disabled || items.len == 0 || e.modifiers != .none {
		return
	}

	selected_idx := bc_selected_index(items, selected)
	mut target_idx := -1
	match e.key_code {
		.left {
			target_idx = if selected_idx >= 0 {
				bc_prev_enabled_index(items, selected_idx)
			} else {
				bc_last_enabled_index(items)
			}
		}
		.right {
			target_idx = if selected_idx >= 0 {
				bc_next_enabled_index(items, selected_idx)
			} else {
				bc_first_enabled_index(items)
			}
		}
		.home {
			target_idx = bc_first_enabled_index(items)
		}
		.end {
			target_idx = bc_last_enabled_index(items)
		}
		.enter, .space {
			target_idx = if selected_idx >= 0 {
				selected_idx
			} else {
				bc_first_enabled_index(items)
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

	if target_id != selected || e.key_code in [.enter, .space] {
		on_select(target_id, mut e, mut w)
	}
	if id_focus > 0 {
		w.set_id_focus(id_focus)
	}
	e.is_handled = true
}

// bc_selected_index resolves the selected index. Prefers explicit
// `selected`; falls back to last enabled item (breadcrumb convention).
fn bc_selected_index(items []BreadcrumbItemCfg, selected string) int {
	if selected.len > 0 {
		for idx, item in items {
			if item.id == selected && !item.disabled {
				return idx
			}
		}
	}
	return bc_last_enabled_index(items)
}

fn bc_first_enabled_index(items []BreadcrumbItemCfg) int {
	for idx, item in items {
		if !item.disabled {
			return idx
		}
	}
	return -1
}

fn bc_last_enabled_index(items []BreadcrumbItemCfg) int {
	for i := items.len - 1; i >= 0; i-- {
		if !items[i].disabled {
			return i
		}
	}
	return -1
}

fn bc_next_enabled_index(items []BreadcrumbItemCfg, selected_idx int) int {
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

fn bc_prev_enabled_index(items []BreadcrumbItemCfg, selected_idx int) int {
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

fn bc_crumb_id(control_id string, item_id string) string {
	return '${control_id}:crumb:${item_id}'
}

fn bc_has_any_content(items []BreadcrumbItemCfg) bool {
	for item in items {
		if item.content.len > 0 {
			return true
		}
	}
	return false
}

fn bc_warn_duplicate_ids(control_id string, items []BreadcrumbItemCfg) {
	mut seen := map[string]bool{}
	for item in items {
		if item.id.len == 0 {
			log.warn('breadcrumb("${control_id}") has an item with empty id')
			continue
		}
		if item.id in seen {
			log.warn('breadcrumb("${control_id}") duplicate item id "${item.id}"')
			continue
		}
		seen[item.id] = true
	}
}
