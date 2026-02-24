module gui

const tree_virtual_buffer_rows = 2

// TreeCfg configures a [tree](#tree). Hierarchical data is presented
// as nodes in a tree-like format. The `indent` property controls the
// amount each subtree is indented. The `spacing` property controls
// the space between nodes.
//
// Virtualization is enabled when `id_scroll > 0` and a bounded
// height (`height` or `max_height`) is set.
//
// Lazy loading is supported via `on_lazy_load` and the `lazy` flag
// on individual [TreeNodeCfg](#TreeNodeCfg) nodes.
@[minify]
pub struct TreeCfg {
	A11yCfg
pub:
	id           string @[required]
	on_select    fn (string, mut Window)         = unsafe { nil }
	on_lazy_load fn (string, string, mut Window) = unsafe { nil }
	nodes        []TreeNodeCfg
	indent       f32 = gui_theme.tree_style.indent
	spacing      f32 = gui_theme.tree_style.spacing
	id_focus     u32
	id_scroll    u32
	height       f32
	max_height   f32
	reorderable  bool
	on_reorder   fn (string, string, mut Window) = unsafe { nil }
}

// TreeNodeCfg configures a [tree_node](#tree_node). Use gui.icon_xxx
// to specify a font from the standard icon catalog. The `id` property
// is optional and defaults to the text value.
//
// Set `lazy: true` on nodes whose children are loaded on demand.
// When expanded and `nodes.len == 0`, the tree shows a loading
// indicator and fires `on_lazy_load`.
pub struct TreeNodeCfg {
pub:
	id              string
	text            string
	icon            string
	text_style      TextStyle = gui_theme.tree_style.text_style
	text_style_icon TextStyle = gui_theme.tree_style.text_style_icon
	nodes           []TreeNodeCfg
	lazy            bool
}

// tree_node is a helper to define a [TreeNodeCfg](#TreeNodeCfg).
// Allows specifying a TreeNodeCfg on a single line.
pub fn tree_node(cfg TreeNodeCfg) TreeNodeCfg {
	return cfg
}

// TreeFlatRow is a flattened representation of a single visible
// tree node, used internally for virtualization and rendering.
// All node fields are copied in to avoid pointer-to-stack issues
// and to comply with GC closure-capture rules.
struct TreeFlatRow {
	id                string
	depth             int
	text              string
	icon              string
	text_style        TextStyle
	text_style_icon   TextStyle
	has_children      bool
	has_real_children bool // nodes.len > 0 (vs lazy placeholder)
	is_lazy           bool
	is_expanded       bool
	is_loading        bool // sentinel for loading indicator rows
}

