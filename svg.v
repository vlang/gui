module gui

import math
import os
import strings

// Security limits for SVG parsing
const default_icon_size = 24
const max_group_depth = 32
const max_elements = 100000
const max_path_segments = 100000
const max_viewbox_dim = 10000
const max_attr_len = 1048576

// ParseState tracks mutable state during SVG parsing.
struct ParseState {
mut:
	elem_count int
}

// GroupStyle holds inherited style properties for groups.
struct GroupStyle {
	transform    [6]f32
	fill         string
	stroke       string
	stroke_width string
	stroke_cap   string
	stroke_join  string
}

// parse_svg parses an SVG string and returns a VectorGraphic.
pub fn parse_svg(content string) !VectorGraphic {
	mut vg := VectorGraphic{
		width:  default_icon_size
		height: default_icon_size
	}

	// Parse viewBox
	if vb := find_attr(content, 'viewBox') {
		parts := vb.split_any(' ,')
		if parts.len >= 4 {
			vg.width = clamp_viewbox_dim(parts[2].f32())
			vg.height = clamp_viewbox_dim(parts[3].f32())
		}
	} else {
		// Try width/height attributes
		if w := find_attr(content, 'width') {
			vg.width = clamp_viewbox_dim(parse_length(w))
		}
		if h := find_attr(content, 'height') {
			vg.height = clamp_viewbox_dim(parse_length(h))
		}
	}

	// Parse with group support
	default_style := GroupStyle{
		transform: identity_transform
	}
	mut state := ParseState{}
	vg.paths = parse_svg_content(content, default_style, 0, mut state)

	return vg
}

// parse_svg_content parses SVG content recursively, handling groups.
// depth limits recursion; state.elem_count limits total elements parsed.
fn parse_svg_content(content string, inherited GroupStyle, depth int, mut state ParseState) []VectorPath {
	mut paths := []VectorPath{}
	mut pos := 0

	// Reject excessive nesting depth
	if depth > max_group_depth {
		return paths
	}

	for pos < content.len {
		// Stop if element limit reached
		if state.elem_count >= max_elements {
			break
		}
		// Find next element
		start := find_index(content, '<', pos) or { break }

		// Skip comments and declarations
		if start + 3 < content.len {
			if content[start..start + 4] == '<!--' {
				// Skip comment
				end := find_index(content, '-->', start) or { break }
				pos = end + 3
				continue
			}
			if content[start + 1] == `!` || content[start + 1] == `?` {
				end := find_index(content, '>', start) or { break }
				pos = end + 1
				continue
			}
		}

		// Check for closing tag
		if start + 1 < content.len && content[start + 1] == `/` {
			end := find_index(content, '>', start) or { break }
			pos = end + 1
			continue
		}

		// Extract tag name
		tag_end := find_tag_name_end(content, start + 1)
		if tag_end <= start + 1 {
			pos = start + 1
			continue
		}
		tag_name := content[start + 1..tag_end]

		// Find element end
		elem_end := find_index(content, '>', start) or { break }
		elem := content[start..elem_end + 1]
		is_self_closing := elem_end > 0 && content[elem_end - 1] == `/`

		// Handle different elements
		if tag_name == 'g' {
			// Parse group
			group_style := merge_group_style(elem, inherited)
			state.elem_count++

			if is_self_closing {
				pos = elem_end + 1
				continue
			}

			// Find closing </g> tag
			group_content_start := elem_end + 1
			group_end := find_closing_tag(content, 'g', group_content_start)
			if group_end > group_content_start {
				group_content := content[group_content_start..group_end]
				paths << parse_svg_content(group_content, group_style, depth + 1, mut
					state)
			}
			// Skip past </g>
			close_end := find_index(content, '>', group_end) or { break }
			pos = close_end + 1
		} else if tag_name == 'path' {
			state.elem_count++
			if p := parse_path_with_style(elem, inherited) {
				paths << p
			}
			pos = elem_end + 1
		} else if tag_name == 'rect' {
			state.elem_count++
			if p := parse_rect_with_style(elem, inherited) {
				paths << p
			}
			pos = elem_end + 1
		} else if tag_name == 'circle' {
			state.elem_count++
			if p := parse_circle_with_style(elem, inherited) {
				paths << p
			}
			pos = elem_end + 1
		} else if tag_name == 'ellipse' {
			state.elem_count++
			if p := parse_ellipse_with_style(elem, inherited) {
				paths << p
			}
			pos = elem_end + 1
		} else if tag_name == 'polygon' {
			state.elem_count++
			if p := parse_polygon_with_style(elem, inherited, true) {
				paths << p
			}
			pos = elem_end + 1
		} else if tag_name == 'polyline' {
			state.elem_count++
			if p := parse_polygon_with_style(elem, inherited, false) {
				paths << p
			}
			pos = elem_end + 1
		} else if tag_name == 'line' {
			state.elem_count++
			if p := parse_line_with_style(elem, inherited) {
				paths << p
			}
			pos = elem_end + 1
		} else {
			pos = elem_end + 1
		}
	}

	return paths
}

