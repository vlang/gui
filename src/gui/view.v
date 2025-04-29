module gui

import gg

// View is a user defined view. Views are never displayed directly. Instead a
// Layout is generated from the View. Window does not hold a reference to a
// View. Views should be stateless for this reason.
//
// Views generate Layouts and Layouts generate Renderers:  `View → Layout → Renderer`
//
// Renderers are draw instructions.
pub interface View {
	id      string
	content []View
	generate(ctx &gg.Context) Layout
}

pub interface Cfg {
	id string
}

// view_to_layout builds a Layout from a View.
fn generate_layout(view &View, window &Window) Layout {
	mut layout := view.generate(window.ui)
	for child_view in view.content {
		layout.children << generate_layout(child_view, window)
	}
	return layout
}