// tree creates a tree view from the given [TreeCfg](#TreeCfg).
// Uses flat-row rendering with optional spacer-based virtualization.
pub fn (mut window Window) tree(cfg TreeCfg) View {
	tree_map := window.view_state.tree_state.get(cfg.id) or {
		map[string]bool{}
	}
	cfg_id := cfg.id
	mut lazy_sm := state_map[string, bool](mut window, ns_tree_lazy, cap_tree_lazy)

	mut flat_rows := []TreeFlatRow{cap: cfg.nodes.len * 4}
	tree_collect_flat_rows(cfg.nodes, tree_map, cfg_id, mut lazy_sm, mut flat_rows, 0)

	// Build visible-node IDs for keyboard nav (skip loading sentinels).
	mut visible_ids := []string{cap: flat_rows.len}
	for fr in flat_rows {
		if !fr.is_loading {
			visible_ids << fr.id
		}
	}

	tree_height := if cfg.height > 0 { cfg.height } else { cfg.max_height }
	virtualize := cfg.id_scroll > 0 && tree_height > 0 && flat_rows.len > 0
	row_height := if virtualize {
		tree_estimate_row_height(cfg, mut window)
	} else {
		f32(0)
	}
	first_visible, last_visible := if virtualize {
		tree_visible_range(tree_height, row_height, flat_rows.len, cfg.id_scroll, mut
			window)
	} else {
		0, flat_rows.len - 1
	}

	indent := cfg.indent
	on_select := cfg.on_select
	on_lazy_load := cfg.on_lazy_load
	text_style_icon := tree_icon_style(cfg.nodes)
	min_width_icon := text_width('${icon_bar} ', text_style_icon, mut window)
	reorderable := cfg.reorderable

	drag := if reorderable {
		drag_reorder_get(mut window, cfg_id)
	} else {
		DragReorderState{}
	}
	dragging := reorderable && drag.active && !drag.cancelled

	mut content := []View{cap: (last_visible - first_visible + 1) + 4}

	if virtualize && first_visible > 0 {
		content << rectangle(
			name:   'tree spacer top'
			color:  color_transparent
			height: f32(first_visible) * row_height
			sizing: fill_fixed
		)
	}

	// Top-level (depth-0) node IDs and count for reorder indices.
	mut top_level_ids := []string{cap: cfg.nodes.len}
	for n in cfg.nodes {
		top_level_ids << n.id
	}
	top_level_count := top_level_ids.len
	on_reorder := cfg.on_reorder
	mut ghost_content := View(rectangle(RectangleCfg{}))
	mut top_idx := 0
	for idx in first_visible .. last_visible + 1 {
		if idx < 0 || idx >= flat_rows.len {
			continue
		}
		fr := flat_rows[idx]
		is_draggable := reorderable && !fr.is_loading && fr.depth == 0
		reorder_idx := top_idx

		// Insert gap spacer at current drop target.
		if dragging && is_draggable && reorder_idx == drag.current_index
			&& drag.current_index != drag.source_index {
			content << drag_reorder_gap_view(drag, .vertical)
		}

		if dragging && is_draggable && reorder_idx == drag.source_index {
			ghost_content = tree_flat_row_content(fr, indent, min_width_icon)
		} else {
			content << tree_flat_row_view(cfg_id, on_select, on_lazy_load, fr, indent,
				min_width_icon, is_draggable, on_reorder, cfg.id_scroll, reorder_idx,
				top_level_count, top_level_ids)
		}

		if fr.depth == 0 {
			top_idx += 1
		}
	}
	// Gap at end.
	if dragging && drag.current_index >= top_level_count {
		content << drag_reorder_gap_view(drag, .vertical)
	}

	if virtualize && last_visible < flat_rows.len - 1 {
		remaining := flat_rows.len - 1 - last_visible
		content << rectangle(
			name:   'tree spacer bottom'
			color:  color_transparent
			height: f32(remaining) * row_height
			sizing: fill_fixed
		)
	}

	// Append floating ghost.
	if dragging {
		content << drag_reorder_ghost_view(drag, ghost_content)
	}

	return column(
		name:             'tree'
		a11y_role:        .tree
		a11y_label:       a11y_label(cfg.a11y_label, cfg.id)
		a11y_description: cfg.a11y_description
		id_focus:         cfg.id_focus
		id_scroll:        cfg.id_scroll
		padding:          padding_none
		spacing:          cfg.spacing
		height:           cfg.height
		max_height:       cfg.max_height
		on_keydown:       fn [cfg_id, on_select, on_lazy_load, visible_ids, reorderable, on_reorder, top_level_ids] (_ &Layout, mut e Event, mut w Window) {
			tree_on_keydown(cfg_id, on_select, on_lazy_load, visible_ids, reorderable,
				on_reorder, top_level_ids, mut e, mut w)
		}
		content:          content
	)
}

// tree_icon_style returns the icon text style from the first node,
// falling back to the theme default.
fn tree_icon_style(nodes []TreeNodeCfg) TextStyle {
	if nodes.len > 0 {
		return nodes[0].text_style_icon
	}
	return gui_theme.tree_style.text_style_icon
}

// tree_lazy_key builds the composite key for the lazy state map.
fn tree_lazy_key(cfg_id string, node_id string) string {
	return '${cfg_id}\t${node_id}'
}

// tree_collect_flat_rows recursively walks the tree producing flat
// rows. Loading sentinels are emitted for expanded lazy nodes with
// no children. Completed lazy loads (nodes arrived) are auto-cleared.
fn tree_collect_flat_rows(nodes []TreeNodeCfg, tree_map map[string]bool, cfg_id string, mut lazy_sm BoundedMap[string, bool], mut out []TreeFlatRow, depth int) {
	for node in nodes {
		id := if node.id.len == 0 { node.text } else { node.id }
		is_expanded := tree_map[id]
		has_children := node.nodes.len > 0 || node.lazy
		lk := tree_lazy_key(cfg_id, id)
		is_loading := lazy_sm.get(lk) or { false }

		// Auto-clear: lazy node now has children → done loading.
		if node.lazy && node.nodes.len > 0 && is_loading {
			lazy_sm.delete(lk)
		}

		out << TreeFlatRow{
			id:                id
			depth:             depth
			text:              node.text
			icon:              node.icon
			text_style:        node.text_style
			text_style_icon:   node.text_style_icon
			has_children:      has_children
			has_real_children: node.nodes.len > 0
			is_lazy:           node.lazy
			is_expanded:       is_expanded
			is_loading:        false
		}

		if is_expanded {
			if node.nodes.len > 0 {
				tree_collect_flat_rows(node.nodes, tree_map, cfg_id, mut lazy_sm, mut
					out, depth + 1)
			} else if node.lazy && is_loading {
				// Loading sentinel row.
				out << TreeFlatRow{
					id:         '${id}.__loading__'
					depth:      depth + 1
					text:       gui_locale.str_loading
					is_loading: true
				}
			}
		}
	}
}

