module markdown

// metadata.v handles parsing of markdown metadata
// (links, footnotes, abbreviations).

// collect_metadata scans lines once for all metadata definitions:
// link refs, abbreviations, and footnotes.
pub fn collect_metadata(scanner MdScanner) (map[string]string, map[string]string, map[string]string) {
	mut link_defs := map[string]string{}
	mut abbr_defs := map[string]string{}
	mut footnote_defs := map[string]string{}
	mut i := 0
	for i < scanner.len() {
		line := scanner.get_line(i)
		trimmed := line.trim_space()

		// Abbreviation: *[ABBR]: expansion
		if trimmed.starts_with('*[') && trimmed.contains(']:')
			&& abbr_defs.len < max_abbreviation_defs {
			bracket_end := trimmed.index(']:') or {
				i++
				continue
			}
			if bracket_end > 2 {
				abbr := trimmed[2..bracket_end]
				expansion := trimmed[bracket_end + 2..].trim_space()
				if abbr.len > 0 && expansion.len > 0 {
					abbr_defs[abbr] = expansion
				}
			}
			i++
			continue
		}

		// Footnote: [^id]: content (with continuation)
		if is_footnote_definition(line) && footnote_defs.len < max_footnote_defs {
			bracket_end := trimmed.index(']:') or {
				i++
				continue
			}
			id := trimmed[2..bracket_end]
			mut content := trimmed[bracket_end + 2..].trim_left(' \t')
			i++
			mut fn_cont := 0
			for i < scanner.len() && fn_cont < max_footnote_continuation_lines {
				next := scanner.get_line(i)
				if next.len == 0 {
					if i + 1 < scanner.len() {
						peek := scanner.get_line(i + 1)
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
				footnote_defs[id] = content
			}
			continue
		}

		// Link definition: [id]: url
		if trimmed.starts_with('[') && link_defs.len < max_link_defs {
			bracket_end := trimmed.index(']:') or {
				i++
				continue
			}
			if bracket_end > 1 {
				id := trimmed[1..bracket_end].to_lower()
				rest := trimmed[bracket_end + 2..].trim_left(' \t')
				if rest.len > 0 {
					mut url_end := rest.len
					for j, c in rest {
						if c == ` ` || c == `\x09` {
							url_end = j
							break
						}
					}
					url := rest[..url_end]
					if url.len > 0 {
						link_defs[id] = url
					}
				}
			}
		}
		i++
	}
	return link_defs, abbr_defs, footnote_defs
}

// is_link_definition checks if a line is a reference link definition.
pub fn is_link_definition(line string) bool {
	trimmed := line.trim_space()
	if !trimmed.starts_with('[') {
		return false
	}
	bracket_end := trimmed.index(']:') or { return false }
	return bracket_end > 1
}

// is_footnote_definition checks if a line is a footnote definition.
pub fn is_footnote_definition(line string) bool {
	trimmed := line.trim_space()
	if !trimmed.starts_with('[^') {
		return false
	}
	bracket_end := trimmed.index(']:') or { return false }
	return bracket_end >= 3
}

// is_word_boundary checks if char at pos is a word boundary
// (non-alphanumeric).
pub fn is_word_boundary(text string, pos int) bool {
	if pos < 0 || pos >= text.len {
		return true
	}
	c := text[pos]
	if (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`) || (c >= `0` && c <= `9`) || c == `_` {
		return false
	}
	return true
}

// replace_abbreviations scans runs for abbreviation occurrences
// and splits/marks them with tooltips. Uses word boundaries to
// avoid partial matches.
pub fn replace_abbreviations(runs []MdRun, abbr_defs map[string]string) []MdRun {
	if abbr_defs.len == 0 {
		return runs
	}
	mut sorted_abbrs := abbr_defs.keys()
	sorted_abbrs.sort_with_compare(fn (a &string, b &string) int {
		return b.len - a.len
	})
	mut result := []MdRun{cap: runs.len * 2}
	for run in runs {
		// Skip non-text runs (links, tooltips, math)
		if run.link != '' || run.tooltip != '' || run.math_id != '' {
			result << run
			continue
		}
		result << split_run_for_abbrs(run, sorted_abbrs, abbr_defs)
	}
	return result
}

// split_run_for_abbrs splits a single run at abbreviation
// boundaries.
fn split_run_for_abbrs(run MdRun, sorted_abbrs []string, abbr_defs map[string]string) []MdRun {
	text := run.text
	if text.len == 0 {
		return [run]
	}

	mut first_chars := [256]bool{}
	for abbr in sorted_abbrs {
		if abbr.len > 0 {
			first_chars[abbr[0]] = true
		}
	}

	mut result := []MdRun{cap: 8}
	mut pos := 0
	mut last_pos := 0

	for pos < text.len {
		if !first_chars[text[pos]] {
			pos++
			continue
		}
		mut matched := false
		for abbr in sorted_abbrs {
			if pos + abbr.len <= text.len && text[pos..pos + abbr.len] == abbr {
				if is_word_boundary(text, pos - 1) && is_word_boundary(text, pos + abbr.len) {
					if pos > last_pos {
						result << MdRun{
							...run
							text: text[last_pos..pos]
						}
					}
					expansion := abbr_defs[abbr]
					result << MdRun{
						...run
						text:    abbr
						tooltip: expansion
					}
					pos += abbr.len
					last_pos = pos
					matched = true
					break
				}
			}
		}
		if !matched {
			pos++
		}
	}

	if last_pos < text.len {
		result << MdRun{
			...run
			text: text[last_pos..]
		}
	}

	if result.len == 0 {
		return [run]
	}
	return result
}
