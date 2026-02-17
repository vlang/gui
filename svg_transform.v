module gui

import math

// identity_transform is the identity affine matrix.
const identity_transform = [f32(1), 0, 0, 1, 0, 0]!

// matrix_multiply composes two affine transforms: result = m1 * m2.
fn matrix_multiply(m1 [6]f32, m2 [6]f32) [6]f32 {
	// | a1 c1 e1 |   | a2 c2 e2 |
	// | b1 d1 f1 | * | b2 d2 f2 |
	// | 0  0  1  |   | 0  0  1  |
	return [
		m1[0] * m2[0] + m1[2] * m2[1], // a
		m1[1] * m2[0] + m1[3] * m2[1], // b
		m1[0] * m2[2] + m1[2] * m2[3], // c
		m1[1] * m2[2] + m1[3] * m2[3], // d
		m1[0] * m2[4] + m1[2] * m2[5] + m1[4], // e
		m1[1] * m2[4] + m1[3] * m2[5] + m1[5], // f
	]!
}

// parse_transform parses SVG transform attribute.
// Supports: matrix, translate, scale, rotate, skewX, skewY
fn parse_transform(s string) [6]f32 {
	mut result := identity_transform
	mut pos := 0
	str := s.trim_space()
	mut count := 0

	for pos < str.len {
		count++
		if count > 100 {
			break
		}
		// Skip whitespace and commas
		for pos < str.len && (str[pos] == ` ` || str[pos] == `,` || str[pos] == `\t`) {
			pos++
		}
		if pos >= str.len {
			break
		}

		// Find transform name
		mut name_end := pos
		for name_end < str.len && str[name_end] != `(` && str[name_end] != ` ` {
			name_end++
		}
		name := str[pos..name_end]

		// Find opening paren
		paren_start := find_index(str, '(', name_end) or { break }
		paren_end := find_index(str, ')', paren_start) or { break }
		args_str := str[paren_start + 1..paren_end]
		args := parse_number_list(args_str)

		m := parse_single_transform(name, args)
		result = matrix_multiply(result, m)
		pos = paren_end + 1
	}

	return result
}

// parse_single_transform parses a single transform function.
fn parse_single_transform(name string, args []f32) [6]f32 {
	if name == 'matrix' && args.len >= 6 {
		return [args[0], args[1], args[2], args[3], args[4], args[5]]!
	}
	if name == 'translate' {
		tx := if args.len >= 1 { args[0] } else { f32(0) }
		ty := if args.len >= 2 { args[1] } else { f32(0) }
		return [f32(1), 0, 0, 1, tx, ty]!
	}
	if name == 'scale' {
		sx := if args.len >= 1 { args[0] } else { f32(1) }
		sy := if args.len >= 2 { args[1] } else { sx }
		return [sx, f32(0), 0, sy, 0, 0]!
	}
	if name == 'rotate' {
		return parse_rotate_transform(args)
	}
	if name == 'skewX' && args.len >= 1 {
		angle := args[0] * math.pi / 180.0
		return [f32(1), 0, math.tanf(angle), 1, 0, 0]!
	}
	if name == 'skewY' && args.len >= 1 {
		angle := args[0] * math.pi / 180.0
		return [f32(1), math.tanf(angle), 0, 1, 0, 0]!
	}
	return identity_transform
}

// parse_rotate_transform handles rotate(angle) or rotate(angle, cx, cy).
fn parse_rotate_transform(args []f32) [6]f32 {
	if args.len < 1 {
		return identity_transform
	}
	angle := args[0] * math.pi / 180.0
	cos_a := math.cosf(angle)
	sin_a := math.sinf(angle)
	if args.len >= 3 {
		// rotate(angle, cx, cy) - rotate around point
		cx := args[1]
		cy := args[2]
		return [cos_a, sin_a, -sin_a, cos_a, cx - cos_a * cx + sin_a * cy,
			cy - sin_a * cx - cos_a * cy]!
	}
	return [cos_a, sin_a, -sin_a, cos_a, f32(0), 0]!
}

// get_transform extracts and parses transform attribute from element.
fn get_transform(elem string) [6]f32 {
	if t := find_attr_or_style(elem, 'transform') {
		return parse_transform(t)
	}
	return identity_transform
}

// get_stroke_color extracts stroke color from element.
// Returns color_inherit sentinel if not specified.
fn get_stroke_color(elem string) Color {
	stroke := find_attr_or_style(elem, 'stroke') or { return color_inherit }
	return parse_svg_color(stroke)
}

// get_stroke_gradient_id extracts gradient ID from stroke="url(#id)".
fn get_stroke_gradient_id(elem string) string {
	stroke := find_attr_or_style(elem, 'stroke') or { return '' }
	return parse_fill_url(stroke) or { '' }
}

// get_stroke_dasharray parses stroke-dasharray attribute into
// a list of dash/gap lengths. Returns empty on 'none' or invalid.
fn get_stroke_dasharray(elem string) []f32 {
	val := find_attr_or_style(elem, 'stroke-dasharray') or { return []f32{} }
	if val.trim_space() == 'none' {
		return []f32{}
	}
	// Replace commas with spaces, then split on whitespace
	parts := val.replace(',', ' ').split(' ').filter(it.len > 0)
	mut result := []f32{cap: parts.len}
	for p in parts {
		n := p.trim_space().f32()
		if n < 0 {
			return []f32{}
		}
		result << n
	}
	// SVG spec: odd-length patterns are repeated to make even
	if result.len > 0 && result.len % 2 != 0 {
		result << result
	}
	return result
}

// get_stroke_width extracts stroke width from element attribute.
// Returns -1.0 sentinel if not specified (caller should use default or inherit).
// The -1.0 sentinel allows distinguishing "not set" from explicit 0.0 (no stroke).
fn get_stroke_width(elem string) f32 {
	width_str := find_attr_or_style(elem, 'stroke-width') or { return -1.0 }
	return parse_length(width_str)
}

// get_stroke_linecap extracts stroke-linecap from element.
// Returns .inherit sentinel if not specified.
fn get_stroke_linecap(elem string) StrokeCap {
	cap := find_attr_or_style(elem, 'stroke-linecap') or { return .inherit }
	return match cap {
		'round' { StrokeCap.round }
		'square' { StrokeCap.square }
		else { StrokeCap.butt }
	}
}

// get_stroke_linejoin extracts stroke-linejoin from element.
// Returns .inherit sentinel if not specified.
fn get_stroke_linejoin(elem string) StrokeJoin {
	join := find_attr_or_style(elem, 'stroke-linejoin') or { return .inherit }
	return match join {
		'round' { StrokeJoin.round }
		'bevel' { StrokeJoin.bevel }
		else { StrokeJoin.miter }
	}
}
