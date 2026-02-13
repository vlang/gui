module gui

// Limits for code highlighting. On cap breach, fall back to plain code style.
const max_code_block_highlight_bytes = 131072
const max_inline_code_highlight_bytes = 2048
const max_highlight_tokens_per_block = 16384
const max_highlight_token_bytes = 4096
const max_highlight_comment_depth = 16
const max_highlight_string_scan_bytes = 32768
const max_highlight_identifier_bytes = 256
const max_highlight_number_bytes = 128

enum MarkdownCodeTokenKind {
	plain
	keyword
	string
	number
	comment
	operator
}

enum MarkdownCodeLanguage {
	generic
	vlang
	javascript
	typescript
	python
	json
}

struct MarkdownCodePalette {
	base     TextStyle
	keyword  TextStyle
	string   TextStyle
	number   TextStyle
	comment  TextStyle
	operator TextStyle
}

struct MarkdownCodeToken {
	kind MarkdownCodeTokenKind
mut:
	start int
	end   int
}

fn normalize_markdown_code_language_hint(language string) string {
	mut lower := language.trim_space().to_lower()
	if lower.len == 0 {
		return ''
	}
	mut end := lower.len
	for i, ch in lower {
		if ch == ` ` || ch == `\t` {
			end = i
			break
		}
	}
	lower = lower[..end]
	return match lower {
		'v', 'vlang' { 'v' }
		'js', 'javascript', 'node', 'nodejs', 'jsx', 'mjs', 'cjs' { 'js' }
		'ts', 'typescript', 'tsx' { 'ts' }
		'py', 'python', 'python3' { 'py' }
		'json', 'jsonc' { 'json' }
		'math', 'latex', 'tex' { 'math' }
		'mermaid' { 'mermaid' }
		else { lower }
	}
}

fn markdown_code_language_from_hint(language string) MarkdownCodeLanguage {
	match normalize_markdown_code_language_hint(language) {
		'v' { return .vlang }
		'js' { return .javascript }
		'ts' { return .typescript }
		'py' { return .python }
		'json' { return .json }
		else { return .generic }
	}
}

fn highlight_inline_code(code string, style MarkdownStyle) []RichTextRun {
	return highlight_code_runs(code, .generic, style, max_inline_code_highlight_bytes)
}

fn highlight_fenced_code(code string, language string, style MarkdownStyle) []RichTextRun {
	lang_hint := normalize_markdown_code_language_hint(language)
	if lang_hint in ['mermaid', 'math'] {
		return markdown_plain_code_runs(code, style.code)
	}
	lang := markdown_code_language_from_hint(language)
	return highlight_code_runs(code, lang, style, max_code_block_highlight_bytes)
}

fn markdown_plain_code_runs(code string, style TextStyle) []RichTextRun {
	return [
		RichTextRun{
			text:  code
			style: style
		},
	]
}

fn markdown_highlight_palette(style MarkdownStyle) MarkdownCodePalette {
	return MarkdownCodePalette{
		base:     style.code
		keyword:  TextStyle{
			...style.code
			color: style.code_keyword_color
		}
		string:   TextStyle{
			...style.code
			color: style.code_string_color
		}
		number:   TextStyle{
			...style.code
			color: style.code_number_color
		}
		comment:  TextStyle{
			...style.code
			color: style.code_comment_color
		}
		operator: TextStyle{
			...style.code
			color: style.code_operator_color
		}
	}
}

