module gui

import math

// to_hsv converts an RGB Color to HSV components.
// Returns h (0-360), s (0-1), v (0-1).
pub fn (c Color) to_hsv() (f32, f32, f32) {
	r := f32(c.r) / 255.0
	g := f32(c.g) / 255.0
	b := f32(c.b) / 255.0

	max := f32_max(r, f32_max(g, b))
	min := f32_min(r, f32_min(g, b))
	delta := max - min

	mut h := f32(0)
	s := if max == 0 { f32(0) } else { delta / max }
	v := max

	if delta != 0 {
		if max == r {
			h = 60.0 * f32(math.fmod(f64((g - b) / delta), 6))
		} else if max == g {
			h = 60.0 * (((b - r) / delta) + 2.0)
		} else {
			h = 60.0 * (((r - g) / delta) + 4.0)
		}
	}
	if h < 0 {
		h += 360.0
	}
	return h, s, v
}

// color_from_hsv creates a Color from HSV values.
// h: 0-360, s: 0-1, v: 0-1. Alpha defaults to 255.
pub fn color_from_hsv(h f32, s f32, v f32) Color {
	return color_from_hsva(h, s, v, 255)
}

// color_from_hsva creates a Color from HSVA values.
// h: 0-360, s: 0-1, v: 0-1, a: 0-255.
pub fn color_from_hsva(h f32, s f32, v f32, a u8) Color {
	c := v * s
	hh := f32(math.fmod(f64(h) / 60.0, 6))
	x := c * (1.0 - f32(math.abs(f64(math.fmod(f64(hh), 2)) - 1.0)))
	m := v - c

	mut r := f32(0)
	mut g := f32(0)
	mut b := f32(0)

	if hh < 1 {
		r = c
		g = x
	} else if hh < 2 {
		r = x
		g = c
	} else if hh < 3 {
		g = c
		b = x
	} else if hh < 4 {
		g = x
		b = c
	} else if hh < 5 {
		r = x
		b = c
	} else {
		r = c
		b = x
	}

	return Color{
		r: u8((r + m) * 255.0)
		g: u8((g + m) * 255.0)
		b: u8((b + m) * 255.0)
		a: a
	}
}

// hue_color returns the pure color for a given hue (s=1, v=1).
pub fn hue_color(h f32) Color {
	return color_from_hsv(h, 1.0, 1.0)
}

// to_hex_string returns the color as a hex string like
// "#RRGGBB" or "#RRGGBBAA" when alpha is not 255.
pub fn (c Color) to_hex_string() string {
	if c.a == 255 {
		return '#${hex_byte(c.r)}${hex_byte(c.g)}${hex_byte(c.b)}'
	}
	return '#${hex_byte(c.r)}${hex_byte(c.g)}${hex_byte(c.b)}${hex_byte(c.a)}'
}

// hex_byte formats a u8 as a two-character uppercase hex string.
fn hex_byte(b u8) string {
	hi := '0123456789ABCDEF'[b >> 4]
	lo := '0123456789ABCDEF'[b & 0x0F]
	return '${rune(hi)}${rune(lo)}'
}

// color_from_hex_string parses a hex color string.
// Supports "#RRGGBB" (alpha=255) and "#RRGGBBAA".
// Returns none on invalid input.
pub fn color_from_hex_string(s string) ?Color {
	raw := if s.starts_with('#') { s[1..] } else { s }
	if raw.len != 6 && raw.len != 8 {
		return none
	}
	r := hex_pair(raw[0], raw[1]) or { return none }
	g := hex_pair(raw[2], raw[3]) or { return none }
	b := hex_pair(raw[4], raw[5]) or { return none }
	a := if raw.len == 8 {
		hex_pair(raw[6], raw[7]) or { return none }
	} else {
		u8(255)
	}
	return Color{
		r: r
		g: g
		b: b
		a: a
	}
}

// hex_pair converts two hex character bytes to a u8.
fn hex_pair(hi u8, lo u8) ?u8 {
	h := hex_nibble(hi) or { return none }
	l := hex_nibble(lo) or { return none }
	return (h << 4) | l
}

// hex_nibble converts a single hex character to its 4-bit value.
fn hex_nibble(c u8) ?u8 {
	if c >= `0` && c <= `9` {
		return u8(c - `0`)
	}
	if c >= `a` && c <= `f` {
		return u8(c - `a` + 10)
	}
	if c >= `A` && c <= `F` {
		return u8(c - `A` + 10)
	}
	return none
}
