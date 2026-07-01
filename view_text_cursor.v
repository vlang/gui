module gui

import gg

// utf8_rune_count returns the number of Unicode code points in s
// without allocating a []rune array.
@[inline]
fn utf8_rune_count(s string) int {
	mut count := 0
	for _ in s.runes_iterator() {
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
fn cursor_up(shape Shape, cursor_pos int, cursor_offset f32, lines_up int, mut _ Window) int {
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

	new_byte_idx := shape.tc.vglyph_layout.get_closest_offset(target_x,
		target_y + (rect.height / 2))

	return byte_to_rune_index(shape.tc.text, new_byte_idx)
}

// cursor_down moves the cursor position down one line using vglyph geometry.
fn cursor_down(shape Shape, cursor_pos int, cursor_offset f32, lines_down int, mut _ Window) int {
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

	new_byte_idx := shape.tc.vglyph_layout.get_closest_offset(target_x,
		target_y + (rect.height / 2))

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

fn cursor_end_of_paragraph(shape Shape, pos int) int {
	byte_idx := rune_to_byte_index(shape.tc.text, pos)
	mut i := byte_idx
	for i < shape.tc.text.len {
		if shape.tc.text[i] == `\n` {
			return byte_to_rune_index(shape.tc.text, i)
		}
		i++
	}
	return utf8_rune_count(shape.tc.text)
}

// get_cursor_column returns the zero-based column index of `cursor_pos` within
// the current line of wrapped text.
fn get_cursor_column(shape Shape, cursor_pos int) int {
	start := cursor_start_of_line(shape, cursor_pos)
	return cursor_pos - start
}

// cursor_position_from_offset finds the character index (rune position) in a string
// that corresponds to the given horizontal pixel offset. It calculates the rendered
// width of text up to each character position and returns the insertion index
// closest to the offset. If the offset is beyond the end of the string, it returns
// the end position.
fn cursor_position_from_offset(str string, offset f32, style TextStyle, mut window Window) int {
	rune_str := str.runes()
	if rune_str.len == 0 || offset <= 0 {
		return 0
	}
	mut prev_width := f32(0)
	for idx in 0 .. rune_str.len {
		width := text_width(rune_str[..idx + 1].string(), style, mut window)
		mid := prev_width + ((width - prev_width) / 2)
		if offset < mid {
			return idx
		}
		prev_width = width
	}
	return rune_str.len
}

fn text_password_cursor_pos_from_offset(shape &Shape, offset f32, y f32, mut window Window) int {
	if text_width(text_shape_display_text(shape), shape.tc.text_style, mut window) > 0 {
		return cursor_position_from_offset(text_shape_display_text(shape), text_password_mask_offset_x(shape,
			offset), shape.tc.text_style, mut window)
	}
	if shape.has_text_layout() {
		byte_idx := shape.tc.vglyph_layout.get_closest_offset(offset, y)
		return byte_to_rune_index(shape.tc.text, byte_idx)
	}
	return cursor_position_from_offset(text_shape_display_text(shape), text_password_mask_offset_x(shape,
		offset), shape.tc.text_style, mut window)
}

fn text_cursor_rect_for_position(shape &Shape, cursor_position int, mut window Window) gg.Rect {
	if text_shape_uses_password_display(shape) && shape.tc.text_mode == .single_line {
		if shape.has_text_layout() && shape.tc.vglyph_layout.lines.len > 0 {
			line := shape.tc.vglyph_layout.lines[0]
			return gg.Rect{
				x:      text_password_cursor_x(shape, cursor_position, mut window)
				y:      line.rect.y
				height: line.rect.height
			}
		}
		return gg.Rect{
			x:      text_password_cursor_x(shape, cursor_position, mut window)
			height: line_height(shape, mut window)
		}
	}

	byte_idx := rune_to_byte_index(shape.tc.text, cursor_position)
	if shape.has_text_layout() {
		return shape.tc.vglyph_layout.get_char_rect(byte_idx) or {
			if byte_idx >= shape.tc.text.len && shape.tc.vglyph_layout.lines.len > 0 {
				last_line := shape.tc.vglyph_layout.lines.last()
				gg.Rect{
					x:      last_line.rect.x + last_line.rect.width
					y:      last_line.rect.y
					height: last_line.rect.height
				}
			} else {
				gg.Rect{
					height: line_height(shape, mut window)
				}
			}
		}
	}
	return gg.Rect{
		height: line_height(shape, mut window)
	}
}

// offset_from_cursor_position returns the horizontal pixel offset of the cursor
// position using vglyph geometry.
fn offset_from_cursor_position(shape Shape, cursor_position int, mut window Window) f32 {
	return text_cursor_rect_for_position(&shape, cursor_position, mut window).x
}

// cursor_pos_to_scroll_y calculates the vertical scroll offset using vglyph geometry.
fn cursor_pos_to_scroll_y(cursor_pos int, shape &Shape, mut w Window) f32 {
	layout := w.layout
	return cursor_pos_to_scroll_y_in_layout(cursor_pos, shape, layout, mut w)
}

fn cursor_pos_to_scroll_y_in_layout(cursor_pos int, shape &Shape, root &Layout, mut w Window) f32 {
	id_scroll_container := shape.id_scroll_container
	if id_scroll_container == 0 {
		return 0
	}
	scroll_container := find_layout_by_id_scroll(root, id_scroll_container) or { return -1 }
	scroll_view_height := scroll_container.shape.height - scroll_container.shape.padding_height()

	byte_idx := rune_to_byte_index(shape.tc.text, cursor_pos)
	if !shape.has_text_layout() {
		return -1
	}

	rect := shape.tc.vglyph_layout.get_char_rect(byte_idx) or { gg.Rect{} }

	current_scroll_y := state_map[u32, f32](mut w, ns_scroll_y, cap_scroll).get(id_scroll_container) or {
		f32(0)
	}

	// rect.y is in text-local coords. Convert to content-relative coords
	// (where 0 = top of scrollable content, after container padding).
	// shape.y includes scroll offset; undo it to get the original position,
	// then subtract the container origin and its padding.
	shape_y_in_content := shape.y - current_scroll_y - scroll_container.shape.y
	padding_top := scroll_container.shape.padding_top()
	cursor_top := shape_y_in_content - padding_top + rect.y
	cursor_bottom := cursor_top + rect.height

	// Visible region in content coords: -scroll_y to -scroll_y + height
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
	layout := w.layout
	return cursor_pos_to_scroll_x_in_layout(cursor_pos, shape, layout, mut w)
}

fn cursor_pos_to_scroll_x_in_layout(cursor_pos int, shape &Shape, root &Layout, mut w Window) f32 {
	id_scroll_container := shape.id_scroll_container
	if id_scroll_container == 0 {
		return 0
	}
	scroll_container := find_layout_by_id_scroll(root, id_scroll_container) or { return -1 }
	scroll_view_width := scroll_container.shape.width - scroll_container.shape.padding_width()

	if !shape.has_text_layout() {
		return -1
	}
	if scroll_view_width <= 0 {
		return 0
	}

	rect := text_cursor_rect_for_position(shape, cursor_pos, mut w)
	current_scroll_x := state_map[u32, f32](mut w, ns_scroll_x, cap_scroll).get(id_scroll_container) or {
		f32(0)
	}

	shape_x_in_content := shape.x - current_scroll_x - scroll_container.shape.x
	padding_left := scroll_container.shape.padding_left()
	caret_left_x := shape_x_in_content - padding_left + text_layout_align_offset_x(shape, mut w) +
		rect.x
	caret_right_x := caret_left_x + f32_max(rect.width, 1)

	view_left := -current_scroll_x
	view_right := view_left + scroll_view_width

	mut target_scroll := current_scroll_x
	if caret_left_x < view_left {
		target_scroll = -caret_left_x
	} else if caret_right_x > view_right {
		target_scroll = -(caret_right_x - scroll_view_width)
	}

	max_offset := f32_min(0, scroll_container.shape.width - scroll_container.shape.padding_width() -
		content_width(scroll_container))
	return f32_clamp(target_scroll, max_offset, 0)
}

struct TextScrollTargets {
	target_x  f32
	current_x f32
	target_y  f32
	current_y f32
}

fn text_private_scroll_active(shape &Shape) bool {
	return shape.tc != unsafe { nil } && shape.tc.text_scroll_key.len > 0
		&& shape.tc.text_mode == .single_line
}

fn text_private_scroll_state_x(shape &Shape, mut w Window) f32 {
	if shape.tc == unsafe { nil } {
		return 0
	}
	if !text_private_scroll_active(shape) {
		return shape.tc.text_scroll_x
	}
	return state_map[string, f32](mut w, ns_input_private_scroll_x, cap_scroll).get(shape.tc.text_scroll_key) or {
		shape.tc.text_scroll_x
	}
}

fn text_private_set_scroll_x(shape &Shape, target_x f32, mut w Window) bool {
	if !text_private_scroll_active(shape) {
		return false
	}
	current_x := text_private_scroll_state_x(shape, mut w)
	if f32_are_close(current_x, target_x) {
		return false
	}
	mut sx := state_map[string, f32](mut w, ns_input_private_scroll_x, cap_scroll)
	sx.set(shape.tc.text_scroll_key, target_x)
	return true
}

fn text_private_scroll_viewport(layout &Layout) ?Layout {
	if layout.parent == unsafe { nil } {
		return none
	}
	return *layout.parent
}

fn text_private_scroll_viewport_width(viewport Layout) f32 {
	return f32_max(0, viewport.shape.width - viewport.shape.padding_width())
}

fn text_private_scroll_content_width(layout &Layout, mut w Window) f32 {
	shape := layout.shape
	if shape.has_text_layout() && shape.tc.vglyph_layout.lines.len > 0 {
		line := shape.tc.vglyph_layout.lines[0]
		visual_width := text_line_visual_width(shape, line, mut w)
		right_edge := line.rect.x + visual_width
		return f32_max(0, right_edge)
	}
	return text_width_shape(shape, mut w)
}

fn text_private_scroll_max_x(layout &Layout, viewport Layout, mut w Window) f32 {
	return f32_min(0, text_private_scroll_viewport_width(viewport) - text_private_scroll_content_width(layout, mut
		w))
}

fn text_private_clamp_scroll_x(scroll_x f32, layout &Layout, viewport Layout, mut w Window) f32 {
	return f32_clamp(scroll_x, text_private_scroll_max_x(layout, viewport, mut w), 0)
}

fn text_private_cursor_scroll_x(cursor_pos int, layout &Layout, current_x f32, mut w Window) ?f32 {
	if !text_private_scroll_active(layout.shape) || !layout.shape.has_text_layout() {
		return none
	}
	viewport := text_private_scroll_viewport(layout) or { return none }
	view_width := text_private_scroll_viewport_width(viewport)
	if view_width <= 0 {
		return 0
	}
	rect := text_cursor_rect_for_position(layout.shape, cursor_pos, mut w)
	caret_left_x := text_layout_align_offset_x(layout.shape, mut w) + rect.x
	caret_right_x := caret_left_x + f32_max(rect.width, 1)
	view_left := -current_x
	view_right := view_left + view_width
	mut target_x := current_x
	if caret_left_x < view_left {
		target_x = -caret_left_x
	} else if caret_right_x > view_right {
		target_x = -(caret_right_x - view_width)
	}
	return text_private_clamp_scroll_x(target_x, layout, viewport, mut w)
}

fn text_scroll_target_active(target f32, current f32) bool {
	return target != -1 && !f32_are_close(target, current)
}

fn (targets TextScrollTargets) needs_scroll() bool {
	return text_scroll_target_active(targets.target_x, targets.current_x)
		|| text_scroll_target_active(targets.target_y, targets.current_y)
}

fn text_scroll_targets(cursor_pos int, layout &Layout, id_scroll_container u32, mut w Window) TextScrollTargets {
	target_x := cursor_pos_to_scroll_x(cursor_pos, layout.shape, mut w)
	current_x := state_map[u32, f32](mut w, ns_scroll_x, cap_scroll).get(id_scroll_container) or {
		f32(0)
	}
	target_y := cursor_pos_to_scroll_y(cursor_pos, layout.shape, mut w)
	current_y := state_map[u32, f32](mut w, ns_scroll_y, cap_scroll).get(id_scroll_container) or {
		f32(0)
	}
	return TextScrollTargets{
		target_x:  target_x
		current_x: current_x
		target_y:  target_y
		current_y: current_y
	}
}

fn text_private_scroll_targets(cursor_pos int, layout &Layout, mut w Window) TextScrollTargets {
	current_x := text_private_scroll_state_x(layout.shape, mut w)
	target_x := text_private_cursor_scroll_x(cursor_pos, layout, current_x, mut w) or { f32(-1) }
	return TextScrollTargets{
		target_x:  target_x
		current_x: current_x
		target_y:  0
		current_y: 0
	}
}

fn text_private_scroll_targets_for_drag(cursor_pos int, layout &Layout, raw_ev Event, mut w Window) TextScrollTargets {
	targets := text_private_scroll_targets(cursor_pos, layout, mut w)
	viewport := text_private_scroll_viewport(layout) or { return targets }
	evs := event_relative_to(viewport.shape, &raw_ev)
	view_left := viewport.shape.padding_left()
	view_right := view_left + text_private_scroll_viewport_width(viewport)
	mut target_x := targets.target_x
	if evs.mouse_x < view_left {
		target_x = text_private_clamp_scroll_x(0, layout, viewport, mut w)
	} else if evs.mouse_x > view_right {
		target_x = text_private_scroll_max_x(layout, viewport, mut w)
	}
	return TextScrollTargets{
		target_x:  target_x
		current_x: targets.current_x
		target_y:  targets.target_y
		current_y: targets.current_y
	}
}

fn text_public_scroll_targets_for_drag(cursor_pos int, layout &Layout, raw_ev Event, id_scroll_container u32, mut w Window) TextScrollTargets {
	targets := text_scroll_targets(cursor_pos, layout, id_scroll_container, mut w)
	if id_scroll_container == 0 {
		return targets
	}
	scroll_container := find_layout_by_id_scroll(w.layout, id_scroll_container) or {
		return targets
	}
	evs := event_relative_to(scroll_container.shape, &raw_ev)
	view_left := scroll_container.shape.padding_left()
	view_width := f32_max(0, scroll_container.shape.width - scroll_container.shape.padding_width())
	view_right := view_left + view_width
	max_offset := f32_min(0, view_width - content_width(scroll_container))
	mut target_x := targets.target_x
	if evs.mouse_x < view_left {
		target_x = f32_clamp(0, max_offset, 0)
	} else if evs.mouse_x > view_right {
		target_x = max_offset
	}
	return TextScrollTargets{
		target_x:  target_x
		current_x: targets.current_x
		target_y:  targets.target_y
		current_y: targets.current_y
	}
}

fn text_scroll_targets_for_layout(cursor_pos int, layout &Layout, id_scroll_container u32, mut w Window) TextScrollTargets {
	if text_private_scroll_active(layout.shape) {
		return text_private_scroll_targets(cursor_pos, layout, mut w)
	}
	return text_scroll_targets(cursor_pos, layout, id_scroll_container, mut w)
}

fn text_scroll_targets_for_drag(cursor_pos int, layout &Layout, raw_ev Event, id_scroll_container u32, mut w Window) TextScrollTargets {
	if text_private_scroll_active(layout.shape) {
		return text_private_scroll_targets_for_drag(cursor_pos, layout, raw_ev, mut w)
	}
	return text_public_scroll_targets_for_drag(cursor_pos, layout, raw_ev, id_scroll_container, mut
		w)
}

fn text_auto_scroll_next_cursor_pos(layout &Layout, cursor_pos int, targets TextScrollTargets, mut w Window) ?int {
	if text_scroll_target_active(targets.target_y, targets.current_y) {
		if targets.target_y > targets.current_y {
			return cursor_up(layout.shape, cursor_pos, -1, 1, mut w)
		}
		return cursor_down(layout.shape, cursor_pos, -1, 1, mut w)
	}
	if text_scroll_target_active(targets.target_x, targets.current_x) {
		if targets.target_x > targets.current_x {
			return cursor_left(cursor_pos)
		}
		return cursor_right(layout.shape, cursor_pos)
	}
	return none
}

fn text_update_auto_scroll_delay(layout &Layout, raw_ev Event, id_scroll_container u32, mut an Animate, mut w Window) {
	scroll_container := find_layout_by_id_scroll(w.layout, id_scroll_container) or { return }
	evs := event_relative_to(scroll_container.shape, raw_ev)
	mut distance := f32(0)
	if evs.mouse_y < 0 {
		distance = f32_max(distance, -evs.mouse_y)
	} else if evs.mouse_y > scroll_container.shape.height {
		distance = f32_max(distance, evs.mouse_y - scroll_container.shape.height)
	}
	if evs.mouse_x < 0 {
		distance = f32_max(distance, -evs.mouse_x)
	} else if evs.mouse_x > scroll_container.shape.width {
		distance = f32_max(distance, evs.mouse_x - scroll_container.shape.width)
	}

	lh := f32_max(1, line_height(layout.shape, mut w))
	if distance > 2 * lh {
		an.delay = auto_scroll_fast
	} else if distance > lh {
		an.delay = auto_scroll_medium
	} else {
		an.delay = auto_scroll_slow
	}
}

fn text_update_private_auto_scroll_delay(layout &Layout, raw_ev Event, mut an Animate, mut w Window) {
	viewport := text_private_scroll_viewport(layout) or { return }
	evs := event_relative_to(viewport.shape, raw_ev)
	mut distance := f32(0)
	view_left := viewport.shape.padding_left()
	view_right := view_left + text_private_scroll_viewport_width(viewport)
	if evs.mouse_x < view_left {
		distance = view_left - evs.mouse_x
	} else if evs.mouse_x > view_right {
		distance = evs.mouse_x - view_right
	}
	lh := f32_max(1, line_height(layout.shape, mut w))
	if distance > 2 * lh {
		an.delay = auto_scroll_fast
	} else if distance > lh {
		an.delay = auto_scroll_medium
	} else {
		an.delay = auto_scroll_slow
	}
}

fn text_update_auto_scroll_delay_for_layout(layout &Layout, raw_ev Event, id_scroll_container u32, mut an Animate, mut w Window) {
	if text_private_scroll_active(layout.shape) {
		text_update_private_auto_scroll_delay(layout, raw_ev, mut an, mut w)
		return
	}
	text_update_auto_scroll_delay(layout, raw_ev, id_scroll_container, mut an, mut w)
}

// mouse_cursor_pos determines the character index (cursor position) within
// the entire text based on the mouse coordinates using vglyph geometry.
fn (tv &TextView) mouse_cursor_pos(shape &Shape, e &Event, mut window Window) int {
	if tv.placeholder_active {
		return 0
	}

	// Convert mouse coords to layout-relative.
	// `layout_text` generates a layout starting at (0,0).
	// So e.mouse_x/y should be relative to shape pos minus padding.
	rel_x := f32(e.mouse_x) - shape.padding.left - text_layout_render_offset_x(shape, mut window)
	rel_y := f32(e.mouse_y) - shape.padding.top
	return text_mouse_cursor_pos_from_local(shape, rel_x, rel_y, mut window)
}

// scroll_cursor_into_view ensures that the text cursor is visible within the
// scroll container.
fn scroll_cursor_into_view(cursor_pos int, layout &Layout, mut w Window) {
	if text_private_scroll_active(layout.shape) {
		current_x := text_private_scroll_state_x(layout.shape, mut w)
		if target_x := text_private_cursor_scroll_x(cursor_pos, layout, current_x, mut w) {
			if text_private_set_scroll_x(layout.shape, target_x, mut w) {
				w.update_window()
			}
		} else {
			input_mark_cursor_reveal(layout.shape.id_focus, mut w)
		}
		scroll_cursor_y_into_view(cursor_pos, layout, mut w)
		return
	}
	scroll_cursor_x_into_view(cursor_pos, layout, mut w)
	scroll_cursor_y_into_view(cursor_pos, layout, mut w)
}

fn scroll_cursor_x_into_view(cursor_pos int, layout &Layout, mut w Window) {
	if layout.shape.id_scroll_container == 0 {
		return
	}
	new_scroll_x := cursor_pos_to_scroll_x(cursor_pos, layout.shape, mut w)
	if new_scroll_x != -1 {
		w.scroll_horizontal_to(layout.shape.id_scroll_container, new_scroll_x)
	}
}

fn scroll_cursor_y_into_view(cursor_pos int, layout &Layout, mut w Window) {
	if layout.shape.id_scroll_container == 0 {
		return
	}
	new_scroll_y := cursor_pos_to_scroll_y(cursor_pos, layout.shape, mut w)
	if new_scroll_y != -1 {
		w.scroll_vertical_to(layout.shape.id_scroll_container, new_scroll_y)
	}
}

// text_mouse_cursor_pos is a standalone version of mouse_cursor_pos that
// takes placeholder_active as a parameter instead of capturing tv.
fn text_mouse_cursor_pos(shape &Shape, e &Event, mut window Window, placeholder_active bool) int {
	if placeholder_active {
		return 0
	}
	rel_x := f32(e.mouse_x) - shape.padding.left - text_layout_render_offset_x(shape, mut window)
	rel_y := f32(e.mouse_y) - shape.padding.top
	return text_mouse_cursor_pos_from_local(shape, rel_x, rel_y, mut window)
}

fn text_mouse_cursor_pos_from_local(shape &Shape, rel_x f32, rel_y f32, mut window Window) int {
	if text_shape_uses_password_display(shape) && shape.tc.text_mode == .single_line {
		return text_password_cursor_pos_from_offset(shape, rel_x, rel_y, mut window)
	}
	if !shape.has_text_layout() {
		return 0
	}
	if shape.tc.text_mode == .single_line && shape.tc.vglyph_layout.lines.len > 0 {
		line := shape.tc.vglyph_layout.lines[0]
		right_edge := line.rect.x + text_line_visual_width(shape, line, mut window)
		if rel_x >= right_edge {
			line_end := int_min(line.start_index + line.length, shape.tc.text.len)
			return byte_to_rune_index(shape.tc.text, line_end)
		}
	}
	byte_idx := shape.tc.vglyph_layout.get_closest_offset(rel_x, rel_y)
	return byte_to_rune_index(shape.tc.text, byte_idx)
}

// text_auto_scroll_cursor is a standalone version of auto_scroll_cursor
// that avoids capturing tv in animation closures.
fn text_auto_scroll_cursor(id_focus u32, id_scroll_container u32, mut an Animate, mut w Window, placeholder_active bool) {
	mut layout := w.layout.find_layout(fn [id_focus] (ly Layout) bool {
		return ly.shape.id_focus == id_focus && ly.shape.shape_type == .text
	}) or { return }

	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	cursor_pos := (imap.get(id_focus) or { InputState{} }).cursor_pos
	start_cursor_pos := w.view_state.mouse_lock.cursor_pos

	raw_ev := Event{
		mouse_x: w.ui.mouse_pos_x
		mouse_y: w.ui.mouse_pos_y
	}
	ev := event_relative_to(layout.shape, raw_ev)
	mut mouse_cursor_pos := text_mouse_cursor_pos(layout.shape, ev, mut w, placeholder_active)

	targets :=
		text_scroll_targets_for_drag(mouse_cursor_pos, layout, raw_ev, id_scroll_container, mut w)
	mouse_cursor_pos = text_auto_scroll_next_cursor_pos(layout, cursor_pos, targets, mut w) or {
		return
	}

	sel_beg, sel_end := selection_range(start_cursor_pos, mouse_cursor_pos)
	imap.set(id_focus, InputState{
		...imap.get(id_focus) or { InputState{} }
		cursor_pos:    mouse_cursor_pos
		cursor_offset: -1
		select_beg:    sel_beg
		select_end:    sel_end
	})

	scroll_cursor_into_view(mouse_cursor_pos, layout, mut w)
	text_update_auto_scroll_delay_for_layout(layout, raw_ev, id_scroll_container, mut an, mut w)
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

	targets := text_scroll_targets_for_drag(mouse_cursor_pos, layout, e, id_scroll_container, mut w)
	if targets.needs_scroll() {
		if !w.has_animation(id_auto_scroll_animation) {
			w.animation_add(mut Animate{
				id:       id_auto_scroll_animation
				callback: fn [placeholder_active, id_focus, id_scroll_container, anchor_beg, anchor_end] (mut an Animate, mut w Window) {
					text_double_click_auto_scroll_cursor(id_focus, id_scroll_container, anchor_beg,
						anchor_end, mut an, mut w, placeholder_active)
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
	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	imap.set(id_focus, InputState{
		...imap.get(id_focus) or { InputState{} }
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
		return ly.shape.id_focus == id_focus && ly.shape.shape_type == .text
	}) or { return }
	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	cursor_pos := (imap.get(id_focus) or { InputState{} }).cursor_pos
	raw_ev := Event{
		mouse_x: w.ui.mouse_pos_x
		mouse_y: w.ui.mouse_pos_y
	}
	ev := event_relative_to(layout.shape, raw_ev)
	mut mouse_cursor_pos := text_mouse_cursor_pos(layout.shape, ev, mut w, placeholder_active)

	targets :=
		text_scroll_targets_for_drag(mouse_cursor_pos, layout, raw_ev, id_scroll_container, mut w)
	mouse_cursor_pos = text_auto_scroll_next_cursor_pos(layout, cursor_pos, targets, mut w) or {
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
	imap.set(id_focus, InputState{
		...imap.get(id_focus) or { InputState{} }
		cursor_pos:    new_cursor_pos
		cursor_offset: -1
		select_beg:    sel_beg
		select_end:    sel_end
	})
	scroll_cursor_into_view(new_cursor_pos, layout, mut w)
	text_update_auto_scroll_delay_for_layout(layout, raw_ev, id_scroll_container, mut an, mut w)
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

		targets :=
			text_scroll_targets_for_drag(mouse_cursor_pos, layout, e, id_scroll_container, mut w)
		if targets.needs_scroll() {
			if !w.has_animation(id_auto_scroll_animation) {
				w.animation_add(mut Animate{
					id:       id_auto_scroll_animation
					callback: fn [placeholder_active, id_focus, id_scroll_container] (mut an Animate, mut w Window) {
						text_auto_scroll_cursor(id_focus, id_scroll_container, mut an, mut w,
							placeholder_active)
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
		mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
		imap.set(id_focus, InputState{
			...imap.get(id_focus) or { InputState{} }
			cursor_pos:    mouse_cursor_pos
			cursor_offset: -1
			select_beg:    sel_beg
			select_end:    sel_end
		})

		scroll_cursor_into_view(mouse_cursor_pos, layout, mut w)
		e.is_handled = true
	}
}
