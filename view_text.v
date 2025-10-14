module gui

import math

// TextMode controls how a text view renders text.
pub enum TextMode as u8 {
	single_line      // one line only. Restricts typing to visible range
	multiline        // wraps `\n`s only
	wrap             // wrap at word breaks and `\n`s. White space is collapsed
	wrap_keep_spaces // wrap at works breaks and `\m`s, Keep white space
}

// Text is an internal structure used to describe a text view
// Members are arranged for packing to reduce memory footprint.
struct TextView implements View {
	cfg    &TextCfg
	sizing Sizing
mut:
	content []View // not used
}

fn (t &TextView) generate(mut window Window) Layout {
	$if !prod {
		gui_stats.increment_layouts()
	}
	if t.cfg.invisible {
		return Layout{}
	}
	input_state := match window.is_focus(t.cfg.id_focus) {
		true { window.view_state.input_state[t.cfg.id_focus] }
		else { InputState{} }
	}
	lines := match t.cfg.mode == .multiline {
		true { wrap_simple(t.cfg.text, t.cfg.tab_size) }
		else { [t.cfg.text] } // dynamic wrapping handled in the layout pipeline
	}
	mut layout := Layout{
		shape: &Shape{
			name:                'text'
			type:                .text
			id_focus:            t.cfg.id_focus
			cfg:                 &t.cfg
			clip:                t.cfg.clip
			focus_skip:          t.cfg.focus_skip
			disabled:            t.cfg.disabled
			min_width:           t.cfg.min_width
			sizing:              t.sizing
			text:                t.cfg.text
			text_is_password:    t.cfg.is_password
			text_is_placeholder: t.cfg.placeholder_active
			text_lines:          lines
			text_mode:           t.cfg.mode
			text_style:          &t.cfg.text_style
			text_sel_beg:        input_state.select_beg
			text_sel_end:        input_state.select_end
			text_tab_size:       t.cfg.tab_size
			on_char_shape:       t.cfg.char_shape
			on_keydown_shape:    t.cfg.keydown_shape
			on_mouse_down_shape: t.cfg.mouse_down_shape
			on_mouse_move_shape: t.cfg.mouse_move_shape
			on_mouse_up_shape:   t.cfg.mouse_up_shape
		}
	}
	layout.shape.width = text_width(layout.shape, mut window)
	layout.shape.height = text_height(layout.shape)
	if t.cfg.mode == .single_line || layout.shape.sizing.width == .fixed {
		layout.shape.min_width = f32_max(layout.shape.width, layout.shape.min_width)
		layout.shape.width = layout.shape.min_width
	}
	if t.cfg.mode == .single_line || layout.shape.sizing.height == .fixed {
		layout.shape.min_height = f32_max(layout.shape.height, layout.shape.min_height)
		layout.shape.height = layout.shape.height
	}
	return layout
}

// TextCfg configures a [text](#text) view
// - [TextMode](#TextMode) controls how text is wrapped.
@[heap]
pub struct TextCfg {
pub:
	text               string
	text_style         TextStyle = gui_theme.text_style
	id_focus           u32
	tab_size           u32 = 4
	min_width          f32
	mode               TextMode
	invisible          bool
	clip               bool
	focus_skip         bool = true
	disabled           bool
	is_password        bool
	placeholder_active bool
}

fn (cfg &TextCfg) free() {
	unsafe {
		cfg.text.free()
		cfg.text_style.free()
	}
}

// text is a general purpose text renderer. Use it for labels or larger
// blocks of multiline text. Giving it an id_focus allows mark and copy
// operations. See [TextCfg](#TextCfg)
pub fn text(cfg TextCfg) View {
	$if !prod {
		gui_stats.increment_text_views()
	}
	return TextView{
		cfg:    &cfg
		sizing: if cfg.mode in [.wrap, .wrap_keep_spaces] { fill_fit } else { fit_fit }
	}
}

fn (cfg &TextCfg) mouse_down_shape(shape &Shape, mut e Event, mut w Window) {
	if w.is_focus(shape.id_focus) {
		w.set_mouse_cursor_ibeam()
	}
	if e.mouse_button == .left && w.is_focus(shape.id_focus) {
		ev := event_relative_to(shape, e)
		cursor_pos := cfg.mouse_cursor_pos(shape, ev, mut w)
		input_state := w.view_state.input_state[shape.id_focus]
		w.view_state.input_state[shape.id_focus] = InputState{
			...input_state
			cursor_pos: cursor_pos
			select_beg: 0
			select_end: 0
		}
		e.is_handled = true
	}
}

fn (cfg &TextCfg) mouse_move_shape(shape &Shape, mut e Event, mut w Window) {
	if w.is_focus(shape.id_focus) {
		w.set_mouse_cursor_ibeam()
	}
	// mouse move events don't have mouse button info. Use context.
	if w.ui.mouse_buttons == .left && w.is_focus(shape.id_focus) {
		if cfg.placeholder_active {
			return
		}
		ev := event_relative_to(shape, e)
		end := u32(cfg.mouse_cursor_pos(shape, ev, mut w))
		input_state := w.view_state.input_state[shape.id_focus]
		cursor_pos := u32(input_state.cursor_pos)
		w.view_state.input_state[shape.id_focus] = InputState{
			...input_state
			select_beg: if cursor_pos < end { cursor_pos } else { end }
			select_end: if cursor_pos < end { end } else { cursor_pos }
		}
		e.is_handled = true
	}
}

fn (cfg &TextCfg) mouse_up_shape(shape &Shape, mut e Event, mut w Window) {
	if w.is_focus(shape.id_focus) {
		w.set_mouse_cursor_ibeam()
		e.is_handled = true
	}
}

