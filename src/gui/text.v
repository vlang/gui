module gui

import gg
import gx
import rand

// Text is an internal structure used to describe a text block
struct Text implements UI_Tree {
	id string
mut:
	spacing   f32
	text      string
	text_cfg  gx.TextCfg
	wrap      bool
	min_width f32
	children  []UI_Tree
}

fn (t &Text) generate(ctx gg.Context) ShapeTree {
	sizing_width_type := if t.wrap { SizingType.flex } else { SizingType.fixed }
	mut shape_tree := ShapeTree{
		shape: Shape{
			id:        t.id
			uid:       rand.uuid_v4()
			type:      .text
			spacing:   t.spacing
			text:      t.text
			text_cfg:  t.text_cfg
			lines:     [t.text]
			wrap:      t.wrap
			sizing:    Sizing{sizing_width_type, .fit}
			min_width: 20
		}
	}
	shape_tree.shape.width = text_width(shape_tree.shape, ctx)
	shape_tree.shape.height = text_height(shape_tree.shape, ctx)
	return shape_tree
}

struct TextConfig {
pub:
	id        string
	spacing   f32
	text      string
	text_cfg  gx.TextCfg
	wrap      bool
	min_width f32
}

fn text(c TextConfig) &Text {
	return &Text{
		id:        c.id
		spacing:   c.spacing
		text:      c.text
		text_cfg:  c.text_cfg
		wrap:      c.wrap
		min_width: c.min_width
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
		shape.lines = text_wrap_text(shape.text, shape.width, ctx)
		shape.width = text_width(shape, ctx)
		lh := line_height(shape, ctx)
		shape.height = shape.lines.len * lh
	}
}

pub fn text_wrap_text(s string, width f32, ctx gg.Context) []string {
	mut line := ''
	mut wrap := []string{cap: 5}
	for field in s.fields() {
		if line == '' {
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
