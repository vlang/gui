module gui

// View is a user defined view. Views are never displayed directly. Instead a
// Layout is generated from the View. Window does not hold a reference to a
// View. Views should be stateless for this reason.
//
// Views generate Layouts and Layouts generate Renderers:
//
// `view_generator → View → generate(View) → Layout → `
// `layout_arrange(mut layout) → render_layout(layout) → Renderers`
//
// Renderers are draw instructions.
pub interface View {
mut:
	content []View
	generate_layout(mut window Window) Layout
}

// generate_layout builds a Layout from a View.
fn generate_layout(mut view View, mut window Window) Layout {
	mut layout := view.generate_layout(mut window)
	layout.children.ensure_cap(view.content.len)
	for mut content in view.content {
		layout.children << generate_layout(mut content, mut window)
	}
	return layout
}

fn clear_views(mut view View) {
	for mut child in view.content {
		clear_views(mut child)
	}

	unsafe { view.content.reset() }
	view.content.clear()
	view = unsafe { nil }
}
