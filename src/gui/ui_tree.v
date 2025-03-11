module gui

import gg

pub interface UI_Tree {
	id string
	generate(ctx gg.Context) ShapeTree
mut:
	children []UI_Tree
}

struct EmptyTree implements UI_Tree {
	id string
mut:
	children []UI_Tree
}

fn (et EmptyTree) generate(_ gg.Context) ShapeTree {
	return ShapeTree{}
}

const empty_tree = EmptyTree{
	id: 'empty_ui_tree'
}

fn generate_shapes(node UI_Tree, window Window) ShapeTree {
	mut shape_tree := node.generate(window.ui)
	for child_node in node.children {
		shape_tree.children << generate_shapes(child_node, window)
	}
	return shape_tree
}
