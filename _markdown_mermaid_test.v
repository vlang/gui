module gui

import os
import time

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

fn test_diagram_cache_should_apply_result_guard() {
	mut cache := BoundedDiagramCache{}
	cache.set(42, DiagramCacheEntry{
		state:      .loading
		request_id: 7
	})
	assert diagram_cache_should_apply_result(&cache, 42, 7)
	assert !diagram_cache_should_apply_result(&cache, 42, 8)
	cache.set(42, DiagramCacheEntry{
		state:      .error
		error:      'x'
		request_id: 7
	})
	assert !diagram_cache_should_apply_result(&cache, 42, 7)
}

fn test_diagram_cache_replaces_old_temp_file() {
	path_a := os.join_path(os.temp_dir(), 'gui_mermaid_a_${time.now().unix_micro()}.png')
	path_b := os.join_path(os.temp_dir(), 'gui_mermaid_b_${time.now().unix_micro()}.png')
	os.write_file(path_a, 'a') or { panic(err) }
	os.write_file(path_b, 'b') or { panic(err) }
	defer {
		if os.exists(path_a) {
			os.rm(path_a) or {}
		}
		if os.exists(path_b) {
			os.rm(path_b) or {}
		}
	}

	mut cache := BoundedDiagramCache{}
	cache.set(1, DiagramCacheEntry{
		state:    .ready
		png_path: path_a
	})
	cache.set(1, DiagramCacheEntry{
		state:    .ready
		png_path: path_b
	})
	assert !os.exists(path_a)
	assert os.exists(path_b)
	cache.clear()
	assert !os.exists(path_b)
}

fn test_markdown_external_api_warning_flag_sets_once() {
	mut w := Window{}
	assert !w.view_state.external_api_warning_logged
	markdown_warn_external_api_once(mut w)
	assert w.view_state.external_api_warning_logged
	next := w.view_state.diagram_request_seq
	markdown_warn_external_api_once(mut w)
	assert w.view_state.external_api_warning_logged
	assert w.view_state.diagram_request_seq == next
}
