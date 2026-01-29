module gui

// Tests for markdown parser

fn test_markdown_header_h1() {
	t := theme()
	rt := markdown_to_rich_text('# Hello')
	assert rt.runs.len >= 1
	// Find the text run (skip line breaks)
	text_run := rt.runs.filter(it.text == 'Hello')[0] or { panic('no Hello run') }
	assert text_run.style.size == t.b1.size
}

fn test_markdown_header_h2() {
	t := theme()
	rt := markdown_to_rich_text('## World')
	assert rt.runs.len >= 1
	// Find the text run (skip line breaks)
	text_run := rt.runs.filter(it.text == 'World')[0] or { panic('no World run') }
	assert text_run.style.size == t.b2.size
}

fn test_markdown_bold() {
	t := theme()
	rt := markdown_to_rich_text('Hello **bold** world')
	assert rt.runs.len == 3
	assert rt.runs[0].text == 'Hello '
	assert rt.runs[1].text == 'bold'
	assert rt.runs[1].style.family == t.b3.family
	assert rt.runs[2].text == ' world'
}

fn test_markdown_italic() {
	t := theme()
	rt := markdown_to_rich_text('Hello *italic* world')
	assert rt.runs.len == 3
	assert rt.runs[0].text == 'Hello '
	assert rt.runs[1].text == 'italic'
	assert rt.runs[1].style.family == t.i3.family
	assert rt.runs[2].text == ' world'
}

fn test_markdown_inline_code() {
	t := theme()
	rt := markdown_to_rich_text('Use `code` here')
	assert rt.runs.len == 3
	assert rt.runs[0].text == 'Use '
	assert rt.runs[1].text == 'code'
	assert rt.runs[1].style.family == t.m3.family
	assert rt.runs[2].text == ' here'
}

fn test_markdown_link() {
	rt := markdown_to_rich_text('Visit [vlang](https://vlang.io)')
	assert rt.runs.len == 2
	assert rt.runs[0].text == 'Visit '
	assert rt.runs[1].text == 'vlang'
	assert rt.runs[1].link == 'https://vlang.io'
	assert rt.runs[1].style.underline == true
}

fn test_markdown_unordered_list() {
	rt := markdown_to_rich_text('- item one')
	assert rt.runs.len >= 2
	assert rt.runs[0].text == '  • '
	assert rt.runs[1].text == 'item one'
}

fn test_markdown_ordered_list() {
	rt := markdown_to_rich_text('1. first')
	assert rt.runs.len >= 2
	assert rt.runs[0].text == '  1. '
	assert rt.runs[1].text == 'first'
}

fn test_markdown_code_block() {
	source := '```
fn main() {}
```'
	rt := markdown_to_rich_text(source)
	assert rt.runs.len >= 1
	found_code := rt.runs.any(it.text.contains('fn main()'))
	assert found_code
}

fn test_markdown_horizontal_rule() {
	rt := markdown_to_rich_text('above\n\n---\n\nbelow')
	// Should contain horizontal line character
	found_rule := rt.runs.any(it.text.contains('────'))
	assert found_rule
}

fn test_markdown_paragraph_break() {
	rt := markdown_to_rich_text('para1\n\npara2')
	// Should have line breaks between paragraphs
	line_breaks := rt.runs.filter(it.text == '\n')
	assert line_breaks.len >= 2
}
