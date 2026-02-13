module gui

// markdown_inline.v handles parsing of inline markdown elements (bold, italic, links, etc.)

const valid_image_exts = ['.png', '.jpg', '.jpeg', '.gif', '.svg', '.bmp', '.webp']

// parse_inline parses inline markdown elements from a string and appends them to runs.
fn parse_inline(text string, base_style TextStyle, md_style MarkdownStyle, mut runs []RichTextRun, link_defs map[string]string, footnote_defs map[string]string, depth int) {
	// Limit recursion depth to prevent stack overflow on
	// malformed input (e.g. '***___'.repeat(200)).
	if depth >= 16 {
		if text.len > 0 {
			runs << RichTextRun{
				text:  text
				style: base_style
			}
		}
		return
	}
	mut pos := 0
	mut current := []u8{cap: text.len}

	for pos < text.len {
		// Escape character: backslash makes next char literal
		if text[pos] == `\\` && pos + 1 < text.len {
			current << text[pos + 1]
			pos += 2
			continue
		}

		// Check for inline math $...$
		if text[pos] == `$` && pos + 1 < text.len && text[pos + 1] != `$` {
			// Disambiguation: opening $ not preceded by digit or $
			prev_ok := pos == 0
				|| (text[pos - 1] != `$` && !(text[pos - 1] >= `0` && text[pos - 1] <= `9`))
			// Opening $ not followed by space
			next_ok := text[pos + 1] != ` `
			if prev_ok && next_ok {
				// Find closing $ (not preceded by space, not followed by digit)
				mut end := pos + 2
				mut found := false
				for end < text.len {
					if text[end] == `$` {
						// Closing $ not preceded by space
						if text[end - 1] != ` ` {
							// Closing $ not followed by digit
							close_ok := end + 1 >= text.len || !(text[end + 1] >= `0`
								&& text[end + 1] <= `9`)
							if close_ok {
								found = true
								break
							}
						}
					}
					end++
				}
				if found && end > pos + 1 {
					if current.len > 0 {
						runs << RichTextRun{
							text:  current.bytestr()
							style: base_style
						}
						current.clear()
					}
					latex := text[pos + 1..end]
					math_id := 'math_${latex.hash()}'
					runs << RichTextRun{
						text:       '\uFFFC' // object replacement char
						style:      base_style
						math_id:    math_id
						math_latex: latex
					}
					pos = end + 1
					continue
				}
			}
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
				code_text := text[pos + 1..end]
				runs << highlight_inline_code(code_text, md_style)
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
					footnote_defs, depth + 1)
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
					footnote_defs, depth + 1)
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
					footnote_defs, depth + 1)
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
					footnote_defs, depth + 1)
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
					footnote_defs, depth + 1)
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
					footnote_defs, depth + 1)
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
					footnote_defs, depth + 1)
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
						runs << rich_footnote(footnote_id, content, base_style)
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

// parse_image_src parses "path =WxH" or "path" into (path, width, height).
fn parse_image_src(raw string) (string, f32, f32) {
	trimmed := raw.trim_space()
	if trimmed.contains(' =') {
		parts := trimmed.split(' =')
		if parts.len == 2 {
			src := parts[0].trim_space()
			dim := parts[1].trim_space()
			if dim.contains('x') {
				wh := dim.split('x')
				if wh.len == 2 {
					return src, wh[0].f32(), wh[1].f32()
				}
			} else {
				return src, dim.f32(), 0
			}
		}
	}
	return trimmed, 0, 0
}

// is_safe_image_path performs basic validation on image paths.
fn is_safe_image_path(path string) bool {
	p := path.to_lower()
	// Allow common image extensions and web URLs
	if p.starts_with('http://') || p.starts_with('https://') {
		return true
	}
	// Block path traversal in local paths
	if p.contains('..') {
		return false
	}
	// Blocks: javascript:, vbscript:, data:, file:,
	// and other unsafe protocols.
	if p.contains(':') && !p.starts_with('http') {
		return false
	}
	// Basic extension check
	for ext in valid_image_exts {
		if p.ends_with(ext) {
			return true
		}
	}
	return false
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
