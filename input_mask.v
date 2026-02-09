module gui

import encoding.utf8

// InputMaskPreset defines common mask patterns.
pub enum InputMaskPreset as u8 {
	none
	phone_us
	credit_card_16
	credit_card_amex
	expiry_mm_yy
	cvc
}

// MaskTokenDef defines one token symbol in a mask pattern.
pub struct MaskTokenDef {
pub:
	symbol    rune
	matcher   fn (rune) bool = mask_never_match
	transform fn (rune) rune = identity_rune
}

// MaskEditResult stores the output of a mask edit operation.
pub struct MaskEditResult {
pub:
	text       string
	cursor_pos int
	changed    bool
}

enum MaskEntryKind as u8 {
	literal
	slot
}

struct CompiledMaskEntry {
	kind      MaskEntryKind
	literal   rune
	symbol    rune
	matcher   fn (rune) bool = unsafe { nil }
	transform fn (rune) rune = identity_rune
}

// CompiledInputMask stores parsed mask entries and lookup indexes.
pub struct CompiledInputMask {
pub:
	pattern string
mut:
	entries            []CompiledMaskEntry
	slot_entry_indexes []int
}

@[inline]
fn identity_rune(r rune) rune {
	return r
}

@[inline]
fn mask_never_match(_ rune) bool {
	return false
}

@[inline]
fn is_ascii_digit(r rune) bool {
	return r >= `0` && r <= `9`
}

@[inline]
fn is_mask_letter(r rune) bool {
	return utf8.is_letter(r)
}

@[inline]
fn is_mask_alnum(r rune) bool {
	return utf8.is_letter(r) || utf8.is_number(r)
}

// input_mask_default_tokens returns built-in mask tokens.
pub fn input_mask_default_tokens() []MaskTokenDef {
	return [
		MaskTokenDef{
			symbol:  `9`
			matcher: is_ascii_digit
		},
		MaskTokenDef{
			symbol:  `a`
			matcher: is_mask_letter
		},
		MaskTokenDef{
			symbol:  `*`
			matcher: is_mask_alnum
		},
	]
}

// input_mask_from_preset returns the mask pattern for a preset.
pub fn input_mask_from_preset(preset InputMaskPreset) string {
	return match preset {
		.none { '' }
		.phone_us { '(999) 999-9999' }
		.credit_card_16 { '9999 9999 9999 9999' }
		.credit_card_amex { '9999 999999 99999' }
		.expiry_mm_yy { '99/99' }
		.cvc { '999' }
	}
}

// compile_input_mask parses a mask pattern and resolves token definitions.
pub fn compile_input_mask(mask string, custom []MaskTokenDef) !CompiledInputMask {
	if mask.len == 0 {
		return error('mask pattern is empty')
	}

	mut token_map := map[rune]MaskTokenDef{}
	for def in input_mask_default_tokens() {
		token_map[def.symbol] = def
	}
	for def in custom {
		token_map[def.symbol] = def
	}

	mask_runes := mask.runes()
	mut entries := []CompiledMaskEntry{cap: mask_runes.len}
	mut escaped := false
	for r in mask_runes {
		if escaped {
			entries << CompiledMaskEntry{
				kind:    .literal
				literal: r
			}
			escaped = false
			continue
		}
		if r == `\\` {
			escaped = true
			continue
		}
		if def := token_map[r] {
			entries << CompiledMaskEntry{
				kind:      .slot
				symbol:    def.symbol
				matcher:   def.matcher
				transform: def.transform
			}
		} else {
			entries << CompiledMaskEntry{
				kind:    .literal
				literal: r
			}
		}
	}
	if escaped {
		entries << CompiledMaskEntry{
			kind:    .literal
			literal: `\\`
		}
	}

	mut slot_entry_indexes := []int{}
	for i, entry in entries {
		if entry.kind == .slot {
			slot_entry_indexes << i
		}
	}

	return CompiledInputMask{
		pattern:            mask
		entries:            entries
		slot_entry_indexes: slot_entry_indexes
	}
}

@[inline]
fn (m &CompiledInputMask) slot_count() int {
	return m.slot_entry_indexes.len
}

@[inline]
fn (m &CompiledInputMask) slot_entry(slot_index int) CompiledMaskEntry {
	return m.entries[m.slot_entry_indexes[slot_index]]
}

fn (m &CompiledInputMask) has_slot_after(entry_index int) bool {
	for i in entry_index + 1 .. m.entries.len {
		if m.entries[i].kind == .slot {
			return true
		}
	}
	return false
}

fn (m &CompiledInputMask) raw_from_formatted_runes(formatted []rune) []rune {
	mut raw := []rune{cap: m.slot_count()}
	limit := int_min(formatted.len, m.entries.len)
	for i in 0 .. limit {
		entry := m.entries[i]
		if entry.kind == .slot && entry.matcher != unsafe { nil } {
			ch := formatted[i]
			if entry.matcher(ch) {
				raw << entry.transform(ch)
			}
		}
	}
	return raw
}

fn (m &CompiledInputMask) format_raw(raw []rune) string {
	if raw.len == 0 || m.entries.len == 0 {
		return ''
	}
	mut out := []rune{cap: m.entries.len}
	mut raw_index := 0
	for i, entry in m.entries {
		if entry.kind == .slot {
			if raw_index >= raw.len {
				break
			}
			ch := raw[raw_index]
			raw_index++
			if entry.matcher != unsafe { nil } && entry.matcher(ch) {
				out << entry.transform(ch)
			}
		} else if raw_index < raw.len && m.has_slot_after(i) {
			out << entry.literal
		}
	}
	return out.string()
}

