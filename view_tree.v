module gui

// TreeCfg configures a [tree](#tree). In a tree view, hierarchical data is presented as
// nodes in a tree-like format.The `indent` property controls the the amount each subtree
// is indented. The `spacing` property controls the space between nodes. The `icon` property
// configures the font used to display icons in a [TreeNodeCfg](#TreeNodeCfg)
@[heap]
pub struct TreeCfg {
pub:
	id        string @[required]
	indent    f32                     = gui_theme.tree_style.indent
	spacing   f32                     = gui_theme.tree_style.spacing
	on_select fn (string, mut Window) = unsafe { nil }
	nodes     []TreeNodeCfg
pub mut:
	window Window @[required]
}

// tree creates a tree view from the given [TreeCfg](#TreeCfg)
pub fn tree(cfg TreeCfg) View {
	mut content := []View{}
	for node in cfg.nodes {
		content << cfg.node_content(node)
	}
	return column(
		padding: padding_none
		spacing: cfg.spacing
		content: content
	)
}

// TreeNodeCfg confgures a [tree_node](#tree_node). Use gui.icon_xxx to specify a
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
// It's only advantage is it allows defining a TreeNodeCfg in a single
// line, where as `TextNodeCfg{}` will format across multiple lines.
pub fn tree_node(cfg TreeNodeCfg) TreeNodeCfg {
	return cfg
}

fn (cfg &TreeCfg) build_nodes(nodes []TreeNodeCfg) []View {
	mut tnodes := []View{}
	for node in nodes {
		tnodes << column(
			id:      node.id
			padding: padding_none
			spacing: cfg.spacing
			content: cfg.node_content(node)
		)
	}
	return tnodes
}

fn (cfg &TreeCfg) node_content(node TreeNodeCfg) []View {
	id := if node.id.len == 0 { node.text } else { node.id }
	is_open := cfg.window.view_state.tree_state[cfg.id][id]
	arrow := match true {
		node.nodes.len == 0 { ' ' }
		is_open { icon_drop_down }
		else { icon_drop_right }
	}
	// caching requires window and cfg to be mutable.
	min_width_icon := get_text_width_no_cache('${icon_bar} ', node.text_style_icon, cfg.window)

	mut content := []View{}
	content << row(
		spacing:  0
		padding:  padding_none
		content:  [
			// arrow
			text(
				text:       '${arrow} '
				min_width:  min_width_icon
				text_style: node.text_style_icon
			),
			// text content
			row(
				spacing: 0
				padding: padding_none
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
		on_click: fn [cfg, is_open, node, id] (_ &ContainerCfg, mut e Event, mut w Window) {
			if node.nodes.len > 0 {
				w.view_state.tree_state[cfg.id][id] = !is_open
			}
			if cfg.on_select != unsafe { nil } {
				cfg.on_select(id, mut w)
				e.is_handled = true
			}
		}
		on_hover: fn (mut node Layout, mut e Event, mut w Window) {
			w.set_mouse_cursor_pointing_hand()
		}
	)
	// child nodes
	if is_open {
		content << column(
			spacing: cfg.spacing
			padding: Padding{
				left: cfg.indent
			}
			content: cfg.build_nodes(node.nodes)
		)
	}
	return content
}
