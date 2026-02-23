module gui

// list_core.v provides pure functions shared by list_box, select,
// combobox, and command_palette. No state, no Window dependency.

// ListCoreItem is the normalized item for the shared list engine.
// Widgets map their domain types to this before calling core fns.
@[minify]
struct ListCoreItem {
	id            string
	label         string // primary display text
	detail        string // secondary (shortcut hint, value)
	icon          string
	group         string // category header text
	disabled      bool
	is_subheading bool
}

// ListCoreCfg configures list_core_views rendering.
@[minify]
struct ListCoreCfg {
	text_style       TextStyle
	detail_style     TextStyle
	subheading_style TextStyle
	color_highlight  Color
	color_hover      Color
	color_selected   Color
	padding_item     Padding
	show_details     bool
	show_icons       bool
	on_item_click    fn (string, int, mut Event, mut Window) = unsafe { nil }
	on_item_hover    fn (int, mut Event, mut Window)         = unsafe { nil }
}

enum ListCoreAction as u8 {
	none
	move_up
	move_down
	select_item
	dismiss
	first
	last
}

// list_core_views builds visible item views with virtualization
// spacers. first/last are indices from list_core_visible_range.
fn list_core_views(items []ListCoreItem, cfg ListCoreCfg, first int, last int, highlighted int, selected_ids []string, row_height f32) []View {
	total := items.len
	cap := if last >= first { last - first + 3 } else { 2 }
	mut views := []View{cap: cap}

	if first > 0 && row_height > 0 {
		views << rectangle(
			name:   'lc spacer top'
			color:  color_transparent
			height: f32(first) * row_height
			sizing: fill_fixed
		)
	}

	for idx in first .. last + 1 {
		if idx < 0 || idx >= total {
			continue
		}
		is_hl := idx == highlighted
		is_sel := items[idx].id in selected_ids
		views << list_core_item_view(items[idx], idx, is_hl, is_sel, cfg)
	}

	if last < total - 1 && row_height > 0 {
		remaining := total - 1 - last
		views << rectangle(
			name:   'lc spacer bottom'
			color:  color_transparent
			height: f32(remaining) * row_height
			sizing: fill_fixed
		)
	}
	return views
}

// list_core_item_view renders a single item row.
fn list_core_item_view(item ListCoreItem, index int, is_highlighted bool, is_selected bool, cfg ListCoreCfg) View {
	bg := if is_highlighted {
		cfg.color_highlight
	} else if is_selected {
		cfg.color_selected
	} else {
		color_transparent
	}

	if item.is_subheading {
		return list_core_subheading_view(item, cfg)
	}

	mut content := []View{cap: 3}

	if cfg.show_icons && item.icon.len > 0 {
		content << text(
			text:       item.icon
			text_style: TextStyle{
				...cfg.text_style
				family: font_file_icon
			}
		)
	}

	content << text(
		text:       item.label
		text_style: cfg.text_style
		mode:       .single_line
	)

	if cfg.show_details && item.detail.len > 0 {
		content << row(
			name:    'lc detail spacer'
			sizing:  fill_fill
			padding: padding_none
		)
		content << text(
			text:       item.detail
			text_style: cfg.detail_style
			mode:       .single_line
		)
	}

	item_id := item.id
	on_click := cfg.on_item_click
	on_hover := cfg.on_item_hover
	has_click := on_click != unsafe { nil }
	has_hover := on_hover != unsafe { nil }
	color_hover := cfg.color_hover
	is_disabled := item.disabled

	return row(
		name:     'lc item'
		color:    bg
		padding:  cfg.padding_item
		sizing:   fill_fit
		content:  content
		on_click: fn [has_click, on_click, item_id, index, is_disabled] (_ voidptr, mut e Event, mut w Window) {
			if has_click && !is_disabled {
				on_click(item_id, index, mut e, mut w)
			}
		}
		on_hover: fn [has_hover, on_hover, color_hover, index, is_disabled] (mut layout Layout, mut e Event, mut w Window) {
			if !is_disabled {
				w.set_mouse_cursor_pointing_hand()
				if layout.shape.color == color_transparent {
					layout.shape.color = color_hover
				}
			}
			if has_hover {
				on_hover(index, mut e, mut w)
			}
		}
	)
}

