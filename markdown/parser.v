module markdown

import strings

// parser.v implements a markdown parser that converts markdown
// text to a style-free AST of MdBlocks.

// parse parses markdown source into style-free AST blocks.
pub fn parse(source string) []MdBlock {
	return parse_with_options(source, ParseOptions{})
}

// parse_with_options parses with configurable behavior.
pub fn parse_with_options(source string, opts ParseOptions) []MdBlock {
	scanner := new_scanner(source)
	link_defs, abbr_defs, footnote_defs := collect_metadata(scanner)

	mut p := MdParser{
		opts:          opts
		link_defs:     link_defs
		abbr_defs:     abbr_defs
		footnote_defs: footnote_defs
		scanner:       scanner
		blocks:        []MdBlock{cap: scanner.len() / 3}
		runs:          []MdRun{cap: 20}
	}

	return p.parse()
}

struct MdParser {
	opts          ParseOptions
	link_defs     map[string]string
	abbr_defs     map[string]string
	footnote_defs map[string]string
	scanner       MdScanner
mut:
	blocks             []MdBlock
	runs               []MdRun
	i                  int
	in_code_block      bool
	code_fence_char    u8
	code_fence_count   int
	code_fence_lang    string
	code_block_content []string
}

fn (mut p MdParser) parse() []MdBlock {
	for p.i < p.scanner.len() {
		line := p.scanner.get_line(p.i)
		trimmed := line.trim_space()

		if p.in_code_block {
			if fence := parse_code_fence(line) {
				if fence.char == p.code_fence_char && fence.count >= p.code_fence_count {
					p.flush_code_block()
					p.i++
					continue
				}
			}
			if p.code_block_content.len >= max_code_block_lines {
				p.flush_code_block()
				p.i++
				continue
			}
			p.code_block_content << line
			p.i++
			continue
		}

		if p.is_metadata_line(line) {
			p.skip_metadata_continuation()
			p.i++
			continue
		}

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
		if p.try_indented_code_block(line) {
			continue
		}
		if p.try_math_block(trimmed) {
			continue
		}
		if p.try_definition_term(trimmed) {
			continue
		}

		p.handle_paragraph(line)
	}

	p.finalize()
	return p.blocks
}

fn (p MdParser) is_metadata_line(line string) bool {
	return is_footnote_definition(line) || is_link_definition(line)
		|| (line.starts_with('*[') && line.contains(']:'))
}

