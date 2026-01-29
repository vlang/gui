module gui

// xtra_markdown.v implements a markdown parser that converts markdown text to RichText.

// MarkdownBlock represents a parsed block of markdown content.
struct MarkdownBlock {
	is_code bool
	is_hr   bool
	content RichText
}

// markdown_to_blocks parses markdown source and returns styled blocks.
fn markdown_to_blocks(source string, style MarkdownStyle) []MarkdownBlock {
	mut blocks := []MarkdownBlock{}
	mut runs := []RichTextRun{}
	lines := source.split('\n')
	mut i := 0
	mut in_code_block := false
	mut code_block_content := []string{}

	for i < lines.len {
		line := lines[i]

		// Handle code blocks
		if line.starts_with('```') {
			if in_code_block {
				// End code block - flush current runs first, then add code block
				trim_trailing_breaks(mut runs)
				if runs.len > 0 {
					blocks << MarkdownBlock{
						is_code: false
						content: RichText{runs: runs.clone()}
					}
					runs.clear()
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
				trim_trailing_breaks(mut runs)
				if runs.len > 0 {
					blocks << MarkdownBlock{
						is_code: false
						content: RichText{runs: runs.clone()}
					}
					runs.clear()
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
		if line.trim_space() in ['---', '***', '___'] && line.trim_space().len >= 3 {
			// Flush current runs first
			trim_trailing_breaks(mut runs)
			if runs.len > 0 {
				blocks << MarkdownBlock{
					is_code: false
					content: RichText{runs: runs.clone()}
				}
				runs.clear()
			}
			// Add hr as separate block
			blocks << MarkdownBlock{
				is_hr: true
			}
			i++
			continue
		}

		// Blank line = paragraph break
		if line.trim_space() == '' {
			if runs.len > 0 {
				runs << rich_br()
			}
			i++
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

		// Unordered list
		if line.starts_with('- ') || line.starts_with('* ') || line.starts_with('+ ') {
			runs << RichTextRun{
				text:  '  • '
				style: style.text
			}
			parse_inline(line[2..], style.text, style, mut runs)
			runs << rich_br()
			i++
			continue
		}

		// Ordered list
		if is_ordered_list(line) {
			dot_pos := line.index('.') or { 0 }
			num := line[..dot_pos]
			rest := line[dot_pos + 1..].trim_left(' ')
			runs << RichTextRun{
				text:  '  ${num}. '
				style: style.text
			}
			parse_inline(rest, style.text, style, mut runs)
			runs << rich_br()
			i++
			continue
		}

		// Regular paragraph
		parse_inline(line, style.text, style, mut runs)
		i++

		// Add line break if not last line
		if i < lines.len {
			runs << rich_br()
		}
	}

	// Handle unclosed code block
	if in_code_block && code_block_content.len > 0 {
		if runs.len > 0 {
			blocks << MarkdownBlock{
				is_code: false
				content: RichText{runs: runs.clone()}
			}
			runs.clear()
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
	if runs.len > 0 {
		blocks << MarkdownBlock{
			is_code: false
			content: RichText{runs: runs}
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
	return RichText{runs: all_runs}
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
	mut current_text := ''

	for pos < text.len {
		// Check for inline code
		if text[pos] == `\`` {
			if current_text.len > 0 {
				runs << RichTextRun{
					text:  current_text
					style: base_style
				}
				current_text = ''
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

		// Check for bold (**text**)
		if pos + 1 < text.len && text[pos] == `*` && text[pos + 1] == `*` {
			if current_text.len > 0 {
				runs << RichTextRun{
					text:  current_text
					style: base_style
				}
				current_text = ''
			}
			end := find_double_closing(text, pos + 2, `*`)
			if end > pos + 2 {
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

		// Check for italic (*text*)
		if text[pos] == `*` {
			if current_text.len > 0 {
				runs << RichTextRun{
					text:  current_text
					style: base_style
				}
				current_text = ''
			}
			end := find_closing(text, pos + 1, `*`)
			if end > pos + 1 {
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

		// Check for links [text](url)
		if text[pos] == `[` {
			bracket_end := find_closing(text, pos + 1, `]`)
			if bracket_end > pos + 1 && bracket_end + 1 < text.len && text[bracket_end + 1] == `(` {
				paren_end := find_closing(text, bracket_end + 2, `)`)
				if paren_end > bracket_end + 2 {
					if current_text.len > 0 {
						runs << RichTextRun{
							text:  current_text
							style: base_style
						}
						current_text = ''
					}
					link_text := text[pos + 1..bracket_end]
					link_url := text[bracket_end + 2..paren_end]
					runs << RichTextRun{
						text: link_text
						link: link_url
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
		}

		current_text += text[pos].ascii_str()
		pos++
	}

	if current_text.len > 0 {
		runs << RichTextRun{
			text:  current_text
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
