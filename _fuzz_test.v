module gui

import svg
import os
import rand

const fuzz_iterations = 1000
const fuzz_max_input_len = 65536

fn fuzz_random_bytes(mut rng rand.PRNG, max_len int) string {
	len := rng.intn(max_len) or { 64 }
	if len == 0 {
		return ''
	}
	mut buf := []u8{len: len}
	for i in 0 .. len {
		buf[i] = u8(rng.intn(256) or { 0 })
	}
	return buf.bytestr()
}

fn fuzz_random_element(mut rng rand.PRNG, pool []string) string {
	idx := rng.intn(pool.len) or { 0 }
	return pool[idx]
}

fn fuzz_grammar_soup(mut rng rand.PRNG, pool []string, max_tokens int) string {
	count := rng.intn(max_tokens) or { 10 }
	mut buf := []u8{cap: count * 8}
	for _ in 0 .. count {
		token := fuzz_random_element(mut rng, pool)
		buf << token.bytes()
	}
	return buf.bytestr()
}

fn test_fuzz_markdown() {
	iterations := if s := os.getenv_opt('FUZZ_ITERATIONS') {
		s.int()
	} else {
		fuzz_iterations
	}
	mut rng := rand.new_default(seed_: [u32(123456), 789012])

	md_tokens := [
		'*',
		'**',
		'***',
		'_',
		'__',
		'___',
		'~~',
		'#',
		'##',
		'###',
		'>',
		'- ',
		'1. ',
		'- [ ] ',
		'- [x] ',
		'`',
		'```',
		'~~~',
		'[',
		'](',
		')',
		'[^',
		']: ',
		'|',
		'---',
		':-:',
		'-:',
		r'\$',
		r'\$\$',
		'\n',
		'\n\n',
		'\t',
		'  \n',
		'\\',
		'hello ',
		'world ',
		'test',
		'==',
		':smile:',
		':',
		'^',
		'~',
		'    ',
		'#heading',
	]

	style := MarkdownStyle{}

	// Edge cases (targeted)
	edge_cases := [
		// Recursion bomb
		'*'.repeat(500) + 'x' + '*'.repeat(500),
		// Deep nesting
		'***___'.repeat(200),
		// Unmatched delimiters
		'[[[[[',
		')))))',
		'`'.repeat(100),
		// Control chars embedded in valid markdown
		'# Hello\x00World\x01\x02',
		// Table bomb
		'| col '.repeat(500) + '\n' + '| --- '.repeat(500) + '|\n',
		// Footnote continuation
		'[^1]: start\n' + '    cont\n'.repeat(30),
		// Empty constructs
		'**',
		'__',
		'~~',
		'``',
		'[]',
		'[]()',
		// Deeply nested bold/italic
		'*' + '**' + '***' + '___' + '__' + '_'.repeat(50),
		// Highlight bombs
		'=='.repeat(500),
		'='.repeat(500),
		// Emoji edge cases
		':'.repeat(500),
		'::::::',
		':' + 'a'.repeat(100) + ':',
		// Super/subscript nesting
		'^'.repeat(200) + 'x' + '^'.repeat(200),
		'~'.repeat(200) + 'x' + '~'.repeat(200),
		// Mixed single/double tilde
		'~x~~y~~~z~~~~',
		// Indented code vs list
		'    code\n- list\n    cont\n    code',
		// Very deep indentation
		'    '.repeat(20) + 'deep',
		// Hard break edge cases
		'line  \nline  \nline  \n'.repeat(50),
		'line\\\nline\\\n'.repeat(50),
	]

	for i in 0 .. iterations {
		input := if i < edge_cases.len {
			edge_cases[i]
		} else {
			bucket := i % 5
			if bucket == 0 {
				// 20% pure random bytes
				fuzz_random_bytes(mut rng, 512)
			} else {
				// 80% grammar-aware soup
				fuzz_grammar_soup(mut rng, md_tokens, 50)
			}
		}
		// Must not panic
		_ = markdown_to_rich_text(input, style)
	}

	// Second pass with hard_line_breaks enabled
	style_hb := MarkdownStyle{
		hard_line_breaks: true
	}
	mut rng2 := rand.new_default(seed_: [u32(987654), 321098])
	for i in 0 .. iterations {
		input := if i < edge_cases.len {
			edge_cases[i]
		} else {
			bucket := i % 5
			if bucket == 0 {
				fuzz_random_bytes(mut rng2, 512)
			} else {
				fuzz_grammar_soup(mut rng2, md_tokens, 50)
			}
		}
		// Must not panic
		_ = markdown_to_rich_text(input, style_hb)
	}
}

