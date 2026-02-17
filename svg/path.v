module svg

import strings

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

					// Validate arc radii - degenerate arcs become line segments
					if rx <= 0 || ry <= 0 {
						segments << PathSegment{.line_to, [ex, ey]}
					} else {
						arc_segs := arc_to_cubic(cur_x, cur_y, rx, ry, phi, large_arc,
							sweep, ex, ey)
						segments << arc_segs
					}

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

// tokenize_path splits path d string into tokens.
// max_tokens limits output size (0 = use max_path_segments).
fn tokenize_path(d string, max_tokens ...int) []string {
	limit := if max_tokens.len > 0 && max_tokens[0] > 0 {
		max_tokens[0]
	} else {
		max_path_segments
	}
	mut tokens := []string{}
	// Pre-allocate with estimated capacity
	mut current := strings.new_builder(d.len / 4)
	mut has_dot := false
	mut i := 0

	for i < d.len {
		if tokens.len >= limit {
			break
		}
		c := d[i]

		if c == ` ` || c == `\t` || c == `\n` || c == `\r` || c == `,` {
			if current.len > 0 {
				tokens << current.str()
				current.go_back_to(0) // Reuse instead of new allocation
				has_dot = false
			}
			i++
			continue
		}

		// Command letters (but not 'e'/'E' inside a number for exponents)
		if (c >= `A` && c <= `Z`) || (c >= `a` && c <= `z`) {
			if (c == `e` || c == `E`) && current.len > 0 {
				// Part of scientific notation (e.g. 1e-5)
				current.write_u8(c)
				i++
				continue
			}
			if current.len > 0 {
				tokens << current.str()
				current.go_back_to(0) // Reuse instead of new allocation
				has_dot = false
			}
			tokens << c.ascii_str()
			i++
			continue
		}

		// Numbers (including negative and decimal)
		if (c >= `0` && c <= `9`) || c == `-` || c == `+` || c == `.` {
			// Handle negative sign that starts a new number
			if (c == `-` || c == `+`) && current.len > 0 {
				// Check last byte without consuming via .str()
				last := current.byte_at(current.len - 1)
				if last != `e` && last != `E` {
					tokens << current.str()
					current.go_back_to(0)
					has_dot = false
				}
			}
			// Handle implicit separator for consecutive numbers like "1.5.5"
			if c == `.` && has_dot {
				tokens << current.str()
				current.go_back_to(0)
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
