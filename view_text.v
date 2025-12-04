module gui

// view_text.v implements text rendering and input handling for single-line
// and multi-line text views. It provides support for text selection, cursor
// movement, copy operations, password masking, and placeholders. The TextView
// component can be configured to handle different text modes including single
// line, multiline with wrapping, and preserving whitespace.
//
import math

// TextMode controls how a text view renders text.
pub enum TextMode as u8 {
	single_line      // one line only. Restricts typing to visible range
	multiline        // wraps `\n`s only
	wrap             // wrap at word breaks and `\n`s. White space is collapsed
	wrap_keep_spaces // wrap at word breaks and `\n`s, Keep white space
}

// Text is an internal structure used to describe a text view
// Members are arranged for packing to reduce memory footprint.
@[minify]
struct TextView implements View {
	sizing Sizing
mut:
	cfg     &TextCfg
	content []View // not used
}

fn (mut tv TextView) generate_layout(mut window Window) Layout {
	$if !prod {
		gui_stats.increment_layouts()
	}
	input_state := match window.is_focus(tv.cfg.id_focus) {
		true { window.view_state.input_state[tv.cfg.id_focus] }
		else { InputState{} }
	}
	lines := match tv.cfg.mode == .multiline {
		true { wrap_simple(tv.cfg.text, tv.cfg.tab_size) }
		else { [tv.cfg.text] } // dynamic wrapping handled in the layout pipeline
	}
	mut layout := Layout{
		shape: &Shape{
			name:                'text'
			shape_type:          .text
			id_focus:            tv.cfg.id_focus
			clip:                tv.cfg.clip
			focus_skip:          tv.cfg.focus_skip
			disabled:            tv.cfg.disabled
			min_width:           tv.cfg.min_width
			sizing:              tv.sizing
			text:                tv.cfg.text
			text_is_password:    tv.cfg.is_password
			text_is_placeholder: tv.cfg.placeholder_active
			text_lines:          lines
			text_mode:           tv.cfg.mode
			text_style:          &tv.cfg.text_style
			text_sel_beg:        input_state.select_beg
			text_sel_end:        input_state.select_end
			text_tab_size:       tv.cfg.tab_size
			on_char:             tv.cfg.on_char
			on_keydown:          tv.cfg.on_key_down
			on_click:            tv.cfg.on_click
			on_mouse_move:       tv.cfg.mouse_move
			on_mouse_up:         view_text_mouse_up
		}
	}
	layout.shape.width = text_width(layout.shape, mut window)
	layout.shape.height = text_height(layout.shape)
	if tv.cfg.mode == .single_line || layout.shape.sizing.width == .fixed {
		layout.shape.min_width = f32_max(layout.shape.width, layout.shape.min_width)
		layout.shape.width = layout.shape.min_width
	}
	if tv.cfg.mode == .single_line || layout.shape.sizing.height == .fixed {
		layout.shape.min_height = f32_max(layout.shape.height, layout.shape.min_height)
		layout.shape.height = layout.shape.height
	}
	return layout
}

// TextCfg configures a [text](#text) view
// - [TextMode](#TextMode) controls how text is wrapped.
@[heap; minify]
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

// text is a general purpose text renderer. Use it for labels or larger
// blocks of multiline text. Giving it an id_focus allows mark and copy
// operations. See [TextCfg](#TextCfg)
pub fn text(cfg TextCfg) View {
	$if !prod {
		gui_stats.increment_text_views()
	}
	if cfg.invisible {
		return invisible_container_view()
	}
	return TextView{
		cfg:    &cfg
		sizing: if cfg.mode in [.wrap, .wrap_keep_spaces] { fill_fit } else { fit_fit }
	}
}

