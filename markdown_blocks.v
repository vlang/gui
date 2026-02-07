module gui

// markdown_blocks.v handles parsing of markdown block-level elements (headers, lists, blockquotes, etc.)

// parse_header_block parses a header line into a MarkdownBlock.
fn parse_header_block(text string, level int, header_style TextStyle, md_style MarkdownStyle, link_defs map[string]string, footnote_defs map[string]string) MarkdownBlock {
	mut header_runs := []RichTextRun{cap: 10}
	parse_inline(text, header_style, md_style, mut header_runs, link_defs, footnote_defs)
	return MarkdownBlock{
		header_level: level
		content:      RichText{
			runs: header_runs
		}
	}
}

// is_setext_underline checks if a line is a setext-style header underline.
// Returns 1 for h1 (===), 2 for h2 (---), 0 for neither.
fn is_setext_underline(line string) int {
	trimmed := line.trim_space()
	if trimmed.len == 0 {
		return 0
	}
	// Check for all '=' (h1)
	if trimmed.replace('=', '') == '' {
		return 1
	}
	// Check for all '-' (h2)
	if trimmed.replace('-', '') == '' {
		return 2
	}
	return 0
}

// is_horizontal_rule checks if a line is a horizontal rule (3+ of -, *, or _).
fn is_horizontal_rule(line string) bool {
	if line.len < 3 {
		return false
	}
	c := line[0]
	if c != `-` && c != `*` && c != `_` {
		return false
	}
	for ch in line {
		if ch != c {
			return false
		}
	}
	return true
}

// is_ordered_list checks if a line is an ordered list item (e.g., "1. item").
fn is_ordered_list(line string) bool {
	dot_pos := line.index('.') or { return false }
	if dot_pos == 0 || dot_pos >= line.len - 1 {
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

// get_indent_level counts leading whitespace and returns indent level (2 spaces or 1 tab = 1 level).
fn get_indent_level(line string) int {
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

// collect_paragraph_content joins continuation lines for paragraphs.
fn collect_paragraph_content(first_line string, lines []string, start_idx int) (string, int) {
	mut consumed := 0
	mut idx := start_idx

	// Count continuation lines (non-blank, non-block-start, bounded)
	for idx < lines.len && consumed < max_paragraph_continuation_lines {
		next := lines[idx]
		next_trimmed := next.trim_space()
		if next_trimmed == '' || is_block_start(next) {
			break
		}
		consumed++
		idx++
	}

	// Fast path: no continuation
	if consumed == 0 {
		return first_line, 0
	}

	// Build combined content
	mut buf := []u8{cap: first_line.len + consumed * 80}
	buf << first_line.bytes()
	idx = start_idx
	for _ in 0 .. consumed {
		buf << ` `
		buf << lines[idx].bytes()
		idx++
	}
	return buf.bytestr(), consumed
}

// collect_list_item_content collects the full content of a list item including continuation lines.
// Returns the combined content and the number of lines consumed (excluding the first).
fn collect_list_item_content(first_content string, lines []string, start_idx int) (string, int) {
	mut consumed := 0
	mut idx := start_idx

	// Check if any continuation lines exist (bounded)
	for idx < lines.len && consumed < max_list_continuation_lines {
		next := lines[idx]
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

	// Fast path: no continuation lines
	if consumed == 0 {
		return first_content, 0
	}

	// Build combined content with buffer
	mut buf := []u8{cap: first_content.len + consumed * 40}
	buf << first_content.bytes()
	idx = start_idx
	for _ in 0 .. consumed {
		buf << ` `
		buf << lines[idx].trim_space().bytes()
		idx++
	}
	return buf.bytestr(), consumed
}

// is_block_start checks if a line starts a new block element.
fn is_block_start(line string) bool {
	trimmed := line.trim_space()
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
	if trimmed in ['---', '***', '___'] {
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

// count_blockquote_depth counts the number of > at the start of a line.
fn count_blockquote_depth(line string) int {
	mut depth := 0
	mut pos := 0
	for pos < line.len {
		if line[pos] == `>` {
			depth++
			pos++
			// Skip optional space after >
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

// strip_blockquote_prefix removes all > and leading spaces from a line.
fn strip_blockquote_prefix(line string) string {
	mut pos := 0
	for pos < line.len {
		if line[pos] == `>` {
			pos++
			// Skip optional space after >
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

// get_task_prefix returns task list prefix if line is a task item, none otherwise.
fn get_task_prefix(trimmed string) ?string {
	if trimmed.starts_with('- [ ] ') || trimmed.starts_with('* [ ] ') {
		return '☐ '
	}
	if trimmed.starts_with('- [x] ') || trimmed.starts_with('* [x] ')
		|| trimmed.starts_with('- [X] ') || trimmed.starts_with('* [X] ') {
		return '☑ '
	}
	return none
}

// is_definition_line checks if a line is a definition list value (starts with ": ").
fn is_definition_line(line string) bool {
	trimmed := line.trim_space()
	return trimmed.len > 1 && trimmed[0] == `:` && trimmed[1] == ` `
}

// peek_for_definition checks if the next non-blank line is a definition.
fn peek_for_definition(lines []string, start_idx int) bool {
	for i := start_idx; i < lines.len; i++ {
		trimmed := lines[i].trim_space()
		if trimmed == '' {
			return false
		}
		if is_definition_line(lines[i]) {
			return true
		}
		return false
	}
	return false
}

// collect_definition_content collects continuation lines for a definition value.
// Continuation lines must be indented. Returns content and lines consumed.
fn collect_definition_content(first_content string, lines []string, start_idx int) (string, int) {
	mut consumed := 0
	mut idx := start_idx

	// Check if any continuation lines exist (must be indented, bounded)
	for idx < lines.len && consumed < max_list_continuation_lines {
		next := lines[idx]
		if next.len == 0 {
			break
		}
		// Continuation must start with whitespace but not be a new definition
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

	// Fast path: no continuation
	if consumed == 0 {
		return first_content, 0
	}

	// Build combined content with buffer
	mut buf := []u8{cap: first_content.len + consumed * 40}
	buf << first_content.bytes()
	idx = start_idx
	for _ in 0 .. consumed {
		buf << ` `
		buf << lines[idx].trim_space().bytes()
		idx++
	}
	return buf.bytestr(), consumed
}
