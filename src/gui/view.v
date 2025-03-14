module gui

import gg

// View is a user defined view. Views are never displayed
// directly. Instead a ShapeTree is generated from the View.
// It is the ShapeTree that is used to render the UI.
pub interface View {
	id string
	generate(ctx gg.Context) ShapeTree
mut:
	children []View
}

// generate_shapes builds a ShapeTree from a View.
fn generate_shapes(node View, window Window) ShapeTree {
	mut shape_tree := node.generate(window.ui)
	for child_node in node.children {
		shape_tree.children << generate_shapes(child_node, window)
	}
	return shape_tree
}
