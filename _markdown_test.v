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

fn test_markdown_footnote_basic() {
	source := 'See note[^1] here\n\n[^1]: This is the footnote content.'
	rt := markdown_to_rich_text(source, MarkdownStyle{})
	// Should have footnote marker with tooltip
	fn_runs := rt.runs.filter(it.tooltip != '')
	assert fn_runs.len == 1
	assert fn_runs[0].text == '[1]'
	assert fn_runs[0].tooltip == 'This is the footnote content.'
}

fn test_markdown_footnote_named() {
	source := 'See[^note] here\n\n[^note]: Named footnote.'
	rt := markdown_to_rich_text(source, MarkdownStyle{})
	fn_runs := rt.runs.filter(it.tooltip != '')
	assert fn_runs.len == 1
	assert fn_runs[0].text == '[note]'
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
