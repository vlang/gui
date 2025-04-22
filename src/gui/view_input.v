module gui

@[heap]
pub struct InputCfg {
	CommonCfg
pub:
	id_focus           u32    // 0 = readonly, >0 = focusable and tabbing order
	text               string // text to display/edit
	placeholder        string // text to show when empty
	wrap               bool   // enable multiline
	is_password        bool   // mask input characters
	padding            Padding   = gui_theme.input_style.padding
	padding_border     Padding   = gui_theme.input_style.padding_border
	color              Color     = gui_theme.input_style.color
	color_border       Color     = gui_theme.input_style.color_border
	color_border_focus Color     = gui_theme.input_style.color_border_focus
	fill               bool      = gui_theme.input_style.fill
	fill_border        bool      = gui_theme.input_style.fill_border
	radius             f32       = gui_theme.input_style.radius
	radius_border      f32       = gui_theme.input_style.radius_border
	text_style         TextStyle = gui_theme.input_style.text_style
	placeholder_style  TextStyle = gui_theme.input_style.placeholder_style
	// update your app model here
	on_text_changed fn (&InputCfg, string, &Window) = unsafe { nil }
}

// input is a text input field.
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
pub fn input(cfg InputCfg) View {
	assert cfg.id_focus != 0
	placeholder_active := cfg.text.len == 0
	txt := if placeholder_active { cfg.placeholder } else { cfg.text }
	txt_style := if placeholder_active { cfg.placeholder_style } else { cfg.text_style }

	return row(
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
		amend_layout: cfg.amend_layout
		cfg:          &cfg
		content:      [
			row(
				color:   cfg.color
				padding: cfg.padding
				// spacing: cfg.spacing
				fill:    cfg.fill
				sizing:  fill_fill
				radius:  cfg.radius
				content: [
					text(
						id_focus:           cfg.id_focus
						text:               txt
						text_style:         txt_style
						wrap:               cfg.wrap
						is_password:        cfg.is_password
						keep_spaces:        true
						placeholder_active: placeholder_active
					),
				]
			),
		]
	)
}

fn (cfg &InputCfg) on_char_shape(shape &Shape, mut event Event, mut w Window) {
	c := event.char_code
	if cfg.on_text_changed != unsafe { nil } {
		mut text := cfg.text
		if event.modifiers & u32(Modifier.ctrl) > 0 && event.modifiers & u32(Modifier.shift) > 0 {
			match c {
				ctrl_z { text = cfg.redo(mut w) }
				else {}
			}
		} else if event.modifiers & u32(Modifier.super) > 0
			&& event.modifiers & u32(Modifier.shift) > 0 {
			match c {
				cmd_z { text = cfg.redo(mut w) }
				else {}
			}
		} else if event.modifiers & u32(Modifier.ctrl) > 0 {
			match c {
				ctrl_v { text = cfg.paste(from_clipboard(), mut w) or { '' } }
				ctrl_x { text = cfg.cut(mut w) or { '' } }
				ctrl_z { text = cfg.undo(mut w) }
				else {}
			}
		} else if event.modifiers & u32(Modifier.super) > 0 {
			match c {
				cmd_v { text = cfg.paste(from_clipboard(), mut w) or { '' } }
				cmd_x { text = cfg.cut(mut w) or { '' } }
				cmd_z { text = cfg.undo(mut w) }
				else {}
			}
		} else {
			match c {
				bsp_char, del_char {
					text = cfg.delete(mut w) or {
						eprintln(err)
						return
					}
				}
				cr_char, lf_char {
					if cfg.wrap {
						text = cfg.insert('\n', mut w) or {
							eprintln(err)
							return
						}
					}
				}
				0...0x1F { // non-printables
					return
				}
				else {
					text = cfg.insert(rune(c).str(), mut w) or {
						eprintln(err)
						return
					}
				}
			}
		}
		event.is_handled = true
		cfg.on_text_changed(cfg, text, w)
	}
}

