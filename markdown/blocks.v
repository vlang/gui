module markdown

// blocks.v handles parsing of markdown block-level elements.

// parse_header_block parses a header line into an MdBlock.
pub fn parse_header_block(text string, level int, link_defs map[string]string, footnote_defs map[string]string) MdBlock {
	mut header_runs := []MdRun{cap: 10}
	parse_inline(text, .plain, mut header_runs, link_defs, footnote_defs, 0)
	return MdBlock{
		header_level: level
		anchor_slug:  heading_slug(text)
		runs:         header_runs
	}
}

// heading_slug converts heading text to a URL-safe anchor slug.
pub fn heading_slug(text string) string {
	mut buf := []u8{cap: text.len}
	for ch in text.to_lower() {
		if (ch >= `a` && ch <= `z`) || (ch >= `0` && ch <= `9`) {
			buf << ch
		} else if ch == ` ` || ch == `-` || ch == `_` {
			if buf.len > 0 && buf.last() != `-` {
				buf << `-`
			}
		}
	}
	for buf.len > 0 && buf.last() == `-` {
		buf.pop()
	}
	return buf.bytestr()
}

// is_setext_underline checks if a line is a setext-style header
// underline. Returns 1 for h1, 2 for h2, 0 for neither.
pub fn is_setext_underline(line string) int {
	trimmed := line.trim_space()
	if trimmed.len == 0 {
		return 0
	}
	if is_all_char(trimmed, `=`) {
		return 1
	}
	if is_all_char(trimmed, `-`) {
		return 2
	}
	return 0
}

fn is_all_char(s string, c u8) bool {
	for ch in s {
		if ch != c {
			return false
		}
	}
	return true
}

// is_horizontal_rule checks if a line is a horizontal rule.
pub fn is_horizontal_rule(line string) bool {
	trimmed := line.trim_space()
	if trimmed.len < 3 {
		return false
	}
	c := trimmed[0]
	if c != `-` && c != `*` && c != `_` {
		return false
	}
	mut count := 0
	for ch in trimmed {
		if ch == c {
			count++
		} else if ch == ` ` || ch == `\t` {
			continue
		} else {
			return false
		}
	}
	return count >= 3
}

// is_ordered_list checks if a line is an ordered list item.
pub fn is_ordered_list(line string) bool {
	mut dot_pos := line.index('.') or { -1 }
	if dot_pos == -1 {
		dot_pos = line.index(')') or { -1 }
	}
	if dot_pos <= 0 || dot_pos >= line.len - 1 {
		return false
	}
	num_part := line[..dot_pos]
	for c in num_part {
		if c < `0` || c > `9` {
			return false
		}
	}
	return line[dot_pos + 1] == ` `
}

// get_indent_level counts leading whitespace and returns indent
// level (2 spaces or 1 tab = 1 level).
pub fn get_indent_level(line string) int {
	mut spaces := 0
	for c in line {
		if c == ` ` {
			spaces++
		} else if c == `\x09` {
			spaces += 2
		} else {
			break
		}
	}
	return spaces / 2
}

// collect_paragraph_content joins continuation lines.
pub fn collect_paragraph_content(first_line string, scanner MdScanner, start_idx int, hard_line_breaks bool) (string, int) {
	mut consumed := 0
	mut idx := start_idx

	for idx < scanner.len() && consumed < max_paragraph_continuation_lines {
		next := scanner.get_line(idx)
		next_trimmed := next.trim_space()
		if next_trimmed == '' || is_block_start(next) {
			break
		}
		consumed++
		idx++
	}

	if consumed == 0 {
		if hard_line_breaks {
			return strip_hard_break_trail(first_line), 0
		}
		return first_line, 0
	}

	mut buf := []u8{cap: first_line.len + consumed * 80}
	if hard_line_breaks {
		stripped := strip_hard_break_trail(first_line)
		buf << stripped.bytes()
		if has_hard_break(first_line) {
			buf << `\n`
		} else {
			buf << ` `
		}
	} else {
		buf << first_line.bytes()
		buf << ` `
	}
	idx = start_idx
	for ci in 0 .. consumed {
		line := scanner.get_line(idx)
		if hard_line_breaks {
			buf << strip_hard_break_trail(line).bytes()
			if ci < consumed - 1 {
				if has_hard_break(line) {
					buf << `\n`
				} else {
					buf << ` `
				}
			}
		} else {
			buf << line.bytes()
			if ci < consumed - 1 {
				buf << ` `
			}
		}
		idx++
	}
	return buf.bytestr(), consumed
}

// has_hard_break checks if a line ends with trailing \ or 2+ spaces.
pub fn has_hard_break(line string) bool {
	if line.len == 0 {
		return false
	}
	if line[line.len - 1] == `\\` {
		return true
	}
	if line.len >= 2 && line[line.len - 1] == ` ` && line[line.len - 2] == ` ` {
		return true
	}
	return false
}

fn strip_hard_break_trail(line string) string {
	if line.len == 0 {
		return line
	}
	if line[line.len - 1] == `\\` {
		return line[..line.len - 1]
	}
	return line.trim_right(' ')
}

// collect_list_item_content collects continuation lines for a
// list item.
pub fn collect_list_item_content(first_content string, scanner MdScanner, start_idx int) (string, int) {
	mut consumed := 0
	mut idx := start_idx

	for idx < scanner.len() && consumed < max_list_continuation_lines {
		next := scanner.get_line(idx)
		if next.len == 0 || (next[0] != ` ` && next[0] != `\x09`) {
			break
		}
		next_trimmed := next.trim_space()
		if next_trimmed == '' || is_block_start(next) {
			break
		}
		consumed++
		idx++
	}

	if consumed == 0 {
		return first_content, 0
	}

	mut buf := []u8{cap: first_content.len + consumed * 40}
	buf << first_content.bytes()
	idx = start_idx
	for _ in 0 .. consumed {
		buf << ` `
		buf << scanner.get_line(idx).trim_space().bytes()
		idx++
	}
	return buf.bytestr(), consumed
}

