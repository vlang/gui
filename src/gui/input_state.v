module gui

// The problem of focus and input states poses a problem in stateless
// views because...they're stateless. Instead, the window maintains
// this state in a map where the key is the w.focus_id. This state
// map is cleared when a new view is introduced.
pub struct InputState {
pub mut:
	// positions are number of runes relative to start of input text
	cursor_pos int
	beg_pos    int
	end_pos    int
}
