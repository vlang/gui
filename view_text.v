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

@[minify]
pub struct TextView implements View {
	TextCfg
	sizing Sizing
mut:
	content []View // not used
}

fn (mut tv TextView) generate_layout(mut window Window) Layout {
	$if !prod {
		gui_stats.increment_layouts()
	}
	input_state := match window.is_focus(tv.id_focus) {
		true { window.view_state.input_state[tv.id_focus] }
		else { InputState{} }
	}
	lines := match tv.mode == .multiline {
		true { wrap_simple(tv.text, tv.tab_size) }
		else { [tv.text] } // dynamic wrapping handled in the layout pipeline
	}
	mut layout := Layout{
		shape: &Shape{
			name:                'text'
			shape_type:          .text
			id_focus:            tv.id_focus
			clip:                tv.clip
			focus_skip:          tv.focus_skip
			disabled:            tv.disabled
			min_width:           tv.min_width
			sizing:              tv.sizing
			text:                tv.text
			text_is_password:    tv.is_password
			text_is_placeholder: tv.placeholder_active
			text_lines:          lines
			text_mode:           tv.mode
			text_style:          &tv.text_style
			text_sel_beg:        input_state.select_beg
			text_sel_end:        input_state.select_end
			text_tab_size:       tv.tab_size
			on_char:             tv.on_char
			on_keydown:          tv.on_key_down
			on_click:            tv.on_click
		}
	}
	layout.shape.width = text_width(layout.shape, mut window)
	layout.shape.height = text_height(layout.shape)
	if tv.mode == .single_line || layout.shape.sizing.width == .fixed {
		layout.shape.min_width = f32_max(layout.shape.width, layout.shape.min_width)
		layout.shape.width = layout.shape.min_width
	}
	if tv.mode == .single_line || layout.shape.sizing.height == .fixed {
		layout.shape.min_height = f32_max(layout.shape.height, layout.shape.min_height)
		layout.shape.height = layout.shape.height
	}
	return layout
}

// TextCfg configures a [text](#text) view. It provides options for text content,
// styling, rendering mode, focus handling, and display behavior. Use this struct
// to create text views for labels, multiline text blocks, or interactive text
// with selection and copy capabilities. The [TextMode](#TextMode) field controls
// how text is wrapped and displayed (single line, multiline, or wrapped).
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

// text is a general purpose text view. Use it for labels or larger
// blocks of multiline text. Giving it an id_focus allows mark and copy
// operations. See [TextCfg](#TextCfg)
pub fn text(cfg TextView) View {
	$if !prod {
		gui_stats.increment_text_views()
	}
	if cfg.invisible {
		return invisible_container_view()
	}
	return TextView{
		text:               cfg.text
		text_style:         cfg.text_style
		id_focus:           cfg.id_focus
		tab_size:           cfg.tab_size
		min_width:          cfg.min_width
		mode:               cfg.mode
		invisible:          cfg.invisible
		clip:               cfg.clip
		focus_skip:         cfg.focus_skip
		disabled:           cfg.disabled
		is_password:        cfg.is_password
		placeholder_active: cfg.placeholder_active
		sizing:             if cfg.mode in [.wrap, .wrap_keep_spaces] { fill_fit } else { fit_fit }
	}
}

// on_click handles mouse click events for the TextView.
// It sets up mouse locking for drag selection updates and positions the text cursor
// based on the click coordinates.
fn (tv &TextView) on_click(layout &Layout, mut e Event, mut w Window) {
	if w.is_focus(layout.shape.id_focus) {
		w.set_mouse_cursor_ibeam()
	}
	if e.mouse_button == .left && w.is_focus(layout.shape.id_focus) {
		id_focus := layout.shape.id_focus
		cursor_pos := tv.mouse_cursor_pos(layout.shape, e, mut w)
		// Init mouse lock to handle dragging selection (mouse move) and finishing selection (mouse up)
		w.mouse_lock(
			cursor_pos: cursor_pos
			mouse_move: fn [tv, id_focus] (layout &Layout, mut e Event, mut w Window) {
				// The layout in mouse locks is always the root layout.
				if ly := layout.find_layout(fn [id_focus] (ly Layout) bool {
					return ly.shape.id_focus == id_focus
				})
				{
					tv.mouse_move_locked(ly, mut e, mut w)
				}
			}
			mouse_up:   fn [tv, id_focus] (layout &Layout, mut e Event, mut w Window) {
				w.mouse_unlock()
				// The layout in mouse locks is always the root layout.
				if ly := layout.find_layout(fn [id_focus] (ly Layout) bool {
					return ly.shape.id_focus == id_focus
				})
				{
					tv.mouse_up_locked(ly, mut e, mut w)
				}
			}
		)
		// Set cursor position and reset text selection
		cursor_offset := offset_from_cursor_position(layout.shape, cursor_pos, w)
		input_state := w.view_state.input_state[layout.shape.id_focus]
		w.view_state.input_state[layout.shape.id_focus] = InputState{
			...input_state
			cursor_pos:    cursor_pos
			select_beg:    0
			select_end:    0
			cursor_offset: cursor_offset
		}
		e.is_handled = true
	}
}

