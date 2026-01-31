module gui

// xtra_markdown.v implements a markdown parser that converts markdown text to RichText.

// Bounds for multi-line constructs (self-synchronization limits)
const max_blockquote_lines = 100
const max_table_lines = 500
const max_list_continuation_lines = 50
const max_footnote_continuation_lines = 20
const max_paragraph_continuation_lines = 100

// CodeBlockState tracks whether we're inside a fenced code block.
struct CodeBlockState {
	in_code_block bool
	fence_char    u8
	fence_count   int
}

// CodeFence represents a parsed code fence line.
struct CodeFence {
	char  u8
	count int
}

// parse_code_fence checks if line is a code fence (``` or ~~~).
// Returns fence info or none.
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
		return CodeFence{
			char:  c
			count: count
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

// MarkdownBlock represents a parsed block of markdown content.
struct MarkdownBlock {
	header_level     int // 0=not header, 1-6 for h1-h6
	is_code          bool
	is_hr            bool
	is_blockquote    bool
	is_image         bool
	is_table         bool
	is_list          bool
	is_def_term      bool // definition list term
	is_def_value     bool // definition list value
	blockquote_depth int
	list_prefix      string // "• ", "1. ", "☐ ", "☑ "
	list_indent      int    // nesting level (0, 1, 2...)
	image_src        string
	image_alt        string
	image_width      f32 // 0 = auto
	image_height     f32 // 0 = auto
	content          RichText
	table_data       ?ParsedTable // parsed table with inline formatting
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
				// End code block - flush current runs first, then add code block
				if block := flush_runs(mut runs) {
					blocks << block
				}
				if code_block_content.len > 0 {
					blocks << MarkdownBlock{
						is_code: true
						content: RichText{
							runs: [
								RichTextRun{
									text:  code_block_content.join('\n')
									style: style.code
								},
							]
						}
					}
				}
				code_block_content.clear()
				in_code_block = false
				code_fence_char = 0
				code_fence_count = 0
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

		// Table recognition: lines starting with | or separator rows
		// Also recognize table start if current line has | and next is separator
		is_table_start := trimmed.starts_with('|') || is_table_separator(trimmed)
			|| (trimmed.contains('|') && i + 1 < lines.len
			&& is_table_separator(lines[i + 1].trim_space()))
		if is_table_start {
			// Flush current runs
			if block := flush_runs(mut runs) {
				blocks << block
			}
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
				blocks << MarkdownBlock{
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
				}
			}
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
			parse_inline(content, style.text, style, mut def_runs, link_defs, footnote_defs)
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
		if line.starts_with('>') {
			// Flush current runs
			if block := flush_runs(mut runs) {
				blocks << block
			}
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
					parse_inline(ql, style.text, style, mut quote_runs, link_defs, footnote_defs)
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
			blocks << MarkdownBlock{
				is_blockquote:    true
				blockquote_depth: max_depth
				content:          RichText{
					runs: quote_runs
				}
			}
			continue
		}

		// Headers
		if line.starts_with('######') {
			if block := flush_runs(mut runs) {
				blocks << block
			}
			blocks << parse_header_block(line[6..].trim_left(' '), 6, style.h6, style,
				link_defs, footnote_defs)
			i++
			continue
		}
		if line.starts_with('#####') {
			if block := flush_runs(mut runs) {
				blocks << block
			}
			blocks << parse_header_block(line[5..].trim_left(' '), 5, style.h5, style,
				link_defs, footnote_defs)
			i++
			continue
		}
		if line.starts_with('####') {
			if block := flush_runs(mut runs) {
				blocks << block
			}
			blocks << parse_header_block(line[4..].trim_left(' '), 4, style.h4, style,
				link_defs, footnote_defs)
			i++
			continue
		}
		if line.starts_with('###') {
			if block := flush_runs(mut runs) {
				blocks << block
			}
			blocks << parse_header_block(line[3..].trim_left(' '), 3, style.h3, style,
				link_defs, footnote_defs)
			i++
			continue
		}
		if line.starts_with('##') {
			if block := flush_runs(mut runs) {
				blocks << block
			}
			blocks << parse_header_block(line[2..].trim_left(' '), 2, style.h2, style,
				link_defs, footnote_defs)
			i++
			continue
		}
		if line.starts_with('#') {
			if block := flush_runs(mut runs) {
				blocks << block
			}
			blocks << parse_header_block(line[1..].trim_left(' '), 1, style.h1, style,
				link_defs, footnote_defs)
			i++
			continue
		}

		// List items
		left_trimmed := line.trim_left(' \t')
		indent := get_indent_level(line)

		// Task list (checked or unchecked)
		if task_prefix := get_task_prefix(left_trimmed) {
			if block := flush_runs(mut runs) {
				blocks << block
			}
			content, consumed := collect_list_item_content(left_trimmed[6..], lines, i + 1)
			mut item_runs := []RichTextRun{cap: 10}
			parse_inline(content, style.text, style, mut item_runs, link_defs, footnote_defs)
			blocks << MarkdownBlock{
				is_list:     true
				list_prefix: task_prefix
				list_indent: indent
				content:     RichText{
					runs: item_runs
				}
			}
			i += 1 + consumed
			continue
		}

		// Unordered list (with nesting support)
		if left_trimmed.starts_with('- ') || left_trimmed.starts_with('* ')
			|| left_trimmed.starts_with('+ ') {
			// Flush any pending runs before list item
			if block := flush_runs(mut runs) {
				blocks << block
			}
			content, consumed := collect_list_item_content(left_trimmed[2..], lines, i + 1)
			mut item_runs := []RichTextRun{cap: 10}
			parse_inline(content, style.text, style, mut item_runs, link_defs, footnote_defs)
			blocks << MarkdownBlock{
				is_list:     true
				list_prefix: '• '
				list_indent: indent
				content:     RichText{
					runs: item_runs
				}
			}
			i += 1 + consumed
			continue
		}

		// Ordered list (with nesting support)
		if is_ordered_list(left_trimmed) {
			// Flush any pending runs before list item
			if block := flush_runs(mut runs) {
				blocks << block
			}
			dot_pos := left_trimmed.index('.') or { 0 }
			num := left_trimmed[..dot_pos]
			rest := left_trimmed[dot_pos + 1..].trim_left(' ')
			content, consumed := collect_list_item_content(rest, lines, i + 1)
			mut item_runs := []RichTextRun{cap: 10}
			parse_inline(content, style.text, style, mut item_runs, link_defs, footnote_defs)
			blocks << MarkdownBlock{
				is_list:     true
				list_prefix: '${num}. '
				list_indent: indent
				content:     RichText{
					runs: item_runs
				}
			}
			i += 1 + consumed
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
			parse_inline(trimmed, style.bold, style, mut term_runs, link_defs, footnote_defs)
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
		parse_inline(content, style.text, style, mut runs, link_defs, footnote_defs)
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
		if block := flush_runs(mut runs) {
			blocks << block
		}
		blocks << MarkdownBlock{
			is_code: true
			content: RichText{
				runs: [
					RichTextRun{
						text:  code_block_content.join('\n')
						style: style.code
					},
				]
			}
		}
	}

	// Flush remaining runs
	if block := flush_runs(mut runs) {
		blocks << block
	}

	// Post-process: apply abbreviation replacements to all blocks (except code)
	if abbr_defs.len > 0 {
		for j, block in blocks {
			if block.is_code {
				continue
			}
			if block.is_table {
				// Apply abbreviations to table cells
				if tbl := block.table_data {
					mut new_headers := []RichText{cap: tbl.headers.len}
					for h in tbl.headers {
						new_headers << RichText{
							runs: replace_abbreviations(h.runs, abbr_defs, style)
						}
					}
					mut new_rows := [][]RichText{cap: tbl.rows.len}
					for row in tbl.rows {
						mut new_row := []RichText{cap: row.len}
						for cell in row {
							new_row << RichText{
								runs: replace_abbreviations(cell.runs, abbr_defs, style)
							}
						}
						new_rows << new_row
					}
					blocks[j] = MarkdownBlock{
						...block
						table_data: ParsedTable{
							headers:    new_headers
							alignments: tbl.alignments
							rows:       new_rows
						}
					}
				}
				continue
			}
			blocks[j] = MarkdownBlock{
				...block
				content: RichText{
					runs: replace_abbreviations(block.content.runs, abbr_defs, style)
				}
			}
		}
	}

	return blocks
}

// markdown_to_rich_text parses markdown source and returns styled RichText (legacy).
pub fn markdown_to_rich_text(source string, style MarkdownStyle) RichText {
	blocks := markdown_to_blocks(source, style)
	mut all_runs := []RichTextRun{}
	for block in blocks {
		all_runs << block.content.runs
	}
	return RichText{
		runs: all_runs
	}
}

// parse_header_block creates a header block with the given level.
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

// parse_inline parses inline markdown (bold, italic, code, links, footnotes).
fn parse_inline(text string, base_style TextStyle, md_style MarkdownStyle, mut runs []RichTextRun, link_defs map[string]string, footnote_defs map[string]string) {
	mut pos := 0
	mut current := []u8{cap: text.len}

	for pos < text.len {
		// Escape character: backslash makes next char literal
		if text[pos] == `\\` && pos + 1 < text.len {
			current << text[pos + 1]
			pos += 2
			continue
		}

		// Check for inline code
		if text[pos] == `\`` {
			if current.len > 0 {
				runs << RichTextRun{
					text:  current.bytestr()
					style: base_style
				}
				current.clear()
			}
			end := find_closing(text, pos + 1, `\``)
			if end > pos + 1 {
				runs << RichTextRun{
					text:  text[pos + 1..end]
					style: md_style.code
				}
				pos = end + 1
				continue
			}
		}

		// Check for bold+italic (***text***)
		if pos + 2 < text.len && text[pos] == `*` && text[pos + 1] == `*` && text[pos + 2] == `*` {
			end := find_triple_closing(text, pos + 3, `*`)
			if end > pos + 3 {
				if current.len > 0 {
					runs << RichTextRun{
						text:  current.bytestr()
						style: base_style
					}
					current.clear()
				}
				bi_style := TextStyle{
					...md_style.bold_italic
					size: base_style.size
				}
				parse_inline(text[pos + 3..end], bi_style, md_style, mut runs, link_defs,
					footnote_defs)
				pos = end + 3
				continue
			}
		}

		// Check for bold (**text**)
		if pos + 1 < text.len && text[pos] == `*` && text[pos + 1] == `*` {
			end := find_double_closing(text, pos + 2, `*`)
			if end > pos + 2 {
				if current.len > 0 {
					runs << RichTextRun{
						text:  current.bytestr()
						style: base_style
					}
					current.clear()
				}
				bold_style := TextStyle{
					...md_style.bold
					size: base_style.size
				}
				parse_inline(text[pos + 2..end], bold_style, md_style, mut runs, link_defs,
					footnote_defs)
				pos = end + 2
				continue
			}
		}

		// Check for strikethrough (~~text~~)
		if pos + 1 < text.len && text[pos] == `~` && text[pos + 1] == `~` {
			if current.len > 0 {
				runs << RichTextRun{
					text:  current.bytestr()
					style: base_style
				}
				current.clear()
			}
			end := find_double_closing(text, pos + 2, `~`)
			if end > pos + 2 {
				strike_style := TextStyle{
					...base_style
					strikethrough: true
				}
				parse_inline(text[pos + 2..end], strike_style, md_style, mut runs, link_defs,
					footnote_defs)
				pos = end + 2
				continue
			}
		}

		// Check for italic (*text*)
		if text[pos] == `*` {
			end := find_closing(text, pos + 1, `*`)
			if end > pos + 1 {
				if current.len > 0 {
					runs << RichTextRun{
						text:  current.bytestr()
						style: base_style
					}
					current.clear()
				}
				italic_style := TextStyle{
					...md_style.italic
					size: base_style.size
				}
				parse_inline(text[pos + 1..end], italic_style, md_style, mut runs, link_defs,
					footnote_defs)
				pos = end + 1
				continue
			}
		}

		// Check for bold+italic (___text___)
		if pos + 2 < text.len && text[pos] == `_` && text[pos + 1] == `_` && text[pos + 2] == `_` {
			end := find_triple_closing(text, pos + 3, `_`)
			if end > pos + 3 {
				if current.len > 0 {
					runs << RichTextRun{
						text:  current.bytestr()
						style: base_style
					}
					current.clear()
				}
				bi_style := TextStyle{
					...md_style.bold_italic
					size: base_style.size
				}
				parse_inline(text[pos + 3..end], bi_style, md_style, mut runs, link_defs,
					footnote_defs)
				pos = end + 3
				continue
			}
		}

		// Check for bold (__text__)
		if pos + 1 < text.len && text[pos] == `_` && text[pos + 1] == `_` {
			end := find_double_closing(text, pos + 2, `_`)
			if end > pos + 2 {
				if current.len > 0 {
					runs << RichTextRun{
						text:  current.bytestr()
						style: base_style
					}
					current.clear()
				}
				bold_style := TextStyle{
					...md_style.bold
					size: base_style.size
				}
				parse_inline(text[pos + 2..end], bold_style, md_style, mut runs, link_defs,
					footnote_defs)
				pos = end + 2
				continue
			}
		}

		// Check for italic (_text_)
		if text[pos] == `_` {
			end := find_closing(text, pos + 1, `_`)
			if end > pos + 1 {
				if current.len > 0 {
					runs << RichTextRun{
						text:  current.bytestr()
						style: base_style
					}
					current.clear()
				}
				italic_style := TextStyle{
					...md_style.italic
					size: base_style.size
				}
				parse_inline(text[pos + 1..end], italic_style, md_style, mut runs, link_defs,
					footnote_defs)
				pos = end + 1
				continue
			}
		}

		// Check for autolinks <url> or <email>
		if text[pos] == `<` {
			end := find_closing(text, pos + 1, `>`)
			if end > pos + 1 {
				inner := text[pos + 1..end]
				// Check if it's a URL or email
				if inner.starts_with('http://') || inner.starts_with('https://')
					|| inner.contains('@') {
					if current.len > 0 {
						runs << RichTextRun{
							text:  current.bytestr()
							style: base_style
						}
						current.clear()
					}
					link_url := if inner.contains('@') && !inner.contains('://') {
						'mailto:${inner}'
					} else {
						inner
					}
					safe_link := if is_safe_url(link_url) { link_url } else { '' }
					runs << RichTextRun{
						text:  inner
						link:  safe_link
						style: TextStyle{
							...base_style
							color:     if safe_link != '' {
								md_style.link_color
							} else {
								base_style.color
							}
							underline: safe_link != ''
						}
					}
					pos = end + 1
					continue
				}
			}
		}

		// Check for links [text](url) or reference links [text][ref], [text][], [text]
		if text[pos] == `[` {
			// Footnote: [^id] -> styled marker with tooltip
			if pos + 1 < text.len && text[pos + 1] == `^` {
				// Find closing ]
				fn_end := find_closing(text, pos + 2, `]`)
				if fn_end > pos + 2 {
					footnote_id := text[pos + 2..fn_end]
					if content := footnote_defs[footnote_id] {
						// Flush current text
						if current.len > 0 {
							runs << RichTextRun{
								text:  current.bytestr()
								style: base_style
							}
							current.clear()
						}
						runs << rich_footnote(footnote_id, content, base_style, md_style)
						pos = fn_end + 1
						continue
					}
				}
				// Undefined footnote - treat as literal
				current << text[pos]
				pos++
				continue
			}
			bracket_end := find_closing(text, pos + 1, `]`)
			if bracket_end > pos + 1 {
				link_text := text[pos + 1..bracket_end]
				// Check for standard link [text](url)
				if bracket_end + 1 < text.len && text[bracket_end + 1] == `(` {
					paren_end := find_closing(text, bracket_end + 2, `)`)
					if paren_end > bracket_end + 2 {
						if current.len > 0 {
							runs << RichTextRun{
								text:  current.bytestr()
								style: base_style
							}
							current.clear()
						}
						link_url := text[bracket_end + 2..paren_end]
						safe_link := if is_safe_url(link_url) { link_url } else { '' }
						runs << RichTextRun{
							text:  link_text
							link:  safe_link
							style: TextStyle{
								...base_style
								color:     if safe_link != '' {
									md_style.link_color
								} else {
									base_style.color
								}
								underline: safe_link != ''
							}
						}
						pos = paren_end + 1
						continue
					}
				}
				// Check for reference link [text][ref] or [text][]
				if bracket_end + 1 < text.len && text[bracket_end + 1] == `[` {
					ref_end := find_closing(text, bracket_end + 2, `]`)
					if ref_end >= bracket_end + 2 {
						ref_id := if ref_end == bracket_end + 2 {
							link_text.to_lower() // implicit [text][]
						} else {
							text[bracket_end + 2..ref_end].to_lower()
						}
						if url := link_defs[ref_id] {
							safe_link := if is_safe_url(url) { url } else { '' }
							if current.len > 0 {
								runs << RichTextRun{
									text:  current.bytestr()
									style: base_style
								}
								current.clear()
							}
							runs << RichTextRun{
								text:  link_text
								link:  safe_link
								style: TextStyle{
									...base_style
									color:     if safe_link != '' {
										md_style.link_color
									} else {
										base_style.color
									}
									underline: safe_link != ''
								}
							}
							pos = ref_end + 1
							continue
						}
					}
				}
				// Check for shortcut reference link [text]
				shortcut_id := link_text.to_lower()
				if url := link_defs[shortcut_id] {
					safe_link := if is_safe_url(url) { url } else { '' }
					if current.len > 0 {
						runs << RichTextRun{
							text:  current.bytestr()
							style: base_style
						}
						current.clear()
					}
					runs << RichTextRun{
						text:  link_text
						link:  safe_link
						style: TextStyle{
							...base_style
							color:     if safe_link != '' {
								md_style.link_color
							} else {
								base_style.color
							}
							underline: safe_link != ''
						}
					}
					pos = bracket_end + 1
					continue
				}
			}
			// Fallthrough: treat [ as literal
			current << text[pos]
			pos++
			continue
		}

		current << text[pos]
		pos++
	}

	if current.len > 0 {
		runs << RichTextRun{
			text:  current.bytestr()
			style: base_style
		}
	}
}

// find_closing finds the position of a closing character.
// For ] and ) it skips backtick spans to handle links like [`code`](url).
fn find_closing(text string, start int, ch u8) int {
	skip_backticks := ch == `]` || ch == `)`
	mut i := start
	for i < text.len {
		// Skip backtick spans when searching for link delimiters
		if skip_backticks && text[i] == `\`` {
			i++
			for i < text.len && text[i] != `\`` {
				i++
			}
			if i < text.len {
				i++ // skip closing backtick
			}
			continue
		}
		if text[i] == ch {
			return i
		}
		i++
	}
	return -1
}

// find_double_closing finds the position of double closing characters (e.g., **).
fn find_double_closing(text string, start int, ch u8) int {
	for i := start; i < text.len - 1; i++ {
		if text[i] == ch && text[i + 1] == ch {
			return i
		}
	}
	return -1
}

// find_triple_closing finds the position of triple closing characters (e.g., ***).
fn find_triple_closing(text string, start int, ch u8) int {
	for i := start; i < text.len - 2; i++ {
		if text[i] == ch && text[i + 1] == ch && text[i + 2] == ch {
			return i
		}
	}
	return -1
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

// trim_trailing_breaks removes excess trailing newline runs, keeping at most one.
fn trim_trailing_breaks(mut runs []RichTextRun) {
	// Count trailing newlines
	mut count := 0
	for i := runs.len - 1; i >= 0; i-- {
		if runs[i].text == '\n' {
			count++
		} else {
			break
		}
	}
	// Remove all but one
	for count > 1 {
		runs.pop()
		count--
	}
}

// get_indent_level counts leading whitespace and returns indent level (2 spaces or 1 tab = 1 level).
fn get_indent_level(line string) int {
	mut spaces := 0
	for c in line {
		if c == ` ` {
			spaces++
		} else if c == `\t` {
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
		if next.len == 0 || (next[0] != ` ` && next[0] != `\t`) {
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

// ParsedTable represents a parsed markdown table.
struct ParsedTable {
	headers    []RichText
	alignments []HorizontalAlign
	rows       [][]RichText
}

// parse_markdown_table parses raw table markdown into structured data.
fn parse_markdown_table(raw string, style MarkdownStyle, link_defs map[string]string, footnote_defs map[string]string) ?ParsedTable {
	lines := raw.split('\n').filter(it.trim_space() != '')
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
		if c == `-` {
			has_dash = true
		} else if c == `|` {
			has_pipe = true
		} else if c != `:` && c != ` ` {
			return false
		}
	}
	return has_dash && has_pipe
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
		rest := trimmed[bracket_end + 2..].trim_left(' \t')
		if rest.len == 0 {
			continue
		}
		// Extract URL (up to space or end)
		mut url_end := rest.len
		for j, c in rest {
			if c == ` ` || c == `\t` {
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
		if next[0] != ` ` && next[0] != `\t` {
			break
		}
		next_trimmed := next.trim_space()
		if next_trimmed == '' || is_block_start(next) || is_definition_line(next) {
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

// collect_abbreviations scans lines for abbreviation definitions *[ABBR]: expansion.
// Returns case-sensitive abbr -> expansion mapping.
fn collect_abbreviations(lines []string) map[string]string {
	mut defs := map[string]string{}
	for line in lines {
		trimmed := line.trim_space()
		// Pattern: *[ABBR]: expansion
		if !trimmed.starts_with('*[') {
			continue
		}
		bracket_end := trimmed.index(']:') or { continue }
		if bracket_end < 2 {
			continue
		}
		abbr := trimmed[2..bracket_end]
		expansion := trimmed[bracket_end + 2..].trim_left(' \t')
		if abbr.len > 0 && expansion.len > 0 {
			defs[abbr] = expansion
		}
	}
	return defs
}

// collect_footnotes scans lines for footnote definitions [^id]: text.
// Returns id -> content mapping, including continuation lines.
// Blank lines between paragraphs preserved as \n\n, multiple blanks collapsed.
fn collect_footnotes(lines []string) map[string]string {
	mut defs := map[string]string{}
	mut i := 0
	for i < lines.len {
		line := lines[i]
		trimmed := line.trim_space()
		// Pattern: [^id]: text
		if !trimmed.starts_with('[^') {
			i++
			continue
		}
		bracket_end := trimmed.index(']:') or {
			i++
			continue
		}
		if bracket_end < 2 {
			i++
			continue
		}
		id := trimmed[2..bracket_end]
		mut content := trimmed[bracket_end + 2..].trim_left(' \t')
		i++
		// Collect continuation lines (indented, may have blank lines between, bounded)
		mut had_blank := false
		mut cont_count := 0
		for i < lines.len && cont_count < max_footnote_continuation_lines {
			next := lines[i]
			// Blank line - check if next non-blank is indented continuation
			if next.len == 0 {
				// Peek ahead for indented line
				if i + 1 < lines.len {
					peek := lines[i + 1]
					if peek.len > 0 && (peek[0] == ` ` || peek[0] == `\t`) {
						had_blank = true
						i++
						continue
					}
				}
				break
			}
			if next[0] != ` ` && next[0] != `\t` {
				break
			}
			// Add paragraph break if we had blank line(s)
			if had_blank {
				content += '\n\n'
				had_blank = false
			} else {
				content += ' '
			}
			content += next.trim_space()
			cont_count++
			i++
		}
		if id.len > 0 && content.len > 0 {
			defs[id] = content
		}
	}
	return defs
}

// is_footnote_definition checks if a line is a footnote definition [^id]: text.
fn is_footnote_definition(line string) bool {
	trimmed := line.trim_space()
	if !trimmed.starts_with('[^') {
		return false
	}
	return trimmed.index(']:') or { return false } >= 2
}

// is_safe_url checks if URL uses allowed protocol.
fn is_safe_url(url string) bool {
	lower := url.to_lower().trim_space()
	if lower.starts_with('http://') || lower.starts_with('https://') || lower.starts_with('mailto:') {
		return true
	}
	// Relative URLs (no protocol) are safe
	if !lower.contains('://') && !lower.starts_with('javascript:') && !lower.starts_with('data:')
		&& !lower.starts_with('vbscript:') {
		return true
	}
	return false
}

// is_safe_image_path checks for path traversal.
fn is_safe_image_path(path string) bool {
	// Block absolute paths and traversal
	if path.starts_with('/') || path.starts_with('\\') {
		return false
	}
	if path.contains('..') {
		return false
	}
	// Block URLs in image paths (not supported anyway)
	if path.contains('://') {
		return false
	}
	return true
}

// parse_image_src splits "path =WxH" into (path, width, height).
// Supports: "path =WxH", "path =Wx", "path =xH", "path" (no dimensions).
fn parse_image_src(raw string) (string, f32, f32) {
	// Find " =" pattern for dimensions
	eq_idx := raw.index(' =') or { return raw.trim_space(), 0, 0 }
	path := raw[..eq_idx].trim_space()
	dims := raw[eq_idx + 2..].trim_space()
	if dims.len == 0 {
		return path, 0, 0
	}
	// Parse WxH, Wx, or xH
	x_idx := dims.index('x') or { return path, 0, 0 }
	w_str := dims[..x_idx]
	h_str := dims[x_idx + 1..]
	w_raw := if w_str.len > 0 { w_str.f32() } else { f32(0) }
	h_raw := if h_str.len > 0 { h_str.f32() } else { f32(0) }
	return path, if w_raw > 0 {
		w_raw
	} else {
		0
	}, if h_raw > 0 {
		h_raw
	} else {
		0
	}
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
