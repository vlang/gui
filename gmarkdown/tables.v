module gmarkdown

// tables.v handles parsing of markdown tables.

// parse_md_table parses raw table lines into structured data.
pub fn parse_md_table(lines []string, link_defs map[string]string, footnote_defs map[string]string) ?MdTable {
	if lines.len < 2 {
		return none
	}
	line0 := lines[0]
	headers := parse_table_row(line0)
	if headers.len == 0 || headers.len > max_table_columns {
		return none
	}
	line1 := lines[1]
	if !is_table_separator(line1.trim_space()) {
		return none
	}
	alignments := parse_table_alignments(line1, headers.len) or { return none }

	mut header_runs := [][]MdRun{cap: headers.len}
	for h in headers {
		mut runs := []MdRun{cap: 4}
		parse_inline(h, .plain, mut runs, link_defs, footnote_defs, 0)
		header_runs << runs
	}

	mut rows := [][][]MdRun{cap: lines.len - 2}
	for i := 2; i < lines.len; i++ {
		row := parse_table_row(lines[i])
		mut normalized := [][]MdRun{len: headers.len, init: []MdRun{}}
		for j, cell in row {
			if j < headers.len {
				mut runs := []MdRun{cap: 4}
				parse_inline(cell, .plain, mut runs, link_defs, footnote_defs, 0)
				normalized[j] = runs
			}
		}
		rows << normalized
	}
	return MdTable{
		headers:    header_runs
		alignments: alignments
		rows:       rows
		col_count:  headers.len
	}
}

// parse_table_row splits a table row by | and trims cells.
pub fn parse_table_row(line string) []string {
	trimmed := line.trim_space()
	mut inner := trimmed
	if inner.starts_with('|') {
		inner = inner[1..]
	}
	if inner.ends_with('|') && !inner.ends_with('\\|') {
		inner = inner[..inner.len - 1]
	}
	mut cells := []string{cap: 8}
	mut current := []u8{cap: inner.len}
	mut i := 0
	for i < inner.len {
		if inner[i] == `\\` && i + 1 < inner.len && inner[i + 1] == `|` {
			current << `|`
			i += 2
		} else if inner[i] == `|` {
			cells << current.bytestr().trim_space()
			current.clear()
			i++
			if cells.len >= max_table_columns {
				break
			}
		} else {
			current << inner[i]
			i++
		}
	}
	if cells.len < max_table_columns {
		cells << current.bytestr().trim_space()
	}
	return cells
}

// parse_table_alignments parses separator row for column alignments.
fn parse_table_alignments(line string, cols int) ?[]MdAlign {
	parts := parse_table_row(line)
	mut aligns := []MdAlign{len: cols, init: MdAlign.start}
	for i, p in parts {
		if i >= cols {
			break
		}
		trimmed := p.trim_space()
		if !trimmed.contains('-') {
			return none
		}
		left_colon := trimmed.starts_with(':')
		right_colon := trimmed.ends_with(':')
		if left_colon && right_colon {
			aligns[i] = .center
		} else if right_colon {
			aligns[i] = .end_
		}
	}
	return aligns
}

// is_table_separator checks if a line is a markdown table separator.
pub fn is_table_separator(s string) bool {
	if s.len < 3 {
		return false
	}
	mut has_dash := false
	mut has_pipe := false
	for c in s {
		if c == `-` || c == `:` {
			has_dash = true
		} else if c == `|` {
			has_pipe = true
		} else if c == ` ` || c == `\x09` {
			continue
		} else {
			return false
		}
	}
	return has_dash && has_pipe
}
