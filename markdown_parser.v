module gui

// markdown_parser.v implements a markdown parser that converts markdown text to RichText.
// It orchestrates the parsing process by delegating to block, inline, table, and metadata modules.

// markdown_to_blocks parses markdown source and returns styled blocks.
fn markdown_to_blocks(source string, style MarkdownStyle) []MarkdownBlock {
	lines := source.split('\n')
	link_defs, abbr_defs, footnote_defs := collect_metadata(lines)

	mut p := MarkdownParser{
		style:         style
		link_defs:     link_defs
		abbr_defs:     abbr_defs
		footnote_defs: footnote_defs
		lines:         lines
		blocks:        []MarkdownBlock{cap: lines.len / 3}
		runs:          []RichTextRun{cap: 20}
	}

	return p.parse()
}

struct MarkdownParser {
	style         MarkdownStyle
	link_defs     map[string]string
	abbr_defs     map[string]string
	footnote_defs map[string]string
	lines         []string
mut:
	blocks             []MarkdownBlock
	runs               []RichTextRun
	i                  int
	in_code_block      bool
	code_fence_char    u8
	code_fence_count   int
	code_fence_lang    string
	code_block_content []string
}

fn (mut p MarkdownParser) parse() []MarkdownBlock {
	for p.i < p.lines.len {
		line := p.lines[p.i]
		trimmed := line.trim_space()

		// Handle code block content
		if p.in_code_block {
			if fence := parse_code_fence(line) {
				if fence.char == p.code_fence_char && fence.count >= p.code_fence_count {
					p.flush_code_block()
					p.i++
					continue
				}
			}
			p.code_block_content << line
			p.i++
			continue
		}

		// Skip metadata definitions
		if p.is_metadata_line(line) {
			p.skip_metadata_continuation()
			p.i++
			continue
		}

		// Try parsing various block types
		if p.try_code_fence(line) {
			continue
		}
		if p.try_horizontal_rule(trimmed) {
			continue
		}
		if p.try_blank_line(trimmed) {
			continue
		}
		if p.try_table() {
			continue
		}
		if p.try_definition_line(line, trimmed) {
			continue
		}
		if p.try_image(line) {
			continue
		}
		if p.try_setext_header(trimmed) {
			continue
		}
		if p.try_blockquote() {
			continue
		}
		if p.try_atx_header(line) {
			continue
		}
		if p.try_list_item() {
			continue
		}
		if p.try_math_block(trimmed) {
			continue
		}
		if p.try_definition_term(trimmed) {
			continue
		}

		// Regular paragraph
		p.handle_paragraph(line)
	}

	p.finalize()
	return p.blocks
}

fn (p MarkdownParser) is_metadata_line(line string) bool {
	return is_footnote_definition(line) || is_link_definition(line)
		|| (line.starts_with('*[') && line.contains(']:'))
}

fn (mut p MarkdownParser) skip_metadata_continuation() {
	if is_footnote_definition(p.lines[p.i]) {
		p.i++
		mut fn_cont := 0
		for p.i < p.lines.len && fn_cont < max_footnote_continuation_lines {
			next := p.lines[p.i]
			if next.len == 0 {
				if p.i + 1 < p.lines.len {
					peek := p.lines[p.i + 1]
					if peek.len > 0 && (peek[0] == ` ` || peek[0] == `\t`) {
						p.i++
						continue
					}
				}
				break
			}
			if next[0] != ` ` && next[0] != `\t` {
				break
			}
			fn_cont++
			p.i++
		}
		p.i-- // Adjust for outer loop increment
	}
}

fn (mut p MarkdownParser) try_code_fence(line string) bool {
	if fence := parse_code_fence(line) {
		p.flush_runs()
		p.in_code_block = true
		p.code_fence_char = fence.char
		p.code_fence_count = fence.count
		p.code_fence_lang = fence.language
		p.i++
		return true
	}
	return false
}

