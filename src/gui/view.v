module gui

import gg

// View is a user defined view. Views are never displayed directly. Instead a
// Layout is generated from the View. Window does not hold a reference to a
// View. Views should be stateless for this reason.
pub interface View {
	id string
	generate(ctx gg.Context) Layout
mut:
	content []View
}

// generate_layout builds a Layout from a View.
fn generate_layout(node View, window Window) Layout {
	mut layout := node.generate(window.ui)
	for child_node in node.content {
		layout.children << generate_layout(child_node, window)
	}
	return layout
}
