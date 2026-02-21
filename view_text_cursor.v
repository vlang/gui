module gui

import gg

// utf8_rune_count returns the number of Unicode code points in s
// without allocating a []rune array.
@[inline]
fn utf8_rune_count(s string) int {
	mut count := 0
	mut i := 0
	for i < s.len {
		b := unsafe { s.str[i] }
		i += ((0xe5000000 >> ((b >> 3) & 0x1e)) & 3) + 1
		count++
	}
	return count
}

// cursor_left moves the cursor position one character to the left in the text.
// It decrements the position by one, but ensures the result never goes below
// zero, effectively preventing the cursor from moving before the start of the
// text. Returns the new cursor position.
fn cursor_left(pos int) int {
	return int_max(0, pos - 1)
}

// cursor_right moves the cursor position one character to the right in wrapped
// text. It increments the position by one, but ensures the result never exceeds
// the total character count of all text lines combined, effectively preventing
// the cursor from moving beyond the end of the text. Returns the new cursor
// position.
fn cursor_right(shape Shape, pos int) int {
	return int_min(utf8_rune_count(shape.tc.text), pos + 1)
}

// cursor_up moves the cursor position up one line using vglyph geometry.
fn cursor_up(shape Shape, cursor_pos int, cursor_offset f32, lines_up int, mut window Window) int {
	if lines_up <= 0 {
		return cursor_pos
	}

	byte_idx := rune_to_byte_index(shape.tc.text, cursor_pos)

	// Check for nil layout
	if !shape.has_text_layout() {
		return cursor_pos
	}

	rect := shape.tc.vglyph_layout.get_char_rect(byte_idx) or {
		if byte_idx >= shape.tc.text.len && shape.tc.text.len > 0 {
			return cursor_pos
		}
		return cursor_pos
	}

	current_x := rect.x
	current_y := rect.y

	target_x := if cursor_offset >= 0 { cursor_offset } else { current_x }
	target_y := current_y - (rect.height * lines_up) - (shape.tc.text_style.line_spacing * lines_up)

	new_byte_idx := shape.tc.vglyph_layout.get_closest_offset(target_x, target_y + (rect.height / 2))

	return byte_to_rune_index(shape.tc.text, new_byte_idx)
}

// cursor_down moves the cursor position down one line using vglyph geometry.
fn cursor_down(shape Shape, cursor_pos int, cursor_offset f32, lines_down int, mut window Window) int {
	if lines_down <= 0 {
		return cursor_pos
	}

	byte_idx := rune_to_byte_index(shape.tc.text, cursor_pos)

	if !shape.has_text_layout() {
		return cursor_pos
	}

	rect := shape.tc.vglyph_layout.get_char_rect(byte_idx) or { return cursor_pos }

	current_x := rect.x
	current_y := rect.y

	target_x := if cursor_offset >= 0 { cursor_offset } else { current_x }
	target_y := current_y + (rect.height * lines_down) +
		(shape.tc.text_style.line_spacing * lines_down)

	new_byte_idx := shape.tc.vglyph_layout.get_closest_offset(target_x, target_y + (rect.height / 2))

	return byte_to_rune_index(shape.tc.text, new_byte_idx)
}

// cursor_home moves the cursor to the beginning of the text by returning
// position 0. This is equivalent to the "Home" key behavior, placing the
// cursor at the start of the entire text content.
fn cursor_home() int {
	return 0
}

// cursor_end moves the cursor to the end of the text by returning the total
// character count across all wrapped text lines. This is equivalent to the
// "End" key behavior, placing the cursor at the end of the entire text content.
fn cursor_end(shape Shape) int {
	return utf8_rune_count(shape.tc.text)
}

const bytes_blanks = [u8(` `), `\t`, `\f`, `\v`]!

