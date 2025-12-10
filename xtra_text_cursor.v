module gui

fn cursor_left(pos int) int {
	return int_max(0, pos - 1)
}

fn cursor_right(strs []string, pos int) int {
	return int_min(count_chars(strs), pos + 1)
}

fn cursor_up(strs []string, pos int) int {
	mut idx := 0
	mut offset := 0
	lengths := strs.map(utf8_str_visible_length(it))

	// find which line to from
	for i, len in lengths {
		idx = i
		if offset + len > pos {
			break
		}
		offset += len
	}

	// move to previous line
	if idx > 0 {
		col := pos - offset
		p_idx := idx - 1
		p_len := lengths[p_idx]
		mut p_start := 0
		for i, len in lengths {
			if i < p_idx {
				p_start += len
			}
		}
		return if col >= p_len { p_start + p_len - 1 } else { p_start + col }
	}
	return pos
}

fn cursor_down(strs []string, pos int) int {
	mut idx := 0
	mut offset := 0
	lengths := strs.map(utf8_str_visible_length(it))

	// find which line to from
	for i, len in lengths {
		idx = i
		if offset + len > pos {
			break
		}
		offset += len
	}

	// move to next line
	if idx < strs.len - 1 {
		col := pos - offset
		n_idx := idx + 1
		n_len := lengths[n_idx]
		mut n_start := 0
		for i, len in lengths {
			if i < n_idx {
				n_start += len
			}
		}
		return if col >= n_len { n_start + n_len - 1 } else { n_start + col }
	}
	return pos
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
