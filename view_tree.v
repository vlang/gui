module gui

// TreeCfg configures a [tree](#tree). In a tree view, hierarchical data is presented as
// nodes in a tree-like format.The `indent` property controls the the amount each subtree
// is indented. The `spacing` property controls the space between nodes. The `icon` property
// configures the font used to display icons in a [TreeNodeCfg](#TreeNodeCfg)
@[minify]
pub struct TreeCfg {
pub:
	id        string @[required]
	on_select fn (string, mut Window) = unsafe { nil }
	nodes     []TreeNodeCfg
	indent    f32 = gui_theme.tree_style.indent
	spacing   f32 = gui_theme.tree_style.spacing
}

// tree creates a tree view from the given [TreeCfg](#TreeCfg)
pub fn (mut window Window) tree(cfg TreeCfg) View {
	mut content := []View{cap: cfg.nodes.len}
	for node in cfg.nodes {
		content << cfg.node_content(node, mut window)
	}
	return column(
		name:    'tree'
		padding: padding_none
		spacing: cfg.spacing
		content: content
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
// It's only advantage is it allows defining a TreeNodeCfg in a single
// line, where as `TextNodeCfg{}` will format across multiple lines.
pub fn tree_node(cfg TreeNodeCfg) TreeNodeCfg {
	return cfg
}

fn (cfg &TreeCfg) build_nodes(nodes []TreeNodeCfg, mut window Window) []View {
	mut tnodes := []View{cap: nodes.len}

	for node in nodes {
		tnodes << column(
			name:    'tree node'
			id:      node.id
			padding: padding_none
			spacing: cfg.spacing
			content: cfg.node_content(node, mut window)
		)
	}
	return tnodes
}

fn (cfg &TreeCfg) node_content(node TreeNodeCfg, mut window Window) []View {
	id := if node.id.len == 0 { node.text } else { node.id }
	is_open := window.view_state.tree_state[cfg.id][id]
	arrow := match true {
		node.nodes.len == 0 { ' ' }
		is_open { icon_drop_down }
		else { icon_drop_right }
	}
	min_width_icon := text_width('${icon_bar} ', node.text_style_icon, mut window)

	mut content := []View{cap: 2}
	cfg_id := cfg.id
	on_select := cfg.on_select

	content << row(
		name:     'tree node content'
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
		on_click: fn [cfg_id, on_select, is_open, node, id] (_ &Layout, mut e Event, mut w Window) {
			if node.nodes.len > 0 {
				w.view_state.tree_state[cfg_id][id] = !is_open
			}
			if on_select != unsafe { nil } {
				on_select(id, mut w)
				e.is_handled = true
			}
		}
		on_hover: fn (mut layout Layout, mut e Event, mut w Window) {
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
			content: cfg.build_nodes(node.nodes, mut window)
		)
	}
	return content
}