// mouse_move_locked handles mouse movement events while the mouse is locked (dragged).
// It updates the text selection range based on the current mouse position relative to the
// starting cursor position.
fn (tv &TextView) mouse_move_locked(layout &Layout, mut e Event, mut w Window) {
	if w.is_focus(layout.shape.id_focus) {
		w.set_mouse_cursor_ibeam()
	}
	// mouse_move events don't have mouse button info. Use context.
	if w.ui.mouse_buttons == .left && w.is_focus(layout.shape.id_focus) {
		if tv.placeholder_active {
			return
		}
		ev := event_relative_to(layout.shape, e)
		input_state := w.view_state.input_state[layout.shape.id_focus]
		start_cursor_pos := w.view_state.mouse_lock.cursor_pos
		mouse_cursor_pos := tv.mouse_cursor_pos(layout.shape, ev, mut w)

		w.view_state.input_state[layout.shape.id_focus] = InputState{
			...input_state
			cursor_pos:    mouse_cursor_pos
			cursor_offset: -1
			select_beg:    match start_cursor_pos < mouse_cursor_pos {
				true { u32(start_cursor_pos) }
				else { u32(mouse_cursor_pos) }
			}
			select_end:    match start_cursor_pos < mouse_cursor_pos {
				true { u32(mouse_cursor_pos) }
				else { u32(start_cursor_pos) }
			}
		}

		scroll_cursor_into_view(mouse_cursor_pos, layout, mut w)
		e.is_handled = true
	}
}

// mouse_up_locked handles mouse up events while the mouse is locked (after a drag selection).
// It finalizes the cursor position based on the mouse release location, updates the view state
// with the new cursor position, and ensures the cursor is scrolled into view.
fn (tv &TextView) mouse_up_locked(layout &Layout, mut e Event, mut w Window) {
	if w.is_focus(layout.shape.id_focus) {
		w.set_mouse_cursor_ibeam()

		// determine the cursor position from the mouse position
		ev := event_relative_to(layout.shape, e)
		mouse_cursor_pos := tv.mouse_cursor_pos(layout.shape, ev, mut w)

		// update the view state with the new mouse_cursor_pos
		input_state := w.view_state.input_state[layout.shape.id_focus]
		w.view_state.input_state[layout.shape.id_focus] = InputState{
			...input_state
			cursor_pos:    mouse_cursor_pos
			cursor_offset: -1
		}

		scroll_cursor_into_view(mouse_cursor_pos, layout, mut w)
		e.is_handled = true
	}
}

// scroll_container_cursor_y
fn scroll_container_cursor_y(cursor_pos int, layout &Layout, mut w Window) f32 {
	id_scroll_container := layout.shape.id_scroll_container

	// Find the scroll container and calculate height. (need to start at the root layout)
	scroll_container := w.layout.find_layout(fn [id_scroll_container] (ly Layout) bool {
		return ly.shape.id_scroll == id_scroll_container
	}) or { return -1 }

	// Determine the height of the scrollable region
	mut padding_height := scroll_container.shape.padding.height()
	if scroll_container.children.len > 0 {
		padding_height += scroll_container.children[0].shape.padding.height()
	}
	scroll_view_height := scroll_container.shape.height - padding_height

	// Find the index of the line where the cursor is located.
	mut line_idx := 0
	mut total_len := 0
	for i, line in layout.shape.text_lines {
		line_idx = i
		total_len += utf8_str_visible_length(line)
		if total_len > cursor_pos {
			break
		}
	}

	// Calculate the y offset of the cursor line.
	// Since scroll offsets are often negative (content moves up), use -lh.
	lh := line_height(layout.shape)
	cursor_y := line_idx * -lh
	cursor_h_y := cursor_y + scroll_view_height - lh

	// Calculate scroll offsets for current visible region
	current_scroll_y := w.view_state.scroll_y[id_scroll_container]
	current_scroll_h_y := current_scroll_y - scroll_view_height + lh

	// Determine if we need to scroll:
	// 1. If cursor is above the current view
	// 2. If cursor is below the current view
	new_scroll_y := match true {
		cursor_y > current_scroll_y { cursor_y - 1 }
		cursor_y < current_scroll_h_y { cursor_h_y }
		else { current_scroll_y }
	}

	return new_scroll_y
}

