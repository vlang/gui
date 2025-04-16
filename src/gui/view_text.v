module gui

import gg

// Text is an internal structure used to describe a text block
@[heap]
struct Text implements View {
	id       string
	id_focus u32 // >0 indicates text is focusable. Value indiciates tabbing order
mut:
	clip         bool
	invisible    bool
	disabled     bool
	keep_spaces  bool
	min_width    f32
	text         string
	text_style   TextStyle
	sizing       Sizing
	line_spacing f32
	wrap         bool
	cfg          TextCfg
	content      []View
}

fn (t Text) generate(ctx &gg.Context) Layout {
	if t.invisible {
		return Layout{}
	}
	mut shape_tree := Layout{
		shape: Shape{
			type:              .text
			id:                t.id
			id_focus:          t.id_focus
			clip:              t.clip
			disabled:          t.disabled
			min_width:         t.min_width
			sizing:            t.sizing
			text:              t.text
			text_keep_spaces:  t.keep_spaces
			text_lines:        [t.text]
			text_line_spacing: t.line_spacing
			text_style:        t.text_style
			text_wrap:         t.wrap
		}
	}
	shape_tree.shape.width = text_width(shape_tree.shape, ctx)
	shape_tree.shape.height = text_height(shape_tree.shape, ctx)
	if !t.wrap || shape_tree.shape.sizing.width == .fixed {
		shape_tree.shape.min_width = f32_max(shape_tree.shape.width, shape_tree.shape.min_width)
		shape_tree.shape.width = shape_tree.shape.min_width
	}
	if !t.wrap || shape_tree.shape.sizing.height == .fixed {
		shape_tree.shape.min_height = f32_max(shape_tree.shape.height, shape_tree.shape.min_height)
		shape_tree.shape.height = shape_tree.shape.height
	}
	return shape_tree
}

pub struct TextCfg {
pub:
	id           string
	id_focus     u32
	clip         bool
	disabled     bool
	invisible    bool
	keep_spaces  bool
	min_width    f32
	line_spacing f32 = gui_theme.text_style.line_spacing
	text         string
	text_style   TextStyle = gui_theme.text_style
	wrap         bool
}

// text renders text. Text wrapping is available. Multiple spaces are compressed
// to one space unless `keep_spaces` is true. The `spacing` parameter is used to
// increase the space between lines. Scrolling is supported.
pub fn text(cfg TextCfg) Text {
	return Text{
		id:           cfg.id
		id_focus:     cfg.id_focus
		clip:         cfg.clip
		invisible:    cfg.invisible
		keep_spaces:  cfg.keep_spaces
		min_width:    cfg.min_width
		line_spacing: cfg.line_spacing
		text:         cfg.text
		text_style:   cfg.text_style
		wrap:         cfg.wrap
		cfg:          &cfg
		sizing:       if cfg.wrap {
			fill_fit
		} else {
			fit_fit
		}
		disabled:     cfg.disabled
	}
}
