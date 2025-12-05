module gui

// view_input.v provides input field functionality for GUI applications.
// It handles text input, cursor management, copy/paste operations, and undo/redo functionality.
// The file implements both single-line and multiline input modes with customizable styling
// and behavior through the InputCfg struct. Key features include:
// - Text selection and cursor positioning
// - Clipboard operations (copy, cut, paste)
// - Undo/redo stack
// - Password field masking
// - Placeholder text
// - Custom callbacks for text changes and enter key
// - Themeable appearance
//
import log
import datatypes
import arrays

// The management of focus and input states poses a problem in stateless views
// because...they're stateless. Instead, the window maintains this state in a
// map where the key is the w.view_state.id_focus. This state map is cleared when a new
// view is introduced.
@[minify]
struct InputState {
pub:
	// positions are number of runes relative to start of input text
	cursor_pos int
	select_beg u32
	select_end u32
	undo       datatypes.Stack[InputMemento]
	redo       datatypes.Stack[InputMemento]
}

@[minify]
struct InputMemento {
pub:
	text       string
	cursor_pos int
	select_beg u32
	select_end u32
}

pub enum InputMode as u8 {
	single_line
	multiline
}

// InputCfg configures an input view. See [input](#input). Use `on_text_changed` to
// capture text updates. To capture the enter-key, provide an `on_enter` callback.
// Placeholder text is shown when the input field is empty.
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
	padding            Padding = gui_theme.input_style.padding
	padding_border     Padding = gui_theme.input_style.padding_border
	color              Color   = gui_theme.input_style.color
	color_hover        Color   = gui_theme.input_style.color_hover
	color_border       Color   = gui_theme.input_style.color_border
	color_border_focus Color   = gui_theme.input_style.color_border_focus
	mode               InputMode // enable multiline
	disabled           bool
	invisible          bool
	is_password        bool // mask input characters with '*'s
	fill               bool = gui_theme.input_style.fill
	fill_border        bool = gui_theme.input_style.fill_border
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
// - wrap allows the input fields to be multiline. See [InputCfg](#InputCfg)
//
// #### Keyboard shortcuts (not final):
// - **left/right**    moves cursor left/right one character
// - **ctrl+left**     moves to start of line, if at start of line moves up one line
// - **ctrl+right**    moves to end of line, if at end of line moves down one line
// - **alt+left**      moves to end of previous word (option+left on Mac)
// - **alt+right**     moves to start of word (option+left on Mac)
// - **home**          move cursor to start of text
// - **end**           move cursor to end of text
// - Add shift to above shortcuts to select text
// ---
// - **ctrl+a**        selects all text (also **cmd+a** on Mac)
// - **ctrl+c**        copies selected text (also **cmd+c** on Mac)
// - **ctrl+v**        pastes text (also **cmd+v** on Mac)
// - **ctrl+x**        deletes text (also **cmd+x** on Mac)
// - **ctrl+z**        undo (also **cmd+z** on Mac)
// - **shift+ctrl+z**  redo (also **shift+cmd+z** on Mac)
// - **escape**        unselects all text
// - **delete**        deletes previous character
// - **backspace**     deletes previous character
// ---
// - left/right arrow keys move cursor to beg/end of selection, when text is selected
pub fn input(cfg InputCfg) View {
	placeholder_active := cfg.text.len == 0
	txt := if placeholder_active { cfg.placeholder } else { cfg.text }
	txt_style := if placeholder_active { cfg.placeholder_style } else { cfg.text_style }
	mode := if cfg.mode == .single_line { TextMode.single_line } else { TextMode.wrap_keep_spaces }

	return row(
		name:         'input border'
		id:           cfg.id
		id_focus:     cfg.id_focus
		width:        cfg.width
		height:       cfg.height
		min_width:    cfg.min_width
		max_width:    cfg.max_width
		min_height:   cfg.min_height
		max_height:   cfg.max_height
		padding:      cfg.padding_border
		color:        cfg.color_border
		fill:         cfg.fill_border
		sizing:       cfg.sizing
		radius:       cfg.radius_border
		disabled:     cfg.disabled
		invisible:    cfg.invisible
		on_char:      cfg.on_char
		amend_layout: cfg.amend_layout
		on_hover:     cfg.hover
		content:      [
			row(
				name:     'input interior'
				color:    cfg.color
				padding:  cfg.padding
				fill:     cfg.fill
				sizing:   fill_fill
				radius:   cfg.radius
				spacing:  spacing_small
				on_click: cfg.on_click_interior
				content:  [
					text(
						id_focus:           cfg.id_focus
						text:               txt
						text_style:         txt_style
						mode:               mode
						is_password:        cfg.is_password
						placeholder_active: placeholder_active
					),
					rectangle(
						color:  color_transparent
						sizing: fill_fit
					),
					row(
						name:     'input icon'
						padding:  padding_none
						on_click: cfg.on_click_icon
						on_hover: cfg.hover_icon
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

// on_click_interior handles clicking in the control but outside the text region
// by forwarding it to the text view.
fn (_ &InputCfg) on_click_interior(layout &Layout, mut e Event, mut w Window) {
	if layout.children.len < 1 {
		return
	}
	ly := layout.children[0]
	if ly.shape.id_focus > 0 {
		w.set_id_focus(ly.shape.id_focus)
	}
	ly.shape.on_click(ly, mut e, mut w)
}

fn (cfg &InputCfg) on_char(layout &Layout, mut event Event, mut w Window) {
	c := event.char_code
	if cfg.on_text_changed != unsafe { nil } {
		mut text := cfg.text
		if event.modifiers.has_all(.ctrl, .shift) {
			match c {
				ctrl_z { text = cfg.redo(mut w) }
				else {}
			}
		} else if event.modifiers.has_all(.super, .shift) {
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

fn (cfg &InputCfg) delete(mut w Window, is_delete bool) ?string {
	mut text := cfg.text.runes()
	input_state := w.view_state.input_state[cfg.id_focus]
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
		text:       cfg.text
		cursor_pos: input_state.cursor_pos
		select_beg: input_state.select_beg
		select_end: input_state.select_end
	})
	w.view_state.input_state[cfg.id_focus] = InputState{
		cursor_pos: cursor_pos
		select_beg: 0
		select_end: 0
		undo:       undo
	}
	return text.string()
}

fn (cfg &InputCfg) insert(s string, mut w Window) !string {
	// clamp max chars to width of box when single line fixed.
	if cfg.mode == .single_line && cfg.sizing.width == .fixed {
		ctx := w.ui
		ctx.set_text_cfg(cfg.text_style.to_text_cfg())
		width := ctx.text_width(cfg.text + s)
		if width > cfg.width - cfg.padding.width() - cfg.padding_border.width() {
			return cfg.text
		}
	}
	mut text := cfg.text.runes()
	input_state := w.view_state.input_state[cfg.id_focus]
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
		text:       cfg.text
		cursor_pos: input_state.cursor_pos
		select_beg: input_state.select_beg
		select_end: input_state.select_end
	})
	w.view_state.input_state[cfg.id_focus] = InputState{
		cursor_pos: cursor_pos
		select_beg: 0
		select_end: 0
		undo:       undo
	}
	return text.string()
}

pub fn (cfg &InputCfg) cut(mut w Window) ?string {
	if cfg.is_password {
		return none
	}
	cfg.copy(w)
	return cfg.delete(mut w, false)
}

pub fn (cfg &InputCfg) copy(w &Window) ?string {
	if cfg.is_password {
		return none
	}
	input_state := w.view_state.input_state[cfg.id_focus]
	if input_state.select_beg != input_state.select_end {
		beg, end := u32_sort(input_state.select_beg, input_state.select_end)
		len := cfg.text.runes().len
		if beg >= len || end > len {
			log.error('beg or end out of range (copy)')
			return none
		}
		rune_text := cfg.text.runes()
		if beg < 0 || end >= rune_text.len {
			return none
		}
		cpy := rune_text[beg..end]
		to_clipboard(cpy.string())
	}
	return none
}

pub fn (cfg &InputCfg) paste(s string, mut w Window) !string {
	return cfg.insert(s, mut w)
}

pub fn (cfg &InputCfg) undo(mut w Window) string {
	input_state := w.view_state.input_state[cfg.id_focus]
	mut undo := input_state.undo
	memento := undo.pop() or { return cfg.text }
	mut redo := input_state.redo
	redo.push(InputMemento{
		text:       cfg.text
		cursor_pos: input_state.cursor_pos
		select_beg: input_state.select_beg
		select_end: input_state.select_end
	})
	w.view_state.input_state[cfg.id_focus] = InputState{
		cursor_pos: memento.cursor_pos
		select_beg: memento.select_beg
		select_end: memento.select_end
		undo:       undo
		redo:       redo
	}
	return memento.text
}

pub fn (cfg &InputCfg) redo(mut w Window) string {
	input_state := w.view_state.input_state[cfg.id_focus]
	mut redo := input_state.redo
	memento := redo.pop() or { return cfg.text }
	mut undo := input_state.undo
	undo.push(InputMemento{
		text:       cfg.text
		cursor_pos: input_state.cursor_pos
		select_beg: input_state.select_beg
		select_end: input_state.select_end
	})
	w.view_state.input_state[cfg.id_focus] = InputState{
		cursor_pos: memento.cursor_pos
		select_beg: memento.select_beg
		select_end: memento.select_end
		undo:       undo
		redo:       redo
	}
	return memento.text
}

fn (cfg &InputCfg) amend_layout(mut layout Layout, mut w Window) {
	if layout.shape.disabled {
		return
	}

	if layout.shape.id_focus > 0 && layout.shape.id_focus == w.id_focus() {
		layout.shape.color = cfg.color_border_focus
	}
}

fn (cfg &InputCfg) hover(mut layout Layout, mut e Event, mut w Window) {
	if !w.is_focus(layout.shape.id_focus) {
		layout.children[0].shape.color = cfg.color_hover
	}
}

fn (cfg &InputCfg) hover_icon(mut layout Layout, mut e Event, mut w Window) {
	if layout.shape.on_click != unsafe { nil } {
		w.set_mouse_cursor_pointing_hand()
	}
}

fn u32_sort(a u32, b u32) (u32, u32) {
	return match b < a {
		true { b, a }
		else { a, b }
	}
}
