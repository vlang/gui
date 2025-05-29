module gui

@[heap]
pub struct TreeCfg {
pub:
	id        string @[required]
	indent    f32                     = 25
	spacing   f32                     = 5
	on_select fn (string, mut Window) = unsafe { nil }
	nodes     []TreeNodeCfg
pub mut:
	window Window @[required]
}

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

pub struct TreeNodeCfg {
pub:
	id    string
	text  string
	icon  string
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
	id := if node.id.len == 0 { node.text } else { node.id }
	is_open := cfg.window.view_state.tree_state[cfg.id][id]
	arrow := match true {
		node.nodes.len == 0 { ' ' }
		is_open { icon_drop_down }
		else { icon_drop_right }
	}
	// caching requires window and cfg to be mutable.
	min_width_icon := get_text_width_no_cache('${icon_bar} ', gui_theme.icon4, cfg.window)

	mut content := []View{}
	content << row(
		spacing:  0
		padding:  padding_none
		content:  [
			// arrow
			text(
				text:       '${arrow} '
				min_width:  min_width_icon
				text_style: gui_theme.icon4
			),
			// text contnet
			row(
				spacing: 0
				padding: padding_none
				content: [
					text(
						text:       '${node.icon} '
						min_width:  min_width_icon
						text_style: gui_theme.icon4
					),
					text(text: node.text),
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