// scroll_cursor_into_view ensures that the text cursor is visible within the
// scroll container.
fn scroll_cursor_into_view(cursor_pos int, layout &Layout, mut w Window) {
	new_scroll_y := scroll_container_cursor_y(cursor_pos, layout, mut w)
	w.scroll_vertical_to(layout.shape.id_scroll_container, new_scroll_y)
}

// mouse_cursor_pos determines the character index (cursor position) within
// the entire text based on the mouse coordinates.
// It handles multiline text by calculating the line index first, then
// identifying the specific character within that line.
fn (tv &TextView) mouse_cursor_pos(shape &Shape, e &Event, mut w Window) int {
	if tv.placeholder_active {
		return 0
	}
	if e.mouse_y < 0 {
		return 0
	}
	// Calculate the line index based on mouse Y and line height, clamped to valid lines
	lh := line_height(shape)
	y := int_clamp(int(e.mouse_y / lh), 0, shape.text_lines.len - 1)
	line := shape.text_lines[y]

	// Find the character index within the identified line
	mut current_width := f32(0.0)
	mut count := -1
	for i, r in line.runes_iterator() {
		char_width := get_text_width(r.str(), shape.text_style, mut w)
		// Check if mouse is close to the beginning of this character.
		// Use a threshold (1/3 of width) to determine if cursor should be before this char.
		if current_width + (char_width / 3) > e.mouse_x {
			count = i
			break
		}
		current_width += char_width
	}

	// Handle case where mouse is past the last character or line is empty
	visible_length := utf8_str_visible_length(line)
	count = match count {
		-1 { int_max(0, visible_length) }
		else { int_min(count, visible_length) }
	}

	// Add lengths of previous lines to get the global index
	for i, l in shape.text_lines {
		if i < y {
			count += utf8_str_visible_length(l)
		}
	}
	return count
}

// on_key_down handles keyboard input for navigation and text selection.
// It supports standard navigation keys (arrows, home, end) and modifiers
// (Alt, Ctrl, Shift) for word/line jumping and selection extension.
fn (tv &TextView) on_key_down(layout &Layout, mut e Event, mut window Window) {
	if window.is_focus(layout.shape.id_focus) {
		if tv.placeholder_active || window.mouse_is_locked() {
			return
		}
		mut input_state := window.view_state.input_state[layout.shape.id_focus]
		mut position := input_state.cursor_pos
		mut offset := input_state.cursor_offset
		text_lines := layout.shape.text_lines

		// Handle navigation with modifiers
		if e.modifiers == .alt || e.modifiers == .alt_shift {
			// Alt: Jump by word or paragraph
			match e.key_code {
				.left { position = cursor_start_of_word(text_lines, position) }
				.right { position = cursor_end_of_word(text_lines, position) }
				.up { position = cursor_start_of_paragraph(text_lines, position) }
				else { return }
			}
		} else if e.modifiers == .ctrl || e.modifiers == .ctrl_shift {
			// Ctrl: Jump to start/end of line
			match e.key_code {
				.left { position = cursor_start_of_line(text_lines, position) }
				.right { position = cursor_end_of_line(text_lines, position) }
				else { return }
			}
		} else if e.modifiers.has_any(.none, .shift) {
			// Standard navigation: char by char, prev/next line, home/end of text
			match e.key_code {
				.left { position = cursor_left(position) }
				.right { position = cursor_right(text_lines, position) }
				.up { position = cursor_up(layout.shape, position, offset, window) }
				.down { position = cursor_down(layout.shape, position, offset, window) }
				.home { position = cursor_home() }
				.end { position = cursor_end(text_lines) }
				else { return }
			}
		} else if e.modifiers == Modifier.super {
			return
		}

		if (e.key_code != .up && e.key_code != .down) || input_state.cursor_offset < 0 {
			offset = offset_from_cursor_position(layout.shape, position, window)
		}

		// input_cursor_on_sticky allows the cursor to stay on during cursor movements.
		// See `blinky_cursor_animation()`
		if position != input_state.cursor_pos {
			window.view_state.cursor_on_sticky = true
		}

		// ================================
		// shift => Extend/shrink selection
		// ================================
		mut select_beg := u32(0)
		mut select_end := u32(0)

		if e.modifiers.has(.shift) {
			old_cursor_pos := input_state.cursor_pos
			select_beg = input_state.select_beg
			select_end = input_state.select_end

			// If there's no selection, start one from the old cursor position.
			if select_beg == select_end {
				select_beg = u32(old_cursor_pos)
				select_end = u32(old_cursor_pos)
			}

			// Move the selection boundary that was at the old cursor position.
			if old_cursor_pos == int(select_beg) {
				select_beg = u32(position)
			} else if old_cursor_pos == int(select_end) {
				select_end = u32(position)
			} else {
				// If the old cursor was not at a boundary (e.g., from a click),
				// move the boundary closest to the new cursor position.
				if math.abs(position - int(select_beg)) < math.abs(position - int(select_end)) {
					select_beg = u32(position)
				} else {
					select_end = u32(position)
				}
			}
			// Ensure beg is always less than or equal to end
			if select_beg > select_end {
				select_beg, select_end = select_end, select_beg
			}
		} else if input_state.select_beg != input_state.select_end && e.modifiers == .none {
			// If a selection exists and a non-shift movement key is pressed,
			// collapse the selection to the beginning or end of the selection.
			position = match e.key_code {
				.left, .home { int(input_state.select_beg) }
				.right, .end { int(input_state.select_end) }
				else { position }
			}
		}

		// Update input state with new cursor position and selection
		window.view_state.input_state[layout.shape.id_focus] = InputState{
			...input_state
			cursor_pos:    position
			select_beg:    select_beg
			select_end:    select_end
			cursor_offset: offset
		}

		// Ensure the new cursor position is visible
		scroll_cursor_into_view(position, layout, mut window)
		e.is_handled = true
	}
}

