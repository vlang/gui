// vtest build: false
// TODO: this test is skipped for now on the CI, because it needs a X11 server to be running,
// in order for clipboard copy/paste to work.
// See these for a way to do it on the CI (which does not run a graphics service by default):
// https://github.com/vlang/v/blob/master/.github/workflows/c2v_ci.yml#L75
// https://github.com/vlang/v/blob/master/.github/workflows/c2v_ci.yml#L103
// https://github.com/vlang/v/blob/master/.github/workflows/c2v_ci.yml#L130
module gui

fn test_input_delete_key_at_end_is_noop() {
	id_focus := u32(9001)
	mut w := Window{}
	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	imap.set(id_focus, InputState{
		cursor_pos: 2
	})
	cfg := InputCfg{
		id_focus: id_focus
		text:     'ab'
	}
	got := cfg.delete(mut w, true) or {
		assert false
		return
	}
	assert got == 'ab'
}

fn test_input_delete_negative_cursor_uses_rune_len() {
	id_focus := u32(9002)
	mut w := Window{}
	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	imap.set(id_focus, InputState{
		cursor_pos: -1
	})
	cfg := InputCfg{
		id_focus: id_focus
		text:     '\xC2\xA2x'
	}
	got := cfg.delete(mut w, false) or {
		assert false
		return
	}
	assert got == '\xC2\xA2'
}

fn test_input_copy_accepts_selection_ending_at_text_len() {
	id_focus := u32(9003)
	mut w := Window{}
	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	imap.set(id_focus, InputState{
		select_beg: 1
		select_end: 3
	})
	cfg := InputCfg{
		id_focus: id_focus
		text:     'abc'
	}
	got := cfg.copy(&w) or {
		assert false
		return
	}
	assert got == 'bc'
}

fn test_input_insert_truncates_oversized_payload() {
	id_focus := u32(9004)
	mut w := Window{}
	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	imap.set(id_focus, InputState{
		cursor_pos: 0
	})
	cfg := InputCfg{
		id_focus: id_focus
		text:     ''
	}
	oversized := 'a'.repeat(input_max_insert_runes + 10)
	got := cfg.insert(oversized, mut w) or {
		assert false
		return
	}
	assert got.runes().len == input_max_insert_runes
}
