module markdown

// highlight.v provides syntax tokenization for code blocks.
// Returns token spans only — palette application is done by
// the gui styling bridge.

// Limits for code highlighting.
pub const max_code_block_highlight_bytes = 131072
pub const max_inline_code_highlight_bytes = 2048
const max_highlight_tokens_per_block = 16384
const max_highlight_token_bytes = 4096
pub const max_highlight_comment_depth = 16
pub const max_highlight_string_scan_bytes = 32768
const max_highlight_identifier_bytes = 256
const max_highlight_number_bytes = 128

pub fn normalize_language_hint(language string) string {
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
		'go', 'golang' { 'go' }
		'rs', 'rust' { 'rust' }
		'c', 'cpp', 'c++', 'cc', 'cxx', 'h', 'hpp', 'hxx' { 'c' }
		'sh', 'bash', 'shell', 'zsh', 'fish' { 'shell' }
		'html', 'htm', 'css', 'xml', 'svg', 'xhtml' { 'html' }
		'math', 'latex', 'tex' { 'math' }
		'mermaid' { 'mermaid' }
		else { lower }
	}
}

pub fn language_from_hint(language string) MdCodeLanguage {
	match normalize_language_hint(language) {
		'v' { return .vlang }
		'js' { return .javascript }
		'ts' { return .typescript }
		'py' { return .python }
		'json' { return .json }
		'go' { return .golang }
		'rust' { return .rust }
		'c' { return .c_lang }
		'shell' { return .shell }
		'html' { return .html }
		else { return .generic }
	}
}