fn test_fuzz_svg() {
	// SVG parsing is heavier per iteration; cap at 50k to
	// avoid timeouts on pathological inputs.
	iterations := if s := os.getenv_opt('FUZZ_ITERATIONS') {
		if s.int() > 50000 { 50000 } else { s.int() }
	} else {
		fuzz_iterations
	}
	mut rng := rand.new_default(seed_: [u32(654321), 210987])

	svg_tokens := [
		'<svg>',
		'</svg>',
		'<path',
		'<rect',
		'<circle',
		'<g>',
		'</g>',
		'<defs>',
		'</defs>',
		'<clipPath',
		' d="',
		' fill="',
		' viewBox="',
		' transform="',
		'M',
		'L',
		'C',
		'S',
		'A',
		'Z',
		'H',
		'V',
		'1,1 ',
		'0 0 ',
		'-5.5 ',
		'99 ',
		'#fff',
		'rgb(',
		'rgba(',
		'none',
		'red',
		'"',
		'translate(',
		'rotate(',
		'scale(',
		'matrix(',
		')',
		'>',
		'/>',
		' ',
		'\n',
	]

	edge_cases := [
		// Deep nesting (exceeds max_group_depth=32)
		'<svg>' + '<g>'.repeat(50) + '</g>'.repeat(50) + '</svg>',
		// Segment flood
		'<svg><path d="M0,0 ' + 'L1,1 '.repeat(1000) + '"/></svg>',
		// Transform chain
		'<svg><g transform="' + 'translate(1,1) '.repeat(200) +
			'"><rect width="1" height="1"/></g></svg>',
		// Extreme coords
		'<svg><rect x="9999999" y="9999999" width="1" height="1"/></svg>',
		// Double-decimal tokenizer edge
		'<svg><path d="M1.5.5.3.4L2.3.4"/></svg>',
		// Unclosed tags
		'<svg><path d="M0,0" <rect',
		// Empty d attribute
		'<svg><path d=""/></svg>',
		// Duplicate attrs
		'<svg><rect fill="red" fill="blue" width="1" height="1"/></svg>',
		// Very large viewBox
		'<svg viewBox="0 0 ' + '0 '.repeat(500) + '"></svg>',
	]

	for i in 0 .. iterations {
		input := if i < edge_cases.len {
			edge_cases[i]
		} else {
			bucket := i % 5
			if bucket == 0 {
				fuzz_random_bytes(mut rng, 512)
			} else {
				fuzz_grammar_soup(mut rng, svg_tokens, 40)
			}
		}
		// Must not panic; errors are acceptable
		svg.parse_svg(input) or { continue }
	}
}

fn test_fuzz_url_validation() {
	iterations := if s := os.getenv_opt('FUZZ_ITERATIONS') {
		s.int()
	} else {
		fuzz_iterations
	}
	mut rng := rand.new_default(seed_: [u32(111111), 222222])

	url_tokens := [
		'javascript:',
		'data:',
		'vbscript:',
		'file:',
		'blob:',
		'http://',
		'https://',
		'mailto:',
		'%6A',
		'%61',
		'&#106;',
		r'\u006A',
		'JaVaScRiPt:',
		'DATA:',
		'VbScRiPt:',
		'//evil.com',
		'///file',
		'http:javascript:',
		'https:data:',
		'alert(1)',
		'<script>',
		'onerror=',
		'example.com',
		'/path',
		'#anchor',
		'?q=1',
	]

	// Known-dangerous inputs that must return false
	dangerous := [
		'javascript:alert(1)',
		'JAVASCRIPT:alert(1)',
		'JaVaScRiPt:void(0)',
		'  javascript:alert(1)',
		'data:text/html,<script>alert(1)</script>',
		'vbscript:msgbox',
		'VBScript:Execute',
	]

	edge_cases := [
		// Null byte injection
		'java\x00script:alert(1)',
		// Tab/newline injection
		'java\tscript:alert(1)',
		'java\nscript:alert(1)',
		// Mixed protocols
		'http:javascript:alert(1)',
		// Protocol-less paths
		'//evil.com/payload',
		'///etc/passwd',
		// Empty / whitespace
		'',
		' ',
		'\t\n',
		// Very long URL
		'https://' + 'a'.repeat(10000),
	]

	// Verify known-dangerous inputs blocked
	for d in dangerous {
		assert !is_safe_url(d), 'expected unsafe: ${d}'
	}

	for i in 0 .. iterations {
		input := if i < edge_cases.len {
			edge_cases[i]
		} else {
			bucket := i % 5
			if bucket == 0 {
				fuzz_random_bytes(mut rng, 256)
			} else {
				fuzz_grammar_soup(mut rng, url_tokens, 10)
			}
		}
		// Must not panic
		_ = is_safe_url(input)

		// Fuzzed inputs starting with javascript: must be blocked
		lower := input.to_lower().trim_space()
		if lower.starts_with('javascript:') {
			assert !is_safe_url(input), 'expected unsafe: ${input}'
		}
	}
}