// find_tag_name_end finds the end of a tag name.
fn find_tag_name_end(s string, start int) int {
	mut i := start
	for i < s.len {
		c := s[i]
		if c == ` ` || c == `\t` || c == `\n` || c == `\r` || c == `>` || c == `/` {
			break
		}
		i++
	}
	return i
}

// find_closing_tag finds the position of the closing tag for a given element.
fn find_closing_tag(content string, tag string, start int) int {
	close_tag := '</${tag}'
	open_tag := '<${tag}'
	mut depth := 1
	mut pos := start

	for pos < content.len && depth > 0 {
		// Find next < character
		next := find_index(content, '<', pos) or { break }

		// Check for closing tag
		if next + close_tag.len <= content.len && content[next..next + close_tag.len] == close_tag {
			depth--
			if depth == 0 {
				return next
			}
			pos = next + close_tag.len
			continue
		}

		// Check for opening tag (nested)
		if next + open_tag.len <= content.len && content[next..next + open_tag.len] == open_tag {
			// Make sure it's actually the tag and not something like <glyph
			end_pos := next + open_tag.len
			if end_pos < content.len {
				c := content[end_pos]
				if c == ` ` || c == `\t` || c == `\n` || c == `>` || c == `/` {
					depth++
				}
			}
		}

		pos = next + 1
	}

	return content.len
}

// merge_group_style merges element attributes with inherited style.
fn merge_group_style(elem string, inherited GroupStyle) GroupStyle {
	// Get element's transform and compose with inherited
	elem_transform := get_transform(elem)
	combined_transform := matrix_multiply(inherited.transform, elem_transform)

	// Inherit or override style properties
	fill := find_attr(elem, 'fill') or { inherited.fill }
	stroke := find_attr(elem, 'stroke') or { inherited.stroke }
	stroke_width := find_attr(elem, 'stroke-width') or { inherited.stroke_width }
	stroke_cap := find_attr(elem, 'stroke-linecap') or { inherited.stroke_cap }
	stroke_join := find_attr(elem, 'stroke-linejoin') or { inherited.stroke_join }

	return GroupStyle{
		transform:    combined_transform
		fill:         fill
		stroke:       stroke
		stroke_width: stroke_width
		stroke_cap:   stroke_cap
		stroke_join:  stroke_join
	}
}

// apply_inherited_style applies inherited style to a path.
fn apply_inherited_style(mut path VectorPath, inherited GroupStyle) {
	// Compose transforms
	path.transform = matrix_multiply(inherited.transform, path.transform)

	// Apply inherited fill if element doesn't specify one (uses sentinel)
	if path.fill_color == color_inherit {
		if inherited.fill.len > 0 {
			path.fill_color = parse_svg_color(inherited.fill)
		} else {
			path.fill_color = black // SVG default
		}
	}

	// Apply inherited stroke if element doesn't specify one (uses sentinel)
	if path.stroke_color == color_inherit {
		if inherited.stroke.len > 0 {
			path.stroke_color = parse_svg_color(inherited.stroke)
		} else {
			path.stroke_color = color_transparent
		}
	}
	if inherited.stroke_width.len > 0 && path.stroke_width < 0 {
		path.stroke_width = parse_length(inherited.stroke_width)
	}
	if path.stroke_width < 0 {
		path.stroke_width = 1.0 // SVG default
	}
	if inherited.stroke_cap.len > 0 && path.stroke_cap == .inherit {
		path.stroke_cap = match inherited.stroke_cap {
			'round' { StrokeCap.round }
			'square' { StrokeCap.square }
			else { StrokeCap.butt }
		}
	}
	if path.stroke_cap == .inherit {
		path.stroke_cap = .butt
	}
	if inherited.stroke_join.len > 0 && path.stroke_join == .inherit {
		path.stroke_join = match inherited.stroke_join {
			'round' { StrokeJoin.round }
			'bevel' { StrokeJoin.bevel }
			else { StrokeJoin.miter }
		}
	}
	if path.stroke_join == .inherit {
		path.stroke_join = .miter
	}
}

