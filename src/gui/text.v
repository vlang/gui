module gui

import gg
import gx

// Text is an internal structure used to describe a text block
struct Text implements View {
	id       string
	id_focus int // >0 indicates text is focusable. Value indiciates tabbing order
mut:
	min_width   f32
	spacing     f32
	style       gx.TextCfg
	text        string
	wrap        bool
	keep_spaces bool
	cfg         &TextCfg
	children    []View
}

fn (t &Text) generate(ctx gg.Context) ShapeTree {
	sizing_width_type := if t.wrap { SizingType.flex } else { SizingType.fixed }
	mut shape_tree := ShapeTree{
		shape: Shape{
			id:          t.id
			id_focus:    t.id_focus
			type:        .text
			spacing:     t.spacing
			text:        t.text
			text_cfg:    t.style
			lines:       [t.text]
			wrap:        t.wrap
			keep_spaces: t.keep_spaces
			sizing:      Sizing{sizing_width_type, .fit}
			min_width:   0
		}
	}
	shape_tree.shape.width = text_width(shape_tree.shape, ctx)
	shape_tree.shape.height = text_height(shape_tree.shape, ctx)
	if !t.wrap {
		shape_tree.shape.min_width = shape_tree.shape.width
		shape_tree.shape.min_height = shape_tree.shape.height
	}
	return shape_tree
}

pub struct TextCfg {
pub:
	id          string
	id_focus    int
	min_width   f32
	spacing     f32 = text_spacing_default
	style       gx.TextCfg
	text        string
	wrap        bool
	keep_spaces bool
}

// text renders text. Text wrapping is available. Multiple spaces are compressed
// to one space unless `keep_spaces` is true. The `spacing` parameter is used to
// increase the space between lines.
pub fn text(cfg TextCfg) &Text {
	return &Text{
		id:          cfg.id
		id_focus:    cfg.id_focus
		min_width:   cfg.min_width
		spacing:     cfg.spacing
		style:       cfg.style
		text:        cfg.text
		wrap:        cfg.wrap
		cfg:         &cfg
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
fn text_wrap_text(s string, width f32, ctx gg.Context) []string {
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

// text_wrap_text_keep_spaces wraps lines to given width (logical units, not
// chars) White space is preserved
fn text_wrap_text_keep_spaces(s string, width f32, ctx gg.Context) []string {
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

// split_text splits a string by spaces and also includes the spaces as separate
// strings
fn split_text(s string) []string {
	space := ' '
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
			} else {
				field += ch
			}
		}
	}
	fields << field
	return fields
}
