module gui

import os

// parse_svg parses an SVG string and returns a VectorGraphic.
pub fn parse_svg(content string) !VectorGraphic {
	mut vg := VectorGraphic{
		width:  24 // default icon size
		height: 24
	}

	// Parse viewBox
	if vb := find_attr(content, 'viewBox') {
		parts := vb.split_any(' ,')
		if parts.len >= 4 {
			vg.width = parts[2].f32()
			vg.height = parts[3].f32()
		}
	} else {
		// Try width/height attributes
		if w := find_attr(content, 'width') {
			vg.width = parse_length(w)
		}
		if h := find_attr(content, 'height') {
			vg.height = parse_length(h)
		}
	}

	// Parse paths
	vg.paths << parse_elements(content, '<path', parse_path_element)
	vg.paths << parse_elements(content, '<rect', parse_rect_element)
	vg.paths << parse_elements(content, '<circle', parse_circle_element)
	vg.paths << parse_elements(content, '<ellipse', parse_ellipse_element)
	vg.paths << parse_elements(content, '<polygon', fn (elem string) ?VectorPath {
		return parse_polygon_element(elem, true)
	})
	vg.paths << parse_elements(content, '<polyline', fn (elem string) ?VectorPath {
		return parse_polygon_element(elem, false)
	})
	vg.paths << parse_elements(content, '<line', parse_line_element)

	return vg
}

// parse_elements finds all elements of a given tag and parses them
fn parse_elements(content string, tag string, parser fn (string) ?VectorPath) []VectorPath {
	mut paths := []VectorPath{}
	mut pos := 0

	for {
		start := find_index(content, tag, pos) or { break }
		end := find_index(content, '>', start) or { break }
		elem := content[start..end + 1]
		if p := parser(elem) {
			paths << p
		}
		pos = end + 1
	}

	return paths
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

// find_attr extracts an attribute value from an element string
fn find_attr(elem string, name string) ?string {
	// Try double quotes
	pattern := '${name}="'
	mut start := find_index(elem, pattern, 0) or { -1 }
	if start >= 0 {
		start += pattern.len
		end := find_index(elem, '"', start) or { return none }
		if end > start {
			return elem[start..end]
		}
	}
	// Try single quotes
	pattern2 := "${name}='"
	start = find_index(elem, pattern2, 0) or { return none }
	start += pattern2.len
	end := find_index(elem, "'", start) or { return none }
	if end > start {
		return elem[start..end]
	}
	return none
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
		fill_color: parse_svg_color(fill)
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
		segments:   segments
		fill_color: parse_svg_color(fill)
	}
}

// parse_circle_element converts <circle> to path
fn parse_circle_element(elem string) ?VectorPath {
	cx := (find_attr(elem, 'cx') or { '0' }).f32()
	cy := (find_attr(elem, 'cy') or { '0' }).f32()
	r := (find_attr(elem, 'r') or { return none }).f32()
	fill := find_attr(elem, 'fill') or { '' }

	return ellipse_to_path(cx, cy, r, r, fill)
}

// parse_ellipse_element converts <ellipse> to path
fn parse_ellipse_element(elem string) ?VectorPath {
	cx := (find_attr(elem, 'cx') or { '0' }).f32()
	cy := (find_attr(elem, 'cy') or { '0' }).f32()
	rx := (find_attr(elem, 'rx') or { return none }).f32()
	ry := (find_attr(elem, 'ry') or { return none }).f32()
	fill := find_attr(elem, 'fill') or { '' }

	return ellipse_to_path(cx, cy, rx, ry, fill)
}

// ellipse_to_path converts an ellipse to a path using 4 cubic beziers
fn ellipse_to_path(cx f32, cy f32, rx f32, ry f32, fill string) VectorPath {
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
		segments:   segments
		fill_color: parse_svg_color(fill)
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
		segments:   segments
		fill_color: parse_svg_color(fill)
	}
}

// parse_line_element converts <line> to path
fn parse_line_element(elem string) ?VectorPath {
	x1 := (find_attr(elem, 'x1') or { '0' }).f32()
	y1 := (find_attr(elem, 'y1') or { '0' }).f32()
	x2 := (find_attr(elem, 'x2') or { '0' }).f32()
	y2 := (find_attr(elem, 'y2') or { '0' }).f32()

	return VectorPath{
		segments:   [
			PathSegment{.move_to, [x1, y1]},
			PathSegment{.line_to, [x2, y2]},
		]
		fill_color: color_transparent
	}
}

// parse_svg_color parses SVG color values
fn parse_svg_color(s string) Color {
	str := s.trim_space()
	if str.len == 0 {
		return black // default fill is black per SVG spec
	}
	if str == 'none' {
		return color_transparent
	}
	if str == 'currentColor' {
		return black
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

	for i < tokens.len {
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
	mut current := ''
	mut i := 0

	for i < d.len {
		c := d[i]

		if c == ` ` || c == `\t` || c == `\n` || c == `\r` || c == `,` {
			if current.len > 0 {
				tokens << current
				current = ''
			}
			i++
			continue
		}

		// Command letters
		if (c >= `A` && c <= `Z`) || (c >= `a` && c <= `z`) {
			if current.len > 0 {
				tokens << current
				current = ''
			}
			tokens << c.ascii_str()
			i++
			continue
		}

		// Numbers (including negative and decimal)
		if (c >= `0` && c <= `9`) || c == `-` || c == `+` || c == `.` {
			// Handle negative sign that's part of a number sequence
			if (c == `-` || c == `+`) && current.len > 0 && current[current.len - 1] != `e`
				&& current[current.len - 1] != `E` {
				tokens << current
				current = ''
			}
			// Handle implicit separator for consecutive numbers like "1.5.5"
			if c == `.` && current.contains('.') {
				tokens << current
				current = ''
			}
			current += c.ascii_str()
			i++
			continue
		}

		i++
	}

	if current.len > 0 {
		tokens << current
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
