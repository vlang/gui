module gui

import clipboard
import gg
import hash.fnv1a
import os

pub fn get_text_width(text string, text_style TextStyle, mut window Window) int {
	ctx := window.ui
	htx := fnv1a.sum32_struct(text_style).str()
	key := text + htx
	return window.text_widths[key] or {
		ctx.set_text_cfg(text_style.to_text_cfg())
		t_width := ctx.text_width(text)
		window.text_widths[key] = t_width
		t_width
	}
}

fn text_width(shape Shape, ctx &gg.Context) int {
	mut max_width := 0
	mut window := unsafe { &Window(ctx.user_data) }
	htx := fnv1a.sum32_struct(shape.text_style).str()
	text_cfg := shape.text_style.to_text_cfg()
	for line in shape.text_lines {
		key := line + htx
		width := window.text_widths[key] or {
			ctx.set_text_cfg(text_cfg)
			t_width := ctx.text_width(line)
			window.text_widths[key] = t_width
			t_width
		}
		max_width = int_max(width, max_width)
	}
	return max_width
}

fn text_height(shape Shape) int {
	lh := line_height(shape)
	return lh * shape.text_lines.len
}

fn line_height(shape Shape) int {
	return int(shape.text_style.size + shape.text_line_spacing)
}

fn text_wrap(mut shape Shape, ctx &gg.Context) {
	if shape.text_wrap && shape.type == .text {
		ctx.set_text_cfg(shape.text_style.to_text_cfg())
		shape.text_lines = match shape.text_keep_spaces {
			true { wrap_text_keep_spaces(shape.text, shape.width, ctx) }
			else { wrap_text_shrink_spaces(shape.text, shape.width, ctx) }
		}
		shape.width = text_width(shape, ctx)
		lh := line_height(shape)
		shape.height = shape.text_lines.len * lh
		shape.max_height = shape.height
		shape.min_height = shape.height
	}
}

// wrap_text_shrink_spaces wraps lines to given width (logical units, not chars)
// Extra white space is compressed.
fn wrap_text_shrink_spaces(s string, width f32, ctx &gg.Context) []string {
	mut line := ''
	mut wrap := []string{cap: 5}
	for field in split_text(s) {
		if field == '\n' {
			wrap << line
			line = ''
			continue
		}
		if field.trim_space().len == 0 {
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
fn wrap_text_keep_spaces(s string, width f32, ctx &gg.Context) []string {
	mut line := ''
	mut wrap := []string{cap: 5}
	for field in split_text(s) {
		if field == '\n' {
			wrap << line
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

const space = ' '

// split_text splits a string by spaces and also includes the spaces as separate
// strings. Newlines are separated from other white-space.
fn split_text(s string) []string {
	state_un := 0
	state_sp := 1
	state_ch := 2

	mut state := state_un
	mut fields := []string{}
	mut field := ''

	for r in s.runes() {
		ch := r.str()
		if state == state_un {
			field += ch
			state = if ch == space { state_sp } else { state_ch }
		} else if state == state_sp {
			if ch == space {
				field += ch
			} else {
				state = state_ch
				fields << field
				field = ch
			}
		} else if state == state_ch {
			if ch == space {
				state = state_sp
				fields << field
				field = ch
			} else if ch == '\n' {
				fields << field
				fields << '\n'
				field = ''
			} else if ch.is_blank() {
				// eat it
			} else {
				field += ch
			}
		}
	}
	fields << field
	return fields
}

// const zero_space = '\xe2\x80\x8b'

// @[inline]
// fn is_split_space(ch string) bool {
// 	return ch == space || ch == zero_space
// }

pub fn font_path_list() []string {
	mut font_root_path := ''
	$if windows {
		font_root_path = 'C:/windows/fonts'
	}
	$if macos {
		font_root_path = '/System/Library/Fonts/*'
	}
	$if linux {
		font_root_path = '/usr/share/fonts/truetype/*'
	}
	$if android {
		font_root_path = '/system/fonts/*'
	}
	font_paths := os.glob('${font_root_path}/*.ttf') or { panic(err) }
	return font_paths
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
