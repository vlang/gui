module gui

pub interface UI_Tree {
	id string
	generate() Shape
mut:
	children []UI_Tree
}

struct EmptyTree implements UI_Tree {
	id string
mut:
	children []UI_Tree
}

fn (et EmptyTree) generate() Shape {
	return Shape{}
}

const empty_tree = EmptyTree{
	id: 'empty_ui_tree'
}

fn generate_shapes(node UI_Tree) ShapeTree {
	mut shape_tree := ShapeTree{}
	shape_tree.shape = node.generate()
	for child_node in node.children {
		shape_tree.children << generate_shapes(child_node)
	}
	return shape_tree
}
