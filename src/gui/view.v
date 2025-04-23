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
	id string
	generate(ctx &gg.Context) Layout
mut:
	content []View
}

pub struct CommonCfg {
pub:
	id         string
	width      f32
	height     f32
	min_width  f32
	min_height f32
	max_width  f32
	max_height f32
	disabled   bool
	invisible  bool
	sizing     Sizing
}

// view_to_layout builds a Layout from a View.
fn generate_layout(view &View, window &Window) Layout {
	mut layout := view.generate(window.ui)
	for child_view in view.content {
		layout.children << generate_layout(child_view, window)
	}
	return layout
}
