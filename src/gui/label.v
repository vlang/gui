module gui

pub struct Label implements UI_Tree {
pub:
	id string
mut:
	children []UI_Tree
}

pub struct LabelConfig {
pub:
	x int
	y int
}

fn (l Label) generate() ShapeTree {
	return ShapeTree{}
}
