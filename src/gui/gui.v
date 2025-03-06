module gui

pub const version = '0.1.0'

pub interface UI_Tree {
	generate() Shape
mut:
	children []UI_Tree
}

struct EmptyTree implements UI_Tree {
mut:
	children []UI_Tree
}

fn (et EmptyTree) generate() Shape {
	return Shape{}
}

const empty_tree = EmptyTree{}

fn generate_shapes(node UI_Tree) ShapeTree {
	mut shape_tree := ShapeTree{}
	shape_tree.shape = node.generate()
	for child_node in node.children {
		shape_tree.children << generate_shapes(child_node)
	}
	return shape_tree
}
