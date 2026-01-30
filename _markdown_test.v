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
	// Single newline within paragraph becomes space, not line break
	rt := markdown_to_rich_text('line one\nline two', MarkdownStyle{})
	spaces := rt.runs.filter(it.text == ' ')
	line_breaks := rt.runs.filter(it.text == '\n')
	assert spaces.len >= 1
	assert line_breaks.len == 0
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

fn test_markdown_footnote_defense() {
	rt := markdown_to_rich_text('See note[^1] here', MarkdownStyle{})
	// Should not crash, footnote rendered as literal
	found := rt.runs.any(it.text.contains('[^1]'))
	assert found
}

fn test_markdown_reference_link_defense() {
	rt := markdown_to_rich_text('See [link][ref] here', MarkdownStyle{})
	// Should not crash, rendered as literal
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
