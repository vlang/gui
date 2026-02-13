module gui

// xtra_markdown.v implements a markdown parser that converts markdown text to RichText.
// It orchestrates the parsing process by delegating to block, inline, table, and metadata modules.

// markdown_to_blocks parses markdown source and returns styled blocks.
fn markdown_to_blocks(source string, style MarkdownStyle) []MarkdownBlock {
	lines := source.split('\n')
	link_defs := collect_link_definitions(lines)
	abbr_defs := collect_abbreviations(lines)
	footnote_defs := collect_footnotes(lines)
	mut blocks := []MarkdownBlock{cap: lines.len / 3}
	mut runs := []RichTextRun{cap: 20}
	mut i := 0
	mut in_code_block := false
	mut code_fence_char := u8(0)
	mut code_fence_count := 0
	mut code_fence_lang := ''
	mut code_block_content := []string{}

	for i < lines.len {
		line := lines[i]
		trimmed := line.trim_space()

		// Skip footnote definition lines (metadata) - must check before link definitions
		// since [^id]: matches [*]: pattern
		if !in_code_block && is_footnote_definition(line) {
			// Skip continuation lines (may have blank lines between, bounded)
			i++
			mut fn_cont := 0
			for i < lines.len && fn_cont < max_footnote_continuation_lines {
				next := lines[i]
				if next.len == 0 {
					// Peek ahead for indented continuation
					if i + 1 < lines.len {
						peek := lines[i + 1]
						if peek.len > 0 && (peek[0] == ` ` || peek[0] == `\t`) {
							i++
							continue
						}
					}
					break
				}
				if next[0] != ` ` && next[0] != `\t` {
					break
				}
				fn_cont++
				i++
			}
			continue
		}

		// Skip link definition lines (metadata)
		if !in_code_block && is_link_definition(line) {
			i++
			continue
		}

		// Handle code blocks (``` or ~~~)
		if fence := parse_code_fence(line) {
			if in_code_block && fence.char == code_fence_char && fence.count >= code_fence_count {
				lang_hint := normalize_markdown_code_language_hint(code_fence_lang)
				code_text := code_block_content.join('\n')
				// End code block - flush current runs first, then add code block
				if block := flush_runs(mut runs) {
					blocks << block
				}
				if code_block_content.len > 0 {
					if lang_hint == 'math' {
						blocks << MarkdownBlock{
							is_math:    true
							math_latex: code_text
						}
					} else {
						blocks << MarkdownBlock{
							is_code:       true
							code_language: lang_hint
							content:       RichText{
								runs: highlight_fenced_code(code_text, lang_hint, style)
							}
						}
					}
				}
				code_block_content.clear()
				in_code_block = false
				code_fence_char = 0
				code_fence_count = 0
				code_fence_lang = ''
				// Add leading space for content after code block
				runs << rich_br()
			} else if !in_code_block {
				// Start code block - flush current runs
				if block := flush_runs(mut runs) {
					blocks << block
				}
				in_code_block = true
				code_fence_char = fence.char
				code_fence_count = fence.count
				code_fence_lang = fence.language
			}
			i++
			continue
		}

		if in_code_block {
			code_block_content << line
			i++
			continue
		}

		// Horizontal rule (3+ of same char: ---, ***, ___)
		if is_horizontal_rule(trimmed) {
			// Flush current runs first
			if block := flush_runs(mut runs) {
				blocks << block
			}
			// Add hr as separate block
			blocks << MarkdownBlock{
				is_hr: true
			}
			i++
			continue
		}

		// Blank line = paragraph break (2 newlines total)
		if trimmed == '' {
			if runs.len > 0 {
				// Add breaks to reach 2 total
				last_is_br := runs.last().text == '\n'
				runs << rich_br()
				if !last_is_br {
					runs << rich_br()
				}
			}
			i++
			continue
		}

		// Abbreviation defense: *[ABBR]: skip as metadata
		if line.starts_with('*[') && line.contains(']:') {
			i++
			continue
		}

		// Table recognition
		if t_block, t_consumed := try_parse_table(lines, i, style, link_defs, footnote_defs) {
			if block := flush_runs(mut runs) {
				blocks << block
			}
			blocks << t_block
			i += t_consumed
			continue
		}

		// Definition list value: line starting with ": "
		if is_definition_line(line) {
			// Flush current runs
			if block := flush_runs(mut runs) {
				blocks << block
			}
			// Strip ": " prefix and collect continuation lines
			first_content := trimmed[2..].trim_left(' \t')
			content, consumed := collect_definition_content(first_content, lines, i + 1)
			mut def_runs := []RichTextRun{cap: 10}
			parse_inline(content, style.text, style, mut def_runs, link_defs, footnote_defs,
				0)
			blocks << MarkdownBlock{
				is_def_value: true
				content:      RichText{
					runs: def_runs
				}
			}
			i += 1 + consumed
			continue
		}

		// Image ![alt](path) or ![alt](path =WxH) - must be at start of line
		if line.starts_with('![') {
			bracket_end := line.index(']') or { -1 }
			if bracket_end > 2 && bracket_end + 1 < line.len && line[bracket_end + 1] == `(` {
				paren_end := line.index_after(')', bracket_end + 2) or { -1 }
				if paren_end > bracket_end + 2 {
					// Flush current runs
					if block := flush_runs(mut runs) {
						blocks << block
					}
					raw := line[bracket_end + 2..paren_end]
					src, w, h := parse_image_src(raw)
					blocks << MarkdownBlock{
						is_image:     true
						image_alt:    line[2..bracket_end]
						image_src:    if is_safe_image_path(src) { src } else { '' }
						image_width:  w
						image_height: h
					}
					i++
					continue
				}
			}
		}

		// Setext-style headers (check before ATX and blockquote)
		if trimmed.len > 0 && i + 1 < lines.len && !is_block_start(trimmed) {
			level := is_setext_underline(lines[i + 1])
			if level > 0 {
				if block := flush_runs(mut runs) {
					blocks << block
				}
				header_style := if level == 1 { style.h1 } else { style.h2 }
				blocks << parse_header_block(trimmed, level, header_style, style, link_defs,
					footnote_defs)
				i += 2
				continue
			}
		}

		// Blockquote
		if b_block, b_consumed := try_parse_blockquote(lines, i, style, link_defs, footnote_defs) {
			if block := flush_runs(mut runs) {
				blocks << block
			}
			blocks << b_block
			i += b_consumed
			continue
		}

		// ATX Headers
		if h_block, h_consumed := try_parse_atx_header(line, style, link_defs, footnote_defs) {
			if block := flush_runs(mut runs) {
				blocks << block
			}
			blocks << h_block
			i += h_consumed
			continue
		}

		// List items
		if l_block, l_consumed := try_parse_list_item(lines, i, style, link_defs, footnote_defs) {
			if block := flush_runs(mut runs) {
				blocks << block
			}
			blocks << l_block
			i += l_consumed
			continue
		}

		// Display math: $$ ... $$
		if trimmed.starts_with('$$') {
			if block := flush_runs(mut runs) {
				blocks << block
			}
			// Single-line: $$ E=mc^2 $$
			if trimmed.len > 4 && trimmed.ends_with('$$') {
				latex := trimmed[2..trimmed.len - 2].trim_space()
				if latex.len > 0 {
					blocks << MarkdownBlock{
						is_math:    true
						math_latex: latex
					}
					i++
					continue
				}
			}
			// Multi-line: collect lines between $$ delimiters
			i++
			mut math_lines := []string{cap: 20}
			for i < lines.len && math_lines.len < 200 {
				ml := lines[i]
				if ml.trim_space() == '$$' {
					break
				}
				math_lines << ml
				i++
			}
			if math_lines.len > 0 {
				blocks << MarkdownBlock{
					is_math:    true
					math_latex: math_lines.join('\n')
				}
			}
			i++ // skip closing $$
			continue
		}

		// Check if this is a definition term (next non-blank line starts with ": ")
		if peek_for_definition(lines, i + 1) {
			// Flush current runs
			if block := flush_runs(mut runs) {
				blocks << block
			}
			// Create def_term block with bold styling
			mut term_runs := []RichTextRun{cap: 10}
			parse_inline(trimmed, style.bold, style, mut term_runs, link_defs, footnote_defs,
				0)
			blocks << MarkdownBlock{
				is_def_term: true
				content:     RichText{
					runs: term_runs
				}
			}
			i++
			continue
		}

		// Regular paragraph - collect continuation lines first
		content, consumed := collect_paragraph_content(line, lines, i + 1)
		parse_inline(content, style.text, style, mut runs, link_defs, footnote_defs, 0)
		i += 1 + consumed

		// Add line break if block element follows
		if i < lines.len {
			next := lines[i]
			next_trimmed := next.trim_space()
			if next_trimmed != '' && is_block_start(next) {
				runs << rich_br()
			}
		}
	}

	// Handle unclosed code block
	if in_code_block && code_block_content.len > 0 {
		lang_hint := normalize_markdown_code_language_hint(code_fence_lang)
		code_text := code_block_content.join('\n')
		if block := flush_runs(mut runs) {
			blocks << block
		}
		blocks << MarkdownBlock{
			is_code:       true
			code_language: lang_hint
			content:       RichText{
				runs: highlight_fenced_code(code_text, lang_hint, style)
			}
		}
	}

	// Flush remaining runs
	if block := flush_runs(mut runs) {
		blocks << block
	}

	// Post-processing: replace abbreviations in all text runs
	if abbr_defs.len > 0 {
		for mut block in blocks {
			block.content.runs = replace_abbreviations(block.content.runs, abbr_defs,
				style)
		}
	}

	return blocks
}