// list_core_subheading_view renders a subheading row.
fn list_core_subheading_view(item ListCoreItem, cfg ListCoreCfg) View {
	return column(
		spacing: 1
		padding: padding_none
		sizing:  fill_fit
		content: [
			text(
				text:       item.label
				text_style: cfg.subheading_style
			),
			row(
				padding: padding_none
				sizing:  fill_fit
				content: [
					rectangle(
						width:  1
						height: 1
						sizing: fill_fit
						color:  cfg.subheading_style.color
					),
				]
			),
		]
	)
}

// list_core_visible_range computes the visible index range from
// scroll offset. Pure arithmetic.
fn list_core_visible_range(item_count int, row_height f32, list_height f32, scroll_y f32) (int, int) {
	if item_count == 0 || row_height <= 0 || list_height <= 0 {
		return 0, -1
	}
	max_idx := item_count - 1
	abs_scroll := if scroll_y < 0 { -scroll_y } else { scroll_y }
	first := int_clamp(int(abs_scroll / row_height), 0, max_idx)
	visible_rows := int(list_height / row_height) + 1
	buf := list_box_virtual_buffer_rows
	first_visible := int_max(0, first - buf)
	mut last_visible := int_min(max_idx, first + visible_rows + buf)
	if first_visible > last_visible {
		last_visible = first_visible
	}
	return first_visible, last_visible
}

// list_core_navigate maps a key code to a list navigation action.
fn list_core_navigate(key KeyCode, item_count int, current int) ListCoreAction {
	if item_count == 0 {
		return .none
	}
	return match key {
		.up { .move_up }
		.down { .move_down }
		.enter { .select_item }
		.escape { .dismiss }
		.home { .first }
		.end { .last }
		else { .none }
	}
}

// list_core_fuzzy_score scores a candidate against a query.
// Returns -1 (no match) or 0+ (lower = better). Zero-alloc,
// raw byte walking.
fn list_core_fuzzy_score(candidate string, query string) int {
	if query.len == 0 {
		return 0
	}
	if candidate.len == 0 {
		return -1
	}
	mut qi := 0
	mut score := 0
	mut prev_match := -1
	for ci in 0 .. candidate.len {
		if qi >= query.len {
			break
		}
		cb := to_lower_byte(candidate[ci])
		qb := to_lower_byte(query[qi])
		if cb == qb {
			if prev_match >= 0 {
				gap := ci - prev_match - 1
				score += gap
			}
			prev_match = ci
			qi++
		}
	}
	if qi < query.len {
		return -1
	}
	return score
}

// to_lower_byte converts ASCII uppercase to lowercase.
@[inline]
fn to_lower_byte(b u8) u8 {
	if b >= 0x41 && b <= 0x5A {
		return b + 32
	}
	return b
}

// list_core_filter filters + ranks items by query. Returns
// indices sorted by score. Empty query returns all in order.
fn list_core_filter(items []ListCoreItem, query string) []int {
	if query.len == 0 {
		mut all := []int{cap: items.len}
		for i in 0 .. items.len {
			all << i
		}
		return all
	}
	mut scored := []ListCoreScored{cap: items.len}
	for i, item in items {
		if item.is_subheading {
			continue
		}
		s := list_core_fuzzy_score(item.label, query)
		if s >= 0 {
			scored << ListCoreScored{
				index: i
				score: s
			}
		}
	}
	scored.sort(a.score < b.score)
	mut result := []int{cap: scored.len}
	for sc in scored {
		result << sc.index
	}
	return result
}

struct ListCoreScored {
	index int
	score int
}

// list_core_row_height_estimate estimates row height from text
// style + padding. No Window needed.
fn list_core_row_height_estimate(style TextStyle, pad Padding) f32 {
	return style.size + pad.height()
}