fn (cfg &TextCfg) on_click(layout &Layout, mut e Event, mut w Window) {
	if w.is_focus(layout.shape.id_focus) {
		w.set_mouse_cursor_ibeam()
	}
	if e.mouse_button == .left && w.is_focus(layout.shape.id_focus) {
		id_focus := layout.shape.id_focus
		w.mouse_lock(
			mouse_move: fn [cfg, id_focus] (layout &Layout, mut e Event, mut w Window) {
				// The layout in mouse locks is always the root layout.
				if ly := layout.find_layout(fn [id_focus] (ly Layout) bool {
					return ly.shape.id_focus == id_focus
				})
				{
					cfg.mouse_move(ly, mut e, mut w)
				}
			}
			mouse_up:   fn [id_focus] (layout &Layout, mut e Event, mut w Window) {
				w.mouse_unlock()
				// The layout in mouse locks is always the root layout.
				if ly := layout.find_layout(fn [id_focus] (ly Layout) bool {
					return ly.shape.id_focus == id_focus
				})
				{
					view_text_mouse_up(ly, mut e, mut w)
				}
			}
		)
		cursor_pos := cfg.mouse_cursor_pos(layout.shape, e, mut w)
		input_state := w.view_state.input_state[layout.shape.id_focus]
		w.view_state.input_state[layout.shape.id_focus] = InputState{
			...input_state
			cursor_pos: cursor_pos
			select_beg: 0
			select_end: 0
		}
		e.is_handled = true
	}
}

fn (cfg &TextCfg) mouse_move(layout &Layout, mut e Event, mut w Window) {
	if w.is_focus(layout.shape.id_focus) {
		w.set_mouse_cursor_ibeam()
	}
	// mouse move events don't have mouse button info. Use context.
	if w.ui.mouse_buttons == .left && w.is_focus(layout.shape.id_focus) {
		if cfg.placeholder_active {
			return
		}
		ev := event_relative_to(layout.shape, e)
		end := u32(cfg.mouse_cursor_pos(layout.shape, ev, mut w))
		input_state := w.view_state.input_state[layout.shape.id_focus]
		cursor_pos := u32(input_state.cursor_pos)
		w.view_state.input_state[layout.shape.id_focus] = InputState{
			...input_state
			select_beg: if cursor_pos < end { cursor_pos } else { end }
			select_end: if cursor_pos < end { end } else { cursor_pos }
		}
		scroll_cursor_into_view(int(end), layout, ev, mut w)
		e.is_handled = true
	}
}

fn scroll_cursor_into_view(cursor_pos int, layout &Layout, e &Event, mut w Window) {
	// - find the index of the line where the cursor is located.
	mut line_idx := 0
	mut total_len := 0
	for i, line in layout.shape.text_lines {
		line_idx = i
		total_len += line.len
		if total_len > cursor_pos {
			break
		}
	}

	// - compute the top/bottom scroll offset required to show it
	lh := line_height(layout.shape)
	total_height := lh * layout.shape.text_lines.len
	shape_height := layout.shape.height - layout.shape.padding.height()
	top_offset := (line_idx * lh) * (total_height / shape_height)

	// - compare to current scroll offset and compute new scroll offset
	y_scroll_offset := w.view_state.offset_y_state[layout.shape.id_scroll_container]
	new_y_scroll_offset := -top_offset

	// - scroll window to offset
	if new_y_scroll_offset > y_scroll_offset && e.mouse_dy < 0 {
		w.scroll_vertical_to(layout.shape.id_scroll_container, new_y_scroll_offset)
	}
}

