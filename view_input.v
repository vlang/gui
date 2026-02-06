module gui

// view_input.v provides input field functionality. It handles text input,
// cursor management, copy/paste operations, and undo/redo functionality.
// Both single-line and multiline modes are supported with customizable
// styling and behavior via InputCfg. Notable features:
// - Text selection and cursor positioning
// - Clipboard operations (copy, cut, paste)
// - Undo/redo stack
// - Password field masking and placeholder text
// - Custom callbacks for text changes and enter key
import log
import arrays

// InputState manages focus and input states. The window maintains this state
// in a map keyed by w.view_state.id_focus. This state map is cleared when a
// new view is introduced.
@[minify]
struct InputState {
pub:
	// number of runes relative to start of input text
	cursor_pos int
	select_beg u32
	select_end u32
	undo       BoundedStack[InputMemento]
	redo       BoundedStack[InputMemento]
	// cursor_offset is used to maintain the horizontal offset of the cursor
	// when traversing vertically through text. It is reset when a non-vertical
	// navigation operation occurs.
	cursor_offset f32
pub mut:
	composition_text string // in-progress IME text
}

// InputMemento stores a snapshot of the input state for undo/redo
// operations. Storing the full text is less memory efficient than operational
// transforms but simplifies implementation and debugging. Given typical input
// field sizes, the tradeoff is acceptable.
@[minify]
struct InputMemento {
pub:
	text          string
	cursor_pos    int
	select_beg    u32
	select_end    u32
	cursor_offset f32
}

pub enum InputMode as u8 {
	single_line
	multiline
}

// InputCfg configures an input view. See [input](#input). Use
// `on_text_changed` to capture text updates. To capture the enter-key, provide
// an `on_enter` callback. Placeholder text is shown when the field is empty.
@[heap; minify]
pub struct InputCfg {
pub:
	id                 string
	text               string // text to display/edit
	icon               string // icon constant
	placeholder        string // text to show when empty
	on_text_changed    fn (&Layout, string, mut Window)    = unsafe { nil }
	on_enter           fn (&Layout, mut Event, mut Window) = unsafe { nil }
	on_click_icon      fn (&Layout, mut Event, mut Window) = unsafe { nil }
	scrollbar_cfg_x    &ScrollbarCfg                       = unsafe { nil }
	scrollbar_cfg_y    &ScrollbarCfg                       = unsafe { nil }
	tooltip            &TooltipCfg                         = unsafe { nil }
	sizing             Sizing
	text_style         TextStyle = gui_theme.input_style.text_style
	placeholder_style  TextStyle = gui_theme.input_style.placeholder_style
	icon_style         TextStyle = gui_theme.input_style.icon_style
	width              f32
	height             f32
	min_width          f32
	min_height         f32
	max_width          f32
	max_height         f32
	radius             f32 = gui_theme.input_style.radius
	radius_border      f32 = gui_theme.input_style.radius_border
	id_focus           u32 // 0 = readonly, >0 = focusable and tabbing order
	id_focus_override  u32
	id_scroll          u32
	scroll_mode        ScrollMode
	padding            Padding = gui_theme.input_style.padding
	size_border        f32     = gui_theme.input_style.size_border
	color              Color   = gui_theme.input_style.color
	color_hover        Color   = gui_theme.input_style.color_hover
	color_border       Color   = gui_theme.input_style.color_border
	color_border_focus Color   = gui_theme.input_style.color_border_focus
	mode               InputMode // enable multiline
	disabled           bool
	invisible          bool
	is_password        bool // mask input characters with '*'s
}

