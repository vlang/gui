module gui

// cursor_left moves the cursor position one character to the left in the text.
// It decrements the position by one, but ensures the result never goes below
// zero, effectively preventing the cursor from moving before the start of the
// text. Returns the new cursor position.
fn cursor_left(pos int) int {
	return int_max(0, pos - 1)
}

// cursor_right moves the cursor position one character to the right in wrapped
// text. It increments the position by one, but ensures the result never exceeds
// the total character count of all text lines combined, effectively preventing
// the cursor from moving beyond the end of the text. Returns the new cursor
// position.
fn cursor_right(strs []string, pos int) int {
	return int_min(count_chars(strs), pos + 1)
}

// cursor_up moves the cursor position up one line in wrapped text, attempting
// to maintain the same horizontal pixel offset. It locates the current line by
// iterating through the wrapped text lines, moves to the previous line, and
// uses the cursor_offset to find the corresponding column position. If the
// cursor_offset is invalid (less than zero, typically -1), it is recomputed
// from the current cursor position. If the previous line is shorter than the
// calculated column, the cursor moves to the end of that line. Returns the
// original position if already at the first line.
fn cursor_up(shape Shape, cursor_pos int, cursor_offset f32, window &Window) int {
	mut idx := 0
	mut offset := 0
	lengths := shape.text_lines.map(utf8_str_visible_length(it))

	// find which line to from
	for i, len in lengths {
		idx = i
		if offset + len > cursor_pos {
			break
		}
		offset += len
	}

	// move to previous line
	if idx > 0 {
		p_idx := idx - 1
		p_len := lengths[p_idx]
		mut p_start := 0
		for i, len in lengths {
			if i < p_idx {
				p_start += len
			}
		}

		// An offset of less than zero (usually -1) indicates that the offset was
		// invalidated, likely because of an edit operation like insert/delete.
		// Compute a new offset based on the current cursor position
		c_offset := match cursor_offset >= 0 {
			true { cursor_offset }
			else { offset_from_cursor_position(shape, cursor_pos, window) }
		}

		cursor_column := cursor_position_from_offset(shape.text_lines[p_idx], c_offset,
			shape.text_style, window)

		new_cursor_position := match true {
			cursor_column <= p_len { p_start + cursor_column }
			else { p_start + p_len - 1 }
		}

		return new_cursor_position
	}
	return cursor_pos
}

// cursor_down moves the cursor position down one line in wrapped text, attempting
// to maintain the same horizontal pixel offset. It locates the current line by
// iterating through the wrapped text lines, moves to the next line, and uses
// the cursor_offset to find the corresponding column position. If the cursor_offset
// is invalid (less than zero, typically -1), it is recomputed from the current
// cursor position. If the next line is shorter than the calculated column, the
// cursor position is adjusted: for lines ending with a newline, it moves to the
// position before the newline; for the last line, it moves to the end of the line.
// Returns the original position if already at the last line.
fn cursor_down(shape Shape, cursor_pos int, cursor_offset f32, window &Window) int {
	mut idx := 0
	mut offset := 0
	lengths := shape.text_lines.map(utf8_str_visible_length(it))

	// find which line to from
	for i, len in lengths {
		idx = i
		if offset + len > cursor_pos {
			break
		}
		offset += len
	}

	// move to next line
	if idx < shape.text_lines.len - 1 {
		n_idx := idx + 1
		n_len := lengths[n_idx]
		n_text := shape.text_lines[n_idx]
		mut n_start := 0
		for i, len in lengths {
			if i < n_idx {
				n_start += len
			}
		}

		// An offset of less than zero (usually -1) indicates that the offset was
		// invalidated, likely because of an edit operation like insert/delete.
		// Compute a new offset based on the current cursor position
		c_offset := match cursor_offset >= 0 {
			true { cursor_offset }
			else { offset_from_cursor_position(shape, cursor_pos, window) }
		}

		cursor_column := cursor_position_from_offset(n_text, c_offset, shape.text_style,
			window)

		new_cursor_position := match true {
			// not past the end
			cursor_column < n_len - 1 { n_start + cursor_column }
			// past the end, ends with new line
			n_text.ends_with('\n') { n_start + n_len - 1 }
			// past the end, last line edge case
			else { n_start + n_len }
		}

		return new_cursor_position
	}
	return cursor_pos
}

// cursor_home moves the cursor to the beginning of the text by returning
// position 0. This is equivalent to the "Home" key behavior, placing the
// cursor at the start of the entire text content.
fn cursor_home() int {
	return 0
}

// cursor_end moves the cursor to the end of the text by returning the total
// character count across all wrapped text lines. This is equivalent to the
// "End" key behavior, placing the cursor at the end of the entire text content.
fn cursor_end(strs []string) int {
	return count_chars(strs)
}

const runes_blanks = [` `, `\t`, `\f`, `\v`]!

