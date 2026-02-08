module gui

// Layout defines a tree of Layouts. Views generate Layouts
@[heap]
pub struct Layout {
pub mut:
	shape    &Shape  = unsafe { nil }
	parent   &Layout = unsafe { nil }
	children []Layout
}

const empty_layout = Layout{
	shape: &Shape{}
}

fn layout_clear(mut layout Layout) {
	for mut ly in layout.children {
		layout_clear(mut ly)
	}
	layout.shape = unsafe { nil }
	layout.parent = unsafe { nil }
	unsafe { layout.children.free() }
}
