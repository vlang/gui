module gui

// markdown_tables.v handles parsing of markdown tables.

// parse_markdown_table parses raw table markdown into structured data.
fn parse_markdown_table(raw string, style MarkdownStyle, link_defs map[string]string, footnote_defs map[string]string) ?ParsedTable {
	lines := raw.split('
').filter(it.trim_space() != '')
	if lines.len < 2 {
		return none
	}
	// Line 0 = headers
	headers := parse_table_row(lines[0])
	if headers.len == 0 {
		return none
	}
	// Line 1 must be a valid separator row
	if !is_table_separator(lines[1].trim_space()) {
		return none
	}
	// Line 1 = separator with alignments (validates each cell has dash)
	alignments := parse_table_alignments(lines[1], headers.len) or { return none }
	// Parse headers with inline formatting
	mut header_rich := []RichText{cap: headers.len}
	for h in headers {
		mut runs := []RichTextRun{cap: 4}
		parse_inline(h, style.text, style, mut runs, link_defs, footnote_defs)
		header_rich << RichText{
			runs: runs
		}
	}
	// Lines 2+ = data rows
	mut rows := [][]RichText{cap: lines.len - 2}
	for i := 2; i < lines.len; i++ {
		row := parse_table_row(lines[i])
		// Pad or trim to match header count
		mut normalized := []RichText{len: headers.len, init: RichText{}}
		for j, cell in row {
			if j < headers.len {
				mut runs := []RichTextRun{cap: 4}
				parse_inline(cell, style.text, style, mut runs, link_defs, footnote_defs)
				normalized[j] = RichText{
					runs: runs
				}
			}
		}
		rows << normalized
	}
	return ParsedTable{
		headers:    header_rich
		alignments: alignments
		rows:       rows
	}
}

// parse_table_row splits a table row by | and trims cells.
fn parse_table_row(line string) []string {
	trimmed := line.trim_space()
	// Remove outer pipes if present
	mut inner := trimmed
	if inner.starts_with('|') {
		inner = inner[1..]
	}
	if inner.ends_with('|') {
		inner = inner[..inner.len - 1]
	}
	parts := inner.split('|')
	mut cells := []string{cap: parts.len}
	for p in parts {
		cells << p.trim_space()
	}
	return cells
}

// parse_table_alignments parses separator row for column alignments.
// Returns none if any cell is invalid (missing dash).
fn parse_table_alignments(line string, cols int) ?[]HorizontalAlign {
	parts := parse_table_row(line)
	mut aligns := []HorizontalAlign{len: cols, init: HorizontalAlign.start}
	for i, p in parts {
		if i >= cols {
			break
		}
		trimmed := p.trim_space()
		// Each separator cell must contain at least one dash
		if !trimmed.contains('-') {
			return none
		}
		left_colon := trimmed.starts_with(':')
		right_colon := trimmed.ends_with(':')
		if left_colon && right_colon {
			aligns[i] = .center
		} else if right_colon {
			aligns[i] = .end
		}
		// default is .start (left)
	}
	return aligns
}

// is_table_separator checks if a line is a markdown table separator (e.g., |---|---|).
// Expects pre-trimmed input.
fn is_table_separator(s string) bool {
	if s.len < 3 {
		return false
	}
	// Must contain at least --- or | and -
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
	return has_dash || (has_dash && has_pipe)
}
