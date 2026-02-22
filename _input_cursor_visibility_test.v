module gui

fn test_input_insert_forces_cursor_visible() {
	id_focus := u32(9101)
	mut w := Window{}
	w.view_state.input_cursor_on = false
	w.view_state.cursor_on_sticky = false
	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	imap.set(id_focus, InputState{
		cursor_pos: 0
	})
	cfg := InputCfg{
		id_focus: id_focus
		text:     ''
	}
	got := cfg.insert('a', mut w) or {
		assert false
		return
	}
	assert got == 'a'
	assert w.view_state.input_cursor_on
	assert w.view_state.cursor_on_sticky
}

fn test_input_delete_forces_cursor_visible() {
	id_focus := u32(9102)
	mut w := Window{}
	w.view_state.input_cursor_on = false
	w.view_state.cursor_on_sticky = false
	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	imap.set(id_focus, InputState{
		cursor_pos: 2
	})
	cfg := InputCfg{
		id_focus: id_focus
		text:     'ab'
	}
	got := cfg.delete(mut w, false) or {
		assert false
		return
	}
	assert got == 'a'
	assert w.view_state.input_cursor_on
	assert w.view_state.cursor_on_sticky
}
