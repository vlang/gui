module gui

import gg
import gx

// Text is an internal structure used to describe a text block
@[heap]
struct Text implements View {
	id       string
	id_focus u32 // >0 indicates text is focusable. Value indiciates tabbing order
mut:
	min_width   f32
	spacing     f32
	text_cfg    gx.TextCfg
	text        string
	wrap        bool
	keep_spaces bool
	sizing      Sizing
	disabled    bool
	clip        bool
	cfg         TextCfg
	content     []View
	on_click    fn (&TextCfg, &gg.Event, &Window) bool = text_click_handler
}

fn (t Text) generate(ctx &gg.Context) Layout {
	mut shape_tree := Layout{
		shape: Shape{
			id:          t.id
			id_focus:    t.id_focus
			type:        .text
			spacing:     t.spacing
			text:        t.text
			text_cfg:    t.text_cfg
			lines:       [t.text]
			wrap:        t.wrap
			keep_spaces: t.keep_spaces
			sizing:      t.sizing
			disabled:    t.disabled
			min_width:   t.min_width
			clip:        t.clip
			on_click:    t.on_click
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
	id          string
	id_focus    u32
	min_width   f32
	spacing     f32        = gui_theme.text_style.spacing
	text_cfg    gx.TextCfg = gui_theme.text_style.text_cfg
	text        string
	wrap        bool
	keep_spaces bool
	disabled    bool
	clip        bool
}

// text renders text. Text wrapping is available. Multiple spaces are compressed
// to one space unless `keep_spaces` is true. The `spacing` parameter is used to
// increase the space between lines. Scrolling is supported.
pub fn text(cfg TextCfg) Text {
	return Text{
		id:          cfg.id
		id_focus:    cfg.id_focus
		min_width:   cfg.min_width
		spacing:     cfg.spacing
		text_cfg:    cfg.text_cfg
		text:        cfg.text
		wrap:        cfg.wrap
		cfg:         &cfg
		keep_spaces: cfg.keep_spaces
		sizing:      if cfg.wrap {
			fill_fit
		} else {
			fit_fit
		}
		disabled:    cfg.disabled
	}
}

// should be mouse down handler.
fn text_click_handler(cfg &TextCfg, e &gg.Event, w &Window) bool {
	println('${e.mouse_x}, ${e.mouse_y}')
	return false
}
