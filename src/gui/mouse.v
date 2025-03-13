module gui

pub enum MouseButton {
	left    = 0
	right   = 1
	middle  = 2
	invalid = 256
}

pub struct MouseEvent {
	mouse_x      f32
	mouse_y      f32
	mouse_button MouseButton
}
