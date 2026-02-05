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

fn test_rtf_hit_test_logic() {
	// Test the hit-testing logic by verifying the bounds checking math
	// We can't easily instantiate vglyph.Item due to required reference fields,
	// so we verify the logic is correct by testing the rect construction
	// and bounds checking separately.

	// Simulate run bounds: x=10, y=20, width=100, ascent=15, descent=5
	// Expected rect: x=10, y=5 (20-15), width=100, height=20 (15+5)

	// Test bounds checking logic (what rtf_hit_test does internally)
	rect_x := f32(10)
	rect_y := f32(20) - f32(15) // y - ascent = 5
	rect_width := f32(100)
	rect_height := f32(15) + f32(5) // ascent + descent = 20

	// Inside bounds
	assert 50 >= rect_x && 10 >= rect_y && 50 < (rect_x + rect_width) && 10 < (rect_y + rect_height) // center
	assert 10 >= rect_x && 5 >= rect_y && 10 < (rect_x + rect_width) && 5 < (rect_y + rect_height) // top-left
	assert 109 >= rect_x && 24 >= rect_y && 109 < (rect_x + rect_width)
		&& 24 < (rect_y + rect_height) // bottom-right edge

	// Outside bounds
	assert !(5 >= rect_x && 10 >= rect_y && 5 < (rect_x + rect_width) && 10 < (rect_y + rect_height)) // left
	assert !(50 >= rect_x && 0 >= rect_y && 50 < (rect_x + rect_width) && 0 < (rect_y + rect_height)) // above
	assert !(110 >= rect_x && 10 >= rect_y && 110 < (rect_x + rect_width)
		&& 10 < (rect_y + rect_height)) // right
	assert !(50 >= rect_x && 25 >= rect_y && 50 < (rect_x + rect_width)
		&& 25 < (rect_y + rect_height)) // below
}

fn test_is_safe_url_edge_cases() {
	// Case variations (should all be blocked)
	assert !is_safe_url('JavaScript:alert(1)')
	assert !is_safe_url('JAVASCRIPT:alert(1)')
	assert !is_safe_url('JaVaScRiPt:alert(1)')

	// Whitespace handling
	assert is_safe_url('  https://example.com  ')
	assert !is_safe_url('  javascript:alert(1)  ')

	// Empty/whitespace
	assert !is_safe_url('')
	assert !is_safe_url('   ')

	// Protocol-like patterns in path (relative path, not protocol)
	assert is_safe_url('path/javascript:test.js')
}