// markdown_to_rich_text parses markdown and returns a single RichText object.
// Useful for small snippets where block-level layout is not needed.
pub fn markdown_to_rich_text(source string, style MarkdownStyle) RichText {
	blocks := markdown_to_blocks(source, style)
	mut all_runs := []RichTextRun{}
	for i, block in blocks {
		all_runs << block.content.runs
		// Add block spacing between blocks
		if i < blocks.len - 1 {
			all_runs << rich_br()
		}
	}
	return RichText{
		runs: all_runs
	}
}

// flush_runs creates a block from accumulated runs and clears state.
fn flush_runs(mut runs []RichTextRun) ?MarkdownBlock {
	trim_trailing_breaks(mut runs)
	if runs.len == 0 {
		return none
	}
	block := MarkdownBlock{
		content: RichText{
			runs: runs
		}
	}
	runs = []RichTextRun{cap: 20}
	return block
}

// parse_code_fence checks if line is a code fence (``` or ~~~).
// Returns fence info or none. Extracts language hint after fence chars.
fn parse_code_fence(line string) ?CodeFence {
	trimmed := line.trim_left(' \t')
	if trimmed.len < 3 {
		return none
	}
	c := trimmed[0]
	if c != `\`` && c != `~` {
		return none
	}
	mut count := 0
	for ch in trimmed {
		if ch == c {
			count++
		} else {
			break
		}
	}
	if count >= 3 {
		// Extract language hint after fence chars
		lang := trimmed[count..].trim_space()
		return CodeFence{
			char:     c
			count:    count
			language: lang
		}
	}
	return none
}