fn view_text_mouse_up(layout &Layout, mut e Event, mut w Window) {
	if w.is_focus(layout.shape.id_focus) {
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
	if e.mouse_y < 0 {
		return 0
	}
	lh := line_height(shape)
	y := int_clamp(int(e.mouse_y / lh), 0, shape.text_lines.len - 1)
	line := shape.text_lines[y]
	mut current_width := f32(0.0)
	mut count := -1
	for i, r in line.runes_iterator() {
		char_width := get_text_width(r.str(), shape.text_style, mut w)
		if current_width + (char_width / 2) > e.mouse_x {
			// One past the `to` position is just cursor after char.
			// Appears to be how others do it (e.g. browsers)
			count = i
			break
		}
		current_width += char_width
	}
	visible_length := utf8_str_visible_length(line)
	count = match count {
		-1 { int_max(0, visible_length) }
		else { int_min(count, visible_length) }
	}
	for i, l in shape.text_lines {
		if i < y {
			count += utf8_str_visible_length(l)
		}
	}
	return count
}

fn (cfg &TextCfg) on_key_down(layout &Layout, mut e Event, mut w Window) {
	if w.is_focus(layout.shape.id_focus) {
		if cfg.placeholder_active {
			return
		}
		mut current_input_state := w.view_state.input_state[layout.shape.id_focus]
		mut new_cursor_pos := current_input_state.cursor_pos

		if e.modifiers == .alt || e.modifiers.has_all(.alt, .shift) {
			match e.key_code {
				.left { new_cursor_pos = start_of_word_pos(layout.shape.text_lines, new_cursor_pos) }
				.right { new_cursor_pos = end_of_word_pos(layout.shape.text_lines, new_cursor_pos) }
				.up { new_cursor_pos = start_of_paragraph(layout.shape.text_lines, new_cursor_pos) }
				else { return }
			}
		} else if e.modifiers == .ctrl || e.modifiers.has_all(.ctrl, .shift) {
			match e.key_code {
				.left { new_cursor_pos = start_of_line_pos(layout.shape.text_lines, new_cursor_pos) }
				.right { new_cursor_pos = end_of_line_pos(layout.shape.text_lines, new_cursor_pos) }
				else { return }
			}
		} else if e.modifiers.has_any(.none, .shift) {
			match e.key_code {
				.left { new_cursor_pos = int_max(0, new_cursor_pos - 1) }
				.right { new_cursor_pos = int_min(cfg.text.runes().len, new_cursor_pos + 1) }
				.home { new_cursor_pos = 0 }
				.end { new_cursor_pos = cfg.text.runes().len }
				else { return }
			}
		} else if e.modifiers == Modifier.super {
			return
		}

		// Moving the cursor when it is animated can happen when the cursor is
		// hidden. Sticky allows the cursor to stay on during cursor movements.
		// See `blinky_cursor_animation()`
		if new_cursor_pos != current_input_state.cursor_pos {
			w.view_state.input_cursor_on_sticky = true
		}

		e.is_handled = true
		mut new_select_beg := u32(0)
		mut new_select_end := u32(0)

		// shift => Extend/shrink selection
		if e.modifiers.has(.shift) {
			old_cursor_pos := current_input_state.cursor_pos
			new_select_beg = current_input_state.select_beg
			new_select_end = current_input_state.select_end

			// If there's no selection, start one from the old cursor position.
			if new_select_beg == new_select_end {
				new_select_beg = u32(old_cursor_pos)
			}

			// Move the selection boundary that was at the old cursor position.
			if old_cursor_pos == int(new_select_beg) {
				new_select_beg = u32(new_cursor_pos)
			} else if old_cursor_pos == int(new_select_end) {
				new_select_end = u32(new_cursor_pos)
			} else {
				// If the old cursor was not at a boundary (e.g., from a click),
				// move the boundary closest to the new cursor position.
				if math.abs(new_cursor_pos - int(new_select_beg)) < math.abs(new_cursor_pos - int(new_select_end)) {
					new_select_beg = u32(new_cursor_pos)
				} else {
					new_select_end = u32(new_cursor_pos)
				}
			}

			if new_select_beg > new_select_end {
				new_select_beg, new_select_end = new_select_end, new_select_beg
			}
		} else if current_input_state.select_beg != current_input_state.select_end
			&& e.modifiers == .none {
			// If a selection exists and a non-shift movement key is pressed,
			// collapse the selection to the beginning or end of the selection.
			new_cursor_pos = match e.key_code {
				.left, .home { int(current_input_state.select_beg) }
				.right, .end { int(current_input_state.select_end) }
				else { new_cursor_pos }
			}
		}

		w.view_state.input_state[layout.shape.id_focus] = InputState{
			...current_input_state
			cursor_pos: new_cursor_pos
			select_beg: new_select_beg
			select_end: new_select_end
		}

		scroll_cursor_into_view(new_cursor_pos, layout, e, mut w)
	}
}

fn (cfg &TextCfg) on_char(layout &Layout, mut event Event, mut w Window) {
	if w.is_focus(layout.shape.id_focus) {
		c := event.char_code
		mut is_handled := true
		if event.modifiers.has(.ctrl) {
			match c {
				ctrl_a { cfg.select_all(layout.shape, mut w) }
				ctrl_c { cfg.copy(layout.shape, w) }
				else { is_handled = false }
			}
		} else if event.modifiers.has(.super) {
			match c {
				cmd_a { cfg.select_all(layout.shape, mut w) }
				cmd_c { cfg.copy(layout.shape, w) }
				else { is_handled = false }
			}
		} else {
			match c {
				escape_char { cfg.unselect_all(mut w) }
				else { is_handled = false }
			}
		}
		event.is_handled = is_handled
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
	len := cfg.text.runes().len
	w.view_state.input_state[cfg.id_focus] = InputState{
		...input_state
		cursor_pos: len
		select_beg: 0
		select_end: u32(len)
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
