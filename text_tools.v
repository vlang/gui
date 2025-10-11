module gui

import clipboard
import encoding.utf8
import hash.fnv1a

pub fn get_text_width_no_cache(text string, text_style TextStyle, window &Window) f32 {
	cfg := text_style.to_text_cfg()
	window.ui.set_text_cfg(cfg)
	return window.ui.text_width(text)
}

@[manualfree]
pub fn get_text_width(text string, text_style TextStyle, mut window Window) f32 {
	htx := fnv1a.sum32_struct(text_style).str()
	defer { unsafe { htx.free() } }
	text_htx := text + htx
	key := fnv1a.sum32_string(text_htx)
	unsafe { text_htx.free() }
	return window.view_state.text_widths[key] or {
		cfg := text_style.to_text_cfg()
		window.ui.set_text_cfg(cfg)
		t_width := window.ui.text_width(text)
		window.view_state.text_widths[key] = t_width
		t_width
	}
}

@[manualfree]
fn text_width(shape &Shape, mut window Window) f32 {
	mut max_width := f32(0)
	mut text_cfg_set := false
	htx := fnv1a.sum32_struct(shape.text_style).str()
	defer { unsafe { htx.free() } }
	for line in shape.text_lines {
		line_htx := line + htx
		key := fnv1a.sum32_string(line_htx)
		unsafe { line_htx.free() }
		width := window.view_state.text_widths[key] or {
			if !text_cfg_set {
				text_cfg := shape.text_style.to_text_cfg()
				window.ui.set_text_cfg(text_cfg)
				text_cfg_set = true
			}
			t_width := window.ui.text_width(line)
			window.view_state.text_widths[key] = t_width
			t_width
		}
		max_width = f32_max(width, max_width)
	}
	return max_width
}

@[inline]
fn text_height(shape &Shape) f32 {
	lh := line_height(shape)
	return lh * shape.text_lines.len
}

@[inline]
fn line_height(shape &Shape) f32 {
	return shape.text_style.size + shape.text_style.line_spacing
}

fn text_wrap(mut shape Shape, mut window Window) {
	if shape.text_mode in [.wrap, .wrap_keep_spaces] && shape.type == .text {
		style := shape.text_style
		width := shape.width - shape.padding.width()
		tab_size := shape.text_tab_size
		shape.text_lines = match shape.text_mode == .wrap_keep_spaces {
			true { wrap_text_keep_spaces(shape.text, style, width, tab_size, mut window) }
			else { wrap_text_shrink_spaces(shape.text, style, width, tab_size, mut window) }
		}
		lh := line_height(shape)
		shape.height = shape.text_lines.len * lh
		shape.max_height = shape.height
		shape.min_height = shape.height
	} else if shape.text_mode in [.wrap, .wrap_keep_spaces] && shape.type == .rtf {
		width := shape.width - shape.padding.width()
		tab_size := shape.text_tab_size
		shape.text_spans = rtf_wrap_text(shape.text_spans, width, tab_size, mut window)
		shape.width, shape.height = spans_size(shape.text_spans)
	}
}

// wrap_text_shrink_spaces wraps lines to given width (logical units, not chars)
// Extra white space is removed.
fn wrap_text_shrink_spaces(s string, text_style TextStyle, width f32, tab_size u32, mut window Window) []string {
	mut line := ''
	mut wrap := []string{cap: 10}
	unsafe { wrap.flags.set(.noslices) }
	for field in split_text(s, tab_size) {
		if field == '\n' {
			wrap << line + '\n'
			line = ''
			continue
		}
		if field.is_blank() {
			continue
		}
		if line.len == 0 {
			line = field + ' '
			continue
		}
		n_line := line + field + ' '
		t_width := get_text_width(n_line, text_style, mut window)
		if t_width > width {
			wrap << line
			line = field + ' '
		} else {
			line = n_line
		}
	}
	wrap << line.substr(0, int_max(0, line.len - 1))
	return wrap
}

