module gui

@[heap]
pub struct TreeCfg {
pub:
	id        string @[required]
	text      string
	indent    f32                     = 10
	padding   Padding                 = padding_two
	on_select fn (string, mut Window) = unsafe { nil }
	nodes     []TreeNodeCfg
}

pub struct TreeNodeCfg {
pub:
	id    string
	text  string
	nodes []TreeNodeCfg
}

pub fn tree(cfg TreeCfg) View {
	return column(
		id:       cfg.id
		spacing:  0
		padding:  cfg.padding
		on_click: cfg.on_click
		content:  [
			row(
				padding: padding_none
				content: [
					text(text: icon_arrow_down, text_style: gui_theme.icon3),
					text(text: cfg.text),
				]
			),
			column(
				spacing: 0
				padding: cfg.padding
				content: cfg.build_nodes(cfg.nodes)
			),
		]
	)
}

pub fn tree_node(cfg TreeNodeCfg) TreeNodeCfg {
	return TreeNodeCfg{
		...cfg
	}
}

fn (cfg &TreeCfg) build_nodes(nodes []TreeNodeCfg) []View {
	mut tnodes := []View{}
	for node in nodes {
		tnodes << column(
			id:       node.id
			spacing:  0
			padding:  cfg.padding
			on_click: cfg.on_click
			content:  [
				row(
					padding: padding_none
					content: [
						text(text: icon_arrow_down, text_style: gui_theme.icon3),
						text(text: node.text),
					]
				),
				column(
					spacing: 0
					padding: Padding{
						...cfg.padding
						left: cfg.padding.left + cfg.indent
					}
					content: cfg.build_nodes(node.nodes)
				),
			]
		)
	}
	return tnodes
}

fn (cfg &TreeCfg) on_click(c &ContainerCfg, mut e Event, mut w Window) {
	if cfg.on_select != unsafe { nil } {
		cfg.on_select(c.id, mut w)
		e.is_handled = true
	}
}