fn (mut p MarkdownParser) flush_code_block() {
	lang_hint := normalize_markdown_code_language_hint(p.code_fence_lang)
	code_text := p.code_block_content.join('\n')
	p.flush_runs()
	if p.code_block_content.len > 0 {
		if lang_hint == 'math' {
			p.blocks << MarkdownBlock{
				is_math:    true
				math_latex: code_text
			}
		} else {
			p.blocks << MarkdownBlock{
				is_code:       true
				code_language: lang_hint
				content:       RichText{
					runs: highlight_fenced_code(code_text, lang_hint, p.style)
				}
			}
		}
	}
	p.code_block_content.clear()
	p.in_code_block = false
	p.code_fence_char = 0
	p.code_fence_count = 0
	p.code_fence_lang = ''
	p.runs << rich_br()
}

fn (mut p MarkdownParser) try_horizontal_rule(trimmed string) bool {
	if is_horizontal_rule(trimmed) {
		p.flush_runs()
		p.blocks << MarkdownBlock{
			is_hr: true
		}
		p.i++
		return true
	}
	return false
}

fn (mut p MarkdownParser) try_blank_line(trimmed string) bool {
	if trimmed == '' {
		if p.runs.len > 0 {
			last_is_br := p.runs.last().text == '\n'
			p.runs << rich_br()
			if !last_is_br {
				p.runs << rich_br()
			}
		}
		p.i++
		return true
	}
	return false
}

fn (mut p MarkdownParser) try_table() bool {
	line := p.lines[p.i]
	trimmed := line.trim_space()
	is_table_start := trimmed.starts_with('|') || is_table_separator(trimmed)
		|| (trimmed.contains('|') && p.i + 1 < p.lines.len
		&& is_table_separator(p.lines[p.i + 1].trim_space()))
	if !is_table_start {
		return false
	}
	mut start_i := p.i
	// Collect consecutive table lines (bounded)
	mut table_lines := []string{cap: 10}
	for start_i < p.lines.len && table_lines.len < max_table_lines {
		tl := p.lines[start_i].trim_space()
		// Collect lines with pipes or separators (entry already validated table start)
		if tl.starts_with('|') || is_table_separator(tl) || tl.contains('|') {
			table_lines << p.lines[start_i]
			start_i++
		} else if tl == '' && table_lines.len > 0 {
			// Blank line ends table
			break
		} else {
			break
		}
	}
	if table_lines.len > 0 {
		parsed_table := parse_markdown_table(table_lines, p.style, p.link_defs, p.footnote_defs)
		p.flush_runs()
		p.blocks << MarkdownBlock{
			is_table:   true
			table_data: parsed_table
			content:    RichText{
				runs: [
					RichTextRun{
						text:  table_lines.join('\n')
						style: p.style.code
					},
				]
			}
		}
		p.i = start_i
		return true
	}
	return false
}

fn (mut p MarkdownParser) try_definition_line(line string, trimmed string) bool {
	if is_definition_line(line) {
		p.flush_runs()
		first_content := trimmed[2..].trim_left(' \t')
		content, consumed := collect_definition_content(first_content, p.lines, p.i + 1)
		mut def_runs := []RichTextRun{cap: 10}
		parse_inline(content, p.style.text, p.style, mut def_runs, p.link_defs, p.footnote_defs,
			0)
		p.blocks << MarkdownBlock{
			is_def_value: true
			content:      RichText{
				runs: def_runs
			}
		}
		p.i += 1 + consumed
		return true
	}
	return false
}

fn (mut p MarkdownParser) try_image(line string) bool {
	if line.starts_with('![') {
		bracket_end := find_closing(line, 2, `]`)
		if bracket_end > 2 && bracket_end + 1 < line.len && line[bracket_end + 1] == `(` {
			paren_end := find_closing(line, bracket_end + 2, `)`)
			if paren_end > bracket_end + 2 {
				p.flush_runs()
				raw := line[bracket_end + 2..paren_end]
				src, w, h := parse_image_src(raw)
				p.blocks << MarkdownBlock{
					is_image:     true
					image_alt:    line[2..bracket_end]
					image_src:    if is_safe_image_path(src) { src } else { '' }
					image_width:  w
					image_height: h
				}
				p.i++
				return true
			}
		}
	}
	return false
}

