module gui

// xtra_markdown.v implements a markdown parser that converts markdown text to RichText.

// markdown_to_rich_text parses markdown source and returns styled RichText.
pub fn markdown_to_rich_text(source string) RichText {
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
				// End code block
				if code_block_content.len > 0 {
					runs << RichTextRun{
						text:  code_block_content.join('\n')
						style: gui_theme.m4
					}
				}
				code_block_content.clear()
				in_code_block = false
			} else {
				// Start code block
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
			if runs.len > 0 {
				runs << rich_br()
			}
			// Add horizontal line using box-drawing characters
			runs << RichTextRun{
				text:  '────────────────────────'
				style: TextStyle{...gui_theme.n4, color: gui_theme.color_border}
			}
			runs << rich_br()
			i++
			continue
		}

		// Blank line = paragraph break
		if line.trim_space() == '' {
			if runs.len > 0 {
				runs << rich_br()
				runs << rich_br()
			}
			i++
			continue
		}

		// Headers
		if line.starts_with('######') {
			parse_header(line[6..].trim_left(' '), gui_theme.b6, mut runs)
			i++
			continue
		}
		if line.starts_with('#####') {
			parse_header(line[5..].trim_left(' '), gui_theme.b5, mut runs)
			i++
			continue
		}
		if line.starts_with('####') {
			parse_header(line[4..].trim_left(' '), gui_theme.b4, mut runs)
			i++
			continue
		}
		if line.starts_with('###') {
			parse_header(line[3..].trim_left(' '), gui_theme.b3, mut runs)
			i++
			continue
		}
		if line.starts_with('##') {
			parse_header(line[2..].trim_left(' '), gui_theme.b2, mut runs)
			i++
			continue
		}
		if line.starts_with('#') {
			parse_header(line[1..].trim_left(' '), gui_theme.b1, mut runs)
			i++
			continue
		}

		// Unordered list
		if line.starts_with('- ') || line.starts_with('* ') || line.starts_with('+ ') {
			runs << RichTextRun{
				text:  '  • '
				style: gui_theme.n3
			}
			parse_inline(line[2..], gui_theme.n3, mut runs)
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
				style: gui_theme.n3
			}
			parse_inline(rest, gui_theme.n3, mut runs)
			runs << rich_br()
			i++
			continue
		}

		// Regular paragraph
		parse_inline(line, gui_theme.n3, mut runs)
		i++

		// Add line break if not last line
		if i < lines.len {
			runs << rich_br()
		}
	}

	// Handle unclosed code block
	if in_code_block && code_block_content.len > 0 {
		runs << RichTextRun{
			text:  code_block_content.join('\n')
			style: gui_theme.m4
		}
	}

	return RichText{
		runs: runs
	}
}

// parse_header adds header text with the given style.
fn parse_header(text string, style TextStyle, mut runs []RichTextRun) {
	if runs.len > 0 {
		runs << rich_br()
	}
	parse_inline(text, style, mut runs)
	runs << rich_br()
}

// parse_inline parses inline markdown (bold, italic, code, links).
fn parse_inline(text string, base_style TextStyle, mut runs []RichTextRun) {
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
					style: gui_theme.m3
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
				// Use b3 (bold medium) but preserve size from base_style
				runs << RichTextRun{
					text:  text[pos + 2..end]
					style: TextStyle{
						...gui_theme.b3
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
				// Use i3 (italic medium) but preserve size from base_style
				runs << RichTextRun{
					text:  text[pos + 1..end]
					style: TextStyle{
						...gui_theme.i3
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
					runs << rich_link(link_text, link_url, base_style)
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