// tree_estimate_row_height returns the estimated height of a single
// tree row for virtualization calculations.
fn tree_estimate_row_height(cfg TreeCfg, mut window Window) f32 {
	ts := if cfg.nodes.len > 0 {
		cfg.nodes[0].text_style
	} else {
		gui_theme.tree_style.text_style
	}
	text_h := tree_font_height(ts, mut window)
	return text_h + cfg.spacing
}

fn tree_font_height(style TextStyle, mut window Window) f32 {
	if isnil(window.text_system) {
		return style.size
	}
	vg_cfg := style.to_vglyph_cfg()
	return window.text_system.font_height(vg_cfg) or { style.size }
}

// tree_visible_range computes the first and last visible flat-row
// indices for the current scroll position. Includes a buffer of
// tree_virtual_buffer_rows on each side.
fn tree_visible_range(tree_height f32, row_height f32, total_rows int, id_scroll u32, mut window Window) (int, int) {
	if total_rows == 0 || row_height <= 0 || tree_height <= 0 {
		return 0, -1
	}
	max_idx := total_rows - 1
	mut sy := state_map[u32, f32](mut window, ns_scroll_y, cap_scroll)
	scroll_y := -(sy.get(id_scroll) or { f32(0) })
	first := int_clamp(int(scroll_y / row_height), 0, max_idx)
	visible_rows := int(tree_height / row_height) + 1
	mut first_visible := int_max(0, first - tree_virtual_buffer_rows)
	last_visible := int_min(max_idx, first + visible_rows + tree_virtual_buffer_rows)
	if first_visible > last_visible {
		first_visible = last_visible
	}
	return first_visible, last_visible
}

// tree_flat_row_content builds the inner content view for ghost.
fn tree_flat_row_content(flat_row TreeFlatRow, indent f32, min_width_icon f32) View {
	arrow := tree_arrow_icon(flat_row)
	return row(
		name:    'tree node content'
		spacing: 0
		padding: padding_none
		content: [
			text(
				text:       '${arrow} '
				min_width:  min_width_icon
				text_style: flat_row.text_style_icon
			),
			row(
				name:    'tree node text'
				spacing: 0
				padding: pad_tblr(1, 5)
				content: [
					text(
						text:       '${flat_row.icon} '
						min_width:  min_width_icon
						text_style: flat_row.text_style_icon
					),
					text(text: flat_row.text, text_style: flat_row.text_style),
				]
			),
		]
	)
}

fn tree_arrow_icon(fr TreeFlatRow) string {
	return match true {
		!fr.has_children {
			' '
		}
		fr.is_expanded {
			icon_drop_down
		}
		else {
			if gui_locale.text_dir == .rtl {
				icon_drop_left
			} else {
				icon_drop_right
			}
		}
	}
}

