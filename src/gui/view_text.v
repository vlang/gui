module gui

import gg
import math

// Text is an internal structure used to describe a text block
@[heap]
struct Text implements View {
	id                 string
	id_focus           u32 // >0 indicates text is focusable. Value indiciates tabbing order
	is_password        bool
	placeholder_active bool
	clip               bool
	invisible          bool
	disabled           bool
	keep_spaces        bool
	min_width          f32
	text               string
	text_style         TextStyle
	sizing             Sizing
	line_spacing       f32
	wrap               bool
	cfg                TextCfg
mut:
	content []View
}

fn (t &Text) generate(ctx &gg.Context) Layout {
	if t.invisible {
		return Layout{}
	}
	window := unsafe { &Window(ctx.user_data) }
	input_state := match window.is_focus(t.id_focus) {
		true { window.input_state[t.id_focus] }
		else { InputState{} }
	}
	mut shape_tree := Layout{
		shape: Shape{
			type:                .text
			id:                  t.id
			id_focus:            t.id_focus
			cfg:                 &t.cfg
			clip:                t.clip
			disabled:            t.disabled
			min_width:           t.min_width
			sizing:              t.sizing
			text:                t.text
			text_keep_spaces:    t.keep_spaces
			text_is_password:    t.is_password
			text_lines:          [t.text]
			text_line_spacing:   t.line_spacing
			text_style:          t.text_style
			text_wrap:           t.wrap
			text_sel_beg:        input_state.select_beg
			text_sel_end:        input_state.select_end
			on_char_shape:       t.char_shape
			on_keydown_shape:    t.keydown_shape
			on_mouse_down_shape: t.mouse_down_shape
			on_mouse_move_shape: t.mouse_move_shape
		}
	}
	shape_tree.shape.width = text_width(shape_tree.shape, ctx)
	shape_tree.shape.height = text_height(shape_tree.shape)
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

@[heap]
pub struct TextCfg {
	is_password        bool
	placeholder_active bool
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

// text is a general purpose text renderer. Use it for labels or larger
// blocks of multiline text. Giving it an id_focus allows mark and copy
// operations.
// - wrap enables wrapping and multiline operations.
// - Multiple spaces are compressed to one space unless `keep_spaces` is true.
// - `spacing` parameter is used to increase the space between lines.
pub fn text(cfg &TextCfg) Text {
	return Text{
		id:                 cfg.id
		id_focus:           cfg.id_focus
		clip:               cfg.clip
		invisible:          cfg.invisible
		keep_spaces:        cfg.keep_spaces
		min_width:          cfg.min_width
		line_spacing:       cfg.line_spacing
		text:               cfg.text
		text_style:         cfg.text_style
		wrap:               cfg.wrap
		cfg:                cfg
		sizing:             if cfg.wrap { fill_fit } else { fit_fit }
		disabled:           cfg.disabled
		placeholder_active: cfg.placeholder_active
		is_password:        cfg.is_password
	}
}

fn (text &Text) mouse_down_shape(shape &Shape, mut e Event, mut w Window) {
	if w.is_focus(shape.id_focus) {
		w.set_mouse_cursor_ibeam()
	}
	if e.mouse_button == .left && w.is_focus(shape.id_focus) {
		ev := event_relative_to(shape, e)
		cursor_pos := text.mouse_cursor_pos(shape, ev, mut w)
		input_state := w.input_state[shape.id_focus]
		w.input_state[shape.id_focus] = InputState{
			...input_state
			cursor_pos: cursor_pos
			select_beg: 0
			select_end: 0
		}
		e.is_handled = true
	}
}

fn (text &Text) mouse_move_shape(shape &Shape, mut e Event, mut w Window) {
	if w.is_focus(shape.id_focus) {
		w.set_mouse_cursor_ibeam()
	}
	// mouse move events don't have mouse button info. Use context.
	if w.ui.mouse_buttons == .left && w.is_focus(shape.id_focus) {
		if text.placeholder_active {
			return
		}
		ev := event_relative_to(shape, e)
		end := u32(text.mouse_cursor_pos(shape, ev, mut w))
		input_state := w.input_state[shape.id_focus]
		cursor_pos := u32(input_state.cursor_pos)
		w.input_state[shape.id_focus] = InputState{
			...input_state
			select_beg: if cursor_pos < end { cursor_pos } else { end }
			select_end: if cursor_pos < end { end } else { cursor_pos }
		}
		e.is_handled = true
	}
}

// mouse_cursor_pos determines where in the input control's text
// field the click occured. Works with multiple line text fields.
fn (text &Text) mouse_cursor_pos(shape &Shape, e &Event, mut w Window) int {
	if text.placeholder_active {
		return 0
	}
	lh := shape.text_style.size + shape.text_style.line_spacing
	y := int(e.mouse_y / lh)
	line := shape.text_lines[y]
	mut ln := ''
	mut count := -1
	for i, r in line.runes() {
		ln += r.str()
		tw := get_text_width(ln, shape.text_style, mut w)
		if tw > e.mouse_x {
			// One past to position just cursor after char
			// Appears to be how others do it (e.g. browsers)
			count = if e.mouse_x < 5 { 0 } else { i + 1 }
			break
		}
	}
	if count == -1 {
		count = int_max(0, line.runes().len)
	}
	count = int_min(count, line.runes().len)
	for i, l in shape.text_lines {
		if i < y {
			count += l.runes().len
		}
	}
	return count
}

fn (text &Text) keydown_shape(shape &Shape, mut e Event, mut w Window) {
	if w.is_focus(shape.id_focus) {
		if text.placeholder_active {
			return
		}
		cfg := unsafe { &TextCfg(shape.cfg) }
		input_state := w.input_state[shape.id_focus]
		mut cursor_pos := input_state.cursor_pos
		match e.key_code {
			.left { cursor_pos = int_max(0, cursor_pos - 1) }
			.right { cursor_pos = int_min(cfg.text.len, cursor_pos + 1) }
			.home { cursor_pos = 0 }
			.end { cursor_pos = cfg.text.len }
			else { return }
		}
		e.is_handled = true
		w.input_state[shape.id_focus] = InputState{
			...input_state
			cursor_pos: cursor_pos
			select_beg: 0
			select_end: 0
		}
		// Extend/shrink selection
		if e.modifiers == u32(Modifier.shift) {
			old_pos := input_state.cursor_pos
			mut beg := input_state.select_beg
			mut end := input_state.select_end
			b_diff := math.abs(cursor_pos - int(beg))
			e_diff := math.abs(cursor_pos - int(end))
			if beg == end {
				if old_pos < cursor_pos {
					beg = u32(old_pos)
					end = u32(cursor_pos)
				} else {
					beg = u32(cursor_pos)
					end = u32(old_pos)
				}
			} else if b_diff < e_diff {
				beg = u32(cursor_pos)
			} else {
				end = u32(cursor_pos)
			}
			if beg > end {
				beg, end = end, beg
			}
			w.input_state[shape.id_focus] = InputState{
				...input_state
				cursor_pos: cursor_pos
				select_beg: beg
				select_end: end
			}
			e.is_handled = true
		}
	}
}

fn (text &Text) char_shape(shape &Shape, mut event Event, mut w Window) {
	if w.is_focus(shape.id_focus) {
		c := event.char_code
		if event.modifiers & u32(Modifier.ctrl) > 0 {
			match c {
				ctrl_a { text.select_all(shape, mut w) }
				ctrl_c { text.copy(shape, w) }
				else {}
			}
		} else if event.modifiers & u32(Modifier.super) > 0 {
			match c {
				cmd_a { text.select_all(shape, mut w) }
				cmd_c { text.copy(shape, w) }
				else {}
			}
		} else {
			match c {
				escape_char { text.unselect_all(mut w) }
				else {}
			}
		}
	}
}

fn (text &Text) copy(shape &Shape, w &Window) ?string {
	if text.placeholder_active || text.is_password {
		return none
	}
	input_state := w.input_state[text.id_focus]
	if input_state.select_beg != input_state.select_end {
		cpy := match shape.text_keep_spaces {
			true {
				shape.text.runes()[input_state.select_beg..input_state.select_end]
			}
			else {
				mut count := 0
				mut buffer := []rune{cap: 100}
				beg := int(input_state.select_beg)
				end := int(input_state.select_end)
				for line in shape.text_lines {
					if count >= end {
						break
					}
					if count > beg {
						buffer << ` `
					}
					for r in line.runes() {
						if count >= end {
							break
						}
						if count >= beg {
							buffer << r
						}
						count += 1
					}
				}
				buffer
			}
		}
		to_clipboard(cpy.string())
	}
	return none
}

pub fn (text &Text) select_all(shape &Shape, mut w Window) {
	if text.placeholder_active {
		return
	}
	input_state := w.input_state[text.id_focus]
	w.input_state[text.id_focus] = InputState{
		...input_state
		cursor_pos: text.text.len
		select_beg: 0
		select_end: u32(text.text.len)
	}
}

pub fn (text &Text) unselect_all(mut w Window) {
	input_state := w.input_state[text.id_focus]
	w.input_state[text.id_focus] = InputState{
		...input_state
		cursor_pos: 0
		select_beg: 0
		select_end: 0
	}
}
