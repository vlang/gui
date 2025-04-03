module gui

import gg

// View is a user defined view. Views are never displayed directly. Instead a
// ShapeTree is generated from the View. Window does not hold a reference to a
// View. Views should be stateless for this reason.
pub interface View {
	id string
	generate(ctx gg.Context) ShapeTree
mut:
	content []View
}

// generate_shapes builds a ShapeTree from a View.
fn generate_shapes(node View, window Window) ShapeTree {
	mut shape_tree := node.generate(window.ui)
	for child_node in node.content {
		shape_tree.children << generate_shapes(child_node, window)
	}
	return shape_tree
}