// input
//
// Example:
// ```v
// gui.input(
// 	id_focus:        1
// 	text:            app.input_a
// 	min_width:       100
// 	max_width:       100
// 	on_text_changed: fn (_ &gui.InputCfg, s string, mut w gui.Window) {
// 		mut state := w.state[App]()
// 		state.input_a = s
// 	}
// )
// ```
// input is a text input field.
//
// - id_focus is required to enable editing features.
// - Input fields without an `on_text_changed` callback are read-only.
// - is_password flag causes the input view to display '*'s.
// - Copy operation is disabled when is_password is true.
// - wrap allows the input fields to be multiline.
//
// Keyboard shortcuts:
// - left/right: moves cursor left/right one character
// - ctrl+left: moves to start of line; if at start, moves up one line
// - ctrl+right: moves to end of line; if at end, moves down one line
// - alt+left: moves to end of previous word (option+left on Mac)
// - alt+right: moves to start of word (option+left on Mac)
// - home: move cursor to start of text
// - end: move cursor to end of text
// - Add shift to above shortcuts to select text
//
// - ctrl+a: selects all text (cmd+a on Mac)
// - ctrl+c: copies selected text (cmd+c on Mac)
// - ctrl+v: pastes text (cmd+v on Mac)
// - ctrl+x: deletes text (cmd+x on Mac)
// - ctrl+z: undo (cmd+z on Mac)
// - shift+ctrl+z: redo (shift+cmd+z on Mac)
// - escape: unselects all text
// - delete: deletes previous character
// - backspace: deletes previous character
pub fn input(cfg InputCfg) View {
	placeholder_active := cfg.text.len == 0
	txt := if placeholder_active { cfg.placeholder } else { cfg.text }
	txt_style := if placeholder_active { cfg.placeholder_style } else { cfg.text_style }
	mode := if cfg.mode == .single_line { TextMode.single_line } else { TextMode.wrap_keep_spaces }

	// Capture values needed for callbacks by copy to avoid dangling reference to cfg
	color_border_focus := cfg.color_border_focus
	color_hover := cfg.color_hover
	id_focus := cfg.id_focus
	on_click_icon := cfg.on_click_icon

	return column(
		name:               'input'
		id:                 cfg.id
		id_focus:           cfg.id_focus
		tooltip:            cfg.tooltip
		width:              cfg.width
		height:             cfg.height
		min_width:          cfg.min_width
		max_width:          cfg.max_width
		min_height:         cfg.min_height
		max_height:         cfg.max_height
		disabled:           cfg.disabled
		clip:               true
		color:              cfg.color
		color_border:       cfg.color_border
		size_border:        cfg.size_border
		invisible:          cfg.invisible
		padding:            cfg.padding
		radius:             cfg.radius
		sizing:             cfg.sizing
		on_char:            make_input_on_char(cfg)
		on_ime_composition: make_input_on_ime_composition(cfg)
		on_ime_result:      make_input_on_ime_result(cfg)
		on_hover:           fn [color_hover, id_focus] (mut layout Layout, mut e Event, mut w Window) {
			if w.is_focus(id_focus) {
				w.set_mouse_cursor_ibeam()
			} else {
				layout.shape.color = color_hover
			}
		}
		amend_layout:       fn [color_border_focus] (mut layout Layout, mut w Window) {
			if layout.shape.disabled {
				return
			}
			if layout.shape.id_focus > 0 && layout.shape.id_focus == w.id_focus() {
				layout.shape.color_border = color_border_focus
			}
		}
		id_scroll:          cfg.id_scroll
		scrollbar_cfg_x:    cfg.scrollbar_cfg_x
		scrollbar_cfg_y:    cfg.scrollbar_cfg_y
		spacing:            0
		content:            [
			row(
				name:     'input interior'
				padding:  padding_none
				sizing:   fill_fill
				on_click: fn (layout &Layout, mut e Event, mut w Window) {
					if layout.children.len < 1 {
						return
					}
					ly := layout.children[0]
					if ly.shape.id_focus > 0 {
						w.set_id_focus(ly.shape.id_focus)
					}
				}
				content:  [
					text(
						id_focus:           cfg.id_focus
						sizing:             fill_fill
						text:               txt
						text_style:         txt_style
						mode:               mode
						is_password:        cfg.is_password
						placeholder_active: placeholder_active
					),
					rectangle(
						color:        color_transparent
						color_border: color_transparent
						sizing:       fill_fill
					),
					row(
						name:     'input icon'
						padding:  padding_none
						on_click: cfg.on_click_icon
						on_hover: fn [on_click_icon] (mut layout Layout, mut e Event, mut w Window) {
							if on_click_icon != unsafe { nil } {
								w.set_mouse_cursor_pointing_hand()
							}
						}
						content:  [
							text(
								text:       cfg.icon
								text_style: cfg.icon_style
							),
						]
					),
				]
			),
		]
	)
}