// try_parse_blockquote checks if line starts a blockquote.
// Returns (block, consumed_lines) if matched, else none.
fn try_parse_blockquote(lines []string, start_idx int, style MarkdownStyle, link_defs map[string]string, footnote_defs map[string]string) ?(MarkdownBlock, int) {
	line := lines[start_idx]
	if !line.starts_with('>') {
		return none
	}
	mut i := start_idx
	// Count initial depth and collect consecutive blockquote lines (bounded)
	mut max_depth := count_blockquote_depth(line)
	mut quote_lines := []string{cap: 10}
	for i < lines.len && quote_lines.len < max_blockquote_lines {
		q := lines[i]
		if q.starts_with('>') {
			depth := count_blockquote_depth(q)
			if depth > max_depth {
				max_depth = depth
			}
			// Strip all > and spaces at start
			content := strip_blockquote_prefix(q)
			quote_lines << content
			i++
		} else {
			break
		}
	}
	mut quote_runs := []RichTextRun{cap: 20}
	for qi, ql in quote_lines {
		// Skip blank lines but keep them as line breaks
		if ql.trim_space() == '' {
			quote_runs << rich_br()
		} else {
			parse_inline(ql, style.text, style, mut quote_runs, link_defs, footnote_defs,
				0)
			if qi < quote_lines.len - 1 {
				next_ql := quote_lines[qi + 1]
				if next_ql.trim_space() == '' {
					// Next line is blank - paragraph break coming
					quote_runs << rich_br()
				} else {
					// Continuation of paragraph - add space
					quote_runs << RichTextRun{
						text:  ' '
						style: style.text
					}
				}
			}
		}
	}
	return MarkdownBlock{
		is_blockquote:    true
		blockquote_depth: max_depth
		content:          RichText{
			runs: quote_runs
		}
	}, i - start_idx
}