// parse_path_with_style parses a path element with inherited style.
fn parse_path_with_style(elem string, inherited GroupStyle) ?VectorPath {
	mut path := parse_path_element(elem) or { return none }
	apply_inherited_style(mut path, inherited)
	return path
}

// parse_rect_with_style parses a rect element with inherited style.
fn parse_rect_with_style(elem string, inherited GroupStyle) ?VectorPath {
	mut path := parse_rect_element(elem) or { return none }
	apply_inherited_style(mut path, inherited)
	return path
}

// parse_circle_with_style parses a circle element with inherited style.
fn parse_circle_with_style(elem string, inherited GroupStyle) ?VectorPath {
	mut path := parse_circle_element(elem) or { return none }
	apply_inherited_style(mut path, inherited)
	return path
}

// parse_ellipse_with_style parses an ellipse element with inherited style.
fn parse_ellipse_with_style(elem string, inherited GroupStyle) ?VectorPath {
	mut path := parse_ellipse_element(elem) or { return none }
	apply_inherited_style(mut path, inherited)
	return path
}

// parse_polygon_with_style parses a polygon/polyline element with inherited style.
fn parse_polygon_with_style(elem string, inherited GroupStyle, close bool) ?VectorPath {
	mut path := parse_polygon_element(elem, close) or { return none }
	apply_inherited_style(mut path, inherited)
	return path
}

// parse_line_with_style parses a line element with inherited style.
fn parse_line_with_style(elem string, inherited GroupStyle) ?VectorPath {
	mut path := parse_line_element(elem) or { return none }
	apply_inherited_style(mut path, inherited)
	return path
}

// find_index finds the index of substr in s starting from pos, returns none if not found
fn find_index(s string, substr string, pos int) ?int {
	for i := pos; i <= s.len - substr.len; i++ {
		mut found := true
		for j := 0; j < substr.len; j++ {
			if s[i + j] != substr[j] {
				found = false
				break
			}
		}
		if found {
			return i
		}
	}
	return none
}

// parse_svg_file loads and parses an SVG file.
pub fn parse_svg_file(path string) !VectorGraphic {
	content := os.read_file(path) or { return error('Failed to read SVG file: ${path}') }
	return parse_svg(content)
}

// find_attr extracts an attribute value from an element string.
// Ensures attribute name is preceded by whitespace to avoid matching substrings.
fn find_attr(elem string, name string) ?string {
	// Whitespace prefixes to check
	prefixes := [u8(` `), `\t`, `\n`, `\r`]
	// Quote styles
	quotes := [u8(`"`), `'`]

	for prefix in prefixes {
		for quote in quotes {
			pattern := '${prefix.ascii_str()}${name}=${quote.ascii_str()}'
			mut start := find_index(elem, pattern, 0) or { continue }
			start += pattern.len
			end := find_index(elem, quote.ascii_str(), start) or { continue }
			if end > start {
				attr_len := end - start
				if attr_len > max_attr_len {
					return none // attribute too long, reject
				}
				return elem[start..end]
			}
		}
	}
	return none
}

// clamp_viewbox_dim clamps dimension to prevent extreme allocations
fn clamp_viewbox_dim(v f32) f32 {
	if v < 0 {
		return 0
	}
	if v > max_viewbox_dim {
		return max_viewbox_dim
	}
	return v
}

// parse_length parses a CSS length value (ignores units for now)
fn parse_length(s string) f32 {
	mut num := ''
	for c in s {
		if (c >= `0` && c <= `9`) || c == `.` || c == `-` {
			num += c.ascii_str()
		} else {
			break
		}
	}
	return num.f32()
}

// parse_path_element parses a <path> element
fn parse_path_element(elem string) ?VectorPath {
	d := find_attr(elem, 'd') or { return none }
	fill := find_attr(elem, 'fill') or { '' }

	mut path := VectorPath{
		fill_color:   parse_svg_color(fill)
		transform:    get_transform(elem)
		stroke_color: get_stroke_color(elem)
		stroke_width: get_stroke_width(elem)
		stroke_cap:   get_stroke_linecap(elem)
		stroke_join:  get_stroke_linejoin(elem)
	}
	path.segments = parse_path_d(d)

	if path.segments.len == 0 {
		return none
	}
	return path
}

