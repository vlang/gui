module gui

@[heap]
pub struct TreeCfg {
pub:
	id        string @[required]
	window    Window @[required]
	text      string
	indent    f32                     = 10
	spacing   f32                     = 5
	on_select fn (string, mut Window) = unsafe { nil }
	nodes     []TreeNodeCfg
}

pub fn tree(cfg TreeCfg) View {
	return column(
		id:      cfg.id
		padding: padding_none
		spacing: cfg.spacing
		content: cfg.node_content(TreeNodeCfg{
			id:    cfg.id
			text:  cfg.text
			nodes: cfg.nodes
		})
	)
}

pub struct TreeNodeCfg {
pub:
	id    string
	text  string
	nodes []TreeNodeCfg
}

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
	is_open := cfg.window.view_state.tree_state[cfg.id][node.id]
	arrow := match true {
		node.nodes.len == 0 { ' ' }
		is_open { icon_drop_down }
		else { icon_drop_right }
	}

	mut content := []View{}
	content << row(
		padding: padding_none
		content: [
			// arrow
			row(
				padding: padding_none
				content: [
					row(
						padding:  padding_none
						content:  [
							text(
								text:       arrow
								min_width:  10
								text_style: gui_theme.icon4
							),
						]
						on_click: fn [cfg, is_open, node] (_ voidptr, mut e Event, mut w Window) {
							w.view_state.tree_state[cfg.id][node.id] = !is_open
						}
					),
				]
			),
			// text contnet
			row(
				padding:  padding_none
				content:  [
					text(text: node.text),
				]
				on_click: fn [cfg, is_open, node] (_ &ContainerCfg, mut e Event, mut w Window) {
					if node.nodes.len > 0 {
						w.view_state.tree_state[cfg.id][node.id] = !is_open
					}
					if cfg.on_select != unsafe { nil } {
						cfg.on_select(node.id, mut w)
						e.is_handled = true
					}
				}
			),
		]
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