// try_parse_list_item checks if line is a list item (task, unordered, or ordered).
// Returns (block, consumed_lines) if matched, else none.
fn try_parse_list_item(lines []string, start_idx int, style MarkdownStyle, link_defs map[string]string, footnote_defs map[string]string) ?(MarkdownBlock, int) {
	line := lines[start_idx]
	left_trimmed := line.trim_left(' \t')
	indent := get_indent_level(line)

	// Task list (checked or unchecked)
	if task_prefix := get_task_prefix(left_trimmed) {
		// Task list prefix is always "- [ ] " or "- [x] " (6 bytes)
		task_prefix_len := 6
		content, consumed := collect_list_item_content(left_trimmed[task_prefix_len..],
			lines, start_idx + 1)
		mut item_runs := []RichTextRun{cap: 10}
		parse_inline(content, style.text, style, mut item_runs, link_defs, footnote_defs,
			0)
		return MarkdownBlock{
			is_list:     true
			list_prefix: task_prefix
			list_indent: indent
			content:     RichText{
				runs: item_runs
			}
		}, 1 + consumed
	}

	// Unordered list (with nesting support)
	if left_trimmed.starts_with('- ') || left_trimmed.starts_with('* ')
		|| left_trimmed.starts_with('+ ') {
		content, consumed := collect_list_item_content(left_trimmed[2..], lines, start_idx + 1)
		mut item_runs := []RichTextRun{cap: 10}
		parse_inline(content, style.text, style, mut item_runs, link_defs, footnote_defs,
			0)
		return MarkdownBlock{
			is_list:     true
			list_prefix: '• '
			list_indent: indent
			content:     RichText{
				runs: item_runs
			}
		}, 1 + consumed
	}

	// Ordered list (with nesting support)
	if is_ordered_list(left_trimmed) {
		dot_pos := left_trimmed.index('.') or { 0 }
		num := left_trimmed[..dot_pos]
		rest := left_trimmed[dot_pos + 1..].trim_left(' ')
		content, consumed := collect_list_item_content(rest, lines, start_idx + 1)
		mut item_runs := []RichTextRun{cap: 10}
		parse_inline(content, style.text, style, mut item_runs, link_defs, footnote_defs,
			0)
		return MarkdownBlock{
			is_list:     true
			list_prefix: '${num}. '
			list_indent: indent
			content:     RichText{
				runs: item_runs
			}
		}, 1 + consumed
	}

	return none
}

// try_parse_table checks if lines starting at idx form a markdown table.
// Returns (block, consumed_lines) if matched, else none.
fn try_parse_table(lines []string, start_idx int, style MarkdownStyle, link_defs map[string]string, footnote_defs map[string]string) ?(MarkdownBlock, int) {
	line := lines[start_idx]
	trimmed := line.trim_space()
	is_table_start := trimmed.starts_with('|') || is_table_separator(trimmed)
		|| (trimmed.contains('|') && start_idx + 1 < lines.len
		&& is_table_separator(lines[start_idx + 1].trim_space()))
	if !is_table_start {
		return none
	}
	mut i := start_idx
	// Collect consecutive table lines (bounded)
	mut table_lines := []string{cap: 10}
	for i < lines.len && table_lines.len < max_table_lines {
		tl := lines[i].trim_space()
		// Collect lines with pipes or separators (entry already validated table start)
		if tl.starts_with('|') || is_table_separator(tl) || tl.contains('|') {
			table_lines << lines[i]
			i++
		} else if tl == '' && table_lines.len > 0 {
			// Blank line ends table
			break
		} else {
			break
		}
	}
	if table_lines.len > 0 {
		raw_table := table_lines.join('\n')
		parsed_table := parse_markdown_table(raw_table, style, link_defs, footnote_defs)
		return MarkdownBlock{
			is_table:   true
			table_data: parsed_table
			content:    RichText{
				runs: [
					RichTextRun{
						text:  raw_table
						style: style.code
					},
				]
			}
		}, i - start_idx
	}
	return none
}

// try_parse_atx_header checks if line is an ATX-style header (# h1).
// Returns (block, consumed_lines) if matched, else none.
fn try_parse_atx_header(line string, style MarkdownStyle, link_defs map[string]string, footnote_defs map[string]string) ?(MarkdownBlock, int) {
	if !line.starts_with('#') {
		return none
	}
	mut level := 0
	for level < line.len && level < 6 && line[level] == `#` {
		level++
	}
	if level > 0 && (level == line.len || line[level] == ` ` || line[level] == `\t`) {
		header_style := match level {
			1 { style.h1 }
			2 { style.h2 }
			3 { style.h3 }
			4 { style.h4 }
			5 { style.h5 }
			else { style.h6 }
		}
		text := line[level..].trim_left(' \t')
		return parse_header_block(text, level, header_style, style, link_defs, footnote_defs), 1
	}
	return none
}

// detect_code_block_state scans from start to idx to determine code block state.
fn detect_code_block_state(lines []string, idx int) CodeBlockState {
	mut in_block := false
	mut fence_char := u8(0)
	mut fence_count := 0

	for i := 0; i < idx && i < lines.len; i++ {
		if fence := parse_code_fence(lines[i]) {
			if !in_block {
				// Opening fence
				in_block = true
				fence_char = fence.char
				fence_count = fence.count
			} else if fence.char == fence_char && fence.count >= fence_count {
				// Matching closing fence
				in_block = false
				fence_char = 0
				fence_count = 0
			}
			// Non-matching fence inside block: ignored
		}
	}
	return CodeBlockState{
		in_code_block: in_block
		fence_char:    fence_char
		fence_count:   fence_count
	}
}
