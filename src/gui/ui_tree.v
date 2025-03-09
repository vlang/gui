module gui

pub interface UI_Tree {
	id string
	generate() ShapeTree
mut:
	children []UI_Tree
}

struct EmptyTree implements UI_Tree {
	id string
mut:
	children []UI_Tree
}

fn (et EmptyTree) generate() ShapeTree {
	return ShapeTree{}
}

const empty_tree = EmptyTree{
	id: 'empty_ui_tree'
}

fn generate_shapes(node UI_Tree) ShapeTree {
	mut shape_tree := node.generate()
	for child_node in node.children {
		shape_tree.children << generate_shapes(child_node)
	}
	return shape_tree
}
