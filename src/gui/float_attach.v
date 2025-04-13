module gui

pub enum FloatAttach {
	top_left
	top_right
	bottom_left
	bottom_right
}

fn layout_float_attach(layout &Layout) (f32, f32) {
	mut x, mut y := match layout.parent != unsafe { nil } {
		true { layout.parent.shape.x, layout.parent.shape.y }
		else { f32(0), f32(0) }
	}
	x, y = match layout.shape.float_attach {
		.top_left { x, y }
		.top_right { x + layout.parent.shape.width, y }
		.bottom_left { x, y + layout.parent.shape.height }
		.bottom_right { x + layout.parent.shape.width, y + layout.parent.shape.height }
	}
	return x, y
}