// cursor_start_of_word finds the start of the current word in wrapped text by locating
// the line containing the given position, searching backwards through blank characters
// (spaces, tabs, form feeds, vertical tabs), and then backwards through non-blank
// characters to find the start of the word. Returns the character position at the
// start of the word, or 0 if at the beginning of the text.
fn cursor_start_of_word(shape Shape, pos int) int {
	if pos < 0 {
		return 0
	}

	byte_idx := rune_to_byte_index(shape.tc.text, pos)
	// Simple backward search on string
	mut i := byte_idx - 1
	if i >= shape.tc.text.len {
		i = shape.tc.text.len - 1
	}

	// 1. Skip spaces backwards
	for i >= 0 && shape.tc.text[i] in bytes_blanks {
		i--
	}
	// 2. Skip non-spaces backwards
	for i >= 0 && shape.tc.text[i] !in bytes_blanks {
		i--
	}

	return byte_to_rune_index(shape.tc.text, i + 1)
}

// cursor_end_of_word finds the end of the current word in wrapped text by locating
// the line containing the given position, skipping over any blank characters (spaces,
// tabs, form feeds, vertical tabs), and then advancing through non-blank characters
// to find the end of the word. Returns the character position at the end of the word.
fn cursor_end_of_word(shape Shape, pos int) int {
	if pos < 0 {
		return 0
	}
	byte_idx := rune_to_byte_index(shape.tc.text, pos)
	mut i := byte_idx

	// 1. Skip spaces forward
	for i < shape.tc.text.len && shape.tc.text[i] in bytes_blanks {
		i++
	}
	// 2. Skip non-spaces forward
	for i < shape.tc.text.len && shape.tc.text[i] !in bytes_blanks {
		i++
	}
	return byte_to_rune_index(shape.tc.text, i)
}

// cursor_start_of_line finds the start of the current line in wrapped text using
// vglyph layout information.
fn cursor_start_of_line(shape Shape, pos int) int {
	byte_idx := rune_to_byte_index(shape.tc.text, pos)

	if !shape.has_text_layout() {
		return 0
	}
	// Find which line contains the index
	for line in shape.tc.vglyph_layout.lines {
		end := line.start_index + line.length
		if byte_idx >= line.start_index && byte_idx < end {
			return byte_to_rune_index(shape.tc.text, line.start_index)
		}
	}

	// If not found, check if it's at the very end of the last line
	if shape.tc.vglyph_layout.lines.len > 0 {
		last := shape.tc.vglyph_layout.lines.last()
		last_end := last.start_index + last.length
		if byte_idx == last_end {
			return byte_to_rune_index(shape.tc.text, last.start_index)
		}
	}

	return 0
}

// cursor_end_of_line finds the end of the current line in wrapped text using
// vglyph layout information.
fn cursor_end_of_line(shape Shape, pos int) int {
	byte_idx := rune_to_byte_index(shape.tc.text, pos)

	if !shape.has_text_layout() {
		return utf8_rune_count(shape.tc.text)
	}

	for i, line in shape.tc.vglyph_layout.lines {
		end := line.start_index + line.length
		if byte_idx >= line.start_index && byte_idx <= end {
			// Return end of this line.
			// If it's the last line, text.len.
			mut limit := end
			if i < shape.tc.vglyph_layout.lines.len - 1 {
				// Check if line ends with newline (it likely does if hard wrap)
				if limit > 0 && shape.tc.text[limit - 1] == `\n` {
					limit--
				}
			}
			return byte_to_rune_index(shape.tc.text, limit)
		}
	}
	return utf8_rune_count(shape.tc.text) // default to end
}

// cursor_start_of_paragraph finds the start of the current paragraph in wrapped text
// by searching backwards from the given position.
fn cursor_start_of_paragraph(shape Shape, pos int) int {
	if pos < 0 {
		return 0
	}
	byte_idx := rune_to_byte_index(shape.tc.text, pos)
	mut i := byte_idx - 1
	if i >= shape.tc.text.len {
		i = shape.tc.text.len - 1
	}

	for i >= 0 {
		if shape.tc.text[i] == `\n` {
			return byte_to_rune_index(shape.tc.text, i + 1)
		}
		i--
	}
	return 0
}

// get_cursor_column returns the zero-based column index of `cursor_pos` within
// the current line of wrapped text.
fn get_cursor_column(shape Shape, cursor_pos int) int {
	start := cursor_start_of_line(shape, cursor_pos)
	return cursor_pos - start
}

