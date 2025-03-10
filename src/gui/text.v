module gui

import gg
import gx

struct Text implements UI_Tree {
	id string
mut:
	padding  Padding
	sizing   Sizing
	spacing  f32
	text     string
	text_cfg gx.TextCfg
	wrap     bool
	children []UI_Tree
}

fn (t &Text) generate() ShapeTree {
	return ShapeTree{
		shape: Shape{
			type:     .text
			padding:  t.padding
			sizing:   t.sizing
			spacing:  t.spacing
			text:     t.text
			text_cfg: t.text_cfg
			lines:    [t.text]
			wrap:     t.wrap
		}
	}
}

struct TextConfig {
pub:
	id       string
	padding  Padding
	sizing   Sizing
	spacing  f32
	text     string
	text_cfg gx.TextCfg
	wrap     bool
}

fn text(c TextConfig) &Text {
	return &Text{
		id:       c.id
		padding:  c.padding
		sizing:   c.sizing
		spacing:  c.spacing
		text:     c.text
		text_cfg: c.text_cfg
		wrap:     c.wrap
	}
}

fn text_width(shape Shape, window Window) int {
	mut max_width := 0
	ctx := window.ui
	ctx.set_text_cfg(gx.TextCfg{})
	for line in shape.lines {
		width := ctx.text_width(line)
		max_width = int_max(width, max_width)
	}
	return max_width
}

fn text_height(shape Shape, window Window) int {
	ctx := window.ui
	lh := line_height(shape, ctx)
	return lh * shape.lines.len
}

fn line_height(shape Shape, ctx gg.Context) int {
	ctx.set_text_cfg(shape.text_cfg)
	return ctx.text_height('Q|W') + int(shape.spacing + f32(0.4999)) + 2
}
