module gui

import vglyph

// markdown_inline.v handles parsing of inline markdown elements (bold, italic, links, etc.)

const valid_image_exts = ['.png', '.jpg', '.jpeg', '.gif', '.svg', '.bmp', '.webp']

const superscript_features = &vglyph.FontFeatures{
	opentype_features: [vglyph.FontFeature{'sups', 1}]
}

const subscript_features = &vglyph.FontFeatures{
	opentype_features: [vglyph.FontFeature{'subs', 1}]
}

// parse_inline parses inline markdown elements from a string and appends them to runs.
fn parse_inline(text string, base_style TextStyle, md_style MarkdownStyle, mut runs []RichTextRun, link_defs map[string]string, footnote_defs map[string]string, depth int) {
	// Limit recursion depth to prevent stack overflow on
	// malformed input (e.g. '***___'.repeat(200)).
	if depth >= max_inline_nesting_depth {
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

		// Check for emoji shortcode :name:
		if text[pos] == `:` && pos + 1 < text.len {
			end := find_emoji_end(text, pos + 1)
			if end > 0 && end < text.len && text[end] == `:` {
				name := text[pos + 1..end]
				emoji := emoji_lookup(name)
				if emoji != '' {
					if current.len > 0 {
						runs << RichTextRun{
							text:  current.bytestr()
							style: base_style
						}
						current.clear()
					}
					runs << RichTextRun{
						text:  emoji
						style: base_style
					}
					pos = end + 1
					continue
				}
			}
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
					size:     base_style.size
					bg_color: base_style.bg_color
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
					size:     base_style.size
					bg_color: base_style.bg_color
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

		// Check for highlight (==text==)
		if pos + 1 < text.len && text[pos] == `=` && text[pos + 1] == `=` {
			end := find_double_closing(text, pos + 2, `=`)
			if end > pos + 2 {
				if current.len > 0 {
					runs << RichTextRun{
						text:  current.bytestr()
						style: base_style
					}
					current.clear()
				}
				hl_style := TextStyle{
					...base_style
					bg_color: md_style.highlight_bg
				}
				parse_inline(text[pos + 2..end], hl_style, md_style, mut runs, link_defs,
					footnote_defs, depth + 1)
				pos = end + 2
				continue
			}
		}

		// Check for subscript (~text~) - single tilde, not ~~
		if text[pos] == `~` && pos + 1 < text.len && text[pos + 1] != `~` {
			end := find_closing(text, pos + 1, `~`)
			// Guard: closing ~ not followed by another ~ (that would be ~~)
			if end > pos + 1 && (end + 1 >= text.len || text[end + 1] != `~`) {
				if current.len > 0 {
					runs << RichTextRun{
						text:  current.bytestr()
						style: base_style
					}
					current.clear()
				}
				sub_style := TextStyle{
					...base_style
					size:     base_style.size * 1.2
					features: subscript_features
				}
				parse_inline(text[pos + 1..end], sub_style, md_style, mut runs, link_defs,
					footnote_defs, depth + 1)
				pos = end + 1
				continue
			}
		}

		// Check for superscript (^text^)
		if text[pos] == `^` && pos + 1 < text.len {
			end := find_closing(text, pos + 1, `^`)
			if end > pos + 1 {
				if current.len > 0 {
					runs << RichTextRun{
						text:  current.bytestr()
						style: base_style
					}
					current.clear()
				}
				sup_style := TextStyle{
					...base_style
					size:     base_style.size * 1.2
					features: superscript_features
				}
				parse_inline(text[pos + 1..end], sup_style, md_style, mut runs, link_defs,
					footnote_defs, depth + 1)
				pos = end + 1
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
					size:     base_style.size
					bg_color: base_style.bg_color
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
					size:     base_style.size
					bg_color: base_style.bg_color
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
					size:     base_style.size
					bg_color: base_style.bg_color
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
					size:     base_style.size
					bg_color: base_style.bg_color
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
					runs << make_link_run(inner, link_url, base_style, md_style.link_color)
					pos = end + 1
					continue
				}
				// Strip HTML tags (not autolinks)
				if is_html_tag(inner) {
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
						runs << make_link_run(link_text, link_url, base_style, md_style.link_color)
						pos = paren_end + 1
						continue
					}
				}
				// Check for reference link [text][ref] or [text][]
				link_text_lower := link_text.to_lower()
				if bracket_end + 1 < text.len && text[bracket_end + 1] == `[` {
					ref_end := find_closing(text, bracket_end + 2, `]`)
					if ref_end >= bracket_end + 2 {
						ref_id := if ref_end == bracket_end + 2 {
							link_text_lower // implicit [text][]
						} else {
							text[bracket_end + 2..ref_end].to_lower()
						}
						if url := link_defs[ref_id] {
							if current.len > 0 {
								runs << RichTextRun{
									text:  current.bytestr()
									style: base_style
								}
								current.clear()
							}
							runs << make_link_run(link_text, url, base_style, md_style.link_color)
							pos = ref_end + 1
							continue
						}
					}
				}
				// Check for shortcut reference link [text]
				shortcut_id := link_text_lower
				if url := link_defs[shortcut_id] {
					if current.len > 0 {
						runs << RichTextRun{
							text:  current.bytestr()
							style: base_style
						}
						current.clear()
					}
					runs << make_link_run(link_text, url, base_style, md_style.link_color)
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

// make_link_run creates a styled link run with URL safety check.
fn make_link_run(link_text string, url string, base_style TextStyle, link_color Color) RichTextRun {
	safe_link := if is_safe_url(url) { url } else { '' }
	return RichTextRun{
		text:  link_text
		link:  safe_link
		style: TextStyle{
			...base_style
			color:     if safe_link != '' { link_color } else { base_style.color }
			underline: safe_link != ''
		}
	}
}

// find_closing finds the position of a closing character.
// For ] and ) it skips backtick spans to handle links like [`code`](url).
// Skips escaped characters (e.g. \]).
fn find_closing(text string, start int, ch u8) int {
	skip_backticks := ch == `]` || ch == `)`
	mut i := start
	for i < text.len {
		// Skip escaped character
		if text[i] == `\\` && i + 1 < text.len {
			i += 2
			continue
		}
		// Skip backtick spans when searching for link delimiters
		if skip_backticks && text[i] == `\`` {
			i++
			for i < text.len && text[i] != `\`` {
				// Skip escaped backtick inside span
				if text[i] == `\\` && i + 1 < text.len {
					i += 2
					continue
				}
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
	mut i := start
	for i < text.len - 1 {
		if text[i] == `\\` && i + 1 < text.len {
			i += 2
			continue
		}
		if text[i] == ch && text[i + 1] == ch {
			return i
		}
		i++
	}
	return -1
}

// find_triple_closing finds the position of triple closing characters (e.g., ***).
fn find_triple_closing(text string, start int, ch u8) int {
	mut i := start
	for i < text.len - 2 {
		if text[i] == `\\` && i + 1 < text.len {
			i += 2
			continue
		}
		if text[i] == ch && text[i + 1] == ch && text[i + 2] == ch {
			return i
		}
		i++
	}
	return -1
}

// parse_image_src parses "path =WxH" or "path" into (path, width, height).
fn parse_image_src(raw string) (string, f32, f32) {
	trimmed := raw.trim_space()
	idx := trimmed.last_index(' =') or { return trimmed, 0, 0 }

	src := trimmed[..idx].trim_space()
	dim := trimmed[idx + 2..].trim_space()

	if dim.contains('x') {
		wh := dim.split('x')
		if wh.len == 2 {
			return src, wh[0].f32(), wh[1].f32()
		}
	}
	return src, dim.f32(), 0
}

// is_safe_image_path performs basic validation on image paths.
fn is_safe_image_path(path string) bool {
	if path.to_lower().replace('%2e', '.').contains('..') {
		return false
	}
	p := path.to_lower().trim_space()
	if p.starts_with('http://') || p.starts_with('https://') {
		return true
	}
	// Blocks: javascript:, vbscript:, data:, file:,
	// and other unsafe protocols. Use is_safe_url logic.
	if !is_safe_url(path) {
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

// is_html_tag checks if text between < > looks like an HTML tag.
// Matches: tag, /tag, tag attr, tag/, br/, etc.
fn is_html_tag(s string) bool {
	if s.len == 0 {
		return false
	}
	start := if s[0] == `/` { 1 } else { 0 }
	if start >= s.len {
		return false
	}
	c := s[start]
	if !((c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`)) {
		return false
	}
	return true
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