fn (mut p MdParser) skip_metadata_continuation() {
	if is_footnote_definition(p.scanner.get_line(p.i)) {
		p.i++
		mut fn_cont := 0
		for p.i < p.scanner.len() && fn_cont < max_footnote_continuation_lines {
			next := p.scanner.get_line(p.i)
			if next.len == 0 {
				if p.i + 1 < p.scanner.len() {
					peek := p.scanner.get_line(p.i + 1)
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
		p.i--
	}
}

fn (mut p MdParser) try_code_fence(line string) bool {
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

fn (mut p MdParser) flush_code_block() {
	lang_hint := normalize_language_hint(p.code_fence_lang)
	mut cap := 0
	for line in p.code_block_content {
		cap += line.len + 1
	}
	mut sb := strings.new_builder(cap)
	for j, line in p.code_block_content {
		sb.write_string(line)
		if j < p.code_block_content.len - 1 {
			sb.write_u8(`\n`)
		}
	}
	code_text := sb.str()
	p.flush_runs()
	if p.code_block_content.len > 0 {
		if lang_hint == 'math' {
			p.blocks << MdBlock{
				is_math:    true
				math_latex: code_text
			}
		} else {
			lang := language_from_hint(lang_hint)
			tokens := tokenize_code(code_text, lang, max_code_block_highlight_bytes)
			mut code_runs := []MdRun{cap: tokens.len + 1}
			if tokens.len == 0 {
				// Oversized or empty — single plain code run
				code_runs << MdRun{
					text:   code_text
					format: .code
				}
			} else {
				for token in tokens {
					code_runs << MdRun{
						text:       code_text[token.start..token.end]
						format:     .code
						code_token: token.kind
					}
				}
			}
			p.blocks << MdBlock{
				is_code:       true
				code_language: lang_hint
				runs:          code_runs
			}
		}
	}
	p.code_block_content.clear()
	p.in_code_block = false
	p.code_fence_char = 0
	p.code_fence_count = 0
	p.code_fence_lang = ''
	p.runs << md_br()
}

fn (mut p MdParser) try_horizontal_rule(trimmed string) bool {
	if is_horizontal_rule(trimmed) {
		p.flush_runs()
		p.blocks << MdBlock{
			is_hr: true
		}
		p.i++
		return true
	}
	return false
}

fn (mut p MdParser) try_blank_line(trimmed string) bool {
	if trimmed == '' {
		if p.runs.len > 0 {
			last_is_br := p.runs.last().text == '\n'
			p.runs << md_br()
			if !last_is_br {
				p.runs << md_br()
			}
		}
		p.i++
		return true
	}
	return false
}

fn (mut p MdParser) try_table() bool {
	line := p.scanner.get_line(p.i)
	trimmed := line.trim_space()
	is_table_start := trimmed.starts_with('|') || is_table_separator(trimmed)
		|| (trimmed.contains('|') && p.i + 1 < p.scanner.len()
		&& is_table_separator(p.scanner.get_line(p.i + 1).trim_space()))
	if !is_table_start {
		return false
	}
	mut start_i := p.i
	mut table_lines := []string{cap: 10}
	for start_i < p.scanner.len() && table_lines.len < max_table_lines {
		tl := p.scanner.get_line(start_i).trim_space()
		if tl.starts_with('|') || is_table_separator(tl) || tl.contains('|') {
			table_lines << p.scanner.get_line(start_i)
			start_i++
		} else if tl == '' && table_lines.len > 0 {
			break
		} else {
			break
		}
	}
	if table_lines.len > 0 {
		parsed_table := parse_md_table(table_lines, p.link_defs, p.footnote_defs)
		p.flush_runs()
		// Fallback plain-text content for the block
		mut fallback_runs := []MdRun{cap: 1}
		fallback_runs << MdRun{
			text:   table_lines.join('\n')
			format: .code
		}
		p.blocks << MdBlock{
			is_table:   true
			table_data: parsed_table
			runs:       fallback_runs
		}
		p.i = start_i
		return true
	}
	return false
}

fn (mut p MdParser) try_definition_line(line string, trimmed string) bool {
	if is_definition_line(line) {
		p.flush_runs()
		first_content := trimmed[2..].trim_left(' \t')
		content, consumed := collect_definition_content(first_content, p.scanner, p.i + 1)
		mut def_runs := []MdRun{cap: 10}
		parse_inline(content, .plain, mut def_runs, p.link_defs, p.footnote_defs, 0)
		p.blocks << MdBlock{
			is_def_value: true
			runs:         def_runs
		}
		p.i += 1 + consumed
		return true
	}
	return false
}

fn (mut p MdParser) try_image(line string) bool {
	if line.starts_with('![') {
		bracket_end := find_closing(line, 2, `]`)
		if bracket_end > 2 && bracket_end + 1 < line.len && line[bracket_end + 1] == `(` {
			paren_end := find_closing(line, bracket_end + 2, `)`)
			if paren_end > bracket_end + 2 {
				p.flush_runs()
				raw := line[bracket_end + 2..paren_end]
				src, w, h := parse_image_src(raw)
				p.blocks << MdBlock{
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

fn (mut p MdParser) try_setext_header(trimmed string) bool {
	if trimmed.len > 0 && p.i + 1 < p.scanner.len() && !is_block_start(trimmed) {
		level := is_setext_underline(p.scanner.get_line(p.i + 1))
		if level > 0 {
			p.flush_runs()
			p.blocks << parse_header_block(trimmed, level, p.link_defs, p.footnote_defs)
			p.i += 2
			return true
		}
	}
	return false
}

fn (mut p MdParser) try_blockquote() bool {
	line := p.scanner.get_line(p.i)
	if !line.starts_with('>') {
		return false
	}
	mut start_i := p.i
	block_depth := count_blockquote_depth(line)
	mut quote_lines := []string{cap: 10}
	for start_i < p.scanner.len() && quote_lines.len < max_blockquote_lines {
		q := p.scanner.get_line(start_i)
		if q.starts_with('>') {
			content := strip_blockquote_prefix(q)
			quote_lines << content
			start_i++
		} else {
			break
		}
	}
	mut quote_runs := []MdRun{cap: 20}
	for qi, ql in quote_lines {
		if ql.trim_space() == '' {
			quote_runs << md_br()
		} else {
			parse_inline(ql, .plain, mut quote_runs, p.link_defs, p.footnote_defs, 0)
			if qi < quote_lines.len - 1 {
				next_ql := quote_lines[qi + 1]
				if next_ql.trim_space() == '' {
					quote_runs << md_br()
				} else if p.opts.hard_line_breaks && has_hard_break(ql) {
					quote_runs << md_br()
				} else {
					quote_runs << MdRun{
						text: ' '
					}
				}
			}
		}
	}
	p.flush_runs()
	p.blocks << MdBlock{
		is_blockquote:    true
		blockquote_depth: block_depth
		runs:             quote_runs
	}
	p.i = start_i
	return true
}

fn (mut p MdParser) try_atx_header(line string) bool {
	if !line.starts_with('#') {
		return false
	}
	mut level := 0
	for level < line.len && level < 6 && line[level] == `#` {
		level++
	}
	if level > 0 && (level == line.len || line[level] == ` ` || line[level] == `\t`) {
		text := line[level..].trim_left(' \t')
		p.flush_runs()
		p.blocks << parse_header_block(text, level, p.link_defs, p.footnote_defs)
		p.i++
		return true
	}
	return false
}

fn (mut p MdParser) try_list_item() bool {
	line := p.scanner.get_line(p.i)
	left_trimmed := line.trim_left(' \t')
	indent := get_indent_level(line)

	if task_prefix := get_task_prefix(left_trimmed) {
		task_prefix_len := 6
		content, consumed := collect_list_item_content(left_trimmed[task_prefix_len..],
			p.scanner, p.i + 1)
		mut item_runs := []MdRun{cap: 10}
		parse_inline(content, .plain, mut item_runs, p.link_defs, p.footnote_defs, 0)
		p.flush_runs()
		p.blocks << MdBlock{
			is_list:     true
			list_prefix: task_prefix
			list_indent: indent
			runs:        item_runs
		}
		p.i += 1 + consumed
		return true
	}

	if left_trimmed.starts_with('- ') || left_trimmed.starts_with('* ')
		|| left_trimmed.starts_with('+ ') {
		content, consumed := collect_list_item_content(left_trimmed[2..], p.scanner, p.i + 1)
		mut item_runs := []MdRun{cap: 10}
		parse_inline(content, .plain, mut item_runs, p.link_defs, p.footnote_defs, 0)
		p.flush_runs()
		p.blocks << MdBlock{
			is_list:     true
			list_prefix: '• '
			list_indent: indent
			runs:        item_runs
		}
		p.i += 1 + consumed
		return true
	}

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
		content, consumed := collect_list_item_content(rest, p.scanner, p.i + 1)
		mut item_runs := []MdRun{cap: 10}
		parse_inline(content, .plain, mut item_runs, p.link_defs, p.footnote_defs, 0)
		p.flush_runs()
		p.blocks << MdBlock{
			is_list:     true
			list_prefix: '${num}${sep} '
			list_indent: indent
			runs:        item_runs
		}
		p.i += 1 + consumed
		return true
	}

	return false
}

fn (mut p MdParser) try_indented_code_block(line string) bool {
	if !has_code_indent(line) {
		return false
	}
	mut code_lines := []string{cap: 20}
	mut idx := p.i
	for idx < p.scanner.len() && code_lines.len < max_code_block_lines {
		l := p.scanner.get_line(idx)
		if has_code_indent(l) {
			code_lines << strip_code_indent(l)
			idx++
		} else if l.trim_space() == '' {
			if idx + 1 < p.scanner.len() && has_code_indent(p.scanner.get_line(idx + 1)) {
				code_lines << ''
				idx++
			} else {
				break
			}
		} else {
			break
		}
	}
	if code_lines.len == 0 {
		return false
	}
	p.flush_runs()
	code_text := code_lines.join('\n')
	lang := language_from_hint('')
	tokens := tokenize_code(code_text, lang, max_code_block_highlight_bytes)
	mut code_runs := []MdRun{cap: tokens.len + 1}
	if tokens.len == 0 {
		code_runs << MdRun{
			text:   code_text
			format: .code
		}
	} else {
		for token in tokens {
			code_runs << MdRun{
				text:       code_text[token.start..token.end]
				format:     .code
				code_token: token.kind
			}
		}
	}
	p.blocks << MdBlock{
		is_code: true
		runs:    code_runs
	}
	p.i = idx
	return true
}

fn (mut p MdParser) try_math_block(trimmed string) bool {
	if trimmed.starts_with('$$') {
		p.flush_runs()
		if trimmed.len > 4 && trimmed.ends_with('$$') {
			latex := trimmed[2..trimmed.len - 2].trim_space()
			if latex.len > 0 {
				p.blocks << MdBlock{
					is_math:    true
					math_latex: latex
				}
				p.i++
				return true
			}
		}
		p.i++
		mut math_lines := []string{cap: 64}
		for p.i < p.scanner.len() && math_lines.len < max_math_block_lines {
			ml := p.scanner.get_line(p.i)
			if ml.trim_space() == '$$' {
				break
			}
			math_lines << ml
			p.i++
		}
		if math_lines.len > 0 {
			p.blocks << MdBlock{
				is_math:    true
				math_latex: math_lines.join('\n')
			}
		}
		p.i++
		return true
	}
	return false
}

fn (mut p MdParser) try_definition_term(trimmed string) bool {
	if peek_for_definition(p.scanner, p.i + 1) {
		p.flush_runs()
		mut term_runs := []MdRun{cap: 10}
		parse_inline(trimmed, .bold, mut term_runs, p.link_defs, p.footnote_defs, 0)
		p.blocks << MdBlock{
			is_def_term: true
			runs:        term_runs
		}
		p.i++
		return true
	}
	return false
}

fn (mut p MdParser) handle_paragraph(line string) {
	content, consumed := collect_paragraph_content(line, p.scanner, p.i + 1, p.opts.hard_line_breaks)
	parse_inline(content, .plain, mut p.runs, p.link_defs, p.footnote_defs, 0)
	p.i += 1 + consumed

	if p.i < p.scanner.len() {
		next := p.scanner.get_line(p.i)
		next_trimmed := next.trim_space()
		if next_trimmed != '' && is_block_start(next) {
			p.runs << md_br()
		}
	}
}

fn (mut p MdParser) finalize() {
	if p.in_code_block && p.code_block_content.len > 0 {
		p.flush_code_block()
	}
	p.flush_runs()

	if p.abbr_defs.len > 0 {
		for mut block in p.blocks {
			block.runs = replace_abbreviations(block.runs, p.abbr_defs)
		}
	}
}

fn (mut p MdParser) flush_runs() {
	trim_trailing_breaks(mut p.runs)
	if p.runs.len > 0 {
		p.blocks << MdBlock{
			runs: p.runs
		}
		p.runs = []MdRun{cap: 20}
	}
}

// parse_code_fence checks if line is a code fence.
pub fn parse_code_fence(line string) ?CodeFence {
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
		lang := trimmed[count..].trim_space()
		return CodeFence{
			char:     c
			count:    count
			language: lang
		}
	}
	return none
}

// detect_code_block_state scans from start to idx.
pub fn detect_code_block_state(scanner MdScanner, idx int) CodeBlockState {
	mut in_block := false
	mut fence_char := u8(0)
	mut fence_count := 0

	for i := 0; i < idx && i < scanner.len(); i++ {
		if fence := parse_code_fence(scanner.get_line(i)) {
			if !in_block {
				in_block = true
				fence_char = fence.char
				fence_count = fence.count
			} else if fence.char == fence_char && fence.count >= fence_count {
				in_block = false
				fence_char = 0
				fence_count = 0
			}
		}
	}
	return CodeBlockState{
		in_code_block: in_block
		fence_char:    fence_char
		fence_count:   fence_count
	}
}