// delete removes text based on cursor position or selection. If text is
// selected, the entire selection is deleted. Otherwise, it deletes the
// character before (backspace) or after (delete) the cursor. Saves state to
// undo stack before modification. Returns modified text or none if invalid.
fn (cfg &InputCfg) delete(mut w Window, is_delete bool) ?string {
	mut text := cfg.text.runes()
	input_state := w.view_state.input_state.get(cfg.id_focus) or { InputState{} }
	mut cursor_pos := input_state.cursor_pos
	if cursor_pos < 0 {
		cursor_pos = cfg.text.len
	} else if input_state.select_beg != input_state.select_end {
		beg, end := u32_sort(input_state.select_beg, input_state.select_end)
		if beg >= text.len || end > text.len {
			log.error('beg or end out of range (delete)')
			return none
		}
		text = arrays.append(text[..beg], text[end..])
		cursor_pos = int_min(int(beg), text.len)
	} else {
		if cursor_pos == 0 && !is_delete {
			return text.string()
		}
		if cursor_pos > text.len {
			log.error('cursor_pos out of range (delete)')
			return none
		}
		step := if is_delete { 1 } else { 0 }
		step_beg := cursor_pos - 1 + step
		step_end := cursor_pos + step
		if step_beg < 0 && step_end >= text.len {
			return none
		}
		text = arrays.append(text[..step_beg], text[step_end..])
		if !is_delete {
			cursor_pos--
		}
	}
	mut undo := input_state.undo
	undo.push(InputMemento{
		text:          cfg.text
		cursor_pos:    input_state.cursor_pos
		select_beg:    input_state.select_beg
		select_end:    input_state.select_end
		cursor_offset: input_state.cursor_offset
	})
	w.view_state.input_state.set(cfg.id_focus, InputState{
		cursor_pos:    cursor_pos
		select_beg:    0
		select_end:    0
		undo:          undo
		cursor_offset: -1 // view_text.v-on_key_down-up/down handler tests for < 0
	})
	return text.string()
}

// insert adds text at the cursor or replaces selection. For single-line
// fixed-width inputs, it validates width constraints. Saves state to undo
// stack before modification. Returns modified text or error.
fn (cfg &InputCfg) insert(s string, mut w Window) !string {
	// clamp max chars to width of box when single line fixed.
	if cfg.mode == .single_line && cfg.sizing.width == .fixed {
		ctx := w.ui
		ctx.set_text_cfg(cfg.text_style.to_text_cfg())
		width := ctx.text_width(cfg.text + s)
		if width > cfg.width - cfg.padding.width() - (cfg.size_border * 2) {
			return cfg.text
		}
	}
	mut text := cfg.text.runes()
	input_state := w.view_state.input_state.get(cfg.id_focus) or { InputState{} }
	mut cursor_pos := input_state.cursor_pos
	if cursor_pos < 0 {
		text = arrays.append(cfg.text.runes(), s.runes())
		cursor_pos = text.len
	} else if input_state.select_beg != input_state.select_end {
		beg, end := u32_sort(input_state.select_beg, input_state.select_end)
		if beg >= text.len || end > text.len {
			return error('beg or end out of range (insert)')
		}
		rs := s.runes()
		text = arrays.append(arrays.append(text[..beg], rs), text[end..])
		cursor_pos = int_min(int(beg) + rs.len, text.len)
	} else {
		if cursor_pos > text.len {
			return error('cursor_pos out of range (insert)')
		}
		rs := s.runes()
		text = arrays.append(arrays.append(text[..cursor_pos], rs), text[cursor_pos..])
		cursor_pos = int_min(cursor_pos + rs.len, text.len)
	}
	mut undo := input_state.undo
	undo.push(InputMemento{
		text:          cfg.text
		cursor_pos:    input_state.cursor_pos
		select_beg:    input_state.select_beg
		select_end:    input_state.select_end
		cursor_offset: input_state.cursor_offset
	})
	w.view_state.input_state.set(cfg.id_focus, InputState{
		cursor_pos:    cursor_pos
		select_beg:    0
		select_end:    0
		undo:          undo
		cursor_offset: -1 // view_text.v-on_key_down-up/down handler tests for < 0
	})
	return text.string()
}