fn (mut p MarkdownParser) try_setext_header(trimmed string) bool {
	if trimmed.len > 0 && p.i + 1 < p.lines.len && !is_block_start(trimmed) {
		level := is_setext_underline(p.lines[p.i + 1])
		if level > 0 {
			p.flush_runs()
			header_style := if level == 1 { p.style.h1 } else { p.style.h2 }
			p.blocks << parse_header_block(trimmed, level, header_style, p.style, p.link_defs,
				p.footnote_defs)
			p.i += 2
			return true
		}
	}
	return false
}

fn (mut p MarkdownParser) try_blockquote() bool {
	line := p.lines[p.i]
	if !line.starts_with('>') {
		return false
	}
	mut start_i := p.i
	// Use first line's depth as block nesting level
	block_depth := count_blockquote_depth(line)
	mut quote_lines := []string{cap: 10}
	for start_i < p.lines.len && quote_lines.len < max_blockquote_lines {
		q := p.lines[start_i]
		if q.starts_with('>') {
			// Strip all > and spaces at start
			content := strip_blockquote_prefix(q)
			quote_lines << content
			start_i++
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
			parse_inline(ql, p.style.text, p.style, mut quote_runs, p.link_defs, p.footnote_defs,
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
						style: p.style.text
					}
				}
			}
		}
	}
	p.flush_runs()
	p.blocks << MarkdownBlock{
		is_blockquote:    true
		blockquote_depth: block_depth
		content:          RichText{
			runs: quote_runs
		}
	}
	p.i = start_i
	return true
}

fn (mut p MarkdownParser) try_atx_header(line string) bool {
	if !line.starts_with('#') {
		return false
	}
	mut level := 0
	for level < line.len && level < 6 && line[level] == `#` {
		level++
	}
	if level > 0 && (level == line.len || line[level] == ` ` || line[level] == `\t`) {
		header_style := match level {
			1 { p.style.h1 }
			2 { p.style.h2 }
			3 { p.style.h3 }
			4 { p.style.h4 }
			5 { p.style.h5 }
			else { p.style.h6 }
		}
		text := line[level..].trim_left(' \t')
		p.flush_runs()
		p.blocks << parse_header_block(text, level, header_style, p.style, p.link_defs,
			p.footnote_defs)
		p.i++
		return true
	}
	return false
}

fn (mut p MarkdownParser) try_list_item() bool {
	line := p.lines[p.i]
	left_trimmed := line.trim_left(' \t')
	indent := get_indent_level(line)

	// Task list (checked or unchecked)
	if task_prefix := get_task_prefix(left_trimmed) {
		// Task list prefix is always "- [ ] " or "- [x] " (6 bytes)
		task_prefix_len := 6
		content, consumed := collect_list_item_content(left_trimmed[task_prefix_len..],
			p.lines, p.i + 1)
		mut item_runs := []RichTextRun{cap: 10}
		parse_inline(content, p.style.text, p.style, mut item_runs, p.link_defs, p.footnote_defs,
			0)
		p.flush_runs()
		p.blocks << MarkdownBlock{
			is_list:     true
			list_prefix: task_prefix
			list_indent: indent
			content:     RichText{
				runs: item_runs
			}
		}
		p.i += 1 + consumed
		return true
	}

	// Unordered list (with nesting support)
	if left_trimmed.starts_with('- ') || left_trimmed.starts_with('* ')
		|| left_trimmed.starts_with('+ ') {
		content, consumed := collect_list_item_content(left_trimmed[2..], p.lines, p.i + 1)
		mut item_runs := []RichTextRun{cap: 10}
		parse_inline(content, p.style.text, p.style, mut item_runs, p.link_defs, p.footnote_defs,
			0)
		p.flush_runs()
		p.blocks << MarkdownBlock{
			is_list:     true
			list_prefix: '• '
			list_indent: indent
			content:     RichText{
				runs: item_runs
			}
		}
		p.i += 1 + consumed
		return true
	}

	// Ordered list (with nesting support)
	if is_ordered_list(left_trimmed) {
		mut sep_pos := left_trimmed.index('.') or { -1 }
		if sep_pos == -1 {
			sep_pos = left_trimmed.index(')') or { -1 }
		}
		if sep_pos <= 0 {
			return false
		}
		num := left_trimmed[..sep_pos]
		sep := left_trimmed[sep_pos..sep_pos + 1]
		rest := left_trimmed[sep_pos + 1..].trim_left(' ')
		content, consumed := collect_list_item_content(rest, p.lines, p.i + 1)
		mut item_runs := []RichTextRun{cap: 10}
		parse_inline(content, p.style.text, p.style, mut item_runs, p.link_defs, p.footnote_defs,
			0)
		p.flush_runs()
		p.blocks << MarkdownBlock{
			is_list:     true
			list_prefix: '${num}${sep} '
			list_indent: indent
			content:     RichText{
				runs: item_runs
			}
		}
		p.i += 1 + consumed
		return true
	}

	return false
}

