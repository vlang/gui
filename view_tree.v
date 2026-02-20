module gui

// TreeCfg configures a [tree](#tree). In a tree view, hierarchical data is presented as
// nodes in a tree-like format. The `indent` property controls the amount each subtree
// is indented. The `spacing` property controls the space between nodes. The `icon` property
// configures the font used to display icons in a [TreeNodeCfg](#TreeNodeCfg)
@[minify]
pub struct TreeCfg {
	A11yCfg
pub:
	id        string @[required]
	on_select fn (string, mut Window) = unsafe { nil }
	nodes     []TreeNodeCfg
	indent    f32 = gui_theme.tree_style.indent
	spacing   f32 = gui_theme.tree_style.spacing
	id_focus  u32
}

// tree creates a tree view from the given [TreeCfg](#TreeCfg)
pub fn (mut window Window) tree(cfg TreeCfg) View {
	// Optimization: Fetch the tree state map once at the top level to avoid
	// repeated lookups for every node in the recursive build process.
	tree_map := window.view_state.tree_state.get(cfg.id) or {
		map[string]bool{}
	}

	mut content := []View{cap: cfg.nodes.len}
	for node in cfg.nodes {
		content << cfg.node_content(node, tree_map, mut window)
	}
	// Build flat visible-node list for keyboard nav
	mut visible_ids := []string{cap: cfg.nodes.len * 2}
	tree_collect_visible(cfg.nodes, tree_map, mut visible_ids)

	cfg_id := cfg.id
	on_select := cfg.on_select
	return column(
		name:             'tree'
		a11y_role:        .tree
		a11y_label:       a11y_label(cfg.a11y_label, cfg.id)
		a11y_description: cfg.a11y_description
		id_focus:         cfg.id_focus
		padding:          padding_none
		spacing:          cfg.spacing
		on_keydown:       fn [cfg_id, on_select, visible_ids] (_ &Layout, mut e Event, mut w Window) {
			tree_on_keydown(cfg_id, on_select, visible_ids, mut e, mut w)
		}
		content:          content
	)
}

// TreeNodeCfg configures a [tree_node](#tree_node). Use gui.icon_xxx to specify a
// font from the standard icon catalog. The `id` property is optional and defaults
// to the text value.
pub struct TreeNodeCfg {
pub:
	id              string
	text            string
	icon            string
	text_style      TextStyle = gui_theme.tree_style.text_style
	text_style_icon TextStyle = gui_theme.tree_style.text_style_icon
	nodes           []TreeNodeCfg
}

// tree_node is a helper method to define a [TreeNodeCfg](#TreeNodeCfg).
// Its only advantage is it allows defining a TreeNodeCfg in a single
// line, whereas `TextNodeCfg{}` will format across multiple lines.
pub fn tree_node(cfg TreeNodeCfg) TreeNodeCfg {
	return cfg
}

fn (cfg &TreeCfg) build_nodes(nodes []TreeNodeCfg, tree_map map[string]bool, mut window Window) []View {
	mut tnodes := []View{cap: nodes.len}

	for node in nodes {
		tnodes << column(
			name:    'tree node'
			id:      node.id
			padding: padding_none
			spacing: cfg.spacing
			content: cfg.node_content(node, tree_map, mut window)
		)
	}
	return tnodes
}