fn (m &CompiledInputMask) formatted_to_raw_index(formatted_len int, formatted_index int, raw_len int) int {
	idx := int_clamp(formatted_index, 0, formatted_len)
	limit := int_min(idx, m.entries.len)
	mut raw_index := 0
	for i in 0 .. limit {
		if m.entries[i].kind == .slot {
			raw_index++
		}
	}
	return int_clamp(raw_index, 0, raw_len)
}

fn (m &CompiledInputMask) selection_raw_range(formatted_len int, cursor_pos int, select_beg u32, select_end u32, raw_len int) (int, int) {
	if select_beg != select_end {
		beg, end := u32_sort(select_beg, select_end)
		return m.formatted_to_raw_index(formatted_len, int(beg), raw_len), m.formatted_to_raw_index(formatted_len,
			int(end), raw_len)
	}
	idx := m.formatted_to_raw_index(formatted_len, cursor_pos, raw_len)
	return idx, idx
}

fn (m &CompiledInputMask) rebuild_raw(prefix []rune, suffix []rune) []rune {
	mut out := []rune{cap: m.slot_count()}
	for ch in prefix {
		if out.len >= m.slot_count() {
			break
		}
		entry := m.slot_entry(out.len)
		if entry.matcher != unsafe { nil } && entry.matcher(ch) {
			out << entry.transform(ch)
		}
	}
	for ch in suffix {
		if out.len >= m.slot_count() {
			break
		}
		entry := m.slot_entry(out.len)
		if entry.matcher != unsafe { nil } && entry.matcher(ch) {
			out << entry.transform(ch)
		}
	}
	return out
}

fn (m &CompiledInputMask) cursor_from_raw_index(raw []rune, raw_index int) int {
	idx := int_clamp(raw_index, 0, raw.len)
	if idx == 0 {
		return 0
	}
	return m.format_raw(raw[..idx]).runes().len
}

// input_mask_insert inserts input into a masked formatted string.
pub fn input_mask_insert(formatted string, cursor_pos int, select_beg u32, select_end u32, input string, compiled &CompiledInputMask) MaskEditResult {
	if compiled == unsafe { nil } || compiled.slot_count() == 0 {
		return MaskEditResult{
			text:       formatted
			cursor_pos: cursor_pos
			changed:    false
		}
	}

	formatted_runes := formatted.runes()
	raw := compiled.raw_from_formatted_runes(formatted_runes)
	start, end := compiled.selection_raw_range(formatted_runes.len, cursor_pos, select_beg,
		select_end, raw.len)

	mut prefix := []rune{cap: compiled.slot_count()}
	prefix << raw[..start]
	mut insert_slot := start

	for ch in input.runes() {
		if insert_slot >= compiled.slot_count() {
			break
		}
		entry := compiled.slot_entry(insert_slot)
		if entry.matcher != unsafe { nil } && entry.matcher(ch) {
			prefix << entry.transform(ch)
			insert_slot++
		}
	}

	new_raw := compiled.rebuild_raw(prefix, raw[end..])
	new_text := compiled.format_raw(new_raw)
	new_cursor := compiled.cursor_from_raw_index(new_raw, insert_slot)
	return MaskEditResult{
		text:       new_text
		cursor_pos: new_cursor
		changed:    new_text != formatted
	}
}

fn input_mask_remove(formatted string, cursor_pos int, select_beg u32, select_end u32, remove_backward bool, compiled &CompiledInputMask) MaskEditResult {
	if compiled == unsafe { nil } || compiled.slot_count() == 0 {
		return MaskEditResult{
			text:       formatted
			cursor_pos: cursor_pos
			changed:    false
		}
	}

	formatted_runes := formatted.runes()
	raw := compiled.raw_from_formatted_runes(formatted_runes)
	mut start, mut end := compiled.selection_raw_range(formatted_runes.len, cursor_pos,
		select_beg, select_end, raw.len)

	if start == end {
		if remove_backward {
			if start == 0 {
				return MaskEditResult{
					text:       formatted
					cursor_pos: cursor_pos
					changed:    false
				}
			}
			start--
			end = start + 1
		} else {
			if start >= raw.len {
				return MaskEditResult{
					text:       formatted
					cursor_pos: cursor_pos
					changed:    false
				}
			}
			end = start + 1
		}
	}

	new_raw := compiled.rebuild_raw(raw[..start], raw[end..])
	new_text := compiled.format_raw(new_raw)
	new_cursor := compiled.cursor_from_raw_index(new_raw, start)
	return MaskEditResult{
		text:       new_text
		cursor_pos: new_cursor
		changed:    new_text != formatted
	}
}

// input_mask_backspace removes one editable slot to the left of cursor.
pub fn input_mask_backspace(formatted string, cursor_pos int, select_beg u32, select_end u32, compiled &CompiledInputMask) MaskEditResult {
	return input_mask_remove(formatted, cursor_pos, select_beg, select_end, true, compiled)
}

// input_mask_delete removes one editable slot at/after cursor.
pub fn input_mask_delete(formatted string, cursor_pos int, select_beg u32, select_end u32, compiled &CompiledInputMask) MaskEditResult {
	return input_mask_remove(formatted, cursor_pos, select_beg, select_end, false, compiled)
}