fn (mut p MarkdownParser) try_math_block(trimmed string) bool {
	if trimmed.starts_with('$$') {
		p.flush_runs()
		if trimmed.len > 4 && trimmed.ends_with('$$') {
			latex := trimmed[2..trimmed.len - 2].trim_space()
			if latex.len > 0 {
				p.blocks << MarkdownBlock{
					is_math:    true
					math_latex: latex
				}
				p.i++
				return true
			}
		}
		p.i++
		mut math_lines := []string{cap: 64}
		for p.i < p.lines.len && math_lines.len < 200 {
			ml := p.lines[p.i]
			if ml.trim_space() == '$$' {
				break
			}
			math_lines << ml
			p.i++
		}
		if math_lines.len > 0 {
			p.blocks << MarkdownBlock{
				is_math:    true
				math_latex: math_lines.join('\n')
			}
		}
		p.i++
		return true
	}
	return false
}

fn (mut p MarkdownParser) try_definition_term(trimmed string) bool {
	if peek_for_definition(p.lines, p.i + 1) {
		p.flush_runs()
		mut term_runs := []RichTextRun{cap: 10}
		parse_inline(trimmed, p.style.bold, p.style, mut term_runs, p.link_defs, p.footnote_defs,
			0)
		p.blocks << MarkdownBlock{
			is_def_term: true
			content:     RichText{
				runs: term_runs
			}
		}
		p.i++
		return true
	}
	return false
}

fn (mut p MarkdownParser) handle_paragraph(line string) {
	content, consumed := collect_paragraph_content(line, p.lines, p.i + 1)
	parse_inline(content, p.style.text, p.style, mut p.runs, p.link_defs, p.footnote_defs,
		0)
	p.i += 1 + consumed

	if p.i < p.lines.len {
		next := p.lines[p.i]
		next_trimmed := next.trim_space()
		if next_trimmed != '' && is_block_start(next) {
			p.runs << rich_br()
		}
	}
}

fn (mut p MarkdownParser) finalize() {
	if p.in_code_block && p.code_block_content.len > 0 {
		p.flush_code_block()
	}
	p.flush_runs()

	if p.abbr_defs.len > 0 {
		for mut block in p.blocks {
			block.content.runs = replace_abbreviations(block.content.runs, p.abbr_defs,
				p.style)
		}
	}
}

fn (mut p MarkdownParser) flush_runs() {
	trim_trailing_breaks(mut p.runs)
	if p.runs.len > 0 {
		p.blocks << MarkdownBlock{
			content: RichText{
				runs: p.runs
			}
		}
		p.runs = []RichTextRun{cap: 20}
	}
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