// tree_flat_row_view produces a single View for one flat row.
fn tree_flat_row_view(cfg_id string, on_select fn (string, mut Window), on_lazy_load fn (string, string, mut Window), flat_row TreeFlatRow, indent f32, min_width_icon f32, reorderable bool, on_reorder fn (string, string, mut Window), id_scroll u32, flat_index int, flat_count int, top_level_ids []string) View {
	if flat_row.is_loading {
		return row(
			name:    'tree loading'
			spacing: 0
			padding: Padding{
				left: f32(flat_row.depth) * indent
			}
			content: [
				text(
					text:       flat_row.text
					text_style: gui_theme.tree_style.text_style
				),
			]
		)
	}

	// Extract all fields for closures (GC compliance).
	id := flat_row.id
	depth := flat_row.depth
	has_children := flat_row.has_children
	is_expanded := flat_row.is_expanded
	is_lazy := flat_row.is_lazy
	node_text := flat_row.text
	node_icon := flat_row.icon
	node_text_style := flat_row.text_style
	node_text_style_icon := flat_row.text_style_icon
	node_has_real_children := flat_row.has_real_children

	arrow := tree_arrow_icon(flat_row)

	node_a11y_state := if is_expanded && has_children {
		AccessState.expanded
	} else {
		AccessState.none
	}

	on_click_fn := if reorderable {
		make_tree_drag_click(cfg_id, id, flat_index, top_level_ids, on_reorder, id_scroll,
			on_select, on_lazy_load, is_expanded, has_children, is_lazy, node_has_real_children)
	} else {
		fn [cfg_id, on_select, on_lazy_load, is_expanded, has_children, is_lazy, node_has_real_children, id] (_ &Layout, mut e Event, mut w Window) {
			tree_row_click(cfg_id, on_select, on_lazy_load, is_expanded, has_children,
				is_lazy, node_has_real_children, id, mut e, mut w)
		}
	}

	return row(
		name:       'tree node content'
		id:         if reorderable { 'tr_${cfg_id}_${id}' } else { '' }
		a11y_role:  .tree_item
		a11y_label: node_text
		a11y_state: node_a11y_state
		spacing:    0
		padding:    Padding{
			left: f32(depth) * indent
		}
		content:    [
			text(
				text:       '${arrow} '
				min_width:  min_width_icon
				text_style: node_text_style_icon
			),
			row(
				name:    'tree node text'
				spacing: 0
				padding: pad_tblr(1, 5)
				content: [
					text(
						text:       '${node_icon} '
						min_width:  min_width_icon
						text_style: node_text_style_icon
					),
					text(text: node_text, text_style: node_text_style),
				]
			),
		]
		on_click:   on_click_fn
		on_hover:   fn (mut layout Layout, mut e Event, mut w Window) {
			w.set_mouse_cursor_pointing_hand()
			for mut child in layout.children {
				child.shape.color = gui_theme.color_hover
			}
		}
	)
}

// tree_row_click handles the normal tree row click behavior.
fn tree_row_click(cfg_id string, on_select fn (string, mut Window), on_lazy_load fn (string, string, mut Window), is_expanded bool, has_children bool, is_lazy bool, node_has_real_children bool, id string, mut e Event, mut w Window) {
	if has_children {
		mut tree_map := w.view_state.tree_state.get(cfg_id) or {
			map[string]bool{}
		}
		tree_map[id] = !is_expanded
		w.view_state.tree_state.set(cfg_id, tree_map)

		if !is_expanded && is_lazy && !node_has_real_children {
			tree_set_loading(cfg_id, id, mut w)
			if on_lazy_load != unsafe { nil } {
				on_lazy_load(cfg_id, id, mut w)
			}
		}
	}
	if on_select != unsafe { nil } {
		on_select(id, mut w)
		e.is_handled = true
	}
}

// make_tree_drag_click creates an on_click that initiates
// drag-reorder and also fires normal tree click behavior.
fn make_tree_drag_click(cfg_id string, id string,
	flat_index int, top_level_ids []string,
	on_reorder fn (string, string, mut Window),
	id_scroll u32,
	on_select fn (string, mut Window),
	on_lazy_load fn (string, string, mut Window),
	is_expanded bool, has_children bool,
	is_lazy bool, node_has_real_children bool) fn (&Layout, mut Event, mut Window) {
	return fn [cfg_id, id, flat_index, top_level_ids, on_reorder, id_scroll, on_select, on_lazy_load, is_expanded, has_children, is_lazy, node_has_real_children] (layout &Layout, mut e Event, mut w Window) {
		drag_reorder_start(cfg_id, flat_index, id, .vertical, top_level_ids, on_reorder,
			id_scroll, layout, e, mut w)
		tree_row_click(cfg_id, on_select, on_lazy_load, is_expanded, has_children, is_lazy,
			node_has_real_children, id, mut e, mut w)
	}
}

// tree_set_loading marks a node as loading in the lazy state map.
fn tree_set_loading(cfg_id string, node_id string, mut w Window) {
	mut lm := state_map[string, bool](mut w, ns_tree_lazy, cap_tree_lazy)
	lm.set(tree_lazy_key(cfg_id, node_id), true)
}

