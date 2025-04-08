module gui

// The management of scroll states poses a problem in stateless views
// because...they're stateless. Instead, the window maintains this state in a
// map where the key is the shape.id_scroll_v/h_scroll_id
// This state map is cleared when a new view is introduced.
pub struct ScrollState {
pub:
	offset_v f32
	offset_h f32
}