// cursor_position_from_offset finds the character index (rune position) in a string
// that corresponds to the given horizontal pixel offset. It calculates the rendered
// width of text up to each character position and returns the index closest to the
// offset. If the offset is beyond the end of the string, it returns the last valid
// character position.
fn cursor_position_from_offset(str string, offset f32, style TextStyle, mut window Window) int {
	rune_str := str.runes()
	for idx in 1 .. rune_str.len {
		width := text_width(rune_str[0..idx].string(), style, mut window)
		if width > offset {
			char_width := text_width(rune_str[idx].str(), style, mut window)
			return if offset - char_width > width { idx } else { idx - 1 }
		}
	}
	return int_max(0, rune_str.len - 1)
}

// offset_from_cursor_position returns the horizontal pixel offset of the cursor
// position using vglyph geometry.
fn offset_from_cursor_position(shape Shape, cursor_position int, mut window Window) f32 {
	byte_idx := rune_to_byte_index(shape.tc.text, cursor_position)
	if !shape.has_text_layout() {
		return 0
	}
	rect := shape.tc.vglyph_layout.get_char_rect(byte_idx) or {
		// If at end, maybe get end of last line?
		if shape.tc.vglyph_layout.lines.len > 0 {
			for line in shape.tc.vglyph_layout.lines {
				end := line.start_index + line.length
				if byte_idx == end {
					return line.rect.x + line.rect.width
				}
			}
		}
		return 0
	}
	return rect.x
}

// cursor_pos_to_scroll_y calculates the vertical scroll offset using vglyph geometry.
fn cursor_pos_to_scroll_y(cursor_pos int, shape &Shape, mut w Window) f32 {
	id_scroll_container := shape.id_scroll_container
	if id_scroll_container == 0 {
		return 0
	}
	scroll_container := find_layout_by_id_scroll(w.layout, id_scroll_container) or { return -1 }
	scroll_view_height := scroll_container.shape.height - scroll_container.shape.padding.height()

	byte_idx := rune_to_byte_index(shape.tc.text, cursor_pos)
	if !shape.has_text_layout() {
		return -1
	}

	rect := shape.tc.vglyph_layout.get_char_rect(byte_idx) or { gg.Rect{} }

	current_scroll_y := w.view_state.scroll_y.get(id_scroll_container) or { f32(0) }

	// rect.y is in text-local coords. Convert to scroll container content coords
	// by adding shape's original position (before scroll was applied).
	// shape.y = original_y + scroll_y, so original_y = shape.y - scroll_y
	shape_y_in_content := shape.y - current_scroll_y - scroll_container.shape.y
	cursor_top := shape_y_in_content + rect.y
	cursor_bottom := cursor_top + rect.height

	// View spans from 0 to scroll_view_height in content coords when scroll=0
	// With scroll, visible region is from -scroll_y to -scroll_y + height
	view_top := -current_scroll_y
	view_bottom := view_top + scroll_view_height

	mut target_scroll := current_scroll_y

	if cursor_top < view_top {
		target_scroll = -cursor_top
	} else if cursor_bottom > view_bottom {
		target_scroll = -(cursor_bottom - scroll_view_height)
	}

	return target_scroll
}

fn cursor_pos_to_scroll_x(cursor_pos int, shape &Shape, mut w Window) f32 {
	return 0
}

// 	id_scroll_container := shape.id_scroll_container
// 	scroll_container := find_scroll_container(id_scroll_container, w) or { return -1 }
//
// 	// Determine the width of the scrollable region
// 	mut padding_width := scroll_container.shape.padding.width()
// 	if scroll_container.children.len > 0 {
// 		padding_width += scroll_container.children[0].shape.padding.width()
// 	}
// 	// scroll_view_width := scroll_container.shape.width - padding_width
//
// 	// Find the index of the line where the cursor is located.
// 	mut line_idx := 0
// 	mut total_len := 0
// 	for i, line in shape.tc.text_lines {
// 		line_idx = i
// 		total_len += utf8_str_visible_length(line)
// 		if total_len > cursor_pos {
// 			break
// 		}
// 	}
//
// 	width := utf8_str_visible_length(shape.tc.text.lines[line_idx][..total_len - cursor_pos])
// }