// parse_rect_element converts <rect> to path
fn parse_rect_element(elem string) ?VectorPath {
	x := (find_attr(elem, 'x') or { '0' }).f32()
	y := (find_attr(elem, 'y') or { '0' }).f32()
	w := (find_attr(elem, 'width') or { return none }).f32()
	h := (find_attr(elem, 'height') or { return none }).f32()
	mut rx := (find_attr(elem, 'rx') or { '0' }).f32()
	mut ry := (find_attr(elem, 'ry') or { '0' }).f32()
	fill := find_attr(elem, 'fill') or { '' }

	if rx == 0 && ry > 0 {
		rx = ry
	}
	if ry == 0 && rx > 0 {
		ry = rx
	}

	mut segments := []PathSegment{}

	if rx == 0 && ry == 0 {
		// Simple rectangle
		segments << PathSegment{.move_to, [x, y]}
		segments << PathSegment{.line_to, [x + w, y]}
		segments << PathSegment{.line_to, [x + w, y + h]}
		segments << PathSegment{.line_to, [x, y + h]}
		segments << PathSegment{.close, []}
	} else {
		// Rounded rectangle using arcs
		if rx > w / 2 {
			rx = w / 2
		}
		if ry > h / 2 {
			ry = h / 2
		}
		segments << PathSegment{.move_to, [x + rx, y]}
		segments << PathSegment{.line_to, [x + w - rx, y]}
		segments << arc_to_cubic(x + w - rx, y, rx, ry, 0, false, true, x + w, y + ry)
		segments << PathSegment{.line_to, [x + w, y + h - ry]}
		segments << arc_to_cubic(x + w, y + h - ry, rx, ry, 0, false, true, x + w - rx,
			y + h)
		segments << PathSegment{.line_to, [x + rx, y + h]}
		segments << arc_to_cubic(x + rx, y + h, rx, ry, 0, false, true, x, y + h - ry)
		segments << PathSegment{.line_to, [x, y + ry]}
		segments << arc_to_cubic(x, y + ry, rx, ry, 0, false, true, x + rx, y)
		segments << PathSegment{.close, []}
	}

	return VectorPath{
		segments:     segments
		fill_color:   parse_svg_color(fill)
		transform:    get_transform(elem)
		stroke_color: get_stroke_color(elem)
		stroke_width: get_stroke_width(elem)
		stroke_cap:   get_stroke_linecap(elem)
		stroke_join:  get_stroke_linejoin(elem)
	}
}

// parse_circle_element converts <circle> to path
fn parse_circle_element(elem string) ?VectorPath {
	cx := (find_attr(elem, 'cx') or { '0' }).f32()
	cy := (find_attr(elem, 'cy') or { '0' }).f32()
	r := (find_attr(elem, 'r') or { return none }).f32()
	fill := find_attr(elem, 'fill') or { '' }

	return ellipse_to_path(cx, cy, r, r, elem, fill)
}

// parse_ellipse_element converts <ellipse> to path
fn parse_ellipse_element(elem string) ?VectorPath {
	cx := (find_attr(elem, 'cx') or { '0' }).f32()
	cy := (find_attr(elem, 'cy') or { '0' }).f32()
	rx := (find_attr(elem, 'rx') or { return none }).f32()
	ry := (find_attr(elem, 'ry') or { return none }).f32()
	fill := find_attr(elem, 'fill') or { '' }

	return ellipse_to_path(cx, cy, rx, ry, elem, fill)
}

// ellipse_to_path converts an ellipse to a path using 4 cubic beziers
fn ellipse_to_path(cx f32, cy f32, rx f32, ry f32, elem string, fill string) VectorPath {
	// Approximate circle with 4 cubic beziers (kappa = 4*(sqrt(2)-1)/3)
	k := f32(0.5522847498)
	kx := rx * k
	ky := ry * k

	mut segments := []PathSegment{}
	segments << PathSegment{.move_to, [cx, cy - ry]}
	segments << PathSegment{.cubic_to, [cx + kx, cy - ry, cx + rx, cy - ky, cx + rx, cy]}
	segments << PathSegment{.cubic_to, [cx + rx, cy + ky, cx + kx, cy + ry, cx, cy + ry]}
	segments << PathSegment{.cubic_to, [cx - kx, cy + ry, cx - rx, cy + ky, cx - rx, cy]}
	segments << PathSegment{.cubic_to, [cx - rx, cy - ky, cx - kx, cy - ry, cx, cy - ry]}
	segments << PathSegment{.close, []}

	return VectorPath{
		segments:     segments
		fill_color:   parse_svg_color(fill)
		transform:    get_transform(elem)
		stroke_color: get_stroke_color(elem)
		stroke_width: get_stroke_width(elem)
		stroke_cap:   get_stroke_linecap(elem)
		stroke_join:  get_stroke_linejoin(elem)
	}
}

