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
const text_double_click_frames = u64(24) // ~400ms at 60 fps

// selection_range returns (select_beg, select_end) for drag selection
@[inline]
fn selection_range(start_pos int, end_pos int) (u32, u32) {
	if start_pos < end_pos {
		return u32(start_pos), u32(end_pos)
	}
	return u32(end_pos), u32(start_pos)
}

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

@[heap; minify]
pub struct TextView implements View {
	TextCfg
mut:
	content []View // not used
}

fn (mut tv TextView) generate_layout(mut window Window) Layout {
	window.stats.increment_layouts()
	window.stats.increment_text_views()

	input_state := state_map[u32, InputState](mut window, ns_input, cap_many).get(tv.id_focus) or {
		InputState{}
	}
	mut events := unsafe { &EventHandlers(nil) }
	if tv.on_char != unsafe { nil } || tv.on_key_down != unsafe { nil }
		|| tv.on_click != unsafe { nil } || tv.on_mouse_scroll_hook != unsafe { nil } {
		mut text_events := &EventHandlers{
			on_char:    tv.on_char
			on_keydown: tv.on_key_down
			on_click:   tv.on_click
		}
		if tv.on_mouse_scroll_hook != unsafe { nil } {
			text_events.on_mouse_scroll = tv.on_mouse_scroll
		}
		events = text_events
	}
	mut layout := Layout{
		shape: &Shape{
			shape_type: .text
			id:         tv.id
			id_focus:   tv.id_focus
			a11y_role:  .static_text
			a11y:       make_a11y_info(a11y_label(tv.a11y_label, tv.text), tv.a11y_description)
			clip:       tv.clip
			focus_skip: tv.focus_skip
			disabled:   tv.disabled
			min_width:  tv.min_width
			sizing:     tv.sizing
			events:     events
			hero:       tv.hero
			opacity:    tv.opacity
			tc:         &ShapeTextConfig{
				text:                tv.text
				text_is_password:    tv.is_password
				text_is_placeholder: tv.placeholder_active
				text_mode:           tv.mode
				text_style:          &tv.text_style
				text_sel_beg:        input_state.select_beg
				text_sel_end:        input_state.select_end
				text_tab_size:       tv.tab_size
			}
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
		layout.shape.height = layout.shape.min_height
	}
	apply_fixed_sizing_constraints(mut layout.shape)
	return layout
}

// TextCfg configures a [text](#text) view. It provides options for text content,
// styling, rendering mode, focus handling, and display behavior. Use this struct
// to create text views for labels, multiline text blocks, or interactive text
// with selection and copy capabilities. The [TextMode](#TextMode) field controls
// how text is wrapped and displayed (single line, multiline, or wrapped).
@[minify]
pub struct TextCfg {
	A11yCfg
	sizing Sizing
pub:
	id                   string
	text                 string
	text_style           TextStyle = gui_theme.text_style
	id_focus             u32
	tab_size             u32 = 4
	min_width            f32
	mode                 TextMode
	invisible            bool
	clip                 bool
	focus_skip           bool = true
	disabled             bool
	is_password          bool
	placeholder_active   bool
	hero                 bool
	opacity              f32 = 1.0
	on_char_hook         fn (&Layout, mut Event, mut Window) = unsafe { nil }
	on_key_down_hook     fn (&Layout, mut Event, mut Window) = unsafe { nil }
	on_mouse_scroll_hook fn (&Layout, mut Event, mut Window) = unsafe { nil }
}

// text is a general purpose text view. Use it for labels or larger
// blocks of multiline text. Giving it an id_focus allows mark and copy
// operations. See [TextCfg](#TextCfg)
pub fn text(cfg TextCfg) View {
	if cfg.invisible {
		return invisible_container_view()
	}
	return TextView{
		id:                   cfg.id
		text:                 cfg.text
		text_style:           cfg.text_style
		id_focus:             cfg.id_focus
		tab_size:             cfg.tab_size
		min_width:            cfg.min_width
		mode:                 cfg.mode
		invisible:            cfg.invisible
		clip:                 cfg.clip
		focus_skip:           cfg.focus_skip
		disabled:             cfg.disabled
		is_password:          cfg.is_password
		placeholder_active:   cfg.placeholder_active
		hero:                 cfg.hero
		opacity:              cfg.opacity
		on_char_hook:         cfg.on_char_hook
		on_key_down_hook:     cfg.on_key_down_hook
		on_mouse_scroll_hook: cfg.on_mouse_scroll_hook
		sizing:               if cfg.mode in [.wrap, .wrap_keep_spaces] { fill_fit } else { fit_fit }
	}
}

// on_click handles mouse click events for the TextView.
// It sets up mouse locking for drag selection updates and positions the text cursor
// based on the click coordinates. A double-click selects the word under the pointer.
fn (tv &TextView) on_click(layout &Layout, mut e Event, mut w Window) {
	if e.mouse_button == .left && layout.shape.id_focus > 0 {
		id_focus := layout.shape.id_focus
		placeholder_active := tv.placeholder_active
		cursor_pos := tv.mouse_cursor_pos(layout.shape, e, mut w)
		mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
		input_state := imap.get(id_focus) or { InputState{} }

		is_double_click := !placeholder_active && input_state.last_click_frame > 0
			&& e.frame_count - input_state.last_click_frame <= text_double_click_frames

		if is_double_click {
			word_beg := cursor_start_of_word(layout.shape, cursor_pos)
			word_end := cursor_end_of_word(layout.shape, cursor_pos)
			w.mouse_lock(
				cursor_pos: word_beg
				mouse_move: fn [placeholder_active, id_focus, word_beg, word_end] (layout &Layout, mut e Event, mut w Window) {
					if ly := layout.find_layout(fn [id_focus] (ly Layout) bool {
						return ly.shape.id_focus == id_focus
					})
					{
						text_double_click_drag(ly, mut e, mut w, placeholder_active, word_beg,
							word_end)
					}
				}
				mouse_up:   fn (layout &Layout, mut e Event, mut w Window) {
					w.mouse_unlock()
					w.remove_animation(id_auto_scroll_animation)
					e.is_handled = true
				}
			)
			imap.set(id_focus, InputState{
				...input_state
				cursor_pos:       word_end
				select_beg:       u32(word_beg)
				select_end:       u32(word_end)
				cursor_offset:    -1
				last_click_frame: 0
			})
			e.is_handled = true
			return
		}

		// single-click: set up drag selection and record frame
		w.mouse_lock(
			cursor_pos: cursor_pos
			mouse_move: fn [placeholder_active, id_focus] (layout &Layout, mut e Event, mut w Window) {
				// The layout in mouse locks is always the root layout.
				if ly := layout.find_layout(fn [id_focus] (ly Layout) bool {
					return ly.shape.id_focus == id_focus
				})
				{
					text_mouse_move_locked(ly, mut e, mut w, placeholder_active)
				}
			}
			mouse_up:   fn (layout &Layout, mut e Event, mut w Window) {
				w.mouse_unlock()
				w.remove_animation(id_auto_scroll_animation)
				e.is_handled = true
			}
		)
		cursor_offset := offset_from_cursor_position(layout.shape, cursor_pos, mut w)
		imap.set(id_focus, InputState{
			...input_state
			cursor_pos:       cursor_pos
			select_beg:       0
			select_end:       0
			cursor_offset:    cursor_offset
			last_click_frame: e.frame_count
		})
		e.is_handled = true
	}
}

// on_key_down handles keyboard input for navigation and text selection.
// It supports standard navigation keys (arrows, home, end) and modifiers
// (Alt, Ctrl, Shift) for word/line jumping and selection extension.
fn (tv &TextView) on_key_down(layout &Layout, mut e Event, mut window Window) {
	if tv.on_key_down_hook != unsafe { nil } {
		tv.on_key_down_hook(layout, mut e, mut window)
		if e.is_handled {
			return
		}
	}
	if window.is_focus(layout.shape.id_focus) {
		if tv.placeholder_active || window.mouse_is_locked() {
			return
		}
		// Suppress navigation while IME is composing
		if window.text_system != unsafe { nil } && window.text_system.is_composing() {
			return
		}
		mut imap := state_map[u32, InputState](mut window, ns_input, cap_many)
		mut input_state := imap.get(layout.shape.id_focus) or { InputState{} }
		mut pos := input_state.cursor_pos
		mut offset := input_state.cursor_offset

		// Pre-collapse selection for vertical navigation.
		// Up/down must collapse to boundary first, then navigate
		// from there (unlike left/right which just collapse).
		if input_state.select_beg != input_state.select_end && e.modifiers == .none {
			match e.key_code {
				.up {
					pos = int(input_state.select_beg)
					offset = offset_from_cursor_position(layout.shape, pos, mut window)
				}
				.down {
					pos = int(input_state.select_end)
					offset = offset_from_cursor_position(layout.shape, pos, mut window)
				}
				else {}
			}
		}

		// Handle navigation with modifiers
		if e.modifiers == .alt || e.modifiers == .alt_shift {
			// Alt: Jump by word or paragraph
			match e.key_code {
				.left { pos = cursor_start_of_word(layout.shape, pos) }
				.right { pos = cursor_end_of_word(layout.shape, pos) }
				.up { pos = cursor_start_of_paragraph(layout.shape, pos) }
				.down { pos = cursor_end_of_paragraph(layout.shape, pos) }
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
		imap.set(layout.shape.id_focus, InputState{
			...input_state
			cursor_pos:    pos
			select_beg:    select_beg
			select_end:    select_end
			cursor_offset: offset
		})

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
	if tv.on_char_hook != unsafe { nil } {
		tv.on_char_hook(layout, mut event, mut w)
		if event.is_handled {
			return
		}
	}
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

fn (tv &TextView) on_mouse_scroll(layout &Layout, mut e Event, mut w Window) {
	if tv.on_mouse_scroll_hook != unsafe { nil } {
		tv.on_mouse_scroll_hook(layout, mut e, mut w)
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
	input_state := state_read_or[u32, InputState](w, ns_input, cfg.id_focus, InputState{})

	// Only copy if there is an active selection
	if input_state.select_beg != input_state.select_end {
		beg := int(input_state.select_beg)
		end := int(input_state.select_end)
		// select_beg/end are rune indices (from mouse_cursor_pos which uses byte_to_rune_index)
		if beg < end && end <= utf8_str_visible_length(shape.tc.text) {
			cpy := shape.tc.text.runes()[beg..end].string()
			to_clipboard(cpy)
			return cpy
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
	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	input_state := imap.get(tv.id_focus) or { InputState{} }
	len := utf8_str_visible_length(tv.text)
	imap.set(tv.id_focus, InputState{
		...input_state
		cursor_pos:    len
		select_beg:    0
		select_end:    u32(len)
		cursor_offset: offset_from_cursor_position(shape, len, mut w)
	})
}

// unselect_all clears any active text selection and resets the cursor
// position to the beginning of the text. This collapses the selection range
// to zero.
pub fn (tv &TextView) unselect_all(mut w Window) {
	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	input_state := imap.get(tv.id_focus) or { InputState{} }
	imap.set(tv.id_focus, InputState{
		...input_state
		select_beg: 0
		select_end: 0
	})
}