// mouse_cursor_pos determines where in the input control's text
// field the click occurred. Works with multiple line text fields.
fn (cfg &TextCfg) mouse_cursor_pos(shape &Shape, e &Event, mut w Window) int {
	if cfg.placeholder_active {
		return 0
	}
	lh := shape.text_style.size + shape.text_style.line_spacing
	y := int(e.mouse_y / lh)
	line := shape.text_lines[y]
	mut ln := ''
	mut count := -1
	for i, r in line.runes_iterator() {
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
		count = int_max(0, utf8_str_visible_length(line))
	}
	count = int_min(count, utf8_str_visible_length(line))
	for i, l in shape.text_lines {
		if i < y {
			count += utf8_str_visible_length(l)
		}
	}
	return count
}

fn (cfg &TextCfg) keydown_shape(shape &Shape, mut e Event, mut w Window) {
	if w.is_focus(shape.id_focus) {
		if cfg.placeholder_active {
			return
		}
		input_state := w.view_state.input_state[shape.id_focus]
		mut cursor_pos := input_state.cursor_pos

		if e.modifiers in [u32(Modifier.alt), u32(int(Modifier.alt) | int(Modifier.shift))] {
			match e.key_code {
				.left { cursor_pos = start_of_word_pos(shape.text_lines, cursor_pos) }
				.right { cursor_pos = end_of_word_pos(shape.text_lines, cursor_pos) }
				.up { cursor_pos = start_of_paragraph(shape.text_lines, cursor_pos) }
				else { return }
			}
		} else if e.modifiers in [u32(Modifier.ctrl), u32(int(Modifier.ctrl) | int(Modifier.shift))] {
			match e.key_code {
				.left { cursor_pos = start_of_line_pos(shape.text_lines, cursor_pos) }
				.right { cursor_pos = end_of_line_pos(shape.text_lines, cursor_pos) }
				else { return }
			}
		} else if e.modifiers in [u32(0), u32(Modifier.shift)] {
			match e.key_code {
				.left { cursor_pos = int_max(0, cursor_pos - 1) }
				.right { cursor_pos = int_min(cfg.text.len, cursor_pos + 1) }
				.home { cursor_pos = 0 }
				.end { cursor_pos = cfg.text.len }
				else { return }
			}
		}

		// Moving the cursor when it is animated can happen when the cursor is
		// hidden. Sticky allows the cursor to stay on during cursor movements.
		// See `blinky_cursor_animation()`
		if cursor_pos != input_state.cursor_pos {
			w.view_state.cursor_on_sticky = true
		}

		e.is_handled = true
		w.view_state.input_state[shape.id_focus] = InputState{
			...input_state
			cursor_pos: cursor_pos
			select_beg: 0
			select_end: 0
		}

		// shift => Extend/shrink selection
		if int(e.modifiers) & int(Modifier.shift) > 0 {
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
			w.view_state.input_state[shape.id_focus] = InputState{
				...input_state
				cursor_pos: cursor_pos
				select_beg: beg
				select_end: end
			}
		} else if input_state.select_beg != input_state.select_end && e.modifiers == 0 {
			w.view_state.input_state[shape.id_focus] = InputState{
				...input_state
				cursor_pos: match e.key_code {
					.left { int(input_state.select_beg) }
					.right { int(input_state.select_end) }
					else { cursor_pos }
				}
			}
		}
	}
}

fn (cfg &TextCfg) char_shape(shape &Shape, mut event Event, mut w Window) {
	if w.is_focus(shape.id_focus) {
		c := event.char_code
		if event.modifiers & u32(Modifier.ctrl) > 0 {
			match c {
				ctrl_a { cfg.select_all(shape, mut w) }
				ctrl_c { cfg.copy(shape, w) }
				else {}
			}
		} else if event.modifiers & u32(Modifier.super) > 0 {
			match c {
				cmd_a { cfg.select_all(shape, mut w) }
				cmd_c { cfg.copy(shape, w) }
				else {}
			}
		} else {
			match c {
				escape_char { cfg.unselect_all(mut w) }
				else {}
			}
		}
	}
}

fn (cfg &TextCfg) copy(shape &Shape, w &Window) ?string {
	if cfg.placeholder_active || cfg.is_password {
		return none
	}
	input_state := w.view_state.input_state[cfg.id_focus]
	if input_state.select_beg != input_state.select_end {
		cpy := match shape.text_mode == .wrap_keep_spaces {
			true {
				shape.text.runes()[input_state.select_beg..input_state.select_end]
			}
			else {
				mut count := 0
				mut buffer := []rune{cap: 100}
				unsafe { buffer.flags.set(.noslices) }
				beg := int(input_state.select_beg)
				end := int(input_state.select_end)
				for line in shape.text_lines {
					if count >= end {
						break
					}
					if count > beg {
						buffer << ` `
					}
					for r in line.runes_iterator() {
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

pub fn (cfg &TextCfg) select_all(shape &Shape, mut w Window) {
	if cfg.placeholder_active {
		return
	}
	input_state := w.view_state.input_state[cfg.id_focus]
	w.view_state.input_state[cfg.id_focus] = InputState{
		...input_state
		cursor_pos: cfg.text.len
		select_beg: 0
		select_end: u32(cfg.text.len)
	}
}

pub fn (cfg &TextCfg) unselect_all(mut w Window) {
	input_state := w.view_state.input_state[cfg.id_focus]
	w.view_state.input_state[cfg.id_focus] = InputState{
		...input_state
		cursor_pos: 0
		select_beg: 0
		select_end: 0
	}
}
