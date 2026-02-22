module gui

// Tests for multi-byte text handling: cursor movement, insert, delete,
// copy, word boundaries, IME commit, and edge cases.

fn make_text_cursor_shape(text string) Shape {
	return Shape{
		shape_type: .text
		tc:         &ShapeTextConfig{
			text: text
		}
	}
}

// ------------------------------------
// ## A. cursor_right / cursor_end
// ------------------------------------

fn test_cursor_right_clamp_3byte() {
	// '€' is 3 bytes, 1 rune
	shape := make_text_cursor_shape('€')
	assert cursor_right(shape, 0) == 1
	assert cursor_right(shape, 1) == 1 // clamped at rune count
}

fn test_cursor_right_clamp_4byte() {
	// '𝐀' (U+1D400) is 4 bytes, 1 rune
	shape := make_text_cursor_shape('𝐀')
	assert cursor_right(shape, 0) == 1
	assert cursor_right(shape, 1) == 1
}

fn test_cursor_right_cjk_string() {
	// '日本語' = 3 runes, 9 bytes
	shape := make_text_cursor_shape('日本語')
	assert cursor_right(shape, 2) == 3
	assert cursor_right(shape, 3) == 3
}

fn test_cursor_end_3byte() {
	shape := make_text_cursor_shape('€€€')
	assert cursor_end(shape) == 3
}

fn test_cursor_end_4byte() {
	shape := make_text_cursor_shape('𝐀𝐁𝐂')
	assert cursor_end(shape) == 3
}

fn test_cursor_end_emoji_only() {
	// '😀😀' = 2 runes, 8 bytes
	shape := make_text_cursor_shape('😀😀')
	assert cursor_end(shape) == 2
}

fn test_cursor_end_empty() {
	shape := make_text_cursor_shape('')
	assert cursor_end(shape) == 0
}

fn test_cursor_end_combining_char() {
	// 'é' as e + combining acute (U+0301) = 2 runes, 3 bytes
	shape := make_text_cursor_shape('e\u0301')
	assert cursor_end(shape) == 2
}

// ------------------------------------
// ## B. cursor_left sanity
// ------------------------------------

fn test_cursor_left_at_zero() {
	assert cursor_left(0) == 0
}

fn test_cursor_left_from_one() {
	assert cursor_left(1) == 0
}

// ------------------------------------
// ## C. cursor_end_of_line no-layout
// ------------------------------------

fn test_cursor_end_of_line_no_layout_3byte() {
	// No vglyph_layout → fallback path
	shape := make_text_cursor_shape('日本語')
	assert cursor_end_of_line(shape, 0) == 3
}

fn test_cursor_end_of_line_no_layout_4byte() {
	shape := make_text_cursor_shape('𝐀𝐁')
	assert cursor_end_of_line(shape, 0) == 2
}

// ------------------------------------
// ## D. Insert with multi-byte text
// ------------------------------------

fn test_insert_emoji_at_start() {
	id_focus := u32(10001)
	mut w := Window{}
	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	imap.set(id_focus, InputState{ cursor_pos: 0 })
	cfg := InputCfg{
		id_focus: id_focus
		text:     'abc'
	}
	got := cfg.insert('😀', mut w) or {
		assert false
		return
	}
	assert got == '😀abc'
}

fn test_insert_emoji_at_middle() {
	id_focus := u32(10002)
	mut w := Window{}
	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	imap.set(id_focus, InputState{ cursor_pos: 1 })
	cfg := InputCfg{
		id_focus: id_focus
		text:     'ab'
	}
	got := cfg.insert('😀', mut w) or {
		assert false
		return
	}
	assert got == 'a😀b'
}

fn test_insert_cjk_string() {
	id_focus := u32(10003)
	mut w := Window{}
	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	imap.set(id_focus, InputState{ cursor_pos: 0 })
	cfg := InputCfg{
		id_focus: id_focus
		text:     ''
	}
	got := cfg.insert('日本語', mut w) or {
		assert false
		return
	}
	assert got == '日本語'
	state := imap.get(id_focus) or { InputState{} }
	assert state.cursor_pos == 3
}

fn test_insert_combining_char() {
	// Insert combining acute after 'e'
	id_focus := u32(10004)
	mut w := Window{}
	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	imap.set(id_focus, InputState{ cursor_pos: 1 })
	cfg := InputCfg{
		id_focus: id_focus
		text:     'e'
	}
	got := cfg.insert('\u0301', mut w) or {
		assert false
		return
	}
	assert got == 'e\u0301'
}