// mouse_cursor_pos determines the character index (cursor position) within
// the entire text based on the mouse coordinates using vglyph geometry.
fn (tv &TextView) mouse_cursor_pos(shape &Shape, e &Event, mut w Window) int {
	if tv.placeholder_active {
		return 0
	}

	// Convert mouse coords to layout-relative.
	// `layout_text` generates a layout starting at (0,0).
	// So e.mouse_x/y should be relative to shape pos minus padding.
	rel_x := f32(e.mouse_x) - shape.padding.left
	rel_y := f32(e.mouse_y) - shape.padding.top

	if !shape.has_text_layout() {
		return 0
	}
	byte_idx := shape.tc.vglyph_layout.get_closest_offset(rel_x, rel_y)
	return byte_to_rune_index(shape.tc.text, byte_idx)
}

// scroll_cursor_into_view ensures that the text cursor is visible within the
// scroll container.
fn scroll_cursor_into_view(cursor_pos int, layout &Layout, mut w Window) {
	new_scroll_y := cursor_pos_to_scroll_y(cursor_pos, layout.shape, mut w)
	w.scroll_vertical_to(layout.shape.id_scroll_container, new_scroll_y)
}

// text_mouse_cursor_pos is a standalone version of mouse_cursor_pos that
// takes placeholder_active as a parameter instead of capturing tv.
fn text_mouse_cursor_pos(shape &Shape, e &Event, mut w Window, placeholder_active bool) int {
	if placeholder_active {
		return 0
	}
	rel_x := f32(e.mouse_x) - shape.padding.left
	rel_y := f32(e.mouse_y) - shape.padding.top
	if !shape.has_text_layout() {
		return 0
	}
	byte_idx := shape.tc.vglyph_layout.get_closest_offset(rel_x, rel_y)
	return byte_to_rune_index(shape.tc.text, byte_idx)
}

// text_auto_scroll_cursor is a standalone version of auto_scroll_cursor
// that avoids capturing tv in animation closures.
fn text_auto_scroll_cursor(id_focus u32, id_scroll_container u32, mut an Animate, mut w Window, placeholder_active bool) {
	mut layout := w.layout.find_layout(fn [id_focus] (ly Layout) bool {
		return ly.shape.id_scroll == id_focus
	}) or { return }

	for {
		if layout.shape.shape_type == .text {
			break
		}
		if layout.children.len == 0 {
			return
		}
		layout = layout.children[0]
	}

	cursor_pos := (w.view_state.input_state.get(id_focus) or { InputState{} }).cursor_pos
	start_cursor_pos := w.view_state.mouse_lock.cursor_pos

	raw_ev := Event{
		mouse_x: w.ui.mouse_pos_x
		mouse_y: w.ui.mouse_pos_y
	}
	ev := event_relative_to(layout.shape, raw_ev)
	mut mouse_cursor_pos := text_mouse_cursor_pos(layout.shape, ev, mut w, placeholder_active)

	scroll_y := cursor_pos_to_scroll_y(mouse_cursor_pos, layout.shape, mut w)
	current_scroll_y := w.view_state.scroll_y.get(id_scroll_container) or { f32(0) }

	if scroll_y > current_scroll_y {
		mouse_cursor_pos = cursor_up(layout.shape, cursor_pos, -1, 1, mut w)
	} else if scroll_y < current_scroll_y {
		mouse_cursor_pos = cursor_down(layout.shape, cursor_pos, -1, 1, mut w)
	} else {
		return
	}

	sel_beg, sel_end := selection_range(start_cursor_pos, mouse_cursor_pos)
	w.view_state.input_state.set(id_focus, InputState{
		...w.view_state.input_state.get(id_focus) or { InputState{} }
		cursor_pos:    mouse_cursor_pos
		cursor_offset: -1
		select_beg:    sel_beg
		select_end:    sel_end
	})

	scroll_cursor_into_view(mouse_cursor_pos, layout, mut w)

	scroll_container := find_layout_by_id_scroll(w.layout, id_scroll_container) or { return }
	evs := event_relative_to(scroll_container.shape, raw_ev)

	distance := match evs.mouse_y < 0 {
		true { -evs.mouse_y }
		else { evs.mouse_y - scroll_container.shape.height }
	}

	lh := line_height(layout.shape, mut w)
	if distance > 2 * lh {
		an.delay = auto_scroll_fast
	} else if distance > lh {
		an.delay = auto_scroll_medium
	} else {
		an.delay = auto_scroll_slow
	}
}

