module gui

// Tests for markdown parser

fn test_markdown_header_h1() {
	t := theme()
	rt := markdown_to_rich_text('# Hello', MarkdownStyle{})
	assert rt.runs.len >= 1
	text_run := rt.runs.filter(it.text == 'Hello')[0] or { panic('no Hello run') }
	assert text_run.style.size == t.b1.size
}

fn test_markdown_header_h2() {
	t := theme()
	rt := markdown_to_rich_text('## World', MarkdownStyle{})
	assert rt.runs.len >= 1
	text_run := rt.runs.filter(it.text == 'World')[0] or { panic('no World run') }
	assert text_run.style.size == t.b2.size
}

fn test_markdown_bold() {
	t := theme()
	rt := markdown_to_rich_text('Hello **bold** world', MarkdownStyle{})
	assert rt.runs.len == 3
	assert rt.runs[0].text == 'Hello '
	assert rt.runs[1].text == 'bold'
	assert rt.runs[1].style.family == t.b3.family
	assert rt.runs[2].text == ' world'
}

fn test_markdown_italic() {
	t := theme()
	rt := markdown_to_rich_text('Hello *italic* world', MarkdownStyle{})
	assert rt.runs.len == 3
	assert rt.runs[0].text == 'Hello '
	assert rt.runs[1].text == 'italic'
	assert rt.runs[1].style.family == t.i3.family
	assert rt.runs[2].text == ' world'
}

fn test_markdown_inline_code() {
	t := theme()
	rt := markdown_to_rich_text('Use `code` here', MarkdownStyle{})
	assert rt.runs.len == 3
	assert rt.runs[0].text == 'Use '
	assert rt.runs[1].text == 'code'
	assert rt.runs[1].style.family == t.m3.family
	assert rt.runs[2].text == ' here'
}

fn test_markdown_link() {
	rt := markdown_to_rich_text('Visit [vlang](https://vlang.io)', MarkdownStyle{})
	assert rt.runs.len == 2
	assert rt.runs[0].text == 'Visit '
	assert rt.runs[1].text == 'vlang'
	assert rt.runs[1].link == 'https://vlang.io'
	assert rt.runs[1].style.underline == true
}

fn test_markdown_unordered_list() {
	blocks := markdown_to_blocks('- item one', MarkdownStyle{})
	assert blocks.len == 1
	assert blocks[0].is_list == true
	assert blocks[0].list_prefix == '• '
	assert blocks[0].list_indent == 0
	assert blocks[0].content.runs[0].text == 'item one'
}

fn test_markdown_ordered_list() {
	blocks := markdown_to_blocks('1. first', MarkdownStyle{})
	assert blocks.len == 1
	assert blocks[0].is_list == true
	assert blocks[0].list_prefix == '1. '
	assert blocks[0].content.runs[0].text == 'first'
}

