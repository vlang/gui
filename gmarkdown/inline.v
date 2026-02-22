module gmarkdown

// inline.v handles parsing of inline markdown elements
// (bold, italic, links, etc.) into style-free MdRun sequences.

const valid_image_exts = ['.png', '.jpg', '.jpeg', '.gif', '.svg', '.bmp', '.webp']

// parse_inline parses inline markdown elements from a string
// and appends them to runs. format carries the inherited
// formatting from enclosing markers (e.g. bold wrapping italic).
pub fn parse_inline(text string, format MdFormat, mut runs []MdRun, link_defs map[string]string, footnote_defs map[string]string, depth int) {
	if depth >= max_inline_nesting_depth {
		if text.len > 0 {
			runs << MdRun{
				text:   text
				format: format
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
						runs << MdRun{
							text:   current.bytestr()
							format: format
						}
						current.clear()
					}
					runs << MdRun{
						text:   emoji
						format: format
					}
					pos = end + 1
					continue
				}
			}
		}

		// Check for inline math $...$
		if text[pos] == `$` && pos + 1 < text.len && text[pos + 1] != `$` {
			prev_ok := pos == 0
				|| (text[pos - 1] != `$` && !(text[pos - 1] >= `0` && text[pos - 1] <= `9`))
			next_ok := text[pos + 1] != ` `
			if prev_ok && next_ok {
				mut end := pos + 2
				mut found := false
				for end < text.len {
					if text[end] == `$` {
						if text[end - 1] != ` ` {
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
						runs << MdRun{
							text:   current.bytestr()
							format: format
						}
						current.clear()
					}
					latex := text[pos + 1..end]
					math_id := 'math_${latex.hash()}'
					runs << MdRun{
						text:       '\uFFFC'
						format:     format
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
				runs << MdRun{
					text:   current.bytestr()
					format: format
				}
				current.clear()
			}
			end := find_closing(text, pos + 1, `\``)
			if end > pos + 1 {
				code_text := text[pos + 1..end]
				tokenize_inline_code(code_text, mut runs)
				pos = end + 1
				continue
			}
		}

		// Check for bold+italic (***text***)
		if pos + 2 < text.len && text[pos] == `*` && text[pos + 1] == `*` && text[pos + 2] == `*` {
			end := find_triple_closing(text, pos + 3, `*`)
			if end > pos + 3 {
				if current.len > 0 {
					runs << MdRun{
						text:   current.bytestr()
						format: format
					}
					current.clear()
				}
				parse_inline(text[pos + 3..end], .bold_italic, mut runs, link_defs, footnote_defs,
					depth + 1)
				pos = end + 3
				continue
			}
		}

		// Check for bold (**text**)
		if pos + 1 < text.len && text[pos] == `*` && text[pos + 1] == `*` {
			end := find_double_closing(text, pos + 2, `*`)
			if end > pos + 2 {
				if current.len > 0 {
					runs << MdRun{
						text:   current.bytestr()
						format: format
					}
					current.clear()
				}
				parse_inline(text[pos + 2..end], .bold, mut runs, link_defs, footnote_defs,
					depth + 1)
				pos = end + 2
				continue
			}
		}

		// Check for strikethrough (~~text~~)
		if pos + 1 < text.len && text[pos] == `~` && text[pos + 1] == `~` {
			if current.len > 0 {
				runs << MdRun{
					text:   current.bytestr()
					format: format
				}
				current.clear()
			}
			end := find_double_closing(text, pos + 2, `~`)
			if end > pos + 2 {
				// Recurse with strikethrough — inner runs get it
				mut inner := []MdRun{cap: 4}
				parse_inline(text[pos + 2..end], format, mut inner, link_defs, footnote_defs,
					depth + 1)
				for r in inner {
					runs << MdRun{
						...r
						strikethrough: true
					}
				}
				pos = end + 2
				continue
			}
		}

		// Check for highlight (==text==)
		if pos + 1 < text.len && text[pos] == `=` && text[pos + 1] == `=` {
			end := find_double_closing(text, pos + 2, `=`)
			if end > pos + 2 {
				if current.len > 0 {
					runs << MdRun{
						text:   current.bytestr()
						format: format
					}
					current.clear()
				}
				mut inner := []MdRun{cap: 4}
				parse_inline(text[pos + 2..end], format, mut inner, link_defs, footnote_defs,
					depth + 1)
				for r in inner {
					runs << MdRun{
						...r
						highlight: true
					}
				}
				pos = end + 2
				continue
			}
		}

		// Check for subscript (~text~) - single tilde, not ~~
		if text[pos] == `~` && pos + 1 < text.len && text[pos + 1] != `~` {
			end := find_closing(text, pos + 1, `~`)
			if end > pos + 1 && (end + 1 >= text.len || text[end + 1] != `~`) {
				if current.len > 0 {
					runs << MdRun{
						text:   current.bytestr()
						format: format
					}
					current.clear()
				}
				mut inner := []MdRun{cap: 4}
				parse_inline(text[pos + 1..end], format, mut inner, link_defs, footnote_defs,
					depth + 1)
				for r in inner {
					runs << MdRun{
						...r
						subscript: true
					}
				}
				pos = end + 1
				continue
			}
		}

		// Check for superscript (^text^)
		if text[pos] == `^` && pos + 1 < text.len {
			end := find_closing(text, pos + 1, `^`)
			if end > pos + 1 {
				if current.len > 0 {
					runs << MdRun{
						text:   current.bytestr()
						format: format
					}
					current.clear()
				}
				mut inner := []MdRun{cap: 4}
				parse_inline(text[pos + 1..end], format, mut inner, link_defs, footnote_defs,
					depth + 1)
				for r in inner {
					runs << MdRun{
						...r
						superscript: true
					}
				}
				pos = end + 1
				continue
			}
		}

		// Check for italic (*text*)
		if text[pos] == `*` {
			end := find_closing(text, pos + 1, `*`)
			if end > pos + 1 {
				if current.len > 0 {
					runs << MdRun{
						text:   current.bytestr()
						format: format
					}
					current.clear()
				}
				parse_inline(text[pos + 1..end], .italic, mut runs, link_defs, footnote_defs,
					depth + 1)
				pos = end + 1
				continue
			}
		}

		// Check for bold+italic (___text___)
		// Per CommonMark, underscore emphasis requires that the
		// opening _ is not preceded by alnum and the closing _
		// is not followed by alnum (intraword rule).
		if pos + 2 < text.len && text[pos] == `_` && text[pos + 1] == `_` && text[pos + 2] == `_`
			&& !is_alnum_at(text, pos - 1) {
			end := find_triple_closing(text, pos + 3, `_`)
			if end > pos + 3 && !is_alnum_at(text, end + 3) {
				if current.len > 0 {
					runs << MdRun{
						text:   current.bytestr()
						format: format
					}
					current.clear()
				}
				parse_inline(text[pos + 3..end], .bold_italic, mut runs, link_defs, footnote_defs,
					depth + 1)
				pos = end + 3
				continue
			}
		}

		// Check for bold (__text__)
		if pos + 1 < text.len && text[pos] == `_` && text[pos + 1] == `_`
			&& !is_alnum_at(text, pos - 1) {
			end := find_double_closing(text, pos + 2, `_`)
			if end > pos + 2 && !is_alnum_at(text, end + 2) {
				if current.len > 0 {
					runs << MdRun{
						text:   current.bytestr()
						format: format
					}
					current.clear()
				}
				parse_inline(text[pos + 2..end], .bold, mut runs, link_defs, footnote_defs,
					depth + 1)
				pos = end + 2
				continue
			}
		}

		// Check for italic (_text_)
		if text[pos] == `_` && !is_alnum_at(text, pos - 1) {
			end := find_closing(text, pos + 1, `_`)
			if end > pos + 1 && !is_alnum_at(text, end + 1) {
				if current.len > 0 {
					runs << MdRun{
						text:   current.bytestr()
						format: format
					}
					current.clear()
				}
				parse_inline(text[pos + 1..end], .italic, mut runs, link_defs, footnote_defs,
					depth + 1)
				pos = end + 1
				continue
			}
		}

		// Check for autolinks <url> or <email>
		if text[pos] == `<` {
			end := find_closing(text, pos + 1, `>`)
			if end > pos + 1 {
				inner := text[pos + 1..end]
				if inner.starts_with('http://') || inner.starts_with('https://')
					|| inner.contains('@') {
					if current.len > 0 {
						runs << MdRun{
							text:   current.bytestr()
							format: format
						}
						current.clear()
					}
					link_url := if inner.contains('@') && !inner.contains('://') {
						'mailto:${inner}'
					} else {
						inner
					}
					safe_link := if is_safe_url(link_url) { link_url } else { '' }
					runs << MdRun{
						text:      inner
						format:    format
						link:      safe_link
						underline: safe_link != ''
					}
					pos = end + 1
					continue
				}
				if is_html_tag(inner) {
					pos = end + 1
					continue
				}
			}
		}

		// Check for links [text](url) or reference links
		if text[pos] == `[` {
			// Footnote: [^id]
			if pos + 1 < text.len && text[pos + 1] == `^` {
				fn_end := find_closing(text, pos + 2, `]`)
				if fn_end > pos + 2 {
					footnote_id := text[pos + 2..fn_end]
					if content := footnote_defs[footnote_id] {
						if current.len > 0 {
							runs << MdRun{
								text:   current.bytestr()
								format: format
							}
							current.clear()
						}
						runs << md_footnote(footnote_id, content, format)
						pos = fn_end + 1
						continue
					}
				}
				current << text[pos]
				pos++
				continue
			}
			bracket_end := find_closing(text, pos + 1, `]`)
			if bracket_end > pos + 1 {
				link_text := text[pos + 1..bracket_end]
				// Standard link [text](url)
				if bracket_end + 1 < text.len && text[bracket_end + 1] == `(` {
					paren_end := find_closing(text, bracket_end + 2, `)`)
					if paren_end > bracket_end + 2 {
						if current.len > 0 {
							runs << MdRun{
								text:   current.bytestr()
								format: format
							}
							current.clear()
						}
						link_url := text[bracket_end + 2..paren_end]
						runs << make_md_link(link_text, link_url, format)
						pos = paren_end + 1
						continue
					}
				}
				// Reference link [text][ref] or [text][]
				link_text_lower := link_text.to_lower()
				if bracket_end + 1 < text.len && text[bracket_end + 1] == `[` {
					ref_end := find_closing(text, bracket_end + 2, `]`)
					if ref_end >= bracket_end + 2 {
						ref_id := if ref_end == bracket_end + 2 {
							link_text_lower
						} else {
							text[bracket_end + 2..ref_end].to_lower()
						}
						if url := link_defs[ref_id] {
							if current.len > 0 {
								runs << MdRun{
									text:   current.bytestr()
									format: format
								}
								current.clear()
							}
							runs << make_md_link(link_text, url, format)
							pos = ref_end + 1
							continue
						}
					}
				}
				// Shortcut reference link [text]
				if url := link_defs[link_text_lower] {
					if current.len > 0 {
						runs << MdRun{
							text:   current.bytestr()
							format: format
						}
						current.clear()
					}
					runs << make_md_link(link_text, url, format)
					pos = bracket_end + 1
					continue
				}
			}
			current << text[pos]
			pos++
			continue
		}

		current << text[pos]
		pos++
	}

	if current.len > 0 {
		runs << MdRun{
			text:   current.bytestr()
			format: format
		}
	}
}

// make_md_link creates a link run with URL safety check.
fn make_md_link(link_text string, url string, format MdFormat) MdRun {
	safe_link := if is_safe_url(url) { url } else { '' }
	return MdRun{
		text:      link_text
		format:    format
		link:      safe_link
		underline: safe_link != ''
	}
}

// md_footnote creates a footnote marker run.
fn md_footnote(id string, content string, format MdFormat) MdRun {
	return MdRun{
		text:    '\xE2\x80\x89[${id}]' // thin space
		format:  format
		tooltip: content
	}
}

// tokenize_inline_code tokenizes inline code and produces
// MdRun entries with code_token set.
fn tokenize_inline_code(code string, mut runs []MdRun) {
	tokens := tokenize_code(code, .generic, max_inline_code_highlight_bytes)
	if tokens.len == 0 {
		runs << MdRun{
			text:   code
			format: .code
		}
		return
	}
	for token in tokens {
		runs << MdRun{
			text:       code[token.start..token.end]
			format:     .code
			code_token: token.kind
		}
	}
}

// is_alnum_at returns true if text[idx] is ASCII
// alphanumeric. Out-of-bounds indices return false.
fn is_alnum_at(text string, idx int) bool {
	if idx < 0 || idx >= text.len {
		return false
	}
	c := text[idx]
	return (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`) || (c >= `0` && c <= `9`)
}

// find_closing finds the position of a closing character.
// For ] and ) it skips backtick spans.
pub fn find_closing(text string, start int, ch u8) int {
	skip_backticks := ch == `]` || ch == `)`
	mut i := start
	for i < text.len {
		if text[i] == `\\` && i + 1 < text.len {
			i += 2
			continue
		}
		if skip_backticks && text[i] == `\`` {
			i++
			for i < text.len && text[i] != `\`` {
				if text[i] == `\\` && i + 1 < text.len {
					i += 2
					continue
				}
				i++
			}
			if i < text.len {
				i++
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

// find_double_closing finds position of double closing chars.
pub fn find_double_closing(text string, start int, ch u8) int {
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

// find_triple_closing finds position of triple closing chars.
pub fn find_triple_closing(text string, start int, ch u8) int {
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

// trim_trailing_breaks removes excess trailing newline runs,
// keeping at most one.
pub fn trim_trailing_breaks(mut runs []MdRun) {
	mut count := 0
	for i := runs.len - 1; i >= 0; i-- {
		if runs[i].text == '\n' {
			count++
		} else {
			break
		}
	}
	for count > 1 {
		runs.pop()
		count--
	}
}

// parse_image_src parses "path =WxH" or "path" into
// (path, width, height).
pub fn parse_image_src(raw string) (string, f32, f32) {
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
pub fn is_safe_image_path(path string) bool {
	if path.to_lower().replace('%2e', '.').contains('..') {
		return false
	}
	p := path.to_lower().trim_space()
	if p.starts_with('http://') || p.starts_with('https://') {
		return true
	}
	if !is_safe_url(path) {
		return false
	}
	for ext in valid_image_exts {
		if p.ends_with(ext) {
			return true
		}
	}
	return false
}

// is_safe_url checks that a URL does not use dangerous schemes.
pub fn is_safe_url(url string) bool {
	lower := decode_percent_prefix(url).to_lower().trim_space()
	if lower.len == 0 {
		return false
	}
	if lower.starts_with('http://') || lower.starts_with('https://') || lower.starts_with('mailto:') {
		return true
	}
	if !lower.contains('://') && !lower.starts_with('javascript:') && !lower.starts_with('data:')
		&& !lower.starts_with('vbscript:') && !lower.starts_with('file:')
		&& !lower.starts_with('blob:') && !lower.starts_with('mhtml:')
		&& !lower.starts_with('ms-help:') && !lower.starts_with('disk:') {
		return true
	}
	return false
}

// decode_percent_prefix decodes leading percent-encoded bytes
// (first 20 chars only — enough for scheme detection).
fn decode_percent_prefix(s string) string {
	limit := if s.len < 20 { s.len } else { 20 }
	mut buf := []u8{cap: limit}
	mut i := 0
	for i < limit {
		if s[i] == `%` && i + 2 < s.len {
			hi := hex_val(s[i + 1])
			lo := hex_val(s[i + 2])
			if hi >= 0 && lo >= 0 {
				buf << u8(hi * 16 + lo)
				i += 3
				continue
			}
		}
		buf << s[i]
		i++
	}
	if limit < s.len {
		buf << s[limit..].bytes()
	}
	return buf.bytestr()
}

fn hex_val(c u8) int {
	if c >= `0` && c <= `9` {
		return int(c - `0`)
	}
	if c >= `a` && c <= `f` {
		return int(c - `a`) + 10
	}
	if c >= `A` && c <= `F` {
		return int(c - `A`) + 10
	}
	return -1
}

// is_html_tag checks if text between < > looks like an HTML tag.
pub fn is_html_tag(s string) bool {
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

// md_br creates a line-break MdRun.
pub fn md_br() MdRun {
	return MdRun{
		text: '\n'
	}
}