// parse_polygon_element converts <polygon> or <polyline> to path
fn parse_polygon_element(elem string, close bool) ?VectorPath {
	points_str := find_attr(elem, 'points') or { return none }
	fill := find_attr(elem, 'fill') or { '' }

	numbers := parse_number_list(points_str)
	if numbers.len < 4 {
		return none
	}

	mut segments := []PathSegment{}
	segments << PathSegment{.move_to, [numbers[0], numbers[1]]}
	for i := 2; i < numbers.len - 1; i += 2 {
		segments << PathSegment{.line_to, [numbers[i], numbers[i + 1]]}
	}
	if close {
		segments << PathSegment{.close, []}
	}

	return VectorPath{
		segments:     segments
		fill_color:   parse_svg_color(fill)
		transform:    get_transform(elem)
		stroke_color: get_stroke_color(elem)
		stroke_width: get_stroke_width(elem)
		stroke_cap:   get_stroke_linecap(elem)
		stroke_join:  get_stroke_linejoin(elem)
	}
}

// parse_line_element converts <line> to path
fn parse_line_element(elem string) ?VectorPath {
	x1 := (find_attr(elem, 'x1') or { '0' }).f32()
	y1 := (find_attr(elem, 'y1') or { '0' }).f32()
	x2 := (find_attr(elem, 'x2') or { '0' }).f32()
	y2 := (find_attr(elem, 'y2') or { '0' }).f32()

	return VectorPath{
		segments:     [
			PathSegment{.move_to, [x1, y1]},
			PathSegment{.line_to, [x2, y2]},
		]
		fill_color:   color_transparent
		transform:    get_transform(elem)
		stroke_color: get_stroke_color(elem)
		stroke_width: get_stroke_width(elem)
		stroke_cap:   get_stroke_linecap(elem)
		stroke_join:  get_stroke_linejoin(elem)
	}
}

// parse_svg_color parses SVG color values.
// Returns color_inherit sentinel if string is empty (attribute not present).
fn parse_svg_color(s string) Color {
	str := s.trim_space()
	if str.len == 0 {
		return color_inherit // not specified, should inherit
	}
	if str == 'none' {
		return color_transparent
	}
	if str == 'currentColor' || str == 'inherit' {
		return color_inherit
	}
	if str.starts_with('#') {
		return parse_hex_color(str)
	}
	if str.starts_with('rgb') {
		return parse_rgb_color(str)
	}
	// Named colors
	return color_from_string(str)
}

// parse_hex_color parses #RGB, #RRGGBB, #RGBA, #RRGGBBAA
fn parse_hex_color(s string) Color {
	hex_str := s[1..]
	match hex_str.len {
		3 {
			// #RGB -> #RRGGBB
			r := svg_hex_digit(hex_str[0]) * 17
			g := svg_hex_digit(hex_str[1]) * 17
			b := svg_hex_digit(hex_str[2]) * 17
			return Color{u8(r), u8(g), u8(b), 255}
		}
		4 {
			// #RGBA
			r := svg_hex_digit(hex_str[0]) * 17
			g := svg_hex_digit(hex_str[1]) * 17
			b := svg_hex_digit(hex_str[2]) * 17
			a := svg_hex_digit(hex_str[3]) * 17
			return Color{u8(r), u8(g), u8(b), u8(a)}
		}
		6 {
			// #RRGGBB
			r := svg_hex_digit(hex_str[0]) * 16 + svg_hex_digit(hex_str[1])
			g := svg_hex_digit(hex_str[2]) * 16 + svg_hex_digit(hex_str[3])
			b := svg_hex_digit(hex_str[4]) * 16 + svg_hex_digit(hex_str[5])
			return Color{u8(r), u8(g), u8(b), 255}
		}
		8 {
			// #RRGGBBAA
			r := svg_hex_digit(hex_str[0]) * 16 + svg_hex_digit(hex_str[1])
			g := svg_hex_digit(hex_str[2]) * 16 + svg_hex_digit(hex_str[3])
			b := svg_hex_digit(hex_str[4]) * 16 + svg_hex_digit(hex_str[5])
			a := svg_hex_digit(hex_str[6]) * 16 + svg_hex_digit(hex_str[7])
			return Color{u8(r), u8(g), u8(b), u8(a)}
		}
		else {
			return black
		}
	}
}