fn test_markdown_code_block() {
	source := '```
fn main() {}
```'
	rt := markdown_to_rich_text(source, MarkdownStyle{})
	assert rt.runs.len >= 1
	found_code := rt.runs.any(it.text.contains('fn main()'))
	assert found_code
}

fn test_markdown_paragraph_break() {
	rt := markdown_to_rich_text('para1\n\npara2', MarkdownStyle{})
	line_breaks := rt.runs.filter(it.text == '\n')
	assert line_breaks.len >= 1
}

fn test_markdown_paragraph_continuation() {
	// Single newline within paragraph joins lines with space
	rt := markdown_to_rich_text('line one\nline two', MarkdownStyle{})
	line_breaks := rt.runs.filter(it.text == '\n')
	assert rt.runs[0].text.contains(' ')
	assert line_breaks.len == 0
}

fn test_markdown_multiline_link() {
	// Links spanning multiple lines should be parsed correctly
	rt := markdown_to_rich_text('[CommonMark\nSpecification](https://commonmark.org/)',
		MarkdownStyle{})
	links := rt.runs.filter(it.link != '')
	assert links.len == 1
	assert links[0].text == 'CommonMark Specification'
	assert links[0].link == 'https://commonmark.org/'
}

fn test_markdown_link_with_backticks() {
	// Backticks in link text should not confuse bracket matching
	rt := markdown_to_rich_text('[`example`](https://example.com)', MarkdownStyle{})
	links := rt.runs.filter(it.link != '')
	assert links.len == 1
	assert links[0].link == 'https://example.com'
}

fn test_markdown_bold_link_with_backticks() {
	// Bold wrapped link with backticks in text
	rt := markdown_to_rich_text('**[`code`](url)**', MarkdownStyle{})
	links := rt.runs.filter(it.link != '')
	assert links.len == 1
	assert links[0].link == 'url'
}

// New tests for added features

fn test_markdown_strikethrough() {
	rt := markdown_to_rich_text('Hello ~~strike~~ world', MarkdownStyle{})
	assert rt.runs.len == 3
	assert rt.runs[0].text == 'Hello '
	assert rt.runs[1].text == 'strike'
	assert rt.runs[1].style.strikethrough == true
	assert rt.runs[2].text == ' world'
}

fn test_markdown_task_list_unchecked() {
	blocks := markdown_to_blocks('- [ ] todo item', MarkdownStyle{})
	assert blocks.len == 1
	assert blocks[0].is_list == true
	assert blocks[0].list_prefix == '☐ '
	assert blocks[0].content.runs[0].text == 'todo item'
}

fn test_markdown_task_list_checked() {
	blocks := markdown_to_blocks('- [x] done item', MarkdownStyle{})
	assert blocks.len == 1
	assert blocks[0].is_list == true
	assert blocks[0].list_prefix == '☑ '
	assert blocks[0].content.runs[0].text == 'done item'
}

fn test_markdown_nested_list() {
	blocks := markdown_to_blocks('- outer\n  - nested', MarkdownStyle{})
	assert blocks.len == 2
	assert blocks[0].is_list == true
	assert blocks[0].list_prefix == '• '
	assert blocks[0].list_indent == 0
	assert blocks[1].is_list == true
	assert blocks[1].list_prefix == '• '
	assert blocks[1].list_indent == 1
}

fn test_markdown_blockquote() {
	blocks := markdown_to_blocks('> quoted text', MarkdownStyle{})
	assert blocks.len == 1
	assert blocks[0].is_blockquote == true
	assert blocks[0].content.runs[0].text == 'quoted text'
}

fn test_markdown_image() {
	blocks := markdown_to_blocks('![alt text](image.png)', MarkdownStyle{})
	assert blocks.len == 1
	assert blocks[0].is_image == true
	assert blocks[0].image_alt == 'alt text'
	assert blocks[0].image_src == 'image.png'
}

fn test_markdown_horizontal_rule() {
	blocks := markdown_to_blocks('above\n\n---\n\nbelow', MarkdownStyle{})
	hr_blocks := blocks.filter(it.is_hr)
	assert hr_blocks.len == 1
}

fn test_markdown_escape_chars() {
	rt := markdown_to_rich_text(r'\*not italic\*', MarkdownStyle{})
	assert rt.runs.len == 1
	assert rt.runs[0].text == '*not italic*'
}

fn test_markdown_bold_italic() {
	rt := markdown_to_rich_text('Use ***both*** styles', MarkdownStyle{})
	assert rt.runs.len == 3
	assert rt.runs[1].text == 'both'
}

fn test_markdown_underscore_bold() {
	t := theme()
	rt := markdown_to_rich_text('Use __bold__ here', MarkdownStyle{})
	assert rt.runs.len == 3
	assert rt.runs[1].text == 'bold'
	assert rt.runs[1].style.family == t.b3.family
}

fn test_markdown_underscore_italic() {
	t := theme()
	rt := markdown_to_rich_text('Use _italic_ here', MarkdownStyle{})
	assert rt.runs.len == 3
	assert rt.runs[1].text == 'italic'
	assert rt.runs[1].style.family == t.i3.family
}

fn test_markdown_autolink_url() {
	rt := markdown_to_rich_text('Visit <https://example.com> now', MarkdownStyle{})
	assert rt.runs.len == 3
	assert rt.runs[1].text == 'https://example.com'
	assert rt.runs[1].link == 'https://example.com'
}

fn test_markdown_autolink_email() {
	rt := markdown_to_rich_text('Email <test@example.com> please', MarkdownStyle{})
	assert rt.runs.len == 3
	assert rt.runs[1].text == 'test@example.com'
	assert rt.runs[1].link == 'mailto:test@example.com'
}

fn test_markdown_nested_blockquote() {
	blocks := markdown_to_blocks('> > nested quote', MarkdownStyle{})
	assert blocks.len == 1
	assert blocks[0].is_blockquote == true
	assert blocks[0].blockquote_depth == 2
}

fn test_markdown_table() {
	blocks := markdown_to_blocks('| A | B |\n|---|---|\n| 1 | 2 |', MarkdownStyle{})
	assert blocks.len == 1
	assert blocks[0].is_table == true
}

fn test_markdown_table_parsing() {
	parsed := parse_markdown_table('| A | B |\n|---|---|\n| 1 | 2 |') or { panic('parse failed') }
	assert parsed.headers == ['A', 'B']
	assert parsed.rows.len == 1
	assert parsed.rows[0] == ['1', '2']
}

fn test_markdown_table_alignments() {
	parsed := parse_markdown_table('| L | C | R |\n|:---|:---:|---:|\n| a | b | c |') or {
		panic('parse failed')
	}
	assert parsed.alignments.len == 3
	assert parsed.alignments[0] == .start
	assert parsed.alignments[1] == .center
	assert parsed.alignments[2] == .end
}

fn test_markdown_table_no_outer_pipes() {
	parsed := parse_markdown_table('A | B\n---|---\n1 | 2') or { panic('parse failed') }
	assert parsed.headers == ['A', 'B']
	assert parsed.rows.len == 1
	assert parsed.rows[0] == ['1', '2']
}

fn test_markdown_table_empty_cells() {
	parsed := parse_markdown_table('| A | B | C |\n|---|---|---|\n| 1 |  | 3 |') or {
		panic('parse failed')
	}
	assert parsed.rows[0] == ['1', '', '3']
}

fn test_markdown_footnote_basic() {
	source := 'See note[^1] here\n\n[^1]: This is the footnote content.'
	rt := markdown_to_rich_text(source, MarkdownStyle{})
	// Should have footnote marker with tooltip
	fn_runs := rt.runs.filter(it.tooltip != '')
	assert fn_runs.len == 1
	assert fn_runs[0].text == '\u2009[1]' // thin space prefix
	assert fn_runs[0].tooltip == 'This is the footnote content.'
}

fn test_markdown_footnote_named() {
	source := 'See[^note] here\n\n[^note]: Named footnote.'
	rt := markdown_to_rich_text(source, MarkdownStyle{})
	fn_runs := rt.runs.filter(it.tooltip != '')
	assert fn_runs.len == 1
	assert fn_runs[0].text == '\u2009[note]' // thin space prefix
	assert fn_runs[0].tooltip == 'Named footnote.'
}

fn test_markdown_footnote_undefined() {
	rt := markdown_to_rich_text('See note[^1] here', MarkdownStyle{})
	// Undefined footnote rendered as literal
	found := rt.runs.any(it.text.contains('[^1]'))
	assert found
}

fn test_markdown_footnote_multiline() {
	source := 'Text[^1]\n\n[^1]: First line\n    continuation.'
	rt := markdown_to_rich_text(source, MarkdownStyle{})
	fn_runs := rt.runs.filter(it.tooltip != '')
	assert fn_runs.len == 1
	assert fn_runs[0].tooltip == 'First line continuation.'
}

fn test_markdown_footnote_multiline_blank() {
	// Blank line between definition and indented continuation - preserved as paragraph break
	source := 'Text[^1]\n\n[^1]: First paragraph.\n\n    Second paragraph.'
	rt := markdown_to_rich_text(source, MarkdownStyle{})
	fn_runs := rt.runs.filter(it.tooltip != '')
	assert fn_runs.len == 1
	assert fn_runs[0].tooltip == 'First paragraph.\n\nSecond paragraph.'
}

fn test_markdown_reference_link() {
	blocks := markdown_to_blocks('[link][ref]\n\n[ref]: https://example.com', MarkdownStyle{})
	assert blocks.len == 1
	links := blocks[0].content.runs.filter(it.link != '')
	assert links.len == 1
	assert links[0].text == 'link'
	assert links[0].link == 'https://example.com'
}

fn test_markdown_implicit_reference_link() {
	blocks := markdown_to_blocks('[Example][]\n\n[Example]: https://example.com', MarkdownStyle{})
	assert blocks.len == 1
	links := blocks[0].content.runs.filter(it.link != '')
	assert links.len == 1
	assert links[0].text == 'Example'
	assert links[0].link == 'https://example.com'
}

fn test_markdown_shortcut_reference_link() {
	blocks := markdown_to_blocks('[Example]\n\n[Example]: https://example.com', MarkdownStyle{})
	assert blocks.len == 1
	links := blocks[0].content.runs.filter(it.link != '')
	assert links.len == 1
	assert links[0].text == 'Example'
	assert links[0].link == 'https://example.com'
}

fn test_markdown_reference_link_undefined() {
	rt := markdown_to_rich_text('See [link][undefined] here', MarkdownStyle{})
	// No definition, rendered as literal
	found := rt.runs.any(it.text.contains('['))
	assert found
}

fn test_markdown_list_continuation() {
	// List item with continuation line should join with space, not line break
	blocks := markdown_to_blocks('- item one\n  continues', MarkdownStyle{})
	assert blocks.len == 1
	assert blocks[0].is_list == true
	// Content should be joined: "item one continues"
	found := blocks[0].content.runs.any(it.text.contains('item one continues'))
	assert found
}

fn test_markdown_ordered_list_double_digit() {
	blocks := markdown_to_blocks('10. tenth item', MarkdownStyle{})
	assert blocks.len == 1
	assert blocks[0].is_list == true
	assert blocks[0].list_prefix == '10. '
	assert blocks[0].content.runs[0].text == 'tenth item'
}

fn test_markdown_definition_list_simple() {
	blocks := markdown_to_blocks('Term\n: Definition', MarkdownStyle{})
	assert blocks.len == 2
	assert blocks[0].is_def_term == true
	assert blocks[0].content.runs[0].text == 'Term'
	assert blocks[1].is_def_value == true
	assert blocks[1].content.runs[0].text == 'Definition'
}

fn test_markdown_definition_list_multiline() {
	blocks := markdown_to_blocks('Term\n: First line\n  continues here', MarkdownStyle{})
	assert blocks.len == 2
	assert blocks[0].is_def_term == true
	assert blocks[1].is_def_value == true
	found := blocks[1].content.runs.any(it.text.contains('First line continues here'))
	assert found
}

fn test_markdown_definition_list_multiple_defs() {
	blocks := markdown_to_blocks('Term\n: Primary def\n: Alternative def', MarkdownStyle{})
	assert blocks.len == 3
	assert blocks[0].is_def_term == true
	assert blocks[1].is_def_value == true
	assert blocks[1].content.runs[0].text == 'Primary def'
	assert blocks[2].is_def_value == true
	assert blocks[2].content.runs[0].text == 'Alternative def'
}

fn test_markdown_abbreviation_basic() {
	source := '*[HTML]: Hyper Text Markup Language\n\nThe HTML spec.'
	blocks := markdown_to_blocks(source, MarkdownStyle{})
	assert blocks.len == 1
	runs := blocks[0].content.runs
	// Should have: "The " + abbr("HTML") + " spec."
	assert runs.len >= 3
	found_abbr := runs.any(it.tooltip == 'Hyper Text Markup Language' && it.text == 'HTML')
	assert found_abbr
}

fn test_markdown_abbreviation_word_boundary() {
	source := '*[HTML]: Hyper Text Markup Language\n\nHTMLX is not HTML.'
	blocks := markdown_to_blocks(source, MarkdownStyle{})
	runs := blocks[0].content.runs
	// HTML should match, HTMLX should not
	abbr_runs := runs.filter(it.tooltip != '')
	assert abbr_runs.len == 1
	assert abbr_runs[0].text == 'HTML'
}

fn test_markdown_setext_h1() {
	t := theme()
	rt := markdown_to_rich_text('Hello\n=====', MarkdownStyle{})
	text_run := rt.runs.filter(it.text == 'Hello')[0] or { panic('no Hello run') }
	assert text_run.style.size == t.b1.size
}

fn test_markdown_setext_h2() {
	t := theme()
	rt := markdown_to_rich_text('World\n-----', MarkdownStyle{})
	text_run := rt.runs.filter(it.text == 'World')[0] or { panic('no World run') }
	assert text_run.style.size == t.b2.size
}

// Security tests

fn test_markdown_blocks_javascript_url() {
	// javascript: URLs should be rejected - link empty, text unstyled
	rt := markdown_to_rich_text('[click](javascript:alert(1))', MarkdownStyle{})
	links := rt.runs.filter(it.link != '')
	assert links.len == 0
	// Text should still appear
	found := rt.runs.any(it.text == 'click')
	assert found
}

fn test_markdown_blocks_data_url() {
	// data: URLs should be rejected
	rt := markdown_to_rich_text('[click](data:text/html,<script>alert(1)</script>)', MarkdownStyle{})
	links := rt.runs.filter(it.link != '')
	assert links.len == 0
}

fn test_markdown_blocks_vbscript_url() {
	// vbscript: URLs should be rejected
	rt := markdown_to_rich_text('[click](vbscript:msgbox(1))', MarkdownStyle{})
	links := rt.runs.filter(it.link != '')
	assert links.len == 0
}

fn test_markdown_blocks_safe_urls() {
	// http, https, mailto should work
	rt := markdown_to_rich_text('[a](http://x) [b](https://y) [c](mailto:z@z)', MarkdownStyle{})
	links := rt.runs.filter(it.link != '')
	assert links.len == 3
	assert links[0].link == 'http://x'
	assert links[1].link == 'https://y'
	assert links[2].link == 'mailto:z@z'
}

fn test_markdown_blocks_relative_url() {
	// Relative URLs (no protocol) should work
	rt := markdown_to_rich_text('[page](./other.html)', MarkdownStyle{})
	links := rt.runs.filter(it.link != '')
	assert links.len == 1
	assert links[0].link == './other.html'
}

fn test_markdown_image_path_traversal() {
	// Path traversal should be blocked
	blocks := markdown_to_blocks('![alt](../../../etc/passwd)', MarkdownStyle{})
	assert blocks.len == 1
	assert blocks[0].is_image == true
	assert blocks[0].image_src == '' // blocked
}

fn test_markdown_image_absolute_path() {
	// Absolute paths should be blocked
	blocks := markdown_to_blocks('![alt](/etc/passwd)', MarkdownStyle{})
	assert blocks.len == 1
	assert blocks[0].image_src == ''
}

fn test_markdown_image_safe_path() {
	// Relative paths without traversal should work
	blocks := markdown_to_blocks('![alt](images/photo.png)', MarkdownStyle{})
	assert blocks.len == 1
	assert blocks[0].image_src == 'images/photo.png'
}

fn test_markdown_autolink_javascript() {
	// javascript: in autolink should be rejected
	rt := markdown_to_rich_text('<javascript:alert(1)>', MarkdownStyle{})
	links := rt.runs.filter(it.link != '')
	assert links.len == 0
}

fn test_markdown_reference_link_javascript() {
	// javascript: URLs in reference links should be rejected
	blocks := markdown_to_blocks('[click][x]\n\n[x]: javascript:alert(1)', MarkdownStyle{})
	links := blocks[0].content.runs.filter(it.link != '')
	assert links.len == 0
}

// Self-synchronizing parser tests

fn test_markdown_tilde_fence() {
	source := '~~~
fn main() {}
~~~'
	rt := markdown_to_rich_text(source, MarkdownStyle{})
	assert rt.runs.len >= 1
	found_code := rt.runs.any(it.text.contains('fn main()'))
	assert found_code
}

fn test_markdown_tilde_fence_with_lang() {
	source := '~~~v
let x = 1
~~~'
	blocks := markdown_to_blocks(source, MarkdownStyle{})
	assert blocks.len >= 1
	assert blocks.any(it.is_code)
}

fn test_markdown_mismatched_fence_ignored() {
	// Opening ``` should not be closed by ~~~
	source := '```
code here
~~~
still code
```'
	blocks := markdown_to_blocks(source, MarkdownStyle{})
	code_blocks := blocks.filter(it.is_code)
	assert code_blocks.len == 1
	// Content should include the ~~~ line since it doesn't close backtick fence
	content := code_blocks[0].content.runs[0].text
	assert content.contains('code here')
	assert content.contains('still code')
}

fn test_code_block_state_detection() {
	lines := [
		'text',
		'```',
		'code',
		'```',
		'more text',
	]
	// At index 0: not in code block
	state0 := detect_code_block_state(lines, 0)
	assert state0.in_code_block == false

	// At index 2 (inside code block)
	state2 := detect_code_block_state(lines, 2)
	assert state2.in_code_block == true
	assert state2.fence_char == `\``

	// At index 4 (after code block closed)
	state4 := detect_code_block_state(lines, 4)
	assert state4.in_code_block == false
}

