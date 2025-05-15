module gui

import clipboard
import encoding.utf8
import gg
import hash.fnv1a

pub fn get_text_width(text string, text_style TextStyle, mut window Window) f32 {
	htx := fnv1a.sum32_struct(text_style).str()
	key := text + htx
	return window.view_state.text_widths[key] or {
		window.ui.set_text_cfg(text_style.to_text_cfg())
		t_width := window.ui.text_width(text)
		window.view_state.text_widths[key] = t_width
		t_width
	}
}

fn text_width(shape Shape, mut window Window) f32 {
	mut max_width := f32(0)
	mut text_cfg_set := false
	htx := fnv1a.sum32_struct(shape.text_style).str()
	for line in shape.text_lines {
		key := line + htx
		width := window.view_state.text_widths[key] or {
			if !text_cfg_set {
				text_cfg := shape.text_style.to_text_cfg()
				window.ui.set_text_cfg(text_cfg)
				text_cfg_set = true
			}
			t_width := window.ui.text_width(line)
			window.view_state.text_widths[key] = t_width
			t_width
		}
		max_width = f32_max(width, max_width)
	}
	return max_width
}

fn text_height(shape Shape) f32 {
	lh := line_height(shape)
	return lh * shape.text_lines.len
}

@[inline]
fn line_height(shape Shape) f32 {
	return shape.text_style.size + shape.text_style.line_spacing
}

fn text_wrap(mut shape Shape, mut window Window) {
	if shape.text_mode in [.wrap, .wrap_keep_spaces] && shape.type == .text {
		window.ui.set_text_cfg(shape.text_style.to_text_cfg())
		width := shape.width - shape.padding.width()
		shape.text_lines = match shape.text_mode == .wrap_keep_spaces {
			true { wrap_text_keep_spaces(shape.text, width, shape.text_tab_size, window.ui) }
			else { wrap_text_shrink_spaces(shape.text, width, shape.text_tab_size, window.ui) }
		}
		lh := line_height(shape)
		shape.height = shape.text_lines.len * lh
		shape.max_height = shape.height
		shape.min_height = shape.height
	}
}

// wrap_text_shrink_spaces wraps lines to given width (logical units, not chars)
// Extra white space is compressed.
fn wrap_text_shrink_spaces(s string, width f32, tab_size u32, ctx &gg.Context) []string {
	mut line := ''
	mut wrap := []string{cap: 5}
	for field in split_text(s, tab_size) {
		if field == '\n' {
			wrap << line + '\n'
			line = ''
			continue
		}
		if field.is_blank() {
			continue
		}
		if line.len == 0 {
			line = field
			continue
		}
		nline := line + ' ' + field
		t_width := ctx.text_width(nline)
		if t_width > width {
			wrap << line
			line = field.trim_space()
		} else {
			line = nline
		}
	}
	wrap << line
	return wrap
}

// wrap_text_keep_spaces wraps lines to given width (logical units, not
// chars) White space is preserved
fn wrap_text_keep_spaces(s string, width f32, tab_size u32, ctx &gg.Context) []string {
	mut line := ''
	mut wrap := []string{cap: 5}
	for field in split_text(s, tab_size) {
		if field == '\n' {
			wrap << line + '\n'
			line = ''
			continue
		}
		nline := line + field
		t_width := ctx.text_width(nline)
		if t_width > width {
			wrap << line
			line = field
		} else {
			line = nline
		}
	}
	wrap << line
	return wrap
}

// wrap_simple wraps only at new lines
fn wrap_simple(s string, tab_size u32) []string {
	mut line := ''
	mut lines := []string{}

	for field in split_text(s, tab_size) {
		if field == '\n' {
			lines << line + '\n'
			line = ''
			continue
		}
		line += field
	}
	lines << line
	return lines
}

const r_space = ` `

// split_text splits a string by spaces with spaces as separate
// strings. Newlines are separate strings from spaces.
fn split_text(s string, tab_size u32) []string {
	state_ch := 0
	state_sp := 1

	mut state := state_ch
	mut fields := []string{}
	mut field := []rune{}

	for r in s.runes() {
		if state == state_ch {
			if r == r_space {
				if field.len > 0 {
					fields << field.string()
				}
				field = [r]
				state = state_sp
			} else if r == `\n` {
				if field.len > 0 {
					fields << field.string()
				}
				fields << '\n'
				field.clear()
			} else if r == `\r` {
				// eat it
			} else if r == `\t` {
				if field.len > 0 {
					fields << field.string()
				}
				mut spaces := int(tab_size) - field.len % int(tab_size)
				spaces = if spaces == 0 { int(tab_size) } else { spaces }
				fields << []rune{len: spaces, init: r_space}.string()
				field.clear()
				state = state_sp
			} else if utf8.is_space(r) {
				if field.len > 0 {
					fields << field.string()
				}
				field = [r_space]
				state = state_sp
			} else {
				field << r
			}
		} else { // state == state_sp
			if r == r_space {
				field << r
			} else if r == `\n` {
				if field.len > 0 {
					fields << field.string()
				}
				fields << '\n'
				field = []
			} else if r == `\r` {
				// eat it
			} else if r == `\t` {
				mut spaces := int(tab_size) - field.len % int(tab_size)
				spaces = if spaces == 0 { int(tab_size) } else { spaces }
				field << []rune{len: spaces, init: r_space}
			} else if utf8.is_space(r) {
				field << r_space
			} else {
				fields << field.string()
				field = [r]
				state = state_ch
			}
		}
	}
	fields << field.string()
	return fields
}

pub fn from_clipboard() string {
	mut cb := clipboard.new()
	defer { cb.free() }
	return cb.paste()
}

pub fn to_clipboard(s ?string) bool {
	if s != none {
		mut cb := clipboard.new()
		defer { cb.free() }
		return cb.copy(s)
	}
	return false
}