// cursor_start_of_word finds the start of the current word in wrapped text by locating
// the line containing the given position, searching backwards through blank characters
// (spaces, tabs, form feeds, vertical tabs), and then backwards through non-blank
// characters to find the start of the word. Returns the character position at the
// start of the word, or 0 if at the beginning of the text.
fn cursor_start_of_word(strs []string, pos int) int {
	if pos < 0 {
		return 0
	}

	mut len := 0
	mut idx := 0
	runes := strs.map(it.runes())

	// find where to start searching
	for ; idx < runes.len; idx++ {
		if len + runes[idx].len < pos {
			len += runes[idx].len
			continue
		}
		break
	}

	mut i := 0
	i = pos - len - 1
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

// cursor_end_of_word finds the end of the current word in wrapped text by locating
// the line containing the given position, skipping over any blank characters (spaces,
// tabs, form feeds, vertical tabs), and then advancing through non-blank characters
// to find the end of the word. Returns the character position at the end of the word.
fn cursor_end_of_word(strs []string, pos int) int {
	if pos < 0 {
		return 0
	}

	mut i := 0
	mut len := 0

	for str in strs {
		runes := str.runes()
		if pos >= len + runes.len {
			len += runes.len
			continue
		}

		i = pos - len
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

// cursor_start_of_line finds the start of the current line in wrapped text by
// locating the line containing the given position and returning the cumulative
// character count up to the beginning of that line.
fn cursor_start_of_line(strs []string, pos int) int {
	mut len := 0
	for str in strs {
		str_len := utf8_str_visible_length(str)
		if pos > len + str_len {
			len += str_len
			continue
		}
		return len
	}
	return len
}

// cursor_end_of_line finds the end of the current line in wrapped text by locating
// the line containing the given position and returning the position at the end of
// that line. For the last line, it returns the actual end position; for other lines,
// it adjusts to account for line boundaries.
fn cursor_end_of_line(strs []string, pos int) int {
	mut len := 0
	mut cnt := 0

	for str in strs {
		cnt += 1
		str_len := utf8_str_visible_length(str)
		if pos >= len + str_len - 1 {
			len += str_len
			continue
		}

		is_last_line := cnt == strs.len
		eol := if is_last_line { 0 } else { 1 }
		return int_max(0, len + str_len - eol)
	}

	return len
}

// cursor_start_of_paragraph finds the start of the current paragraph in wrapped text
// by searching backwards from the given position. A paragraph is defined as text
// separated by newline characters. It locates the line containing the position,
// searches backwards for the first newline character, and returns the position
// immediately after that newline (or 0 if at the start of the text).
fn cursor_start_of_paragraph(strs []string, pos int) int {
	if pos < 0 {
		return 0
	}

	mut len := 0
	mut idx := 0
	runes := strs.map(it.runes())

	// find where to start searching
	for ; idx < runes.len; idx++ {
		if len + runes[idx].len < pos {
			len += runes[idx].len
			continue
		}
		break
	}

	mut i := 0
	i = pos - len - 1
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

// get_cursor_column returns the zero-based column index of `cursor_pos` within
// the current line of wrapped text. It iterates through the wrapped lines to
// locate the line containing `cursor_pos` and subtracts the cumulative lengths
// to compute the position within that line.
fn get_cursor_column(strs []string, cursor_pos int) int {
	mut len := 0
	for str in strs {
		str_len := utf8_str_visible_length(str)
		if len + str_len < cursor_pos {
			len += str_len
			continue
		}
		break
	}
	cursor_column := cursor_pos - len
	assert cursor_column >= 0
	return cursor_column
}

// cursor_position_from_offset finds the character index (rune position) in a string
// that corresponds to the given horizontal pixel offset. It calculates the rendered
// width of text up to each character position and returns the index closest to the
// offset. If the offset is beyond the end of the string, it returns the last valid
// character position.
fn cursor_position_from_offset(str string, offset f32, style TextStyle, window &Window) int {
	rune_str := str.runes()
	for idx in 1 .. rune_str.len {
		width := get_text_width_no_cache(rune_str[0..idx].string(), style, window)
		if width > offset {
			char_width := get_text_width_no_cache(rune_str[idx].str(), style, window)
			return if offset - char_width > width { idx } else { idx - 1 }
		}
	}
	return int_max(0, rune_str.len - 1)
}

// offset_from_cursor_position returns the horizontal pixel offset of the cursor
// position within wrapped text. It locates the line containing the cursor position,
// calculates the column within that line, and measures the rendered width of text
// up to that column using the shape's text style. If the cursor position is beyond
// the end of a line, it returns the cumulative length of previous lines.
fn offset_from_cursor_position(shape Shape, cursor_position int, window &Window) f32 {
	mut len := 0
	mut str := ''
	for text_line in shape.text_lines {
		str_len := utf8_str_visible_length(text_line)
		if len + str_len < cursor_position {
			len += str_len
			continue
		}
		str = text_line
		break
	}
	rune_str := str.runes()
	cursor_column := cursor_position - len
	if cursor_column >= rune_str.len {
		return get_text_width_no_cache(str, shape.text_style, window)
	}
	rune_slice := rune_str[0..cursor_column]
	offset := get_text_width_no_cache(rune_slice.string(), shape.text_style, window)
	return offset
}