fn test_code_block_state_tilde() {
	lines := [
		'~~~',
		'code',
	]
	state := detect_code_block_state(lines, 2)
	assert state.in_code_block == true
	assert state.fence_char == `~`
}

fn test_parse_code_fence() {
	// Backtick fence
	if fence := parse_code_fence('```') {
		assert fence.char == `\``
		assert fence.count == 3
	} else {
		assert false
	}

	// Tilde fence
	if fence := parse_code_fence('~~~python') {
		assert fence.char == `~`
		assert fence.count == 3
	} else {
		assert false
	}

	// Longer fence
	if fence := parse_code_fence('`````') {
		assert fence.char == `\``
		assert fence.count == 5
	} else {
		assert false
	}

	// Not a fence
	assert parse_code_fence('hello') == none
	assert parse_code_fence('``') == none
}

fn test_bounded_blockquote() {
	// Blockquote should be bounded (verify no infinite loop)
	mut lines := []string{cap: 150}
	for _ in 0 .. 150 {
		lines << '> line'
	}
	source := lines.join('\n')
	blocks := markdown_to_blocks(source, MarkdownStyle{})
	// Should have at least one blockquote block, bounded at 100 lines
	assert blocks.len >= 1
	assert blocks[0].is_blockquote == true
}

fn test_bounded_table() {
	// Table should be bounded
	mut lines := []string{cap: 10}
	lines << '| A | B |'
	lines << '|---|---|'
	for _ in 0 .. 5 {
		lines << '| 1 | 2 |'
	}
	source := lines.join('\n')
	blocks := markdown_to_blocks(source, MarkdownStyle{})
	assert blocks.len == 1
	assert blocks[0].is_table == true
}

fn test_unclosed_code_block() {
	// Unclosed code block should still be rendered
	source := '```
code without closing'
	blocks := markdown_to_blocks(source, MarkdownStyle{})
	code_blocks := blocks.filter(it.is_code)
	assert code_blocks.len == 1
	assert code_blocks[0].content.runs[0].text == 'code without closing'
}