// on_char handles character input events for keyboard shortcuts. It processes
// modifier key combinations (Ctrl/Cmd) for Select All (Ctrl/Cmd+A) and Copy
// (Ctrl/Cmd+C), as well as the Escape key to clear text selection. The function
// only processes events when the view has focus and the mouse is not locked.
fn (tv &TextView) on_char(layout &Layout, mut event Event, mut w Window) {
	if w.is_focus(layout.shape.id_focus) && !w.mouse_is_locked() {
		c := event.char_code
		mut is_handled := true

		// Handle Copy and Select All shortcuts
		if event.modifiers.has(.ctrl) {
			match c {
				ctrl_a { tv.select_all(layout.shape, mut w) }
				ctrl_c { tv.copy(layout.shape, w) }
				else { is_handled = false }
			}
		} else if event.modifiers.has(.super) {
			match c {
				cmd_a { tv.select_all(layout.shape, mut w) }
				cmd_c { tv.copy(layout.shape, w) }
				else { is_handled = false }
			}
		} else {
			// Handle non-modifier shortcuts
			match c {
				escape_char { tv.unselect_all(mut w) }
				else { is_handled = false }
			}
		}
		event.is_handled = is_handled
	}
}

// copy copies the selected text to the system clipboard.
// It handles different text modes:
// - `wrap_keep_spaces`: uses original text slice.
// - other modes: reconstructs text from visual lines, joining them with spaces.
// Returns none if copy is not allowed (e.g. password field) or no selection.
fn (cfg &TextCfg) copy(shape &Shape, w &Window) ?string {
	// Prevent copying from password fields or placeholders
	if cfg.placeholder_active || cfg.is_password {
		return none
	}
	input_state := w.view_state.input_state[cfg.id_focus]

	// Only copy if there is an active selection
	if input_state.select_beg != input_state.select_end {
		cpy := match shape.text_mode == .wrap_keep_spaces {
			true {
				// In keep_spaces mode, we can directly slice the source text
				shape.text.runes()[input_state.select_beg..input_state.select_end]
			}
			else {
				// Reconstruct text from visual lines
				mut count := 0
				mut buffer := []rune{cap: 100}
				unsafe { buffer.flags.set(.noslices) }
				beg := int(input_state.select_beg)
				end := int(input_state.select_end)
				for line in shape.text_lines {
					if count >= end {
						break
					}
					// Add a space between lines if we are inside the selection
					if count > beg {
						buffer << ` `
					}
					for r in line.runes_iterator() {
						if count >= end {
							break
						}
						// Collect characters within the selection range
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

// select_all selects all text in the TextView by setting the selection range
// from the beginning to the end of the text. The cursor position is moved to
// the end of the text. Does nothing if the placeholder is active.
pub fn (tv &TextView) select_all(shape &Shape, mut w Window) {
	if tv.placeholder_active {
		return
	}
	input_state := w.view_state.input_state[tv.id_focus]
	len := utf8_str_visible_length(tv.text)
	w.view_state.input_state[tv.id_focus] = InputState{
		...input_state
		cursor_pos:    len
		select_beg:    0
		select_end:    u32(len)
		cursor_offset: offset_from_cursor_position(shape, len, w)
	}
}

// unselect_all clears any active text selection and resets the cursor
// position to the beginning of the text. This collapses the selection range
// to zero.
pub fn (tv &TextView) unselect_all(mut w Window) {
	input_state := w.view_state.input_state[tv.id_focus]
	w.view_state.input_state[tv.id_focus] = InputState{
		...input_state
		select_beg: 0
		select_end: 0
	}
}
