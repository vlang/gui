module gui

fn cursor_left(pos int) int {
	return int_max(0, pos - 1)
}

fn cursor_right(strs []string, pos int) int {
	return int_min(count_chars(strs), pos + 1)
}

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

		cursor_column := cursor_position_from_offset(shape.text_lines[p_idx], cursor_offset,
			shape.text_style, window)

		new_cursor_position := match true {
			cursor_column <= p_len { p_start + cursor_column }
			else { p_start + p_len - 1 }
		}

		return new_cursor_position
	}
	return cursor_pos
}

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
		mut n_start := 0
		for i, len in lengths {
			if i < n_idx {
				n_start += len
			}
		}

		cursor_column := cursor_position_from_offset(shape.text_lines[n_idx], cursor_offset,
			shape.text_style, window)

		new_cursor_position := match true {
			cursor_column <= n_len { n_start + cursor_column }
			else { n_start + n_len - 1 }
		}

		return new_cursor_position
	}
	return cursor_pos
}

fn cursor_home() int {
	return 0
}

fn cursor_end(strs []string) int {
	return count_chars(strs)
}

const runes_blanks = [` `, `\t`, `\f`, `\v`]!

// cursor_start_of_word finds start of word position in wrapped text starting from pos
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

// cursor_end_of_word finds end of word position in wrapped text starting from pos
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

// cursor_start_of_line finds start of line position in wrapped text starting from pos
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

// cursor_end_of_line finds end of line position in wrapped text starting from pos
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

// cursor_start_of_paragraph finds start of paragraph position in wrapped text starting from pos
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
		return len
	}
	rune_slice := rune_str[0..cursor_column]
	offset := get_text_width_no_cache(rune_slice.string(), shape.text_style, window)
	return offset
}
