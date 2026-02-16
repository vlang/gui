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

fn test_markdown_inline_code_highlight_tokens() {
	style := MarkdownStyle{}
	rt := markdown_to_rich_text('Use `x == 10` here', style)
	op_run := rt.runs.filter(it.text == '==')[0] or { panic('no operator run') }
	num_run := rt.runs.filter(it.text == '10')[0] or { panic('no number run') }
	assert op_run.style.color == style.code_operator_color
	assert num_run.style.color == style.code_number_color
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

	// Support ')' delimiter
	blocks2 := markdown_to_blocks('1) second', MarkdownStyle{})
	assert blocks2.len == 1
	assert blocks2[0].is_list == true
	assert blocks2[0].list_prefix == '1) '
	assert blocks2[0].content.runs[0].text == 'second'
}

fn test_markdown_code_block() {
	source := '```
fn main() {}
```'
	rt := markdown_to_rich_text(source, MarkdownStyle{})
	assert rt.runs.len >= 1
	found_code := rich_text_to_string(rt).contains('fn main()')
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

// Helper to extract text from RichText for test comparison
fn rich_text_to_string(rt RichText) string {
	mut s := ''
	for run in rt.runs {
		s += run.text
	}
	return s
}

fn test_markdown_table_parsing() {
	style := MarkdownStyle{}
	parsed := parse_markdown_table('| A | B |\n|---|---|\n| 1 | 2 |'.split('\n'), style,
		map[string]string{}, map[string]string{}) or { panic('parse failed') }
	assert rich_text_to_string(parsed.headers[0]) == 'A'
	assert rich_text_to_string(parsed.headers[1]) == 'B'
	assert parsed.rows.len == 1
	assert rich_text_to_string(parsed.rows[0][0]) == '1'
	assert rich_text_to_string(parsed.rows[0][1]) == '2'
}

fn test_markdown_table_alignments() {
	style := MarkdownStyle{}
	parsed := parse_markdown_table('| L | C | R |\n|:---|:---:|---:|\n| a | b | c |'.split('\n'),
		style, map[string]string{}, map[string]string{}) or { panic('parse failed') }
	assert parsed.alignments.len == 3
	assert parsed.alignments[0] == .start
	assert parsed.alignments[1] == .center
	assert parsed.alignments[2] == .end
}

fn test_markdown_table_no_outer_pipes() {
	style := MarkdownStyle{}
	parsed := parse_markdown_table('A | B\n---|---\n1 | 2'.split('\n'), style, map[string]string{},
		map[string]string{}) or { panic('parse failed') }
	assert rich_text_to_string(parsed.headers[0]) == 'A'
	assert rich_text_to_string(parsed.headers[1]) == 'B'
	assert parsed.rows.len == 1
	assert rich_text_to_string(parsed.rows[0][0]) == '1'
	assert rich_text_to_string(parsed.rows[0][1]) == '2'
}

fn test_markdown_table_empty_cells() {
	style := MarkdownStyle{}
	parsed := parse_markdown_table('| A | B | C |\n|---|---|---|\n| 1 |  | 3 |'.split('\n'),
		style, map[string]string{}, map[string]string{}) or { panic('parse failed') }
	assert rich_text_to_string(parsed.rows[0][0]) == '1'
	assert rich_text_to_string(parsed.rows[0][1]) == ''
	assert rich_text_to_string(parsed.rows[0][2]) == '3'
}

fn test_markdown_table_inline_formatting() {
	style := MarkdownStyle{}
	parsed := parse_markdown_table('| **bold** | _italic_ | `code` |\n|---|---|---|\n| [link](url) | a | b |'.split('\n'),
		style, map[string]string{}, map[string]string{}) or { panic('parse failed') }
	// Headers should have inline formatting parsed
	assert rich_text_to_string(parsed.headers[0]) == 'bold'
	assert rich_text_to_string(parsed.headers[1]) == 'italic'
	assert rich_text_to_string(parsed.headers[2]) == 'code'
	// Check that bold header has multiple runs (text styling applied)
	assert parsed.headers[0].runs.len >= 1
	// Cell with link
	assert rich_text_to_string(parsed.rows[0][0]) == 'link'
	assert parsed.rows[0][0].runs[0].link == 'url'
}

fn test_markdown_table_invalid_separator() {
	style := MarkdownStyle{}
	// Separator without dashes should fail
	result := parse_markdown_table('| A | B |\n|:::|:::|\n| 1 | 2 |'.split('\n'), style,
		map[string]string{}, map[string]string{})
	assert result == none
}

fn test_markdown_table_no_separator() {
	style := MarkdownStyle{}
	// No separator row should fail
	result := parse_markdown_table('| A | B |\n| 1 | 2 |'.split('\n'), style, map[string]string{},
		map[string]string{})
	assert result == none
}

fn test_markdown_table_without_leading_pipes() {
	// Tables without leading pipes should still be recognized
	source := 'Header A | Header B\n---------|----------\nCell 1 | Cell 2'
	blocks := markdown_to_blocks(source, MarkdownStyle{})
	assert blocks.len == 1
	assert blocks[0].is_table == true
	if tbl := blocks[0].table_data {
		assert tbl.headers.len == 2
		assert rich_text_to_string(tbl.headers[0]) == 'Header A'
		assert rich_text_to_string(tbl.rows[0][1]) == 'Cell 2'
	} else {
		assert false // table_data should exist
	}
}

fn test_markdown_prose_with_pipe_not_table() {
	// Prose containing | should NOT be captured as table
	source := 'Use a|b syntax for alternatives.'
	blocks := markdown_to_blocks(source, MarkdownStyle{})
	assert blocks.len == 1
	assert blocks[0].is_table == false
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
	found_code := rich_text_to_string(rt).contains('fn main()')
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
	content := rich_text_to_string(code_blocks[0].content)
	assert content.contains('code here')
	assert content.contains('still code')
}

fn test_markdown_fenced_v_highlight() {
	style := MarkdownStyle{}
	source := '```v
fn main() {
	return 1
}
```'
	blocks := markdown_to_blocks(source, style)
	code := blocks.filter(it.is_code)[0] or { panic('no code block') }
	assert code.code_language == 'v'
	fn_run := code.content.runs.filter(it.text == 'fn')[0] or { panic('no fn run') }
	num_run := code.content.runs.filter(it.text == '1')[0] or { panic('no number run') }
	assert fn_run.style.color == style.code_keyword_color
	assert num_run.style.color == style.code_number_color
}

fn test_markdown_fenced_python_highlight() {
	style := MarkdownStyle{}
	source := '```python
# note
if x:
    pass
```'
	blocks := markdown_to_blocks(source, style)
	code := blocks.filter(it.is_code)[0] or { panic('no code block') }
	comment_run := code.content.runs.filter(it.text == '# note')[0] or { panic('no comment run') }
	kw_run := code.content.runs.filter(it.text == 'if')[0] or { panic('no keyword run') }
	assert comment_run.style.color == style.code_comment_color
	assert kw_run.style.color == style.code_keyword_color
}

fn test_markdown_fenced_unknown_language_generic_highlight() {
	style := MarkdownStyle{}
	source := '```foo
x == 42
```'
	blocks := markdown_to_blocks(source, style)
	code := blocks.filter(it.is_code)[0] or { panic('no code block') }
	assert code.code_language == 'foo'
	op_run := code.content.runs.filter(it.text == '==')[0] or { panic('no operator run') }
	num_run := code.content.runs.filter(it.text == '42')[0] or { panic('no number run') }
	assert op_run.style.color == style.code_operator_color
	assert num_run.style.color == style.code_number_color
}

fn test_code_block_state_detection() {
	source := 'text
```
code
```
more text'
	scanner := new_markdown_scanner(source)
	// At index 0: not in code block
	state0 := detect_code_block_state(scanner, 0)
	assert state0.in_code_block == false

	// At index 2 (inside code block)
	state2 := detect_code_block_state(scanner, 2)
	assert state2.in_code_block == true
	assert state2.fence_char == `\``

	// At index 4 (after code block closed)
	state4 := detect_code_block_state(scanner, 4)
	assert state4.in_code_block == false
}