// is_block_start checks if a line starts a new block element.
pub fn is_block_start(line string) bool {
	trimmed := line.trim_space()
	if trimmed.len == 0 {
		return false
	}
	fc := trimmed[0]
	if fc != `#` && fc != `>` && fc != `\`` && fc != `~` && fc != `!` && fc != `-` && fc != `*`
		&& fc != `+` && fc != `|` && fc != `:` && fc != `$` && fc != `_` && (fc < `0` || fc > `9`) {
		return false
	}
	if trimmed.starts_with('#') {
		return true
	}
	if trimmed.starts_with('>') {
		return true
	}
	if trimmed.starts_with('```') || trimmed.starts_with('~~~') {
		return true
	}
	if trimmed.starts_with('![') {
		return true
	}
	if is_horizontal_rule(trimmed) {
		return true
	}
	if trimmed.starts_with('- ') || trimmed.starts_with('* ') || trimmed.starts_with('+ ') {
		return true
	}
	if trimmed.starts_with('- [ ]') || trimmed.starts_with('- [x]') || trimmed.starts_with('- [X]') {
		return true
	}
	if trimmed.starts_with('* [ ]') || trimmed.starts_with('* [x]') || trimmed.starts_with('* [X]') {
		return true
	}
	if is_ordered_list(trimmed) {
		return true
	}
	if trimmed.starts_with('|') || is_table_separator(trimmed) {
		return true
	}
	if is_definition_line(trimmed) {
		return true
	}
	if trimmed.starts_with('$$') {
		return true
	}
	return false
}

// count_blockquote_depth counts leading > characters.
pub fn count_blockquote_depth(line string) int {
	mut depth := 0
	mut pos := 0
	for pos < line.len {
		if line[pos] == `>` {
			depth++
			pos++
			if pos < line.len && line[pos] == ` ` {
				pos++
			}
		} else if line[pos] == ` ` {
			pos++
		} else {
			break
		}
	}
	return depth
}

// strip_blockquote_prefix removes all > and leading spaces.
pub fn strip_blockquote_prefix(line string) string {
	mut pos := 0
	for pos < line.len {
		if line[pos] == `>` {
			pos++
			if pos < line.len && line[pos] == ` ` {
				pos++
			}
		} else if line[pos] == ` ` {
			pos++
		} else {
			break
		}
	}
	return if pos < line.len { line[pos..] } else { '' }
}

// get_task_prefix returns task list prefix if line is a task item.
pub fn get_task_prefix(trimmed string) ?string {
	if trimmed.starts_with('- [ ] ') || trimmed.starts_with('* [ ] ') {
		return '☐ '
	}
	if trimmed.starts_with('- [x] ') || trimmed.starts_with('* [x] ')
		|| trimmed.starts_with('- [X] ') || trimmed.starts_with('* [X] ') {
		return '☑ '
	}
	return none
}

// is_definition_line checks if a line starts with ": ".
pub fn is_definition_line(line string) bool {
	trimmed := line.trim_space()
	return trimmed.len > 1 && trimmed[0] == `:` && trimmed[1] == ` `
}

// peek_for_definition checks if next non-blank line is a definition.
pub fn peek_for_definition(scanner MdScanner, start_idx int) bool {
	for i := start_idx; i < scanner.len(); i++ {
		trimmed := scanner.get_line(i).trim_space()
		if trimmed == '' {
			return false
		}
		if is_definition_line(scanner.get_line(i)) {
			return true
		}
		return false
	}
	return false
}

// collect_definition_content collects continuation lines for a
// definition value.
pub fn collect_definition_content(first_content string, scanner MdScanner, start_idx int) (string, int) {
	mut consumed := 0
	mut idx := start_idx

	for idx < scanner.len() && consumed < max_list_continuation_lines {
		next := scanner.get_line(idx)
		if next.len == 0 {
			break
		}
		if next[0] != ` ` && next[0] != `\x09` {
			break
		}
		next_trimmed := next.trim_space()
		if next_trimmed == '' || is_block_start(next) || is_definition_line(next) {
			break
		}
		consumed++
		idx++
	}

	if consumed == 0 {
		return first_content, 0
	}

	mut buf := []u8{cap: first_content.len + consumed * 40}
	buf << first_content.bytes()
	idx = start_idx
	for _ in 0 .. consumed {
		buf << ` `
		buf << scanner.get_line(idx).trim_space().bytes()
		idx++
	}
	return buf.bytestr(), consumed
}

// has_code_indent returns true if line starts with 4+ spaces or tab.
pub fn has_code_indent(line string) bool {
	if line.len == 0 {
		return false
	}
	if line[0] == `\t` {
		return true
	}
	if line.len >= 4 && line[0] == ` ` && line[1] == ` ` && line[2] == ` ` && line[3] == ` ` {
		return true
	}
	return false
}

// strip_code_indent removes one level of code indent.
pub fn strip_code_indent(line string) string {
	if line.len == 0 {
		return ''
	}
	if line[0] == `\t` {
		return line[1..]
	}
	if line.len >= 4 && line[0] == ` ` && line[1] == ` ` && line[2] == ` ` && line[3] == ` ` {
		return line[4..]
	}
	return line
}