// wrap_text_keep_spaces wraps lines to given width (logical units, not chars) White space is preserved
// 1. Preserves original spaces - No new spaces are added, only existing spaces from the input text are used
// 2. Tries to leave at least one space at the end - When wrapping is needed, it attempts to include
//    trailing spaces from the next field if they fit within the width limit
// 3. Splits multiple spaces appropriately - If a space field contains multiple spaces, it includes
//    as many as will fit and carries the rest to the next line
// 4. Wraps earlier when necessary - If no trailing spaces can be added, it tries to wrap at an earlier space
//    within the current line to ensure a space at the end
// 5. Respects width constraints - Never exceeds the specified width limit
// 6. Handles edge cases - Properly handles empty lines and overly long fields to avoid infinite loops
fn wrap_text_keep_spaces(s string, text_style TextStyle, width f32, tab_size u32, mut window Window) []string {
	mut line := ''
	mut wrap := []string{cap: 10}
	unsafe { wrap.flags.set(.noslices) }
	mut fields := split_text(s, tab_size)

	mut i := 0
	for i < fields.len {
		field := fields[i]
		if field == '\n' {
			wrap << line + '\n'
			line = ''
			i++
			continue
		}
		n_line := line + field
		t_width := get_text_width(n_line, text_style, mut window)
		if t_width > width {
			// Check if we can add at least one space to the current line
			mut wrapped_line := line
			mut can_add_space := false

			if line.len > 0 && !line.ends_with(' ') && i + 1 < fields.len {
				next_field := fields[i + 1]
				if next_field != '\n' && next_field.is_blank() {
					// Try to fit as many spaces as possible (at least one)
					mut spaces_to_add := ''
					for space in next_field {
						test_line := line + spaces_to_add + space.str()
						test_width := get_text_width(test_line, text_style, mut window)
						if test_width <= width {
							spaces_to_add += space.str()
							can_add_space = true
						} else {
							break
						}
					}

					if can_add_space {
						wrapped_line = line + spaces_to_add
						// Update the next field with remaining spaces
						remaining_spaces := next_field[spaces_to_add.len..]
						if remaining_spaces.len > 0 {
							fields[i + 1] = remaining_spaces
						} else {
							// All spaces were consumed, remove this field
							fields.delete(i + 1)
						}
					}
				}
			}

			// Can't add a space and line is not empty? Need to wrap earlier
			if !can_add_space && line.len > 0 && !line.ends_with(' ') {
				// Look back to see if we can wrap at an earlier space
				mut should_wrap_early := false
				if line.contains(' ') {
					// Find the last space in the current line
					last_space_idx := line.last_index(' ') or { -1 }
					if last_space_idx > 0 {
						early_wrap := line[..last_space_idx + 1]
						remaining := line[last_space_idx + 1..]
						wrapped_line = early_wrap
						line = remaining + field
						should_wrap_early = true
					}
				}

				if !should_wrap_early {
					// Can't wrap early, force wrap without space
					wrapped_line = line
					line = field
				}
			} else if line.len > 0 {
				// Added space(s) or line already ends with space
				line = field
			} else {
				// Line is empty but field is too wide - add it anyway to avoid infinite loop
				line = field
			}

			if line.len > 0 || wrapped_line.len > 0 {
				wrap << wrapped_line
			}
		} else {
			line = n_line
		}
		i++
	}
	wrap << line
	return wrap
}

// wrap_simple wraps only at new lines
fn wrap_simple(s string, tab_size u32) []string {
	mut line := ''
	mut lines := []string{cap: 10}
	unsafe { lines.flags.set(.noslices) }

	for field in split_text(s, tab_size) {
		if field == '\n' {
			lines << line + '\n'
			line = ''
			continue
		}
		line += field
	}
	lines << line
	return lines
}

const r_space = ` `

