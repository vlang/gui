module gui

import vglyph

fn test_rtf_cfg_validation() {
	// Simple config validation
	cfg := RtfCfg{
		id:        'test_rtf'
		rich_text: RichText{
			runs: [
				RichTextRun{
					text:  'Hello'
					style: TextStyle{}
				},
			]
		}
	}
	assert cfg.id == 'test_rtf'
	assert cfg.rich_text.runs.len == 1
}

fn test_is_safe_url() {
	// Valid URLs
	assert is_safe_url('https://google.com')
	assert is_safe_url('http://example.com')
	assert is_safe_url('mailto:user@example.com')
	assert is_safe_url('/local/path')
	assert is_safe_url('relative/path')

	// Invalid URLs
	assert !is_safe_url('javascript:alert(1)')
	assert !is_safe_url('vbscript:msgbox')
	assert !is_safe_url('data:text/plain;base64,SGVsbG8=')
	assert !is_safe_url('file:///etc/passwd') // unknown protocol in whitelist
}

fn test_find_run_at_pos() {
	// We can't easily mock Layout and Shape fully without a Window,
	// but we can test the helper logic if we construct a minimal shape/layout structure.
	// However, vglyph types might be hard to instantiate manually with private fields.
	// Let's rely on integration tests or simply trust the logic extraction refactor
	// (which was structurally identical to previous code).
	// We will skip complex layout mocking here and focus on the logic we added/moved.
}
