module gui

// The management of scroll states poses a problem in stateless views
// because...they're stateless. Instead, the window maintains this state in a
// map where the key is the shape.v_scroll_id/h_scroll_id
// This state map is cleared when a new view is introduced.
pub struct ScrollState {
pub mut:
	v_offset f32
	y_offset f32
}
