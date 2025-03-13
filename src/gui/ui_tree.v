module gui

import gg

pub const empty_ui_tree_id = '__empty_ui_tree__'

// UI_Tree is a user defined view. UI_Trees are never displayed
// directly. Instead a ShapeTree is generated from the UI_Tree.
// It is the ShapeTree that is used to render the UI.
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

const empty_ui_tree = EmptyTree{
	id: empty_ui_tree_id
}

// generate_shapes builds a ShapeTree from a UI_Tree.
fn generate_shapes(node UI_Tree, window Window) ShapeTree {
	mut shape_tree := node.generate(window.ui)
	for child_node in node.children {
		shape_tree.children << generate_shapes(child_node, window)
	}
	return shape_tree
}
