module gui

// xtra_markdown.v implements a markdown parser that converts markdown text to RichText.

// MarkdownBlock represents a parsed block of markdown content.
struct MarkdownBlock {
	is_code          bool
	is_hr            bool
	is_blockquote    bool
	is_image         bool
	is_table         bool
	is_list          bool
	blockquote_depth int
	list_prefix      string // "• ", "1. ", "☐ ", "☑ "
	list_indent      int    // nesting level (0, 1, 2...)
	image_src        string
	image_alt        string
	content          RichText
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
	mut blocks := []MarkdownBlock{cap: lines.len / 3}
	mut runs := []RichTextRun{cap: 20}
	mut i := 0
	mut in_code_block := false
	mut code_block_content := []string{}

	for i < lines.len {
		line := lines[i]
		trimmed := line.trim_space()

		// Handle code blocks
		if line.starts_with('```') {
			if in_code_block {
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
				// Add leading space for content after code block
				runs << rich_br()
			} else {
				// Start code block - flush current runs
				if block := flush_runs(mut runs) {
					blocks << block
				}
				in_code_block = true
			}
			i++
			continue
		}

		if in_code_block {
			code_block_content << line
			i++
			continue
		}

		// Horizontal rule
		if trimmed in ['---', '***', '___'] {
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

		// Blank line = paragraph break
		if trimmed == '' {
			if runs.len > 0 {
				runs << rich_br()
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
		if trimmed.starts_with('|') || is_table_separator(trimmed) {
			// Flush current runs
			if block := flush_runs(mut runs) {
				blocks << block
			}
			// Collect consecutive table lines
			mut table_lines := []string{cap: 10}
			for i < lines.len {
				tl := lines[i].trim_space()
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
				blocks << MarkdownBlock{
					is_table: true
					content:  RichText{
						runs: [
							RichTextRun{
								text:  table_lines.join('\n')
								style: style.code
							},
						]
					}
				}
			}
			continue
		}

		// Definition list: line starting with : (treat as paragraph for now)
		if trimmed.len > 1 && trimmed[0] == `:` && trimmed[1] == ` ` {
			// Treat as regular paragraph
			parse_inline(line, style.text, style, mut runs)
			runs << rich_br()
			i++
			continue
		}

		// Image ![alt](path) - must be at start of line
		if line.starts_with('![') {
			bracket_end := line.index(']') or { -1 }
			if bracket_end > 2 && bracket_end + 1 < line.len && line[bracket_end + 1] == `(` {
				paren_end := line.index_after(')', bracket_end + 2) or { -1 }
				if paren_end > bracket_end + 2 {
					// Flush current runs
					if block := flush_runs(mut runs) {
						blocks << block
					}
					blocks << MarkdownBlock{
						is_image:  true
						image_alt: line[2..bracket_end]
						image_src: line[bracket_end + 2..paren_end]
					}
					i++
					continue
				}
			}
		}

		// Blockquote
		if line.starts_with('>') {
			// Flush current runs
			if block := flush_runs(mut runs) {
				blocks << block
			}
			// Count initial depth and collect consecutive blockquote lines
			mut max_depth := count_blockquote_depth(line)
			mut quote_lines := []string{cap: 10}
			for i < lines.len {
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
					parse_inline(ql, style.text, style, mut quote_runs)
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
			parse_header(line[6..].trim_left(' '), style.h6, style, mut runs)
			i++
			continue
		}
		if line.starts_with('#####') {
			parse_header(line[5..].trim_left(' '), style.h5, style, mut runs)
			i++
			continue
		}
		if line.starts_with('####') {
			parse_header(line[4..].trim_left(' '), style.h4, style, mut runs)
			i++
			continue
		}
		if line.starts_with('###') {
			parse_header(line[3..].trim_left(' '), style.h3, style, mut runs)
			i++
			continue
		}
		if line.starts_with('##') {
			parse_header(line[2..].trim_left(' '), style.h2, style, mut runs)
			i++
			continue
		}
		if line.starts_with('#') {
			parse_header(line[1..].trim_left(' '), style.h1, style, mut runs)
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
			parse_inline(content, style.text, style, mut item_runs)
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
			parse_inline(content, style.text, style, mut item_runs)
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
			parse_inline(content, style.text, style, mut item_runs)
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

		// Regular paragraph
		parse_inline(line, style.text, style, mut runs)
		i++

		// Add space if next line continues paragraph, line break if block element
		if i < lines.len {
			next := lines[i]
			next_trimmed := next.trim_space()
			if next_trimmed == '' {
				// Blank line handler will deal with it
			} else if is_block_start(next) {
				// Block element coming - add line break
				runs << rich_br()
			} else {
				// Continuation of paragraph - add space instead of line break
				runs << RichTextRun{
					text:  ' '
					style: style.text
				}
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

// parse_header adds header text with the given style.
fn parse_header(text string, header_style TextStyle, md_style MarkdownStyle, mut runs []RichTextRun) {
	if runs.len > 0 {
		runs << rich_br()
	}
	parse_inline(text, header_style, md_style, mut runs)
	runs << rich_br()
}

// parse_inline parses inline markdown (bold, italic, code, links).
fn parse_inline(text string, base_style TextStyle, md_style MarkdownStyle, mut runs []RichTextRun) {
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
				runs << RichTextRun{
					text:  text[pos + 3..end]
					style: TextStyle{
						...md_style.bold_italic
						size: base_style.size
					}
				}
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
				runs << RichTextRun{
					text:  text[pos + 2..end]
					style: TextStyle{
						...md_style.bold
						size: base_style.size
					}
				}
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
				runs << RichTextRun{
					text:  text[pos + 2..end]
					style: TextStyle{
						...base_style
						strikethrough: true
					}
				}
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
				runs << RichTextRun{
					text:  text[pos + 1..end]
					style: TextStyle{
						...md_style.italic
						size: base_style.size
					}
				}
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
				runs << RichTextRun{
					text:  text[pos + 3..end]
					style: TextStyle{
						...md_style.bold_italic
						size: base_style.size
					}
				}
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
				runs << RichTextRun{
					text:  text[pos + 2..end]
					style: TextStyle{
						...md_style.bold
						size: base_style.size
					}
				}
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
				runs << RichTextRun{
					text:  text[pos + 1..end]
					style: TextStyle{
						...md_style.italic
						size: base_style.size
					}
				}
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
					runs << RichTextRun{
						text:  inner
						link:  link_url
						style: TextStyle{
							...base_style
							color:     md_style.link_color
							underline: true
						}
					}
					pos = end + 1
					continue
				}
			}
		}

		// Check for links [text](url)
		if text[pos] == `[` {
			// Footnote defense: [^...] treat as literal
			if pos + 1 < text.len && text[pos + 1] == `^` {
				current << text[pos]
				pos++
				continue
			}
			bracket_end := find_closing(text, pos + 1, `]`)
			if bracket_end > pos + 1 {
				// Reference link defense: [text][ref] - no ( after ]
				if bracket_end + 1 >= text.len || text[bracket_end + 1] != `(` {
					// Not a standard link, treat as literal text
					current << text[pos]
					pos++
					continue
				}
				paren_end := find_closing(text, bracket_end + 2, `)`)
				if paren_end > bracket_end + 2 {
					if current.len > 0 {
						runs << RichTextRun{
							text:  current.bytestr()
							style: base_style
						}
						current.clear()
					}
					link_text := text[pos + 1..bracket_end]
					link_url := text[bracket_end + 2..paren_end]
					runs << RichTextRun{
						text:  link_text
						link:  link_url
						style: TextStyle{
							...base_style
							color:     md_style.link_color
							underline: true
						}
					}
					pos = paren_end + 1
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
fn find_closing(text string, start int, ch u8) int {
	for i := start; i < text.len; i++ {
		if text[i] == ch {
			return i
		}
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

// collect_list_item_content collects the full content of a list item including continuation lines.
// Returns the combined content and the number of lines consumed (excluding the first).
fn collect_list_item_content(first_content string, lines []string, start_idx int) (string, int) {
	mut consumed := 0
	mut idx := start_idx

	// Check if any continuation lines exist
	for idx < lines.len {
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
	if trimmed.starts_with('```') {
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