fn (cfg &InputCfg) delete(mut w Window) ?string {
	mut text := cfg.text
	input_state := w.input_state[cfg.id_focus]
	mut cursor_pos := input_state.cursor_pos
	if cursor_pos < 0 {
		cursor_pos = cfg.text.len
	} else if cursor_pos > 0 {
		if input_state.select_beg != input_state.select_end {
			text = text[..input_state.select_beg] + text[input_state.select_end..]
			cursor_pos = int_min(int(input_state.select_beg), text.len)
		} else {
			text = cfg.text[..cursor_pos - 1] + cfg.text[cursor_pos..]
			cursor_pos -= 1
		}
	}
	mut undo := input_state.undo
	undo.push(InputMemento{
		text:       cfg.text
		cursor_pos: input_state.cursor_pos
		select_beg: input_state.select_beg
		select_end: input_state.select_end
	})
	w.input_state[cfg.id_focus] = InputState{
		cursor_pos: cursor_pos
		select_beg: 0
		select_end: 0
		undo:       undo
	}
	return text
}

fn (cfg &InputCfg) insert(s string, mut w Window) !string {
	// clamp max chars to width of box when single line fixed.
	if !cfg.wrap && cfg.sizing.width == .fixed {
		ctx := w.ui
		ctx.set_text_cfg(cfg.text_style.to_text_cfg())
		width := ctx.text_width(cfg.text + s)
		if width > cfg.width - cfg.padding.width() - cfg.padding_border.width() {
			return cfg.text
		}
	}
	mut text := cfg.text
	input_state := w.input_state[cfg.id_focus]
	mut cursor_pos := input_state.cursor_pos
	if cursor_pos < 0 {
		text = cfg.text + s
		cursor_pos = text.len
	} else if input_state.select_beg != input_state.select_end {
		text = text[..input_state.select_beg] + s + text[input_state.select_end..]
		cursor_pos = int_min(int(input_state.select_beg) - 1, text.len)
	} else {
		text = text[..cursor_pos] + s + text[cursor_pos..]
		cursor_pos = int_min(cursor_pos + s.len, text.len)
	}
	mut undo := input_state.undo
	undo.push(InputMemento{
		text:       cfg.text
		cursor_pos: input_state.cursor_pos
		select_beg: input_state.select_beg
		select_end: input_state.select_end
	})
	w.input_state[cfg.id_focus] = InputState{
		cursor_pos: cursor_pos
		select_beg: 0
		select_end: 0
		undo:       undo
	}
	return text
}

pub fn (cfg &InputCfg) cut(mut w Window) ?string {
	cfg.copy(w)
	return cfg.delete(mut w)
}

pub fn (cfg &InputCfg) copy(w &Window) ?string {
	input_state := w.input_state[cfg.id_focus]
	if input_state.select_beg != input_state.select_end {
		cpy := cfg.text[input_state.select_beg..input_state.select_end] or { '' }
		to_clipboard(cpy)
	}
	return none
}

pub fn (cfg &InputCfg) paste(s string, mut w Window) !string {
	return cfg.insert(s, mut w)
}

pub fn (cfg &InputCfg) undo(mut w Window) string {
	input_state := w.input_state[cfg.id_focus]
	mut undo := input_state.undo
	memento := undo.pop() or { return cfg.text }
	mut redo := input_state.redo
	redo.push(InputMemento{
		text:       cfg.text
		cursor_pos: input_state.cursor_pos
		select_beg: input_state.select_beg
		select_end: input_state.select_end
	})
	w.input_state[cfg.id_focus] = InputState{
		cursor_pos: memento.cursor_pos
		select_beg: memento.select_beg
		select_end: memento.select_end
		undo:       undo
		redo:       redo
	}
	return memento.text
}

pub fn (cfg &InputCfg) redo(mut w Window) string {
	input_state := w.input_state[cfg.id_focus]
	mut redo := input_state.redo
	memento := redo.pop() or { return cfg.text }
	mut undo := input_state.undo
	undo.push(InputMemento{
		text:       cfg.text
		cursor_pos: input_state.cursor_pos
		select_beg: input_state.select_beg
		select_end: input_state.select_end
	})
	w.input_state[cfg.id_focus] = InputState{
		cursor_pos: memento.cursor_pos
		select_beg: memento.select_beg
		select_end: memento.select_end
		undo:       undo
		redo:       redo
	}
	return memento.text
}

fn (cfg &InputCfg) amend_layout(mut node Layout, mut w Window) {
	if node.shape.disabled {
		return
	}

	// Composite views don't have a generate method.
	// To add internal envet handlers requires that
	// the function is assigned here.
	node.shape.on_char_shape = cfg.on_char_shape

	if node.shape.id_focus > 0 && node.shape.id_focus == w.id_focus() {
		node.shape.color = cfg.color_border_focus
	}
}
