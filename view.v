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
	uid       u64
	view_type ViewType
	generate(mut window Window) Layout
mut:
	content []View
}

enum ViewType {
	container
	text
	rtf
	image
}

// generate_layout builds a Layout from a View.
fn generate_layout(view &View, mut window Window) Layout {
	mut layout := view.generate(mut window)
	layout.children.ensure_cap(view.content.len)
	for child_view in view.content {
		layout.children << generate_layout(child_view, mut window)
	}
	return layout
}
