module gui

// test_markdown_mermaid checks if mermaid blocks are correctly identified.
fn test_markdown_mermaid() {
	source := '```mermaid
graph TD
    A --> B
```'
	blocks := markdown_to_blocks(source, MarkdownStyle{})
	mermaid_blocks := blocks.filter(it.is_code && it.code_language == 'mermaid')
	assert mermaid_blocks.len == 1

	// Extraction check: should contain the graph source
	content := rich_text_plain(mermaid_blocks[0].content)
	assert content.contains('graph TD')
	assert content.contains('A --> B')
}

// test_markdown_mermaid_alt_fence checks tilde fences for mermaid.
fn test_markdown_mermaid_alt_fence() {
	source := '~~~mermaid
sequenceDiagram
    Alice->>Bob: Hello
~~~'
	blocks := markdown_to_blocks(source, MarkdownStyle{})
	mermaid_blocks := blocks.filter(it.is_code && it.code_language == 'mermaid')
	assert mermaid_blocks.len == 1

	content := rich_text_plain(mermaid_blocks[0].content)
	assert content.contains('sequenceDiagram')
	assert content.contains('Alice->>Bob')
}