fn highlight_code_runs(code string, lang MarkdownCodeLanguage, style MarkdownStyle, max_bytes int) []RichTextRun {
	if code.len == 0 {
		return []RichTextRun{}
	}
	if code.len > max_bytes {
		return markdown_plain_code_runs(code, style.code)
	}

	palette := markdown_highlight_palette(style)
	mut tokens := []MarkdownCodeToken{cap: 128}
	mut pos := 0
	for pos < code.len {
		if tokens.len >= max_highlight_tokens_per_block {
			return markdown_fallback_with_tail(tokens, code, pos, palette)
		}

		start_pos := pos
		ch := code[pos]

		if is_markdown_code_whitespace(ch) {
			mut end := pos + 1
			for end < code.len && is_markdown_code_whitespace(code[end]) {
				if end - pos >= max_highlight_token_bytes {
					return markdown_fallback_with_tail(tokens, code, pos, palette)
				}
				end++
			}
			markdown_append_token(mut tokens, .plain, pos, end)
			pos = end
		} else if markdown_has_line_comment_start(code, pos, lang) {
			mut end := pos + markdown_line_comment_prefix_len(code, pos, lang)
			for end < code.len && code[end] != `\n` {
				if end - pos >= max_highlight_token_bytes {
					return markdown_fallback_with_tail(tokens, code, pos, palette)
				}
				end++
			}
			markdown_append_token(mut tokens, .comment, pos, end)
			pos = end
		} else if markdown_has_block_comment_start(code, pos, lang) {
			mut end := pos + 2
			mut depth := 1
			for end < code.len {
				if end - pos >= max_highlight_string_scan_bytes
					|| end - pos >= max_highlight_token_bytes {
					return markdown_fallback_with_tail(tokens, code, pos, palette)
				}
				if markdown_block_comments_nested(lang) && end + 1 < code.len && code[end] == `/`
					&& code[end + 1] == `*` {
					depth++
					if depth > max_highlight_comment_depth {
						return markdown_fallback_with_tail(tokens, code, pos, palette)
					}
					end += 2
					continue
				}
				if end + 1 < code.len && code[end] == `*` && code[end + 1] == `/` {
					depth--
					end += 2
					if depth == 0 {
						break
					}
					continue
				}
				end++
			}
			if end > code.len {
				end = code.len
			}
			markdown_append_token(mut tokens, .comment, pos, end)
			pos = end
		} else if markdown_is_string_delim(ch, lang) {
			end, ok := markdown_scan_string(code, pos, lang)
			if !ok {
				return markdown_fallback_with_tail(tokens, code, pos, palette)
			}
			markdown_append_token(mut tokens, .string, pos, end)
			pos = end
		} else if markdown_is_number_start(code, pos) {
			end, ok := markdown_scan_number(code, pos)
			if !ok {
				return markdown_fallback_with_tail(tokens, code, pos, palette)
			}
			markdown_append_token(mut tokens, .number, pos, end)
			pos = end
		} else if markdown_is_identifier_start(ch, lang) {
			end, ok := markdown_scan_identifier(code, pos, lang)
			if !ok {
				return markdown_fallback_with_tail(tokens, code, pos, palette)
			}
			ident := code[pos..end]
			token_kind := if markdown_is_keyword(ident, lang) {
				MarkdownCodeTokenKind.keyword
			} else {
				MarkdownCodeTokenKind.plain
			}
			markdown_append_token(mut tokens, token_kind, pos, end)
			pos = end
		} else if markdown_is_operator_char(ch) {
			mut end := pos + 1
			for end < code.len && markdown_is_operator_char(code[end]) {
				if end - pos >= max_highlight_token_bytes {
					return markdown_fallback_with_tail(tokens, code, pos, palette)
				}
				end++
			}
			markdown_append_token(mut tokens, .operator, pos, end)
			pos = end
		} else {
			markdown_append_token(mut tokens, .plain, pos, pos + 1)
			pos++
		}

		// Self-synchronization fallback: force forward progress.
		if pos <= start_pos {
			markdown_append_token(mut tokens, .plain, start_pos, start_pos + 1)
			pos = start_pos + 1
		}
	}

	return markdown_tokens_to_runs(tokens, code, palette)
}

fn markdown_fallback_with_tail(tokens []MarkdownCodeToken, code string, pos int, palette MarkdownCodePalette) []RichTextRun {
	mut runs := markdown_tokens_to_runs(tokens, code, palette)
	if pos < code.len {
		runs << RichTextRun{
			text:  code[pos..]
			style: palette.base
		}
	}
	return runs
}

fn markdown_tokens_to_runs(tokens []MarkdownCodeToken, code string, palette MarkdownCodePalette) []RichTextRun {
	mut runs := []RichTextRun{cap: tokens.len}
	for token in tokens {
		style := markdown_style_for_token(token.kind, palette)
		runs << RichTextRun{
			text:  code[token.start..token.end]
			style: style
		}
	}
	return runs
}