// split_text splits a string by spaces with spaces as separate
// strings. Newlines are separate strings from spaces.
fn split_text(s string, tab_size u32) []string {
	state_ch := 0
	state_sp := 1

	mut state := state_ch
	mut fields := []string{cap: 100}
	unsafe { fields.flags.set(.noslices) }
	mut field := []rune{cap: 50}
	unsafe { field.flags.set(.noslices) }
	for r in s.runes_iterator() {
		if state == state_ch {
			if r == r_space {
				if field.len > 0 {
					fields << field.string()
				}
				field.clear()
				field << r
				state = state_sp
			} else if r == `\n` {
				if field.len > 0 {
					fields << field.string()
				}
				fields << '\n'
				field.clear()
			} else if r == `\r` {
				// eat it
			} else if r == `\t` {
				if field.len > 0 {
					fields << field.string()
				}
				mut spaces := int(tab_size) - field.len % int(tab_size)
				spaces = if spaces == 0 { int(tab_size) } else { spaces }
				fields << []rune{len: spaces, init: r_space}.string()
				field.clear()
				state = state_sp
			} else if utf8.is_space(r) {
				if field.len > 0 {
					fields << field.string()
				}
				field.clear()
				field << r_space
				state = state_sp
			} else {
				field << r
			}
		} else { // state == state_sp
			if r == r_space {
				field << r
			} else if r == `\n` {
				if field.len > 0 {
					fields << field.string()
				}
				fields << '\n'
				field.clear()
			} else if r == `\r` {
				// eat it
			} else if r == `\t` {
				mut spaces := int(tab_size) - field.len % int(tab_size)
				spaces = if spaces == 0 { int(tab_size) } else { spaces }
				field << []rune{len: spaces, init: r_space}
			} else if utf8.is_space(r) {
				field << r_space
			} else {
				fields << field.string()
				field.clear()
				field << r
				state = state_ch
			}
		}
	}
	fields << field.string()
	return fields
}

const runes_blanks = [` `, `\t`, `\f`, `\v`]

// start_of_word_pos finds start of word in wrapped text
fn start_of_word_pos(strs []string, offset int) int {
	if offset < 0 {
		return 0
	}

	mut len := 0
	mut idx := 0
	runes := strs.map(it.runes())

	// find where to start searching
	for ; idx < runes.len; idx++ {
		if len + runes[idx].len < offset {
			len += runes[idx].len
			continue
		}
		break
	}

	mut i := 0
	i = offset - len - 1
	for ; idx >= 0; idx-- {
		for i >= 0 && runes[idx][i] in runes_blanks {
			i--
		}

		for i >= 0 && runes[idx][i] !in runes_blanks {
			i--
		}

		i += 1

		if i > 0 {
			break
		}

		if idx == 0 {
			return 0
		}

		if i == 0 && runes[idx][i] !in runes_blanks {
			break
		}

		prev_len := runes[idx - 1].len
		len -= prev_len
		i = prev_len - 1
	}
	return int_max(i + len, 0)
}

// end_of_word_pos finds end of word in wrapped text
fn end_of_word_pos(strs []string, offset int) int {
	if offset < 0 {
		return 0
	}

	mut i := 0
	mut len := 0

	for str in strs {
		runes := str.runes()
		if offset >= len + runes.len {
			len += runes.len
			continue
		}

		i = offset - len
		for i < runes.len && runes[i] in runes_blanks {
			i++
		}

		for i < runes.len && runes[i] !in runes_blanks {
			i++
		}

		break
	}

	return i + len
}

fn start_of_line_pos(strs []string, offset int) int {
	mut len := 0

	for str in strs {
		runes := str.runes()
		if offset > len + runes.len {
			len += runes.len
			continue
		}

		return len
	}

	return len
}

fn end_of_line_pos(strs []string, offset int) int {
	mut len := 0
	mut cnt := 0

	for str in strs {
		cnt += 1
		runes := str.runes()
		if offset >= len + runes.len - 1 {
			len += runes.len
			continue
		}

		is_last_line := cnt == strs.len
		eol := if is_last_line { 0 } else { 1 }
		return int_max(0, len + runes.len - eol)
	}

	return len
}

fn start_of_paragraph(strs []string, offset int) int {
	if offset < 0 {
		return 0
	}

	mut len := 0
	mut idx := 0
	runes := strs.map(it.runes())

	// find where to start searching
	for ; idx < runes.len; idx++ {
		if len + runes[idx].len < offset {
			len += runes[idx].len
			continue
		}
		break
	}

	mut i := 0
	i = offset - len - 1
	for ; idx >= 0; idx-- {
		for i >= 0 && runes[idx][i] != `\n` {
			i--
		}
		if idx == 0 {
			return 0
		}
		prev_len := runes[idx - 1].len
		len -= prev_len
		if i >= 0 {
			break
		}
		i = prev_len - 1
	}

	return int_max(i + len, 0)
}

pub fn from_clipboard() string {
	mut cb := clipboard.new()
	defer { cb.free() }
	return cb.paste()
}

pub fn to_clipboard(s ?string) bool {
	if s != none {
		mut cb := clipboard.new()
		defer { cb.free() }
		return cb.copy(s)
	}
	return false
}
