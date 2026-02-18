module gui

struct InputFormatterTestState {
mut:
	changed_text  string
	commit_text   string
	commit_reason InputCommitReason
}

fn test_input_pre_commit_rejects_delta_without_state_mutation() {
	id_focus := u32(9005)
	mut w := Window{}
	w.view_state.input_state.set(id_focus, InputState{
		cursor_pos: 1
	})
	cfg := InputCfg{
		id_focus:             id_focus
		text:                 'ab'
		pre_commit_transform: fn (_ string, proposed string) ?string {
			if proposed.contains('x') {
				return none
			}
			return proposed
		}
	}
	got := cfg.insert('x', mut w) or {
		assert false
		return
	}
	assert got == 'ab'
	state := w.view_state.input_state.get(id_focus) or {
		assert false
		return
	}
	assert state.cursor_pos == 1
	assert state.undo.len() == 0
}

fn test_input_pre_commit_transforms_text_before_state_write() {
	id_focus := u32(9006)
	mut w := Window{}
	w.view_state.input_state.set(id_focus, InputState{
		cursor_pos: 2
	})
	cfg := InputCfg{
		id_focus:             id_focus
		text:                 'ab'
		pre_commit_transform: fn (_ string, proposed string) ?string {
			return proposed.to_upper()
		}
	}
	got := cfg.insert('c', mut w) or {
		assert false
		return
	}
	assert got == 'ABC'
	state := w.view_state.input_state.get(id_focus) or {
		assert false
		return
	}
	assert state.cursor_pos == 3
	assert state.undo.len() == 1
}

fn test_input_single_line_enter_runs_post_commit_normalize_and_commit_callback() {
	mut state := &InputFormatterTestState{}
	mut w := Window{
		state: state
	}
	cfg := InputRuntimeCfg{
		id_focus:              9101
		text:                  '  abc  '
		post_commit_normalize: fn (text string, _ InputCommitReason) string {
			return text.trim_space()
		}
		on_text_changed:       fn (_ &Layout, text string, mut w Window) {
			mut s := w.state[InputFormatterTestState]()
			s.changed_text = text
		}
		on_text_commit:        fn (_ &Layout, text string, reason InputCommitReason, mut w Window) {
			mut s := w.state[InputFormatterTestState]()
			s.commit_text = text
			s.commit_reason = reason
		}
	}
	handler := make_input_on_char(cfg)
	layout := Layout{}
	mut e := Event{
		char_code: cr_char
	}
	handler(&layout, mut e, mut w)
	assert e.is_handled
	assert state.changed_text == 'abc'
	assert state.commit_text == 'abc'
	assert state.commit_reason == .enter
}

fn test_input_commit_text_uses_blur_reason() {
	mut state := &InputFormatterTestState{}
	mut w := Window{
		state: state
	}
	cfg := InputCfg{
		id_focus:              9102
		text:                  '  xyz  '
		post_commit_normalize: fn (text string, _ InputCommitReason) string {
			return text.trim_space()
		}
		on_text_changed:       fn (_ &Layout, text string, mut w Window) {
			mut s := w.state[InputFormatterTestState]()
			s.changed_text = text
		}
		on_text_commit:        fn (_ &Layout, text string, reason InputCommitReason, mut w Window) {
			mut s := w.state[InputFormatterTestState]()
			s.commit_text = text
			s.commit_reason = reason
		}
	}
	layout := Layout{}
	cfg.commit_text(&layout, .blur, mut w)
	assert state.changed_text == 'xyz'
	assert state.commit_text == 'xyz'
	assert state.commit_reason == .blur
}