fn test_code_block_state_tilde() {
	source := '~~~
code'
	scanner := new_markdown_scanner(source)
	state := detect_code_block_state(scanner, 2)
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
	assert rich_text_to_string(code_blocks[0].content) == 'code without closing'
}

fn test_markdown_highlight_inline_limit_fallback() {
	style := MarkdownStyle{}
	code := 'x'.repeat(max_inline_code_highlight_bytes + 10)
	runs := highlight_inline_code(code, style)
	assert runs.len == 1
	assert runs[0].text == code
	assert runs[0].style.color == style.code.color
}

fn test_markdown_highlight_block_depth_limit_no_hang() {
	style := MarkdownStyle{}
	openers := '/*'.repeat(max_highlight_comment_depth + 1)
	closers := '*/'.repeat(max_highlight_comment_depth + 1)
	code := '${openers}x${closers}'
	runs := highlight_fenced_code(code, 'v', style)
	assert rich_text_to_string(RichText{
		runs: runs
	}) == code
}

fn test_markdown_highlight_string_scan_limit_no_hang() {
	style := MarkdownStyle{}
	code := '"' + 'a'.repeat(max_highlight_string_scan_bytes + 20)
	runs := highlight_fenced_code(code, 'js', style)
	assert rich_text_to_string(RichText{
		runs: runs
	}) == code
}

