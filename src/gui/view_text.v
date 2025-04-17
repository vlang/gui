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
			type:                .text
			id:                  t.id
			id_focus:            t.id_focus
			cfg:                 &TextCfg{
				...t.cfg
			}
			clip:                t.clip
			disabled:            t.disabled
			min_width:           t.min_width
			sizing:              t.sizing
			text:                t.text
			text_keep_spaces:    t.keep_spaces
			text_lines:          [t.text]
			text_line_spacing:   t.line_spacing
			text_style:          t.text_style
			text_wrap:           t.wrap
			on_keydown_shape:    text_keydown_shape
			on_mouse_down_shape: text_mouse_down_shape
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
		sizing:       if cfg.wrap { fill_fit } else { fit_fit }
		disabled:     cfg.disabled
	}
}

fn text_mouse_down_shape(shape &Shape, e &Event, mut w Window) bool {
	if e.mouse_button == .left {
		ev := event_relative_to(shape, e)
		cursor_pos := text_mouse_cursor_pos(shape, ev, mut w)
		if w.is_focus(shape.id_focus) {
			w.input_state[w.id_focus] = InputState{
				...w.input_state[w.id_focus]
				cursor_pos: cursor_pos
			}
			return true
		}
		// text selection goes here?
	}
	return false
}

// mouse_cursor_pos determines where in the input control's text
// field the click occured. Works with multiple line text fields.
fn text_mouse_cursor_pos(shape &Shape, e &Event, mut w Window) int {
	lh := shape.text_style.size + shape.text_style.line_spacing
	y := int(e.mouse_y / lh)
	if y >= 0 && y < shape.text_lines.len {
		mut ln := ''
		for i, r in shape.text_lines[y].runes() {
			ln += r.str()
			tw := get_text_width(ln, shape.text_style, mut w)
			if tw >= e.mouse_x {
				mut count := 0
				for line in shape.text_lines[..y] {
					count += line.len
				}
				return count + i
			}
		}
	}
	return shape.text.len
}

fn text_keydown_shape(shape &Shape, e &Event, mut w Window) bool {
	if w.is_focus(shape.id_focus) {
		cfg := unsafe { &TextCfg(shape.cfg) }
		input_state := w.input_state[w.id_focus]
		mut cursor_pos := input_state.cursor_pos
		match e.key_code {
			.left { cursor_pos = int_max(0, cursor_pos - 1) }
			.right { cursor_pos = int_min(cfg.text.len, cursor_pos + 1) }
			.home { cursor_pos = 0 }
			.end { cursor_pos = cfg.text.len }
			else { return false }
		}
		w.input_state[w.id_focus] = InputState{
			...input_state
			cursor_pos: cursor_pos
		}
		return true
	}
	return false
}
