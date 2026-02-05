module gui

// markdown_metadata.v handles parsing of markdown metadata (links, footnotes, abbreviations).

// collect_link_definitions scans lines for reference link definitions [id]: url "title".
// Returns lowercase id -> url mapping.
fn collect_link_definitions(lines []string) map[string]string {
	mut defs := map[string]string{}
	for line in lines {
		trimmed := line.trim_space()
		// Pattern: [id]: url or [id]: url "title"
		if !trimmed.starts_with('[') {
			continue
		}
		bracket_end := trimmed.index(']:') or { continue }
		if bracket_end < 1 {
			continue
		}
		id := trimmed[1..bracket_end].to_lower()
		rest := trimmed[bracket_end + 2..].trim_left(' 	')
		if rest.len == 0 {
			continue
		}
		// Extract URL (up to space or end)
		mut url_end := rest.len
		for j, c in rest {
			if c == ` ` || c == `\x09` {
				url_end = j
				break
			}
		}
		url := rest[..url_end]
		if url.len > 0 {
			defs[id] = url
		}
	}
	return defs
}

// is_link_definition checks if a line is a reference link definition.
fn is_link_definition(line string) bool {
	trimmed := line.trim_space()
	if !trimmed.starts_with('[') {
		return false
	}
	bracket_end := trimmed.index(']:') or { return false }
	return bracket_end >= 1
}

// collect_abbreviations scans lines for abbreviation definitions *[ABBR]: expansion.
// Returns map of ABBR -> expansion.
fn collect_abbreviations(lines []string) map[string]string {
	mut defs := map[string]string{}
	for line in lines {
		trimmed := line.trim_space()
		if trimmed.starts_with('*[') && trimmed.contains(']:') {
			bracket_end := trimmed.index(']:') or { continue }
			if bracket_end > 2 {
				abbr := trimmed[2..bracket_end]
				expansion := trimmed[bracket_end + 2..].trim_space()
				if abbr.len > 0 && expansion.len > 0 {
					defs[abbr] = expansion
				}
			}
		}
	}
	return defs
}

// collect_footnotes scans lines for footnote definitions [^id]: content.
// Returns map of id -> content.
fn collect_footnotes(lines []string) map[string]string {
	mut defs := map[string]string{}
	mut i := 0
	for i < lines.len {
		line := lines[i]
		trimmed := line.trim_space()
		if is_footnote_definition(line) {
			bracket_end := trimmed.index(']:') or {
				i++
				continue
			}
			id := trimmed[2..bracket_end]
			mut content := trimmed[bracket_end + 2..].trim_left(' 	')

			// Collect continuation lines (indented, bounded)
			i++
			mut fn_cont := 0
			for i < lines.len && fn_cont < max_footnote_continuation_lines {
				next := lines[i]
				if next.len == 0 {
					// Peek ahead for indented continuation
					if i + 1 < lines.len {
						peek := lines[i + 1]
						if peek.len > 0 && (peek[0] == ` ` || peek[0] == `\t`) {
							content += '\n\n'
							i++
							continue
						}
					}
					break
				}
				if next[0] != ` ` && next[0] != `\t` {
					break
				}
				if content.ends_with('\n') {
					content += next.trim_left(' \t')
				} else {
					content += ' ' + next.trim_left(' \t')
				}
				fn_cont++
				i++
			}
			if id.len > 0 && content.len > 0 {
				defs[id] = content
			}
			continue
		}
		i++
	}
	return defs
}

// is_footnote_definition checks if a line is a footnote definition.
fn is_footnote_definition(line string) bool {
	trimmed := line.trim_space()
	if !trimmed.starts_with('[^') {
		return false
	}
	bracket_end := trimmed.index(']:') or { return false }
	return bracket_end >= 3
}

// is_word_boundary checks if char at pos is a word boundary (non-alphanumeric).
fn is_word_boundary(text string, pos int) bool {
	if pos < 0 || pos >= text.len {
		return true
	}
	c := text[pos]
	// alphanumeric = word char
	if (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`) || (c >= `0` && c <= `9`) || c == `_` {
		return false
	}
	return true
}

// replace_abbreviations scans runs for abbreviation occurrences and splits/marks them.
// Uses word boundaries to avoid partial matches.
fn replace_abbreviations(runs []RichTextRun, abbr_defs map[string]string, md_style MarkdownStyle) []RichTextRun {
	if abbr_defs.len == 0 {
		return runs
	}
	mut result := []RichTextRun{cap: runs.len * 2}
	for run in runs {
		// Skip non-text runs (links, code, etc)
		if run.link != '' || run.tooltip != '' {
			result << run
			continue
		}
		result << split_run_for_abbrs(run, abbr_defs, md_style)
	}
	return result
}

// split_run_for_abbrs splits a single run at abbreviation boundaries.
fn split_run_for_abbrs(run RichTextRun, abbr_defs map[string]string, md_style MarkdownStyle) []RichTextRun {
	text := run.text
	if text.len == 0 {
		return [run]
	}
	mut result := []RichTextRun{cap: 4}
	mut pos := 0

	for pos < text.len {
		// Find earliest valid abbreviation match (with word boundaries)
		mut best_start := -1
		mut best_end := -1
		mut best_abbr := ''
		mut best_expansion := ''

		for abbr, expansion in abbr_defs {
			// Search for all occurrences of this abbreviation starting from pos
			mut search_pos := pos
			for search_pos < text.len {
				start := text.index_after(abbr, search_pos) or { break }
				end := start + abbr.len
				// Check word boundaries
				if is_word_boundary(text, start - 1) && is_word_boundary(text, end) {
					// Valid match - check if it's the earliest
					if best_start == -1 || start < best_start {
						best_start = start
						best_end = end
						best_abbr = abbr
						best_expansion = expansion
					}
					break // Found valid match for this abbr
				}
				// Not a valid word boundary, search further
				search_pos = start + 1
			}
		}

		if best_start == -1 {
			// No more matches - add remaining text
			if pos < text.len {
				result << RichTextRun{
					text:  text[pos..]
					style: run.style
				}
			}
			break
		}

		// Add text before abbreviation
		if best_start > pos {
			result << RichTextRun{
				text:  text[pos..best_start]
				style: run.style
			}
		}

		// Add abbreviation run with tooltip and bold style
		result << rich_abbr(best_abbr, best_expansion, run.style)
		pos = best_end
	}

	if result.len == 0 {
		return [run]
	}
	return result
}