// svg_hex_digit converts a hex character (0-9, a-f, A-F) to its integer value (0-15).
fn svg_hex_digit(c u8) int {
	if c >= `0` && c <= `9` {
		return int(c - `0`)
	}
	if c >= `a` && c <= `f` {
		return int(c - `a` + 10)
	}
	if c >= `A` && c <= `F` {
		return int(c - `A` + 10)
	}
	return 0
}

// parse_rgb_color parses rgb(r,g,b) or rgba(r,g,b,a)
fn parse_rgb_color(s string) Color {
	start := find_index(s, '(', 0) or { return black }
	end := find_index(s, ')', 0) or { return black }
	if end <= start + 1 {
		return black
	}
	parts := s[start + 1..end].split(',')
	if parts.len < 3 {
		return black
	}
	r := parts[0].trim_space().int()
	g := parts[1].trim_space().int()
	b := parts[2].trim_space().int()
	mut a := 255
	if parts.len >= 4 {
		alpha := parts[3].trim_space().f32()
		if alpha <= 1.0 {
			a = int(alpha * 255)
		} else {
			a = int(alpha)
		}
	}
	return Color{u8(r), u8(g), u8(b), u8(a)}
}

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

	for pos < str.len {
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
	if t := find_attr(elem, 'transform') {
		return parse_transform(t)
	}
	return identity_transform
}

// get_stroke_color extracts stroke color from element.
// Returns color_inherit sentinel if not specified.
fn get_stroke_color(elem string) Color {
	stroke := find_attr(elem, 'stroke') or { return color_inherit }
	return parse_svg_color(stroke)
}

// get_stroke_width extracts stroke width from element.
// Returns -1 (sentinel) if not specified.
fn get_stroke_width(elem string) f32 {
	width := find_attr(elem, 'stroke-width') or { return -1.0 }
	return parse_length(width)
}

// get_stroke_linecap extracts stroke-linecap from element.
// Returns .inherit sentinel if not specified.
fn get_stroke_linecap(elem string) StrokeCap {
	cap := find_attr(elem, 'stroke-linecap') or { return .inherit }
	return match cap {
		'round' { StrokeCap.round }
		'square' { StrokeCap.square }
		else { StrokeCap.butt }
	}
}

// get_stroke_linejoin extracts stroke-linejoin from element.
// Returns .inherit sentinel if not specified.
fn get_stroke_linejoin(elem string) StrokeJoin {
	join := find_attr(elem, 'stroke-linejoin') or { return .inherit }
	return match join {
		'round' { StrokeJoin.round }
		'bevel' { StrokeJoin.bevel }
		else { StrokeJoin.miter }
	}
}