// cut copies selected text to clipboard then deletes it. Returns modified
// text. Disabled for password fields.
pub fn (cfg &InputCfg) cut(mut w Window) ?string {
	if cfg.is_password {
		return none
	}
	cfg.copy(w)
	return cfg.delete(mut w, false)
}

// copy copies selected text to clipboard. Returns none if successful or
// disabled (password fields).
pub fn (cfg &InputCfg) copy(w &Window) ?string {
	if cfg.is_password {
		return none
	}
	input_state := w.view_state.input_state.get(cfg.id_focus) or { InputState{} }
	if input_state.select_beg != input_state.select_end {
		beg, end := u32_sort(input_state.select_beg, input_state.select_end)
		len := utf8_str_visible_length(cfg.text)
		if beg >= len || end > len {
			log.error('beg or end out of range (copy)')
			return none
		}
		rune_text := cfg.text.runes()
		if beg < 0 || end >= len {
			return none
		}
		cpy := rune_text[beg..end]
		to_clipboard(cpy.string())
	}
	return none
}

// paste inserts clipboard text at cursor or replaces selection. Returns
// modified text.
pub fn (cfg &InputCfg) paste(s string, mut w Window) !string {
	return cfg.insert(s, mut w)
}

// undo reverts to previous state from undo stack and pushes current state
// to redo stack. Returns restored text or current text if stack empty.
pub fn (cfg &InputCfg) undo(mut w Window) string {
	input_state := w.view_state.input_state.get(cfg.id_focus) or { InputState{} }
	mut undo := input_state.undo
	memento := undo.pop() or { return cfg.text }
	mut redo := input_state.redo
	redo.push(InputMemento{
		text:          cfg.text
		cursor_pos:    input_state.cursor_pos
		select_beg:    input_state.select_beg
		select_end:    input_state.select_end
		cursor_offset: input_state.cursor_offset
	})
	w.view_state.input_state.set(cfg.id_focus, InputState{
		cursor_pos:    memento.cursor_pos
		select_beg:    memento.select_beg
		select_end:    memento.select_end
		undo:          undo
		redo:          redo
		cursor_offset: memento.cursor_offset
	})
	return memento.text
}

// redo reapplies a previously undone operation. Returns restored text or
// current text if stack empty.
pub fn (cfg &InputCfg) redo(mut w Window) string {
	input_state := w.view_state.input_state.get(cfg.id_focus) or { InputState{} }
	mut redo := input_state.redo
	memento := redo.pop() or { return cfg.text }
	mut undo := input_state.undo
	undo.push(InputMemento{
		text:          cfg.text
		cursor_pos:    input_state.cursor_pos
		select_beg:    input_state.select_beg
		select_end:    input_state.select_end
		cursor_offset: input_state.cursor_offset
	})
	w.view_state.input_state.set(cfg.id_focus, InputState{
		cursor_pos:    memento.cursor_pos
		select_beg:    memento.select_beg
		select_end:    memento.select_end
		cursor_offset: memento.cursor_offset
		undo:          undo
		redo:          redo
	})
	return memento.text
}

// amend_layout adjusts appearance during layout, effectively updating visual
// hints like border color based on focus/disabled state.
fn (cfg &InputCfg) amend_layout(mut layout Layout, mut w Window) {
	if layout.shape.disabled {
		return
	}
	if layout.shape.id_focus > 0 && layout.shape.id_focus == w.id_focus() {
		layout.shape.color_border = cfg.color_border_focus
	}
}