// tree_clear_loading removes a node's loading state.
fn tree_clear_loading(cfg_id string, node_id string, mut w Window) {
	mut lm := state_map[string, bool](mut w, ns_tree_lazy, cap_tree_lazy)
	lm.delete(tree_lazy_key(cfg_id, node_id))
}

// tree_on_keydown handles keyboard navigation for the tree.
fn tree_on_keydown(cfg_id string, on_select fn (string, mut Window), on_lazy_load fn (string, string, mut Window), visible_ids []string, reorderable bool, on_reorder fn (string, string, mut Window), top_level_ids []string, mut e Event, mut w Window) {
	// Escape cancels active drag.
	if reorderable && drag_reorder_escape(cfg_id, e.key_code, mut w) {
		e.is_handled = true
		return
	}
	// Alt+Up/Down keyboard reorder (top-level nodes only).
	if reorderable && on_reorder != unsafe { nil } {
		mut tf := state_map[string, string](mut w, ns_tree_focus, cap_tree_focus)
		focused := tf.get(cfg_id) or { '' }
		cur := top_level_ids.index(focused)
		if cur >= 0
			&& drag_reorder_keyboard_move(e.key_code, e.modifiers, .vertical, cur, top_level_ids, on_reorder, mut w) {
			// Update focus to follow the moved item.
			new_idx := if e.key_code == .up { cur - 1 } else { cur + 1 }
			if new_idx >= 0 && new_idx < top_level_ids.len {
				tf.set(cfg_id, top_level_ids[new_idx])
			}
			e.is_handled = true
			return
		}
	}

	if visible_ids.len == 0 {
		return
	}
	mut tf := state_map[string, string](mut w, ns_tree_focus, cap_tree_focus)
	focused := tf.get(cfg_id) or { '' }
	cur_idx := visible_ids.index(focused)

	match e.key_code {
		.up {
			next := if cur_idx > 0 { cur_idx - 1 } else { 0 }
			tf.set(cfg_id, visible_ids[next])
			w.update_window()
			e.is_handled = true
		}
		.down {
			next := if cur_idx < visible_ids.len - 1 {
				cur_idx + 1
			} else {
				visible_ids.len - 1
			}
			tf.set(cfg_id, visible_ids[next])
			w.update_window()
			e.is_handled = true
		}
		.left {
			if cur_idx >= 0 {
				mut tree_map := w.view_state.tree_state.get(cfg_id) or {
					map[string]bool{}
				}
				if tree_map[focused] {
					tree_map[focused] = false
					w.view_state.tree_state.set(cfg_id, tree_map)
					// Clear loading state on collapse.
					tree_clear_loading(cfg_id, focused, mut w)
				}
			}
			w.update_window()
			e.is_handled = true
		}
		.right {
			if cur_idx >= 0 {
				mut tree_map := w.view_state.tree_state.get(cfg_id) or {
					map[string]bool{}
				}
				if !tree_map[focused] {
					tree_map[focused] = true
					w.view_state.tree_state.set(cfg_id, tree_map)
					// Trigger lazy load on right-arrow expand.
					tree_try_lazy_load(cfg_id, focused, on_lazy_load, mut w)
				}
			}
			w.update_window()
			e.is_handled = true
		}
		.enter, .space {
			if cur_idx >= 0 && on_select != unsafe { nil } {
				on_select(focused, mut w)
			}
			e.is_handled = true
		}
		.home {
			tf.set(cfg_id, visible_ids[0])
			w.update_window()
			e.is_handled = true
		}
		.end {
			tf.set(cfg_id, visible_ids.last())
			w.update_window()
			e.is_handled = true
		}
		else {}
	}
}

// tree_try_lazy_load fires on_lazy_load for the given node if not
// already loading.
fn tree_try_lazy_load(cfg_id string, node_id string, on_lazy_load fn (string, string, mut Window), mut w Window) {
	if on_lazy_load == unsafe { nil } {
		return
	}
	lk := tree_lazy_key(cfg_id, node_id)
	lm := state_map_read[string, bool](w, ns_tree_lazy) or {
		tree_set_loading(cfg_id, node_id, mut w)
		on_lazy_load(cfg_id, node_id, mut w)
		return
	}
	if lm.get(lk) or { false } {
		return
	}
	tree_set_loading(cfg_id, node_id, mut w)
	on_lazy_load(cfg_id, node_id, mut w)
}