fn markdown_style_for_token(kind MarkdownCodeTokenKind, palette MarkdownCodePalette) TextStyle {
	return match kind {
		.plain { palette.base }
		.keyword { palette.keyword }
		.string { palette.string }
		.number { palette.number }
		.comment { palette.comment }
		.operator { palette.operator }
	}
}

fn markdown_append_token(mut tokens []MarkdownCodeToken, kind MarkdownCodeTokenKind, start int, end int) {
	if start == end {
		return
	}
	if tokens.len > 0 && tokens.last().kind == kind && tokens.last().end == start {
		tokens[tokens.len - 1].end = end
		return
	}
	tokens << MarkdownCodeToken{
		kind:  kind
		start: start
		end:   end
	}
}

fn markdown_is_identifier_start(ch u8, lang MarkdownCodeLanguage) bool {
	if (ch >= `a` && ch <= `z`) || (ch >= `A` && ch <= `Z`) || ch == `_` {
		return true
	}
	return (lang in [.javascript, .typescript] || lang == .generic) && ch == `$`
}

fn markdown_is_identifier_continue(ch u8, lang MarkdownCodeLanguage) bool {
	if markdown_is_identifier_start(ch, lang) {
		return true
	}
	return ch >= `0` && ch <= `9`
}

fn markdown_scan_identifier(code string, pos int, lang MarkdownCodeLanguage) (int, bool) {
	mut end := pos + 1
	for end < code.len && markdown_is_identifier_continue(code[end], lang) {
		if end - pos >= max_highlight_identifier_bytes || end - pos >= max_highlight_token_bytes {
			return 0, false
		}
		end++
	}
	return end, true
}

fn markdown_is_number_start(code string, pos int) bool {
	if code[pos] >= `0` && code[pos] <= `9` {
		return true
	}
	return code[pos] == `.` && pos + 1 < code.len && code[pos + 1] >= `0` && code[pos + 1] <= `9`
}

fn markdown_scan_number(code string, pos int) (int, bool) {
	mut end := pos
	mut seen_exp := false
	for end < code.len {
		ch := code[end]
		is_num := (ch >= `0` && ch <= `9`) || ch == `.` || ch == `_`
		is_base := (ch >= `a` && ch <= `f`) || (ch >= `A` && ch <= `F`) || ch == `x`
			|| ch == `X` || ch == `b` || ch == `B` || ch == `o` || ch == `O`
		is_exp := (ch == `e` || ch == `E`) && !seen_exp
		if is_exp {
			seen_exp = true
			end++
			if end < code.len && (code[end] == `+` || code[end] == `-`) {
				end++
			}
			continue
		}
		if is_num || is_base {
			end++
			if end - pos >= max_highlight_number_bytes || end - pos >= max_highlight_token_bytes {
				return 0, false
			}
			continue
		}
		break
	}
	if end == pos {
		return 0, false
	}
	return end, true
}

fn markdown_is_string_delim(ch u8, lang MarkdownCodeLanguage) bool {
	match lang {
		.json {
			return ch == `"`
		}
		.python {
			return ch == `"` || ch == `'`
		}
		.javascript, .typescript {
			return ch == `"` || ch == `'` || ch == `\``
		}
		else {
			return ch == `"` || ch == `'` || ch == `\``
		}
	}
}

fn markdown_scan_string(code string, pos int, lang MarkdownCodeLanguage) (int, bool) {
	quote := code[pos]
	if lang == .python && pos + 2 < code.len && code[pos + 1] == quote && code[pos + 2] == quote {
		mut end := pos + 3
		for end + 2 < code.len {
			if end - pos >= max_highlight_string_scan_bytes
				|| end - pos >= max_highlight_token_bytes {
				return 0, false
			}
			if code[end] == quote && code[end + 1] == quote && code[end + 2] == quote {
				return end + 3, true
			}
			end++
		}
		return code.len, true
	}

	mut end := pos + 1
	for end < code.len {
		if end - pos >= max_highlight_string_scan_bytes || end - pos >= max_highlight_token_bytes {
			return 0, false
		}
		ch := code[end]
		if ch == `\\` {
			if end + 1 < code.len {
				end += 2
				continue
			}
			end++
			break
		}
		if ch == quote {
			end++
			break
		}
		end++
	}
	return end, true
}