// text_double_click_drag handles mouse-move events during a word-level drag
// initiated by a double-click. Selection extends word-by-word, anchored to
// the initially-selected word [anchor_beg, anchor_end).
fn text_double_click_drag(layout &Layout, mut e Event, mut w Window, placeholder_active bool, anchor_beg int, anchor_end int) {
	if w.ui.mouse_buttons != .left || placeholder_active {
		return
	}
	id_focus := layout.shape.id_focus
	id_scroll_container := layout.shape.id_scroll_container
	ev := event_relative_to(layout.shape, e)
	mouse_cursor_pos := text_mouse_cursor_pos(layout.shape, ev, mut w, placeholder_active)

	scroll_y := cursor_pos_to_scroll_y(mouse_cursor_pos, layout.shape, mut w)
	current_scroll_y := w.view_state.scroll_y.get(id_scroll_container) or { f32(0) }

	if scroll_y != current_scroll_y {
		if !w.has_animation(id_auto_scroll_animation) {
			w.animation_add(mut Animate{
				id:       id_auto_scroll_animation
				callback: fn [placeholder_active, id_focus, id_scroll_container, anchor_beg, anchor_end] (mut an Animate, mut w Window) {
					text_double_click_auto_scroll_cursor(id_focus, id_scroll_container,
						anchor_beg, anchor_end, mut an, mut w, placeholder_active)
				}
				delay:    auto_scroll_slow
				repeat:   true
			})
		}
		return
	} else {
		w.remove_animation(id_auto_scroll_animation)
	}

	mut sel_beg := u32(0)
	mut sel_end := u32(0)
	mut new_cursor_pos := 0
	if mouse_cursor_pos < anchor_beg {
		sel_beg = u32(cursor_start_of_word(layout.shape, mouse_cursor_pos))
		sel_end = u32(anchor_end)
		new_cursor_pos = int(sel_beg)
	} else {
		sel_beg = u32(anchor_beg)
		sel_end = u32(cursor_end_of_word(layout.shape, mouse_cursor_pos))
		new_cursor_pos = int(sel_end)
	}
	w.view_state.input_state.set(id_focus, InputState{
		...w.view_state.input_state.get(id_focus) or { InputState{} }
		cursor_pos:    new_cursor_pos
		cursor_offset: -1
		select_beg:    sel_beg
		select_end:    sel_end
	})
	scroll_cursor_into_view(new_cursor_pos, layout, mut w)
	e.is_handled = true
}

