module gui

import gg
import gx
import rand

// Text is an internal structure used to describe a text block
struct Text implements View {
	id       string
	focus_id int // >0 indicates text is focusable. Value indiciates tabbing order
mut:
	min_width   f32
	spacing     f32
	style       gx.TextCfg
	text        string
	wrap        bool
	keep_spaces bool
	children    []View
}

fn (t &Text) generate(ctx gg.Context) ShapeTree {
	sizing_width_type := if t.wrap { SizingType.flex } else { SizingType.fit }
	mut shape_tree := ShapeTree{
		shape: Shape{
			id:          t.id
			uid:         rand.uuid_v4()
			focus_id:    t.focus_id
			type:        .text
			spacing:     t.spacing
			text:        t.text
			text_cfg:    t.style
			lines:       [t.text]
			wrap:        t.wrap
			keep_spaces: t.keep_spaces
			sizing:      Sizing{sizing_width_type, .fit}
			min_width:   20
		}
	}
	shape_tree.shape.width = text_width(shape_tree.shape, ctx)
	shape_tree.shape.height = text_height(shape_tree.shape, ctx)
	return shape_tree
}

pub struct TextCfg {
pub:
	id          string
	focus_id    int
	min_width   f32
	spacing     f32
	style       gx.TextCfg
	text        string
	wrap        bool
	keep_spaces bool
}

// text renders text according to the TextCfg.
// Text wrapping is support fo multiple lines.
// Newlines are considered white-space are converted to spaces.
// Multple spaces are compressed to one space.
// The `spacing` parameter can be used to increase the space between lines.
pub fn text(cfg TextCfg) &Text {
	return &Text{
		id:          cfg.id
		focus_id:    cfg.focus_id
		min_width:   cfg.min_width
		spacing:     cfg.spacing
		style:       cfg.style
		text:        cfg.text
		wrap:        cfg.wrap
		keep_spaces: cfg.keep_spaces
	}
}

fn text_width(shape Shape, ctx gg.Context) int {
	ctx.set_text_cfg(shape.text_cfg)
	mut max_width := 0
	for line in shape.lines {
		width := ctx.text_width(line)
		max_width = int_max(width, max_width)
	}
	return max_width
}

fn text_height(shape Shape, ctx gg.Context) int {
	assert shape.type == .text
	lh := line_height(shape, ctx)
	return lh * shape.lines.len
}

fn line_height(shape Shape, ctx gg.Context) int {
	assert shape.type == .text
	ctx.set_text_cfg(shape.text_cfg)
	return ctx.text_height('Q|W') + int(shape.spacing + f32(0.4999)) + 2
}

fn text_wrap(mut shape Shape, ctx gg.Context) {
	if shape.type == .text && shape.wrap {
		ctx.set_text_cfg(shape.text_cfg)
		shape.lines = match shape.keep_spaces {
			true { text_wrap_text_keep_spaces(shape.text, shape.width, ctx) }
			else { text_wrap_text(shape.text, shape.width, ctx) }
		}

		shape.width = text_width(shape, ctx)
		lh := line_height(shape, ctx)
		shape.height = shape.lines.len * lh
	}
}

// text_wrap_text wraps lines to given width (logical units, not chars)
// Extra white space is compressed to on space including tabs and newlines.
pub fn text_wrap_text(s string, width f32, ctx gg.Context) []string {
	mut line := ''
	mut wrap := []string{cap: 5}
	for field in s.fields() {
		if line.len == 0 {
			line = field
			continue
		}
		nline := line + ' ' + field
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

// text_wrap_text_keep_spaces wraps lines to given width (logical units, not chars)
// White space is preserved
pub fn text_wrap_text_keep_spaces(s string, width f32, ctx gg.Context) []string {
	mut line := ''
	mut wrap := []string{cap: 5}
	for field in split_text(s) {
		if line.len == 0 {
			line = field
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

// split_text splits a string by spaces but also includes
// the spaces and separate strings
pub fn split_text(s string) []string {
	sr := s.runes()
	mut state := 0 // 1=space, 2=char
	mut fields := []string{}
	mut field := ''

	for r in sr {
		ss := r.str()
		if state == 0 {
			field += ss
			state = if ss == ' ' { 1 } else { 2 }
		} else if state == 1 { // space
			if ss[0].is_space() {
				field += ss
			} else {
				state = 2
				fields << field
				field = ss
			}
		} else if state == 2 { // char
			if ss[0].is_space() {
				state = 1
				fields << field
				field = ss
			} else {
				field += ss
			}
		}
	}
	fields << field
	return fields
}