fn markdown_has_line_comment_start(code string, pos int, lang MarkdownCodeLanguage) bool {
	if pos + 1 < code.len && code[pos] == `/` && code[pos + 1] == `/`
		&& lang in [.generic, .vlang, .javascript, .typescript] {
		return true
	}
	return code[pos] == `#` && lang in [.generic, .python]
}

fn markdown_line_comment_prefix_len(code string, pos int, lang MarkdownCodeLanguage) int {
	if pos + 1 < code.len && code[pos] == `/` && code[pos + 1] == `/`
		&& lang in [.generic, .vlang, .javascript, .typescript] {
		return 2
	}
	return 1
}

fn markdown_has_block_comment_start(code string, pos int, lang MarkdownCodeLanguage) bool {
	return pos + 1 < code.len && code[pos] == `/` && code[pos + 1] == `*`
		&& lang in [.generic, .vlang, .javascript, .typescript]
}

fn markdown_block_comments_nested(lang MarkdownCodeLanguage) bool {
	return lang == .vlang || lang == .generic
}

fn markdown_is_keyword(ident string, lang MarkdownCodeLanguage) bool {
	match lang {
		.vlang {
			return ident in ['as', 'asm', 'assert', 'atomic', 'break', 'const', 'continue', 'defer',
				'else', 'enum', 'false', 'fn', 'for', 'global', 'go', 'goto', 'if', 'import', 'in',
				'interface', 'is', 'lock', 'match', 'module', 'mut', 'none', 'or', 'pub', 'return',
				'rlock', 'select', 'shared', 'sizeof', 'spawn', 'static', 'struct', 'true', 'type',
				'typeof', 'union', 'unsafe', 'volatile']
		}
		.javascript {
			return ident in ['async', 'await', 'break', 'case', 'catch', 'class', 'const', 'continue',
				'debugger', 'default', 'delete', 'do', 'else', 'export', 'extends', 'false',
				'finally', 'for', 'function', 'if', 'import', 'in', 'instanceof', 'let', 'new',
				'null', 'return', 'super', 'switch', 'this', 'throw', 'true', 'try', 'typeof',
				'var', 'void', 'while', 'with', 'yield']
		}
		.typescript {
			return ident in ['abstract', 'any', 'as', 'asserts', 'async', 'await', 'bigint',
				'boolean', 'break', 'case', 'catch', 'class', 'const', 'constructor', 'continue',
				'debugger', 'declare', 'default', 'delete', 'do', 'else', 'enum', 'export', 'extends',
				'false', 'finally', 'for', 'from', 'function', 'get', 'if', 'implements', 'import',
				'in', 'infer', 'instanceof', 'interface', 'is', 'keyof', 'let', 'module', 'namespace',
				'never', 'new', 'null', 'number', 'object', 'package', 'private', 'protected',
				'public', 'readonly', 'return', 'set', 'static', 'string', 'super', 'switch',
				'symbol', 'this', 'throw', 'true', 'try', 'type', 'typeof', 'undefined', 'unique',
				'unknown', 'var', 'void', 'while', 'with', 'yield']
		}
		.python {
			return ident in ['False', 'None', 'True', 'and', 'as', 'assert', 'async', 'await',
				'break', 'class', 'continue', 'def', 'del', 'elif', 'else', 'except', 'finally',
				'for', 'from', 'global', 'if', 'import', 'in', 'is', 'lambda', 'nonlocal', 'not',
				'or', 'pass', 'raise', 'return', 'try', 'while', 'with', 'yield']
		}
		.json {
			return ident in ['true', 'false', 'null']
		}
		.generic {
			return false
		}
	}
}

fn markdown_is_operator_char(ch u8) bool {
	return ch in [`+`, `-`, `*`, `/`, `%`, `=`, `&`, `|`, `^`, `!`, `<`, `>`, `?`, `:`, `.`, `,`,
		`;`, `(`, `)`, `[`, `]`, `{`, `}`, `~`]
}

fn is_markdown_code_whitespace(ch u8) bool {
	return ch == ` ` || ch == `\t` || ch == `\n` || ch == `\r`
}
