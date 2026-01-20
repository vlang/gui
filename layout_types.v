module gui

// ==================================================
// Note: Adding @[heap] to struct Layout causes flickering in scrollbars.
// Test by running `v run fonts.v`.

// Layout defines a tree of Layouts. Views generate Layouts
pub struct Layout {
pub mut:
	shape    &Shape  = unsafe { nil }
	parent   &Layout = unsafe { nil }
	children []Layout
}

const empty_layout = Layout{
	shape: &Shape{}
}