// tokenize_code tokenizes source code and returns token spans.
// Returns empty slice if code exceeds max_bytes.
pub fn tokenize_code(code string, lang MdCodeLanguage, max_bytes int) []MdCodeToken {
	if code.len == 0 || code.len > max_bytes {
		return []MdCodeToken{}
	}

	mut tokens := []MdCodeToken{cap: 128}
	mut pos := 0
	for pos < code.len {
		if tokens.len >= max_highlight_tokens_per_block {
			append_tail_token(mut tokens, code, pos)
			return tokens
		}

		start_pos := pos
		ch := code[pos]

		if is_code_whitespace(ch) {
			mut end := pos + 1
			for end < code.len && is_code_whitespace(code[end]) {
				if end - pos >= max_highlight_token_bytes {
					append_tail_token(mut tokens, code, pos)
					return tokens
				}
				end++
			}
			append_token(mut tokens, .plain, pos, end)
			pos = end
		} else if has_line_comment_start(code, pos, lang) {
			mut end := pos + line_comment_prefix_len(code, pos, lang)
			for end < code.len && code[end] != `\n` {
				if end - pos >= max_highlight_token_bytes {
					append_tail_token(mut tokens, code, pos)
					return tokens
				}
				end++
			}
			append_token(mut tokens, .comment, pos, end)
			pos = end
		} else if has_block_comment_start(code, pos, lang) {
			if lang == .html {
				mut end := pos + 4
				for end + 2 < code.len {
					if end - pos >= max_highlight_string_scan_bytes
						|| end - pos >= max_highlight_token_bytes {
						append_tail_token(mut tokens, code, pos)
						return tokens
					}
					if code[end] == `-` && code[end + 1] == `-` && code[end + 2] == `>` {
						end += 3
						break
					}
					end++
				}
				if end > code.len {
					end = code.len
				}
				append_token(mut tokens, .comment, pos, end)
				pos = end
			} else {
				mut end := pos + 2
				mut depth := 1
				for end < code.len {
					if end - pos >= max_highlight_string_scan_bytes
						|| end - pos >= max_highlight_token_bytes {
						append_tail_token(mut tokens, code, pos)
						return tokens
					}
					if block_comments_nested(lang) && end + 1 < code.len && code[end] == `/`
						&& code[end + 1] == `*` {
						depth++
						if depth > max_highlight_comment_depth {
							append_tail_token(mut tokens, code, pos)
							return tokens
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
				append_token(mut tokens, .comment, pos, end)
				pos = end
			}
		} else if is_string_delim(ch, lang) {
			end, ok := scan_string(code, pos, lang)
			if !ok {
				append_tail_token(mut tokens, code, pos)
				return tokens
			}
			append_token(mut tokens, .string_, pos, end)
			pos = end
		} else if is_number_start(code, pos) {
			end, ok := scan_number(code, pos)
			if !ok {
				append_tail_token(mut tokens, code, pos)
				return tokens
			}
			append_token(mut tokens, .number, pos, end)
			pos = end
		} else if is_identifier_start(ch, lang) {
			end, ok := scan_identifier(code, pos, lang)
			if !ok {
				append_tail_token(mut tokens, code, pos)
				return tokens
			}
			ident := code[pos..end]
			token_kind := if is_keyword(ident, lang) {
				MdCodeTokenKind.keyword
			} else {
				MdCodeTokenKind.plain
			}
			append_token(mut tokens, token_kind, pos, end)
			pos = end
		} else if is_operator_char(ch) {
			mut end := pos + 1
			for end < code.len && is_operator_char(code[end]) {
				if end - pos >= max_highlight_token_bytes {
					append_tail_token(mut tokens, code, pos)
					return tokens
				}
				end++
			}
			append_token(mut tokens, .operator, pos, end)
			pos = end
		} else {
			append_token(mut tokens, .plain, pos, pos + 1)
			pos++
		}

		if pos <= start_pos {
			append_token(mut tokens, .plain, start_pos, start_pos + 1)
			pos = start_pos + 1
		}
	}

	return tokens
}

fn append_tail_token(mut tokens []MdCodeToken, code string, pos int) {
	if pos < code.len {
		append_token(mut tokens, .plain, pos, code.len)
	}
}

fn append_token(mut tokens []MdCodeToken, kind MdCodeTokenKind, start int, end int) {
	if start == end {
		return
	}
	if tokens.len > 0 && tokens.last().kind == kind && tokens.last().end == start {
		tokens[tokens.len - 1].end = end
		return
	}
	tokens << MdCodeToken{
		kind:  kind
		start: start
		end:   end
	}
}

fn is_identifier_start(ch u8, lang MdCodeLanguage) bool {
	if (ch >= `a` && ch <= `z`) || (ch >= `A` && ch <= `Z`) || ch == `_` {
		return true
	}
	if (lang in [.javascript, .typescript] || lang == .generic) && ch == `$` {
		return true
	}
	return lang == .html && ch == `-`
}

fn is_identifier_continue(ch u8, lang MdCodeLanguage) bool {
	if is_identifier_start(ch, lang) {
		return true
	}
	if ch >= `0` && ch <= `9` {
		return true
	}
	return lang == .html && ch == `-`
}

fn scan_identifier(code string, pos int, lang MdCodeLanguage) (int, bool) {
	mut end := pos + 1
	for end < code.len && is_identifier_continue(code[end], lang) {
		if end - pos >= max_highlight_identifier_bytes || end - pos >= max_highlight_token_bytes {
			return 0, false
		}
		end++
	}
	return end, true
}

fn is_number_start(code string, pos int) bool {
	if code[pos] >= `0` && code[pos] <= `9` {
		return true
	}
	return code[pos] == `.` && pos + 1 < code.len && code[pos + 1] >= `0` && code[pos + 1] <= `9`
}

fn scan_number(code string, pos int) (int, bool) {
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

fn is_string_delim(ch u8, lang MdCodeLanguage) bool {
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
		.golang {
			return ch == `"` || ch == `'` || ch == `\``
		}
		.rust, .c_lang {
			return ch == `"` || ch == `'`
		}
		.shell {
			return ch == `"` || ch == `'`
		}
		.html {
			return ch == `"` || ch == `'`
		}
		else {
			return ch == `"` || ch == `'` || ch == `\``
		}
	}
}

fn scan_string(code string, pos int, lang MdCodeLanguage) (int, bool) {
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

fn has_line_comment_start(code string, pos int, lang MdCodeLanguage) bool {
	if pos + 1 < code.len && code[pos] == `/` && code[pos + 1] == `/`
		&& lang in [.generic, .vlang, .javascript, .typescript, .golang, .rust, .c_lang] {
		return true
	}
	if code[pos] == `#` && lang in [.generic, .python, .shell] {
		return true
	}
	return false
}

fn line_comment_prefix_len(code string, pos int, lang MdCodeLanguage) int {
	if pos + 1 < code.len && code[pos] == `/` && code[pos + 1] == `/`
		&& lang in [.generic, .vlang, .javascript, .typescript, .golang, .rust, .c_lang] {
		return 2
	}
	return 1
}

fn has_block_comment_start(code string, pos int, lang MdCodeLanguage) bool {
	if pos + 1 < code.len && code[pos] == `/` && code[pos + 1] == `*`
		&& lang in [.generic, .vlang, .javascript, .typescript, .golang, .rust, .c_lang] {
		return true
	}
	if pos + 3 < code.len && code[pos] == `<` && code[pos + 1] == `!` && code[pos + 2] == `-`
		&& code[pos + 3] == `-` && lang == .html {
		return true
	}
	return false
}

fn block_comments_nested(lang MdCodeLanguage) bool {
	return lang == .vlang || lang == .rust || lang == .generic
}

fn is_keyword(ident string, lang MdCodeLanguage) bool {
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
		.golang {
			return ident in ['break', 'case', 'chan', 'const', 'continue', 'default', 'defer',
				'else', 'fallthrough', 'for', 'func', 'go', 'goto', 'if', 'import', 'interface',
				'map', 'package', 'range', 'return', 'select', 'struct', 'switch', 'type', 'var',
				'true', 'false', 'nil', 'iota', 'append', 'cap', 'close', 'copy', 'delete', 'len',
				'make', 'new', 'panic', 'print', 'println', 'recover', 'error', 'string', 'int',
				'int8', 'int16', 'int32', 'int64', 'uint', 'uint8', 'uint16', 'uint32', 'uint64',
				'float32', 'float64', 'complex64', 'complex128', 'bool', 'byte', 'rune', 'any']
		}
		.rust {
			return ident in ['as', 'async', 'await', 'break', 'const', 'continue', 'crate', 'dyn',
				'else', 'enum', 'extern', 'false', 'fn', 'for', 'if', 'impl', 'in', 'let', 'loop',
				'match', 'mod', 'move', 'mut', 'pub', 'ref', 'return', 'self', 'Self', 'static',
				'struct', 'super', 'trait', 'true', 'type', 'unsafe', 'use', 'where', 'while',
				'yield', 'Box', 'Option', 'Result', 'Some', 'None', 'Ok', 'Err', 'Vec', 'String',
				'str', 'i8', 'i16', 'i32', 'i64', 'i128', 'isize', 'u8', 'u16', 'u32', 'u64', 'u128',
				'usize', 'f32', 'f64', 'bool', 'char', 'println', 'eprintln', 'format', 'panic',
				'todo', 'unimplemented', 'unreachable', 'macro_rules']
		}
		.c_lang {
			return ident in [
				'auto',
				'break',
				'case',
				'char',
				'const',
				'continue',
				'default',
				'do',
				'double',
				'else',
				'enum',
				'extern',
				'float',
				'for',
				'goto',
				'if',
				'inline',
				'int',
				'long',
				'register',
				'restrict',
				'return',
				'short',
				'signed',
				'sizeof',
				'static',
				'struct',
				'switch',
				'typedef',
				'union',
				'unsigned',
				'void',
				'volatile',
				'while',
				'_Bool',
				'_Complex',
				'_Imaginary',
				'bool',
				'true',
				'false',
				'NULL',
				'nullptr',
				'class',
				'namespace',
				'template',
				'typename',
				'public',
				'private',
				'protected',
				'virtual',
				'override',
				'final',
				'new',
				'delete',
				'this',
				'throw',
				'try',
				'catch',
				'using',
				'constexpr',
				'noexcept',
				'decltype',
				'static_cast',
				'dynamic_cast',
				'reinterpret_cast',
				'const_cast',
				'operator',
				'friend',
				'mutable',
				'explicit',
				'export',
				'concept',
				'requires',
				'co_await',
				'co_return',
				'co_yield',
				'include',
				'define',
				'ifdef',
				'ifndef',
				'endif',
				'pragma',
				'std',
				'cout',
				'cin',
				'endl',
				'string',
				'vector',
				'map',
				'set',
				'pair',
				'unique_ptr',
				'shared_ptr',
				'weak_ptr',
				'size_t',
				'uint8_t',
				'uint16_t',
				'uint32_t',
				'uint64_t',
				'int8_t',
				'int16_t',
				'int32_t',
				'int64_t',
			]
		}
		.shell {
			return ident in ['if', 'then', 'else', 'elif', 'fi', 'for', 'while', 'until', 'do',
				'done', 'case', 'esac', 'in', 'function', 'select', 'time', 'coproc', 'return',
				'exit', 'break', 'continue', 'shift', 'export', 'readonly', 'declare', 'local',
				'typeset', 'unset', 'eval', 'exec', 'source', 'set', 'true', 'false', 'echo',
				'printf', 'read', 'test', 'cd', 'pwd', 'ls', 'cp', 'mv', 'rm', 'mkdir', 'rmdir',
				'chmod', 'chown', 'grep', 'sed', 'awk', 'find', 'xargs', 'cat', 'head', 'tail',
				'sort', 'uniq', 'wc', 'tr', 'cut', 'tee', 'curl', 'wget', 'tar', 'gzip', 'git',
				'docker', 'sudo', 'apt', 'yum', 'brew', 'pip', 'npm', 'yarn']
		}
		.html {
			return ident in ['html', 'head', 'body', 'div', 'span', 'p', 'a', 'img', 'ul', 'ol',
				'li', 'table', 'tr', 'td', 'th', 'form', 'input', 'button', 'select', 'option',
				'textarea', 'label', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'header', 'footer', 'nav',
				'main', 'section', 'article', 'aside', 'script', 'style', 'link', 'meta', 'title',
				'br', 'hr', 'pre', 'code', 'strong', 'em', 'blockquote', 'iframe', 'canvas', 'svg',
				'video', 'audio', 'source', 'template', 'slot', 'details', 'summary', 'dialog',
				'color', 'background', 'margin', 'padding', 'border', 'display', 'position', 'width',
				'height', 'font', 'text', 'align', 'flex', 'grid', 'float', 'clear', 'overflow',
				'opacity', 'transform', 'transition', 'animation', 'cursor', 'none', 'block',
				'inline', 'absolute', 'relative', 'fixed', 'sticky', 'static', 'inherit', 'initial',
				'unset', 'auto', 'important', 'media', 'keyframes', 'import', 'var', 'calc', 'min',
				'max', 'clamp', 'rgb', 'rgba', 'hsl', 'hsla']
		}
		.json {
			return ident in ['true', 'false', 'null']
		}
		.generic {
			return false
		}
	}
}

fn is_operator_char(ch u8) bool {
	return ch in [`+`, `-`, `*`, `/`, `%`, `=`, `&`, `|`, `^`, `!`, `<`, `>`, `?`, `:`, `.`, `,`,
		`;`, `(`, `)`, `[`, `]`, `{`, `}`, `~`]
}

fn is_code_whitespace(ch u8) bool {
	return ch == ` ` || ch == `\t` || ch == `\n` || ch == `\r`
}