fn test_insert_ascii_into_multibyte() {
	id_focus := u32(10005)
	mut w := Window{}
	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	// Cursor at rune pos 1 in '日本' (between 日 and 本)
	imap.set(id_focus, InputState{ cursor_pos: 1 })
	cfg := InputCfg{
		id_focus: id_focus
		text:     '日本'
	}
	got := cfg.insert('x', mut w) or {
		assert false
		return
	}
	assert got == '日x本'
}

// ------------------------------------
// ## E. Delete with multi-byte text
// ------------------------------------

fn test_backspace_after_emoji() {
	id_focus := u32(10010)
	mut w := Window{}
	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	// Cursor after the emoji (rune pos 1)
	imap.set(id_focus, InputState{ cursor_pos: 1 })
	cfg := InputCfg{
		id_focus: id_focus
		text:     '😀x'
	}
	got := cfg.delete(mut w, false) or {
		assert false
		return
	}
	assert got == 'x'
}

fn test_backspace_after_3byte() {
	id_focus := u32(10011)
	mut w := Window{}
	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	imap.set(id_focus, InputState{ cursor_pos: 1 })
	cfg := InputCfg{
		id_focus: id_focus
		text:     '€x'
	}
	got := cfg.delete(mut w, false) or {
		assert false
		return
	}
	assert got == 'x'
}

fn test_forward_delete_on_emoji() {
	id_focus := u32(10012)
	mut w := Window{}
	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	// Cursor before the emoji (rune pos 0), forward delete
	imap.set(id_focus, InputState{ cursor_pos: 0 })
	cfg := InputCfg{
		id_focus: id_focus
		text:     '😀x'
	}
	got := cfg.delete(mut w, true) or {
		assert false
		return
	}
	assert got == 'x'
}

fn test_backspace_combining_char() {
	id_focus := u32(10013)
	mut w := Window{}
	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	// 'e' + combining acute = 2 runes; cursor at 2, backspace removes
	// the combining char
	imap.set(id_focus, InputState{ cursor_pos: 2 })
	cfg := InputCfg{
		id_focus: id_focus
		text:     'e\u0301'
	}
	got := cfg.delete(mut w, false) or {
		assert false
		return
	}
	assert got == 'e'
}

// ------------------------------------
// ## F. Selection + copy
// ------------------------------------

fn test_copy_single_multibyte_char() {
	id_focus := u32(10020)
	mut w := Window{}
	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	imap.set(id_focus, InputState{
		select_beg: 0
		select_end: 1
	})
	cfg := InputCfg{
		id_focus: id_focus
		text:     '€ab'
	}
	got := cfg.copy(&w) or {
		assert false
		return
	}
	assert got == '€'
}

fn test_copy_span_across_multibyte() {
	id_focus := u32(10021)
	mut w := Window{}
	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	// Select runes 1..3 in 'a€bé' → '€b'
	imap.set(id_focus, InputState{
		select_beg: 1
		select_end: 3
	})
	cfg := InputCfg{
		id_focus: id_focus
		text:     'a€b\u00e9'
	}
	got := cfg.copy(&w) or {
		assert false
		return
	}
	assert got == '€b'
}

fn test_copy_emoji() {
	id_focus := u32(10022)
	mut w := Window{}
	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	imap.set(id_focus, InputState{
		select_beg: 1
		select_end: 2
	})
	cfg := InputCfg{
		id_focus: id_focus
		text:     'a😀b'
	}
	got := cfg.copy(&w) or {
		assert false
		return
	}
	assert got == '😀'
}

// ------------------------------------
// ## G. Insert replacing selection
// ------------------------------------

fn test_replace_multibyte_selection_with_ascii() {
	id_focus := u32(10030)
	mut w := Window{}
	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	// Select the emoji at rune 1..2 in 'a😀b'
	imap.set(id_focus, InputState{
		cursor_pos: 1
		select_beg: 1
		select_end: 2
	})
	cfg := InputCfg{
		id_focus: id_focus
		text:     'a😀b'
	}
	got := cfg.insert('x', mut w) or {
		assert false
		return
	}
	assert got == 'axb'
}

fn test_replace_ascii_selection_with_emoji() {
	id_focus := u32(10031)
	mut w := Window{}
	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	// Select 'bc' (runes 1..3) in 'abcd'
	imap.set(id_focus, InputState{
		cursor_pos: 1
		select_beg: 1
		select_end: 3
	})
	cfg := InputCfg{
		id_focus: id_focus
		text:     'abcd'
	}
	got := cfg.insert('😀', mut w) or {
		assert false
		return
	}
	assert got == 'a😀d'
}