// Math tests

fn test_markdown_display_math_single_line() {
	blocks := markdown_to_blocks(r'$$ E=mc^2 $$', MarkdownStyle{})
	assert blocks.len == 1
	assert blocks[0].is_math == true
	assert blocks[0].math_latex == 'E=mc^2'
}

fn test_markdown_display_math_multi_line() {
	source := '\$\$
\\int_0^1 x^2 dx
\$\$'
	blocks := markdown_to_blocks(source, MarkdownStyle{})
	math_blocks := blocks.filter(it.is_math)
	assert math_blocks.len == 1
	assert math_blocks[0].math_latex.contains('\\int_0^1')
}

fn test_markdown_math_code_fence() {
	source := '```math
\\sum_{n=1}^{\\infty} \\frac{1}{n^2}
```'
	blocks := markdown_to_blocks(source, MarkdownStyle{})
	math_blocks := blocks.filter(it.is_math)
	assert math_blocks.len == 1
	assert math_blocks[0].math_latex.contains('\\sum')
	// Should NOT be a code block
	code_blocks := blocks.filter(it.is_code)
	assert code_blocks.len == 0
}

fn test_markdown_inline_math() {
	rt := markdown_to_rich_text(r'The equation $E=mc^2$ is famous.', MarkdownStyle{})
	math_runs := rt.runs.filter(it.math_id != '')
	assert math_runs.len == 1
	assert math_runs[0].math_latex == 'E=mc^2'
	assert math_runs[0].text == '\uFFFC'
}

fn test_markdown_inline_math_dollar_price() {
	// $10 should NOT be treated as math (digit after $)
	rt := markdown_to_rich_text(r'The price is $10 today.', MarkdownStyle{})
	math_runs := rt.runs.filter(it.math_id != '')
	assert math_runs.len == 0
}

fn test_markdown_inline_math_dollar_space() {
	// $ x$ should NOT be math (space after opening $)
	rt := markdown_to_rich_text(r'Value $ x$ here.', MarkdownStyle{})
	math_runs := rt.runs.filter(it.math_id != '')
	assert math_runs.len == 0
}

fn test_markdown_escaped_dollar() {
	// Escaped \$ should be literal
	rt := markdown_to_rich_text(r'Cost is \$5.', MarkdownStyle{})
	math_runs := rt.runs.filter(it.math_id != '')
	assert math_runs.len == 0
	found := rt.runs.any(it.text.contains('$'))
	assert found
}

fn test_markdown_inline_math_not_preceded_by_digit() {
	// Digit before $ should prevent math
	rt := markdown_to_rich_text(r'Get 5$x$ here.', MarkdownStyle{})
	math_runs := rt.runs.filter(it.math_id != '')
	assert math_runs.len == 0
}

// Edge case tests for parser fixes

fn test_markdown_escaped_closing_delimiter() {
	t := theme()
	// Escaped \* prevents ** from closing bold
	rt := markdown_to_rich_text(r'**text\**', MarkdownStyle{})
	// Bold requires matching **, but \* escapes one star.
	// Verify no run has bold family (bold not matched).
	for run in rt.runs {
		assert run.style.family != t.b3.family
	}
}

fn test_markdown_table_escaped_pipe() {
	style := MarkdownStyle{}
	parsed := parse_markdown_table(r'| a \| b | c |
|---|---|
| d \| e | f |'.split('\n'),
		style, map[string]string{}, map[string]string{}) or { panic('parse failed') }
	// Should have 2 columns, not 3
	assert parsed.headers.len == 2
	assert rich_text_to_string(parsed.headers[0]) == 'a | b'
	assert rich_text_to_string(parsed.headers[1]) == 'c'
	assert rich_text_to_string(parsed.rows[0][0]) == 'd | e'
	assert rich_text_to_string(parsed.rows[0][1]) == 'f'
}

fn test_markdown_blockquote_depth_first_line() {
	// Depth should reflect first line, not max across all lines
	blocks := markdown_to_blocks('> a\n>> b\n> c', MarkdownStyle{})
	assert blocks.len == 1
	assert blocks[0].is_blockquote == true
	assert blocks[0].blockquote_depth == 1
}

fn test_markdown_math_block_many_lines() {
	// Math block with >20 lines (cap consistency)
	mut lines := []string{cap: 30}
	lines << '$$'
	for i in 0 .. 25 {
		lines << 'x_{${i}} + y_{${i}}'
	}
	lines << '$$'
	blocks := markdown_to_blocks(lines.join('\n'), MarkdownStyle{})
	math_blocks := blocks.filter(it.is_math)
	assert math_blocks.len == 1
	assert math_blocks[0].math_latex.contains('x_{24}')
}

fn test_markdown_ordered_list_paren() {
	// Ordered list with ) separator
	blocks := markdown_to_blocks('1) item', MarkdownStyle{})
	assert blocks.len == 1
	assert blocks[0].is_list == true
	assert blocks[0].list_prefix == '1) '
	assert blocks[0].content.runs[0].text == 'item'
}

fn test_markdown_find_closing_trailing_backslash() {
	// Backslash as last char should not cause out-of-bounds
	pos := find_closing(r'abc\', 0, `x`)
	assert pos == -1
}

fn test_markdown_find_double_closing_trailing_backslash() {
	pos := find_double_closing(r'abc\', 0, `*`)
	assert pos == -1
}

fn test_markdown_find_triple_closing_trailing_backslash() {
	pos := find_triple_closing(r'abc\', 0, `*`)
	assert pos == -1
}

// S1: sanitize_latex nested payload bypass
fn test_sanitize_latex_nested_bypass() {
	// \inp + \input + ut → after one pass: \input
	assert sanitize_latex(r'\inp\inputut') == ''
	// Nested \include: \inc + \include + lude → \include
	assert sanitize_latex(r'\inc\includelude') == ''
	// Already-blocked single command
	assert sanitize_latex(r'\write18') == ''
	// Clean input unchanged
	assert sanitize_latex(r'\frac{1}{2}') == r'\frac{1}{2}'
}

// S2: is_safe_url percent-encoded protocol bypass
fn test_is_safe_url_percent_encoded_javascript() {
	// %6A = 'j' → javascript:
	assert is_safe_url('%6Aavascript:alert(1)') == false
	// Mixed case + percent encoding
	assert is_safe_url('%6a%61vascript:alert(1)') == false
	// Percent-encoded data:
	assert is_safe_url('%64ata:text/html,<script>') == false
	// Normal safe URLs still work
	assert is_safe_url('https://example.com') == true
	assert is_safe_url('mailto:a@b.com') == true
	assert is_safe_url('./relative') == true
}

// S3: empty link definition key
fn test_empty_link_definition_rejected() {
	// "[]: url" should not register as link def
	scanner := new_markdown_scanner('[]: http://evil.com')
	link_defs, _, _ := collect_metadata(scanner)
	assert link_defs.len == 0
}

fn test_is_link_definition_empty_key() {
	assert is_link_definition('[]: http://example.com') == false
	assert is_link_definition('[a]: http://example.com') == true
}

// Table column limit
fn test_table_column_limit() {
	// Build table with 150 columns (exceeds max_table_columns=100)
	mut hdr := []string{cap: 150}
	mut sep := []string{cap: 150}
	mut row := []string{cap: 150}
	for i in 0 .. 150 {
		hdr << 'H${i}'
		sep << '---'
		row << '${i}'
	}
	lines := [hdr.join('|'), sep.join('|'), row.join('|')]
	style := MarkdownStyle{}
	parsed := parse_markdown_table(lines, style, map[string]string{}, map[string]string{}) or {
		// Rejected due to column limit — acceptable
		return
	}
	// If parsed, headers must be capped
	assert parsed.headers.len <= max_table_columns
}

// Highlight tests

fn test_markdown_highlight() {
	rt := markdown_to_rich_text('Hello ==marked== world', MarkdownStyle{})
	assert rt.runs.len == 3
	assert rt.runs[0].text == 'Hello '
	assert rt.runs[1].text == 'marked'
	assert rt.runs[1].style.bg_color.a > 0 // has highlight bg
	assert rt.runs[2].text == ' world'
}

fn test_markdown_highlight_nested_bold() {
	rt := markdown_to_rich_text('==**bold highlight**==', MarkdownStyle{})
	assert rt.runs.len >= 1
	bold_runs := rt.runs.filter(it.text == 'bold highlight')
	assert bold_runs.len == 1
	assert bold_runs[0].style.bg_color.a > 0
}

// Emoji tests

fn test_markdown_emoji_basic() {
	rt := markdown_to_rich_text('Hello :smile: world', MarkdownStyle{})
	found := rt.runs.any(it.text == '😄')
	assert found
}

fn test_markdown_emoji_unknown() {
	// Unknown emoji should stay as literal
	rt := markdown_to_rich_text(':notanemoji:', MarkdownStyle{})
	found := rt.runs.any(it.text.contains(':notanemoji:'))
	assert found
}

fn test_markdown_emoji_plus_one() {
	rt := markdown_to_rich_text(':+1:', MarkdownStyle{})
	found := rt.runs.any(it.text == '👍')
	assert found
}

fn test_markdown_emoji_minus_one() {
	rt := markdown_to_rich_text(':-1:', MarkdownStyle{})
	found := rt.runs.any(it.text == '👎')
	assert found
}

fn test_markdown_emoji_bare_colon() {
	// Bare colons should not crash or consume text
	rt := markdown_to_rich_text('time: 10:30', MarkdownStyle{})
	text := rich_text_to_string(rt)
	assert text.contains('time: 10:30')
}

// Indented code block tests

fn test_markdown_indented_code_block() {
	source := '    fn main() {\n    }'
	blocks := markdown_to_blocks(source, MarkdownStyle{})
	assert blocks.len >= 1
	assert blocks[0].is_code == true
	content := rich_text_to_string(blocks[0].content)
	assert content.contains('fn main()')
}

fn test_markdown_indented_code_tab() {
	source := '\tfn main() {}'
	blocks := markdown_to_blocks(source, MarkdownStyle{})
	assert blocks.len >= 1
	assert blocks[0].is_code == true
}

fn test_markdown_indented_code_after_list() {
	// List item takes priority over indented code
	source := '- list item\n    code line'
	blocks := markdown_to_blocks(source, MarkdownStyle{})
	assert blocks[0].is_list == true
}

// Heading anchor tests

fn test_markdown_heading_slug() {
	assert heading_slug('Hello World') == 'hello-world'
	assert heading_slug('API Reference') == 'api-reference'
	assert heading_slug('C++ & Rust!') == 'c-rust'
	assert heading_slug('  spaces  ') == 'spaces'
}

fn test_markdown_heading_anchor_set() {
	blocks := markdown_to_blocks('## Hello World', MarkdownStyle{})
	assert blocks.len == 1
	assert blocks[0].header_level == 2
	assert blocks[0].anchor_slug == 'hello-world'
}

// Superscript/subscript tests

fn test_markdown_superscript() {
	rt := markdown_to_rich_text('E=mc^2^', MarkdownStyle{})
	sup_runs := rt.runs.filter(it.text == '2')
	assert sup_runs.len >= 1
	// OpenType 'sups' feature handles sizing
	assert sup_runs[0].style.features != unsafe { nil }
}

fn test_markdown_subscript() {
	rt := markdown_to_rich_text('H~2~O', MarkdownStyle{})
	sub_runs := rt.runs.filter(it.text == '2')
	assert sub_runs.len >= 1
	// OpenType 'subs' feature handles sizing
	assert sub_runs[0].style.features != unsafe { nil }
}

fn test_markdown_subscript_vs_strikethrough() {
	// ~~text~~ is strikethrough, not subscript
	rt := markdown_to_rich_text('~~strike~~', MarkdownStyle{})
	assert rt.runs.len >= 1
	assert rt.runs[0].style.strikethrough == true
}

fn test_markdown_tilde_disambiguation() {
	// ~x~~y~~ : ~x~ = subscript, ~~y~~ = strikethrough
	rt := markdown_to_rich_text('~x~ and ~~y~~', MarkdownStyle{})
	sub_runs := rt.runs.filter(it.text == 'x')
	strike_runs := rt.runs.filter(it.text == 'y')
	assert sub_runs.len >= 1
	assert strike_runs.len >= 1
	assert strike_runs[0].style.strikethrough == true
}

// Syntax highlighting language tests

fn test_markdown_fenced_go_highlight() {
	style := MarkdownStyle{}
	source := '```go\nfunc main() {\n\treturn\n}\n```'
	blocks := markdown_to_blocks(source, style)
	code := blocks.filter(it.is_code)[0] or { panic('no code block') }
	assert code.code_language == 'go'
	kw_run := code.content.runs.filter(it.text == 'func')[0] or { panic('no func keyword') }
	assert kw_run.style.color == style.code_keyword_color
}

fn test_markdown_fenced_rust_highlight() {
	style := MarkdownStyle{}
	source := '```rust\nfn main() {\n\tlet x = 1;\n}\n```'
	blocks := markdown_to_blocks(source, style)
	code := blocks.filter(it.is_code)[0] or { panic('no code block') }
	assert code.code_language == 'rust'
	kw_run := code.content.runs.filter(it.text == 'fn')[0] or { panic('no fn keyword') }
	assert kw_run.style.color == style.code_keyword_color
}

fn test_markdown_fenced_shell_highlight() {
	style := MarkdownStyle{}
	source := '```bash\n# comment\necho hello\n```'
	blocks := markdown_to_blocks(source, style)
	code := blocks.filter(it.is_code)[0] or { panic('no code block') }
	assert code.code_language == 'shell'
	comment_run := code.content.runs.filter(it.text == '# comment')[0] or {
		panic('no comment run')
	}
	assert comment_run.style.color == style.code_comment_color
}

// Hard line break tests

fn test_markdown_hard_break_backslash() {
	style := MarkdownStyle{
		hard_line_breaks: true
	}
	rt := markdown_to_rich_text('line one\\\nline two', style)
	text := rich_text_to_string(rt)
	assert text.contains('line one')
	assert text.contains('\n')
	assert text.contains('line two')
}

fn test_markdown_hard_break_trailing_spaces() {
	style := MarkdownStyle{
		hard_line_breaks: true
	}
	rt := markdown_to_rich_text('line one  \nline two', style)
	text := rich_text_to_string(rt)
	assert text.contains('\n')
}

fn test_markdown_no_hard_break_default() {
	// Without flag, lines join with space
	style := MarkdownStyle{}
	rt := markdown_to_rich_text('line one\\\nline two', style)
	text := rich_text_to_string(rt)
	// Should join with space, no newline
	assert text.contains('line one')
}