// parse_path_d parses the SVG path d attribute
fn parse_path_d(d string) []PathSegment {
	mut segments := []PathSegment{}
	mut tokens := tokenize_path(d)
	mut i := 0

	mut cur_x := f32(0)
	mut cur_y := f32(0)
	mut start_x := f32(0)
	mut start_y := f32(0)
	mut last_ctrl_x := f32(0)
	mut last_ctrl_y := f32(0)
	mut last_cmd := u8(0)

	for i < tokens.len && segments.len < max_path_segments {
		token := tokens[i]
		if token.len == 0 {
			i++
			continue
		}

		c := token[0]
		is_cmd := (c >= `A` && c <= `Z`) || (c >= `a` && c <= `z`)

		mut cmd := if is_cmd { c } else { last_cmd }
		if is_cmd {
			i++
		}

		match cmd {
			`M`, `m` {
				relative := cmd == `m`
				for i < tokens.len && is_number_token(tokens[i]) {
					x := tokens[i].f32()
					y := if i + 1 < tokens.len { tokens[i + 1].f32() } else { f32(0) }
					i += 2

					if relative {
						cur_x += x
						cur_y += y
					} else {
						cur_x = x
						cur_y = y
					}

					if segments.len == 0 || segments[segments.len - 1].cmd == .close
						|| (relative && cmd == `m`) || (!relative && cmd == `M`) {
						segments << PathSegment{.move_to, [cur_x, cur_y]}
						start_x = cur_x
						start_y = cur_y
						// Subsequent coords are lineto
						cmd = if relative { `l` } else { `L` }
					} else {
						segments << PathSegment{.line_to, [cur_x, cur_y]}
					}
				}
			}
			`L`, `l` {
				relative := cmd == `l`
				for i < tokens.len && is_number_token(tokens[i]) {
					x := tokens[i].f32()
					y := if i + 1 < tokens.len { tokens[i + 1].f32() } else { f32(0) }
					i += 2
					if relative {
						cur_x += x
						cur_y += y
					} else {
						cur_x = x
						cur_y = y
					}
					segments << PathSegment{.line_to, [cur_x, cur_y]}
				}
			}
			`H`, `h` {
				relative := cmd == `h`
				for i < tokens.len && is_number_token(tokens[i]) {
					x := tokens[i].f32()
					i++
					if relative {
						cur_x += x
					} else {
						cur_x = x
					}
					segments << PathSegment{.line_to, [cur_x, cur_y]}
				}
			}
			`V`, `v` {
				relative := cmd == `v`
				for i < tokens.len && is_number_token(tokens[i]) {
					y := tokens[i].f32()
					i++
					if relative {
						cur_y += y
					} else {
						cur_y = y
					}
					segments << PathSegment{.line_to, [cur_x, cur_y]}
				}
			}
			`C`, `c` {
				relative := cmd == `c`
				for i + 5 < tokens.len && is_number_token(tokens[i]) {
					c1x := tokens[i].f32()
					c1y := tokens[i + 1].f32()
					c2x := tokens[i + 2].f32()
					c2y := tokens[i + 3].f32()
					x := tokens[i + 4].f32()
					y := tokens[i + 5].f32()
					i += 6
					if relative {
						segments << PathSegment{.cubic_to, [
							cur_x + c1x,
							cur_y + c1y,
							cur_x + c2x,
							cur_y + c2y,
							cur_x + x,
							cur_y + y,
						]}
						last_ctrl_x = cur_x + c2x
						last_ctrl_y = cur_y + c2y
						cur_x += x
						cur_y += y
					} else {
						segments << PathSegment{.cubic_to, [c1x, c1y, c2x, c2y, x, y]}
						last_ctrl_x = c2x
						last_ctrl_y = c2y
						cur_x = x
						cur_y = y
					}
				}
			}
			`S`, `s` {
				relative := cmd == `s`
				for i + 3 < tokens.len && is_number_token(tokens[i]) {
					// Reflect previous control point
					c1x := if last_cmd == `C` || last_cmd == `c` || last_cmd == `S`
						|| last_cmd == `s` {
						cur_x * 2 - last_ctrl_x
					} else {
						cur_x
					}
					c1y := if last_cmd == `C` || last_cmd == `c` || last_cmd == `S`
						|| last_cmd == `s` {
						cur_y * 2 - last_ctrl_y
					} else {
						cur_y
					}

					c2x := tokens[i].f32()
					c2y := tokens[i + 1].f32()
					x := tokens[i + 2].f32()
					y := tokens[i + 3].f32()
					i += 4

					if relative {
						segments << PathSegment{.cubic_to, [
							c1x,
							c1y,
							cur_x + c2x,
							cur_y + c2y,
							cur_x + x,
							cur_y + y,
						]}
						last_ctrl_x = cur_x + c2x
						last_ctrl_y = cur_y + c2y
						cur_x += x
						cur_y += y
					} else {
						segments << PathSegment{.cubic_to, [c1x, c1y, c2x, c2y, x, y]}
						last_ctrl_x = c2x
						last_ctrl_y = c2y
						cur_x = x
						cur_y = y
					}
					last_cmd = cmd
				}
			}
			`Q`, `q` {
				relative := cmd == `q`
				for i + 3 < tokens.len && is_number_token(tokens[i]) {
					cx := tokens[i].f32()
					cy := tokens[i + 1].f32()
					x := tokens[i + 2].f32()
					y := tokens[i + 3].f32()
					i += 4

					if relative {
						segments << PathSegment{.quad_to, [
							cur_x + cx,
							cur_y + cy,
							cur_x + x,
							cur_y + y,
						]}
						last_ctrl_x = cur_x + cx
						last_ctrl_y = cur_y + cy
						cur_x += x
						cur_y += y
					} else {
						segments << PathSegment{.quad_to, [cx, cy, x, y]}
						last_ctrl_x = cx
						last_ctrl_y = cy
						cur_x = x
						cur_y = y
					}
				}
			}
			`T`, `t` {
				relative := cmd == `t`
				for i + 1 < tokens.len && is_number_token(tokens[i]) {
					// Reflect previous control point
					cx := if last_cmd == `Q` || last_cmd == `q` || last_cmd == `T`
						|| last_cmd == `t` {
						cur_x * 2 - last_ctrl_x
					} else {
						cur_x
					}
					cy := if last_cmd == `Q` || last_cmd == `q` || last_cmd == `T`
						|| last_cmd == `t` {
						cur_y * 2 - last_ctrl_y
					} else {
						cur_y
					}

					x := tokens[i].f32()
					y := tokens[i + 1].f32()
					i += 2

					if relative {
						segments << PathSegment{.quad_to, [cx, cy, cur_x + x, cur_y + y]}
						last_ctrl_x = cx
						last_ctrl_y = cy
						cur_x += x
						cur_y += y
					} else {
						segments << PathSegment{.quad_to, [cx, cy, x, y]}
						last_ctrl_x = cx
						last_ctrl_y = cy
						cur_x = x
						cur_y = y
					}
					last_cmd = cmd
				}
			}
			`A`, `a` {
				relative := cmd == `a`
				for i + 6 < tokens.len && is_number_token(tokens[i]) {
					rx := tokens[i].f32()
					ry := tokens[i + 1].f32()
					phi := tokens[i + 2].f32()
					large_arc := tokens[i + 3].f32() != 0
					sweep := tokens[i + 4].f32() != 0
					x := tokens[i + 5].f32()
					y := tokens[i + 6].f32()
					i += 7

					mut ex := x
					mut ey := y
					if relative {
						ex += cur_x
						ey += cur_y
					}

					arc_segs := arc_to_cubic(cur_x, cur_y, rx, ry, phi, large_arc, sweep,
						ex, ey)
					segments << arc_segs

					cur_x = ex
					cur_y = ey
				}
			}
			`Z`, `z` {
				segments << PathSegment{.close, []}
				cur_x = start_x
				cur_y = start_y
			}
			else {
				i++
			}
		}
		last_cmd = cmd
	}

	return segments
}