// ------------------------------------
// ## H. Word boundary with multi-byte
// ------------------------------------

fn test_cursor_end_of_word_cjk_mixed() {
	// 'hello 日本語 world'
	// Rune positions: h=0 e=1 l=2 l=3 o=4 ' '=5 日=6 本=7 語=8
	// ' '=9 w=10 o=11 r=12 l=13 d=14
	shape := make_text_cursor_shape('hello 日本語 world')
	// From rune 5 (space), skip space then skip non-spaces → end of '日本語'
	assert cursor_end_of_word(shape, 5) == 9
}

fn test_cursor_start_of_word_cjk_mixed() {
	shape := make_text_cursor_shape('hello 日本語 world')
	// From rune 9 (space after 語), skip space back, then skip non-spaces
	// back → start of '日本語' at rune 6
	assert cursor_start_of_word(shape, 9) == 6
}

// ------------------------------------
// ## I. IME commit simulation
// ------------------------------------

fn test_ime_commit_cjk_into_empty() {
	id_focus := u32(10040)
	mut w := Window{}
	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	imap.set(id_focus, InputState{ cursor_pos: 0 })
	cfg := InputCfg{
		id_focus: id_focus
		text:     ''
	}
	got := cfg.insert('中文', mut w) or {
		assert false
		return
	}
	assert got == '中文'
	state := imap.get(id_focus) or { InputState{} }
	assert state.cursor_pos == 2
}

fn test_ime_commit_cjk_at_cursor() {
	id_focus := u32(10041)
	mut w := Window{}
	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	imap.set(id_focus, InputState{ cursor_pos: 2 })
	cfg := InputCfg{
		id_focus: id_focus
		text:     'abcd'
	}
	got := cfg.insert('漢字', mut w) or {
		assert false
		return
	}
	assert got == 'ab漢字cd'
	state := imap.get(id_focus) or { InputState{} }
	assert state.cursor_pos == 4
}

fn test_ime_commit_replacing_selection() {
	id_focus := u32(10042)
	mut w := Window{}
	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	imap.set(id_focus, InputState{
		cursor_pos: 1
		select_beg: 1
		select_end: 3
	})
	cfg := InputCfg{
		id_focus: id_focus
		text:     'abcd'
	}
	got := cfg.insert('日', mut w) or {
		assert false
		return
	}
	assert got == 'a日d'
	state := imap.get(id_focus) or { InputState{} }
	assert state.cursor_pos == 2
}

// ------------------------------------
// ## J. Edge cases
// ------------------------------------

fn test_cursor_right_empty_text() {
	shape := make_text_cursor_shape('')
	assert cursor_right(shape, 0) == 0
}

fn test_cursor_end_single_4byte() {
	shape := make_text_cursor_shape('😀')
	assert cursor_end(shape) == 1
}

fn test_insert_empty_string() {
	id_focus := u32(10050)
	mut w := Window{}
	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	imap.set(id_focus, InputState{ cursor_pos: 1 })
	cfg := InputCfg{
		id_focus: id_focus
		text:     '日本'
	}
	got := cfg.insert('', mut w) or {
		assert false
		return
	}
	assert got == '日本'
}

fn test_delete_empty_text() {
	id_focus := u32(10051)
	mut w := Window{}
	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	imap.set(id_focus, InputState{ cursor_pos: 0 })
	cfg := InputCfg{
		id_focus: id_focus
		text:     ''
	}
	got := cfg.delete(mut w, false) or {
		assert false
		return
	}
	assert got == ''
}

fn test_mixed_script_sequential_insert() {
	id_focus := u32(10052)
	mut w := Window{}
	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	imap.set(id_focus, InputState{ cursor_pos: 0 })
	cfg1 := InputCfg{
		id_focus: id_focus
		text:     ''
	}
	text1 := cfg1.insert('abc', mut w) or {
		assert false
		return
	}
	assert text1 == 'abc'
	// Cursor now at 3
	cfg2 := InputCfg{
		id_focus: id_focus
		text:     text1
	}
	text2 := cfg2.insert('日本', mut w) or {
		assert false
		return
	}
	assert text2 == 'abc日本'
	// Cursor now at 5
	cfg3 := InputCfg{
		id_focus: id_focus
		text:     text2
	}
	text3 := cfg3.insert('😀', mut w) or {
		assert false
		return
	}
	assert text3 == 'abc日本😀'
}