// text_double_click_auto_scroll_cursor is the animation callback for auto-scroll
// during a word-level drag. Mirrors text_auto_scroll_cursor but applies word
// boundaries instead of raw cursor positions.
fn text_double_click_auto_scroll_cursor(id_focus u32, id_scroll_container u32, anchor_beg int, anchor_end int, mut an Animate, mut w Window, placeholder_active bool) {
	mut layout := w.layout.find_layout(fn [id_focus] (ly Layout) bool {
		return ly.shape.id_scroll == id_focus
	}) or { return }
	for {
		if layout.shape.shape_type == .text {
			break
		}
		if layout.children.len == 0 {
			return
		}
		layout = layout.children[0]
	}
	cursor_pos := (w.view_state.input_state.get(id_focus) or { InputState{} }).cursor_pos
	raw_ev := Event{
		mouse_x: w.ui.mouse_pos_x
		mouse_y: w.ui.mouse_pos_y
	}
	ev := event_relative_to(layout.shape, raw_ev)
	mut mouse_cursor_pos := text_mouse_cursor_pos(layout.shape, ev, mut w, placeholder_active)

	scroll_y := cursor_pos_to_scroll_y(mouse_cursor_pos, layout.shape, mut w)
	current_scroll_y := w.view_state.scroll_y.get(id_scroll_container) or { f32(0) }
	if scroll_y > current_scroll_y {
		mouse_cursor_pos = cursor_up(layout.shape, cursor_pos, -1, 1, mut w)
	} else if scroll_y < current_scroll_y {
		mouse_cursor_pos = cursor_down(layout.shape, cursor_pos, -1, 1, mut w)
	} else {
		return
	}

	mut sel_beg := u32(0)
	mut sel_end := u32(0)
	mut new_cursor_pos := 0
	if mouse_cursor_pos < anchor_beg {
		sel_beg = u32(cursor_start_of_word(layout.shape, mouse_cursor_pos))
		sel_end = u32(anchor_end)
		new_cursor_pos = int(sel_beg)
	} else {
		sel_beg = u32(anchor_beg)
		sel_end = u32(cursor_end_of_word(layout.shape, mouse_cursor_pos))
		new_cursor_pos = int(sel_end)
	}
	w.view_state.input_state.set(id_focus, InputState{
		...w.view_state.input_state.get(id_focus) or { InputState{} }
		cursor_pos:    new_cursor_pos
		cursor_offset: -1
		select_beg:    sel_beg
		select_end:    sel_end
	})
	scroll_cursor_into_view(new_cursor_pos, layout, mut w)

	scroll_container := find_layout_by_id_scroll(w.layout, id_scroll_container) or { return }
	evs := event_relative_to(scroll_container.shape, raw_ev)
	distance := if evs.mouse_y < 0 {
		-evs.mouse_y
	} else {
		evs.mouse_y - scroll_container.shape.height
	}
	lh := line_height(layout.shape, mut w)
	if distance > 2 * lh {
		an.delay = auto_scroll_fast
	} else if distance > lh {
		an.delay = auto_scroll_medium
	} else {
		an.delay = auto_scroll_slow
	}
}

// text_mouse_move_locked is a standalone version of mouse_move_locked
// that avoids capturing tv in mouse lock closures.
fn text_mouse_move_locked(layout &Layout, mut e Event, mut w Window, placeholder_active bool) {
	if w.ui.mouse_buttons == .left {
		if placeholder_active {
			return
		}

		id_focus := layout.shape.id_focus
		id_scroll_container := layout.shape.id_scroll_container

		start_cursor_pos := w.view_state.mouse_lock.cursor_pos
		ev := event_relative_to(layout.shape, e)
		mut mouse_cursor_pos := text_mouse_cursor_pos(layout.shape, ev, mut w, placeholder_active)

		scroll_y := cursor_pos_to_scroll_y(mouse_cursor_pos, layout.shape, mut w)
		current_scroll_y := w.view_state.scroll_y.get(id_scroll_container) or { f32(0) }

		if scroll_y != current_scroll_y {
			if !w.has_animation(id_auto_scroll_animation) {
				w.animation_add(mut Animate{
					id:       id_auto_scroll_animation
					callback: fn [placeholder_active, id_focus, id_scroll_container] (mut an Animate, mut w Window) {
						text_auto_scroll_cursor(id_focus, id_scroll_container, mut an, mut
							w, placeholder_active)
					}
					delay:    auto_scroll_slow
					repeat:   true
				})
			}
			return
		} else {
			w.remove_animation(id_auto_scroll_animation)
		}

		sel_beg, sel_end := selection_range(start_cursor_pos, mouse_cursor_pos)
		w.view_state.input_state.set(id_focus, InputState{
			...w.view_state.input_state.get(id_focus) or { InputState{} }
			cursor_pos:    mouse_cursor_pos
			cursor_offset: -1
			select_beg:    sel_beg
			select_end:    sel_end
		})

		scroll_cursor_into_view(mouse_cursor_pos, layout, mut w)
		e.is_handled = true
	}
}
