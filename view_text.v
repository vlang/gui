module gui

// view_text.v implements text rendering and input handling for single-line
// and multi-line text views. It provides support for text selection, cursor
// movement, copy operations, password masking, and placeholders. The TextView
// component can be configured to handle different text modes including single
// line, multiline with wrapping, and preserving whitespace.
//
import math
import time

const id_auto_scroll_animation = 'auto_scroll_animation'
const auto_scroll_slow = 150 * time.millisecond
const auto_scroll_medium = 80 * time.millisecond
const auto_scroll_fast = 30 * time.millisecond

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
mut:
	content []View // not used
}

fn (mut tv TextView) generate_layout(mut window Window) Layout {
	stats_increment_layouts()

	input_state := window.view_state.input_state[tv.id_focus]
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

	// Optimization: Measure text width directly without layout generation.
	// This provides the "intrinsic width" (single line) which is essential for .fit containers (like Menus).
	// The main layout pipeline will handle wrapping constraints later if needed.
	// We use `text_width` which enables `no_hit_testing`, ensuring this is fast.
	layout.shape.width = text_width(tv.text, tv.text_style, mut window)
	layout.shape.height = line_height(layout.shape, mut window)

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
	sizing Sizing
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
pub fn text(cfg TextCfg) View {
	stats_increment_text_views()
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
	if e.mouse_button == .left && layout.shape.id_focus > 0 {
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
		cursor_offset := offset_from_cursor_position(layout.shape, cursor_pos, mut w)
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
	// mouse_move events don't have mouse button info. Use context.
	if w.ui.mouse_buttons == .left {
		if tv.placeholder_active {
			return
		}

		id_focus := layout.shape.id_focus
		id_scroll_container := layout.shape.id_scroll_container

		start_cursor_pos := w.view_state.mouse_lock.cursor_pos
		ev := event_relative_to(layout.shape, e)
		mut mouse_cursor_pos := tv.mouse_cursor_pos(layout.shape, ev, mut w)

		scroll_y := cursor_pos_to_scroll_y(mouse_cursor_pos, layout.shape, mut w)
		current_scroll_y := w.view_state.scroll_y[id_scroll_container]

		if scroll_y != current_scroll_y {
			if !w.has_animation(id_auto_scroll_animation) {
				w.animation_add(mut Animate{
					id:       id_auto_scroll_animation
					callback: fn [tv, id_focus, id_scroll_container] (mut an Animate, mut w Window) {
						tv.auto_scroll_cursor(id_focus, id_scroll_container, mut an, mut
							w)
					}
					delay:    auto_scroll_slow
					repeat:   true
				})
			}
			return
		} else {
			w.remove_animation(id_auto_scroll_animation)
		}

		w.view_state.input_state[id_focus] = InputState{
			...w.view_state.input_state[id_focus]
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
fn (tv &TextView) mouse_up_locked(layout &Layout, mut e Event, mut w Window) {
	w.remove_animation(id_auto_scroll_animation)
	e.is_handled = true
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
		mut pos := input_state.cursor_pos
		mut offset := input_state.cursor_offset

		// Handle navigation with modifiers
		if e.modifiers == .alt || e.modifiers == .alt_shift {
			// Alt: Jump by word or paragraph
			match e.key_code {
				.left { pos = cursor_start_of_word(layout.shape, pos) }
				.right { pos = cursor_end_of_word(layout.shape, pos) }
				.up { pos = cursor_start_of_paragraph(layout.shape, pos) }
				else { return }
			}
		} else if e.modifiers == .ctrl || e.modifiers == .ctrl_shift {
			// Ctrl: Jump to start/end of line
			match e.key_code {
				.left { pos = cursor_start_of_line(layout.shape, pos) }
				.right { pos = cursor_end_of_line(layout.shape, pos) }
				else { return }
			}
		} else if e.modifiers.has_any(.none, .shift) {
			// Standard navigation: char by char, prev/next line, home/end of text
			mut lpp := 0 // lines per page
			layout_scroll := find_layout_by_id_scroll(window.layout, layout.shape.id_scroll_container)
			if layout_scroll != none {
				layout_scroll_height := layout_scroll.shape.height - layout_scroll.shape.padding.height()
				lpp = int(layout_scroll_height / line_height(layout.shape, mut window))
			}
			match e.key_code {
				.left { pos = cursor_left(pos) }
				.right { pos = cursor_right(layout.shape, pos) }
				.up { pos = cursor_up(layout.shape, pos, offset, 1, mut window) }
				.down { pos = cursor_down(layout.shape, pos, offset, 1, mut window) }
				.page_up { pos = cursor_up(layout.shape, pos, offset, lpp, mut window) }
				.page_down { pos = cursor_down(layout.shape, pos, offset, lpp, mut window) }
				.home { pos = cursor_home() }
				.end { pos = cursor_end(layout.shape) }
				else { return }
			}
		} else if e.modifiers == Modifier.super {
			return
		}

		if (e.key_code != .up && e.key_code != .down) || input_state.cursor_offset < 0 {
			offset = offset_from_cursor_position(layout.shape, pos, mut window)
		}

		// input_cursor_on_sticky allows the cursor to stay on during cursor movements.
		// See `blinky_cursor_animation()`
		if pos != input_state.cursor_pos {
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
				select_beg = u32(pos)
			} else if old_cursor_pos == int(select_end) {
				select_end = u32(pos)
			} else {
				// If the old cursor was not at a boundary (e.g., from a click),
				// move the boundary closest to the new cursor position.
				if math.abs(pos - int(select_beg)) < math.abs(pos - int(select_end)) {
					select_beg = u32(pos)
				} else {
					select_end = u32(pos)
				}
			}
			// Ensure beg is always less than or equal to end
			if select_beg > select_end {
				select_beg, select_end = select_end, select_beg
			}
		} else if input_state.select_beg != input_state.select_end && e.modifiers == .none {
			// If a selection exists and a non-shift movement key is pressed,
			// collapse the selection to the beginning or end of the selection.
			pos = match e.key_code {
				.left, .home { int(input_state.select_beg) }
				.right, .end { int(input_state.select_end) }
				else { pos }
			}
		}

		// Update input state with new cursor position and selection
		window.view_state.input_state[layout.shape.id_focus] = InputState{
			...input_state
			cursor_pos:    pos
			select_beg:    select_beg
			select_end:    select_end
			cursor_offset: offset
		}

		// Ensure the new cursor position is visible
		scroll_cursor_into_view(pos, layout, mut window)
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
		// Use shape.text source of truth
		beg := int(input_state.select_beg)
		end := int(input_state.select_end)
		if beg < end && end <= shape.text.len { // Check bounds just in case? visual indices are runes?
			// input_state.select_beg/end are likely rune indices (based on usage elsewhere)
			// Need to slice runes.
			// shape.text.runes()[beg..end]
			// This is expensive but safe.

			// Wait, are select_beg/end byte indices or rune indices?
			// `on_click`: cursor_pos := tv.mouse_cursor_pos(...)
			// `mouse_cursor_pos` returns `byte_to_rune_index`. So they are Rune indices.

			// So we must slice runes.
			cpy := shape.text.runes()[beg..end].string()
			to_clipboard(cpy)
		}
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
		cursor_offset: offset_from_cursor_position(shape, len, mut w)
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