// tokenize_path splits path d string into tokens
fn tokenize_path(d string) []string {
	mut tokens := []string{}
	mut current := strings.new_builder(32)
	mut has_dot := false
	mut i := 0

	for i < d.len {
		c := d[i]

		if c == ` ` || c == `\t` || c == `\n` || c == `\r` || c == `,` {
			if current.len > 0 {
				tokens << current.str()
				current = strings.new_builder(32)
				has_dot = false
			}
			i++
			continue
		}

		// Command letters
		if (c >= `A` && c <= `Z`) || (c >= `a` && c <= `z`) {
			if current.len > 0 {
				tokens << current.str()
				current = strings.new_builder(32)
				has_dot = false
			}
			tokens << c.ascii_str()
			i++
			continue
		}

		// Numbers (including negative and decimal)
		if (c >= `0` && c <= `9`) || c == `-` || c == `+` || c == `.` {
			cur_str := current.str()
			cur_len := cur_str.len
			// Handle negative sign that's part of a number sequence
			if (c == `-` || c == `+`) && cur_len > 0 && cur_str[cur_len - 1] != `e`
				&& cur_str[cur_len - 1] != `E` {
				tokens << cur_str
				current = strings.new_builder(32)
				has_dot = false
			} else if cur_len > 0 {
				current.write_string(cur_str)
			}
			// Handle implicit separator for consecutive numbers like "1.5.5"
			if c == `.` && has_dot {
				tokens << current.str()
				current = strings.new_builder(32)
				has_dot = false
			}
			current.write_u8(c)
			if c == `.` {
				has_dot = true
			}
			i++
			continue
		}

		i++
	}

	if current.len > 0 {
		tokens << current.str()
	}

	return tokens
}

// is_number_token checks if a token looks like a number
fn is_number_token(s string) bool {
	if s.len == 0 {
		return false
	}
	c := s[0]
	return (c >= `0` && c <= `9`) || c == `-` || c == `+` || c == `.`
}

// parse_number_list parses a space/comma separated list of numbers
fn parse_number_list(s string) []f32 {
	tokens := tokenize_path(s)
	mut numbers := []f32{cap: tokens.len}
	for t in tokens {
		if is_number_token(t) {
			numbers << t.f32()
		}
	}
	return numbers
}
