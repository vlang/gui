module gui

import gx

struct Text implements UI_Tree {
	id string
mut:
	padding  Padding
	sizing   Sizing
	text     string
	children []UI_Tree
}

fn (t &Text) generate() ShapeTree {
	return ShapeTree{
		shape: Shape{
			type:    .text
			padding: t.padding
			sizing:  t.sizing
			text:    t.text
		}
	}
}

struct TextConfig {
pub:
	id      string
	padding Padding
	sizing  Sizing = Sizing{.fixed, .fixed}
	text    string
}

fn text(c TextConfig) &Text {
	return &Text{
		id:      c.id
		padding: c.padding
		sizing:  c.sizing
		text:    c.text
	}
}

fn text_width(text string, window Window) int {
	ctx := window.ui
	ctx.set_text_cfg(gx.TextCfg{})
	return ctx.text_width(text)
}

fn text_height(text string, window Window) int {
	ctx := window.ui
	ctx.set_text_cfg(gx.TextCfg{})
	return ctx.text_height(text)
}
