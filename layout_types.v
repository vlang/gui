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
	for i in 0 .. layout.children.len {
		layout_clear(mut layout.children[i])
	}
	layout.shape = unsafe { nil }
	layout.parent = unsafe { nil }
	layout.children.clear()
	layout.children = []Layout{}
}