// hover handles mouse-over events. Sets I-beam cursor when focused,
// otherwise applies hover color.
fn (cfg &InputCfg) hover(mut layout Layout, mut e Event, mut w Window) {
	if w.is_focus(layout.shape.id_focus) {
		w.set_mouse_cursor_ibeam()
	} else {
		layout.shape.color = cfg.color_hover
	}
}

// hover_icon changes cursor to pointing hand if icon is interactive.
fn (_ &InputCfg) hover_icon(mut layout Layout, mut e Event, mut w Window) {
	if layout.shape.on_click != unsafe { nil } {
		w.set_mouse_cursor_pointing_hand()
	}
}

// make_input_on_ime_composition creates a handler for in-progress IME text.
fn make_input_on_ime_composition(cfg InputCfg) fn (&Layout, mut Event, mut Window) {
	return fn [cfg] (layout &Layout, mut event Event, mut w Window) {
		mut state := w.view_state.input_state.get(cfg.id_focus) or { return }
		state.composition_text = event.ime_text
		w.view_state.input_state.set(cfg.id_focus, state)
		w.update_window()
		event.is_handled = true
	}
}

// make_input_on_ime_result creates a handler for committed IME text.
fn make_input_on_ime_result(cfg InputCfg) fn (&Layout, mut Event, mut Window) {
	return fn [cfg] (layout &Layout, mut event Event, mut w Window) {
		if cfg.on_text_changed != unsafe { nil } {
			res := cfg.insert(event.ime_text, mut w) or {
				log.error(err.msg())
				return
			}
			// Clear composition text upon commitment
			mut state := w.view_state.input_state.get(cfg.id_focus) or { return }
			state.composition_text = ''
			w.view_state.input_state.set(cfg.id_focus, state)

			event.is_handled = true
			cfg.on_text_changed(layout, res, mut w)
		}
	}
}

// make_input_on_char creates an on_char handler that captures the InputCfg
// by value to avoid dangling reference issues. The InputCfg is heap-allocated
// due to its @[heap] attribute.
fn make_input_on_char(cfg InputCfg) fn (&Layout, mut Event, mut Window) {
	return fn [cfg] (layout &Layout, mut event Event, mut w Window) {
		if w.mouse_is_locked() {
			return
		}
		c := event.char_code
		if cfg.on_text_changed != unsafe { nil } {
			mut text := cfg.text
			if event.modifiers == .ctrl_shift {
				match c {
					ctrl_z { text = cfg.redo(mut w) }
					else {}
				}
			} else if event.modifiers == .super_shift {
				match c {
					cmd_z { text = cfg.redo(mut w) }
					else {}
				}
			} else if event.modifiers == .ctrl {
				match c {
					ctrl_v { text = cfg.paste(from_clipboard(), mut w) or { return } }
					ctrl_x { text = cfg.cut(mut w) or { return } }
					ctrl_z { text = cfg.undo(mut w) }
					else {}
				}
			} else if event.modifiers == .super {
				match c {
					cmd_v { text = cfg.paste(from_clipboard(), mut w) or { return } }
					cmd_x { text = cfg.cut(mut w) or { return } }
					cmd_z { text = cfg.undo(mut w) }
					else {}
				}
			} else {
				match c {
					bsp_char {
						text = cfg.delete(mut w, false) or { return }
					}
					del_char {
						$if macos {
							text = cfg.delete(mut w, false) or { return }
						} $else {
							text = cfg.delete(mut w, true) or { return }
						}
					}
					cr_char, lf_char {
						if cfg.on_enter != unsafe { nil } {
							cfg.on_enter(layout, mut event, mut w)
							event.is_handled = true
							return
						} else {
							if cfg.mode != .single_line {
								text = cfg.insert('\n', mut w) or {
									log.error(err.msg())
									return
								}
							}
						}
					}
					0...0x1F { // non-printable
						return
					}
					else {
						text = cfg.insert(rune(c).str(), mut w) or {
							log.error(err.msg())
							return
						}
					}
				}
			}
			event.is_handled = true
			cfg.on_text_changed(layout, text, mut w)
		}
	}
}