fn (cfg &TreeCfg) node_content(node TreeNodeCfg, tree_map map[string]bool, mut window Window) []View {
	id := if node.id.len == 0 { node.text } else { node.id }
	is_open := tree_map[id]
	arrow := match true {
		node.nodes.len == 0 {
			' '
		}
		is_open {
			icon_drop_down
		}
		else {
			if gui_locale.text_dir == .rtl { icon_drop_left } else { icon_drop_right }
		}
	}
	min_width_icon := text_width('${icon_bar} ', node.text_style_icon, mut window)

	mut content := []View{cap: 2}
	cfg_id := cfg.id
	on_select := cfg.on_select

	// Capture only what's needed for the closure to reduce allocation
	has_children := node.nodes.len > 0

	node_a11y_state := if is_open && has_children {
		AccessState.expanded
	} else {
		AccessState.none
	}
	content << row(
		name:       'tree node content'
		a11y_role:  .tree_item
		a11y_label: node.text
		a11y_state: node_a11y_state
		spacing:    0
		padding:    padding_none
		content:    [
			// arrow
			text(
				text:       '${arrow} '
				min_width:  min_width_icon
				text_style: node.text_style_icon
			),
			// text content
			row(
				name:    'tree node text'
				spacing: 0
				padding: pad_tblr(1, 5)
				content: [
					text(
						text:       '${node.icon} '
						min_width:  min_width_icon
						text_style: node.text_style_icon
					),
					text(text: node.text, text_style: node.text_style),
				]
			),
		]
		on_click:   fn [cfg_id, on_select, is_open, has_children, id] (_ &Layout, mut e Event, mut w Window) {
			if has_children {
				mut tree_map := w.view_state.tree_state.get(cfg_id) or {
					map[string]bool{}
				}
				tree_map[id] = !is_open
				w.view_state.tree_state.set(cfg_id, tree_map)
			}
			if on_select != unsafe { nil } {
				on_select(id, mut w)
				e.is_handled = true
			}
		}
		on_hover:   fn (mut layout Layout, mut e Event, mut w Window) {
			w.set_mouse_cursor_pointing_hand()
			for mut child in layout.children {
				child.shape.color = gui_theme.color_hover
			}
		}
	)
	// child nodes
	if is_open {
		content << column(
			spacing: cfg.spacing
			padding: Padding{
				left: cfg.indent
			}
			content: cfg.build_nodes(node.nodes, tree_map, mut window)
		)
	}
	return content
}

// tree_collect_visible builds a flat list of visible node IDs.
fn tree_collect_visible(nodes []TreeNodeCfg, tree_map map[string]bool, mut out []string) {
	for node in nodes {
		id := if node.id.len == 0 { node.text } else { node.id }
		out << id
		if tree_map[id] {
			tree_collect_visible(node.nodes, tree_map, mut out)
		}
	}
}

// tree_find_node_parent returns the parent ID of node_id,
// or empty string if it is a root node.
fn tree_find_node_parent(nodes []TreeNodeCfg, node_id string, parent_id string) string {
	for node in nodes {
		id := if node.id.len == 0 { node.text } else { node.id }
		if id == node_id {
			return parent_id
		}
		result := tree_find_node_parent(node.nodes, node_id, id)
		if result.len > 0 || (result.len == 0 && node.nodes.any((if it.id.len == 0 {
			it.text
		} else {
			it.id
		}) == node_id)) {
			return id
		}
	}
	return ''
}

// tree_node_has_children checks if the given node_id has children.
fn tree_node_has_children(nodes []TreeNodeCfg, node_id string) bool {
	for node in nodes {
		id := if node.id.len == 0 { node.text } else { node.id }
		if id == node_id {
			return node.nodes.len > 0
		}
		if tree_node_has_children(node.nodes, node_id) {
			return true
		}
	}
	return false
}

// tree_on_keydown handles keyboard navigation for the tree.
fn tree_on_keydown(cfg_id string, on_select fn (string, mut Window), visible_ids []string, mut e Event, mut w Window) {
	if visible_ids.len == 0 {
		return
	}
	focused := w.view_state.tree_focus.get(cfg_id) or { '' }
	cur_idx := visible_ids.index(focused)

	match e.key_code {
		.up {
			next := if cur_idx > 0 { cur_idx - 1 } else { 0 }
			w.view_state.tree_focus.set(cfg_id, visible_ids[next])
			w.update_window()
			e.is_handled = true
		}
		.down {
			next := if cur_idx < visible_ids.len - 1 {
				cur_idx + 1
			} else {
				visible_ids.len - 1
			}
			w.view_state.tree_focus.set(cfg_id, visible_ids[next])
			w.update_window()
			e.is_handled = true
		}
		.left {
			if cur_idx >= 0 {
				mut tree_map := w.view_state.tree_state.get(cfg_id) or {
					map[string]bool{}
				}
				if tree_map[focused] {
					// Collapse current node
					tree_map[focused] = false
					w.view_state.tree_state.set(cfg_id, tree_map)
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
					// Expand current node
					tree_map[focused] = true
					w.view_state.tree_state.set(cfg_id, tree_map)
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
			w.view_state.tree_focus.set(cfg_id, visible_ids[0])
			w.update_window()
			e.is_handled = true
		}
		.end {
			w.view_state.tree_focus.set(cfg_id, visible_ids.last())
			w.update_window()
			e.is_handled = true
		}
		else {}
	}
}
