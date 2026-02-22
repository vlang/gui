module gui

fn test_input_mask_presets() {
	assert input_mask_from_preset(.none) == ''
	assert input_mask_from_preset(.phone_us) == '(999) 999-9999'
	assert input_mask_from_preset(.credit_card_16) == '9999 9999 9999 9999'
	assert input_mask_from_preset(.credit_card_amex) == '9999 999999 99999'
	assert input_mask_from_preset(.expiry_mm_yy) == '99/99'
	assert input_mask_from_preset(.cvc) == '999'
}

fn test_input_mask_sanitize_paste_phone() {
	compiled := compile_input_mask(input_mask_from_preset(.phone_us), []) or {
		assert false, err.msg()
		return
	}
	res := input_mask_insert('', 0, 0, 0, 'abc555-123-4567xyz', &compiled)
	assert res.changed
	assert res.text == '(555) 123-4567'
	assert res.cursor_pos == res.text.runes().len
}

fn test_input_mask_reject_invalid_char() {
	compiled := compile_input_mask('99', []) or {
		assert false, err.msg()
		return
	}
	res := input_mask_insert('', 0, 0, 0, 'a', &compiled)
	assert !res.changed
	assert res.text == ''
	assert res.cursor_pos == 0
}

fn test_input_mask_delete_skips_literals() {
	compiled := compile_input_mask(input_mask_from_preset(.phone_us), []) or {
		assert false, err.msg()
		return
	}
	mut text := ''
	mut cursor := 0
	for ch in '5551234'.runes() {
		res := input_mask_insert(text, cursor, 0, 0, ch.str(), &compiled)
		text = res.text
		cursor = res.cursor_pos
	}
	assert text == '(555) 123-4'

	// Cursor before ')' should delete the next editable slot (the 4th digit).
	del := input_mask_delete(text, 4, 0, 0, &compiled)
	assert del.changed
	assert del.text == '(555) 234'
}

fn test_input_mask_backspace_removes_editable_slot() {
	compiled := compile_input_mask(input_mask_from_preset(.phone_us), []) or {
		assert false, err.msg()
		return
	}
	start := input_mask_insert('', 0, 0, 0, '5551234', &compiled)
	assert start.text == '(555) 123-4'

	back := input_mask_backspace(start.text, start.cursor_pos, 0, 0, &compiled)
	assert back.changed
	assert back.text == '(555) 123'
}

fn is_ascii_upper_letter(r rune) bool {
	return (r >= `a` && r <= `z`) || (r >= `A` && r <= `Z`)
}

fn to_upper_ascii(r rune) rune {
	if r >= `a` && r <= `z` {
		return r - 32
	}
	return r
}

fn test_input_mask_custom_token_transform() {
	custom := [
		MaskTokenDef{
			symbol:    `A`
			matcher:   is_ascii_upper_letter
			transform: to_upper_ascii
		},
	]
	compiled := compile_input_mask('AA-99', custom) or {
		assert false, err.msg()
		return
	}
	res := input_mask_insert('', 0, 0, 0, 'ab12', &compiled)
	assert res.changed
	assert res.text == 'AB-12'
}

fn test_input_cfg_masked_insert_delete() {
	id_focus := u32(1001)
	mut w := Window{}
	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	imap.set(id_focus, InputState{
		cursor_pos: 0
	})

	cfg_insert := InputCfg{
		id_focus:    id_focus
		text:        ''
		mask_preset: .phone_us
	}
	text := cfg_insert.insert('555-123-4567', mut w) or {
		assert false, err.msg()
		return
	}
	assert text == '(555) 123-4567'

	cfg_delete := InputCfg{
		id_focus:    id_focus
		text:        text
		mask_preset: .phone_us
	}
	text2 := cfg_delete.delete(mut w, false) or {
		assert false
		return
	}
	assert text2 == '(555) 123-456'
}
