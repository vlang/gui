module gui

// parse_fill_url extracts gradient ID from fill="url(#id)".
// Returns the ID string or none if not a url() reference.
fn parse_fill_url(fill string) ?string {
	str := fill.trim_space()
	if !str.starts_with('url(') {
		return none
	}
	hash_pos := find_index(str, '#', 0) or { return none }
	end_pos := find_index(str, ')', hash_pos) or { return none }
	if end_pos > hash_pos + 1 {
		return str[hash_pos + 1..end_pos]
	}
	return none
}

// parse_svg_color converts SVG color strings to Color values.
// Returns color_inherit sentinel if string is empty (attribute not present).
// Sentinel values are used to implement CSS-style inheritance:
// - color_inherit (magenta): Attribute not specified, inherit from parent/group
// - color_transparent (alpha=0): Explicit 'none' value, don't render
// These sentinels are resolved during style application.
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
	// url() references handled by parse_fill_url; treat as
	// transparent here so fill_gradient_id takes precedence.
	if str.starts_with('url(') {
		return color_transparent
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
	r := clamp_byte(parts[0].trim_space().int())
	g := clamp_byte(parts[1].trim_space().int())
	b := clamp_byte(parts[2].trim_space().int())
	mut a := 255
	if parts.len >= 4 {
		alpha := parts[3].trim_space().f32()
		if alpha <= 1.0 {
			a = clamp_byte(int(alpha * 255))
		} else {
			a = clamp_byte(int(alpha))
		}
	}
	return Color{u8(r), u8(g), u8(b), u8(a)}
}

// parse_opacity_attr extracts an opacity value from element.
// Returns fallback if not specified. Clamps to 0.0..1.0.
fn parse_opacity_attr(elem string, name string, fallback f32) f32 {
	val := find_attr_or_style(elem, name) or { return fallback }
	o := val.f32()
	if o < 0 {
		return 0
	}
	if o > 1.0 {
		return 1.0
	}
	return o
}

// apply_opacity multiplies opacity into color alpha channel.
@[inline]
fn apply_opacity(c Color, opacity f32) Color {
	if opacity >= 1.0 {
		return c
	}
	return Color{c.r, c.g, c.b, u8(f32(c.a) * opacity)}
}
