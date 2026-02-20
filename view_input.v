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
import vglyph

const input_max_insert_runes = 65_536

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

pub enum InputCommitReason as u8 {
	enter
	blur
}

// InputCfg configures an input view. See [input](#input). Use
// `on_text_changed` to capture text updates. To capture the enter-key, provide
// an `on_enter` callback. Placeholder text is shown when the field is empty.
@[minify]
pub struct InputCfg {
	A11yCfg
	SizeCfg
pub:
	id                    string
	text                  string // text to display/edit
	icon                  string // icon constant
	placeholder           string // text to show when empty
	mask                  string // explicit pattern; e.g. '(999) 999-9999'
	mask_preset           InputMaskPreset = .none // preset pattern when `mask` is empty
	mask_tokens           []MaskTokenDef // custom token defs; merged with built-ins
	pre_commit_transform  fn (string, string) ?string                         = unsafe { nil }
	post_commit_normalize fn (string, InputCommitReason) string               = unsafe { nil }
	on_text_changed       fn (&Layout, string, mut Window)                    = unsafe { nil }
	on_text_commit        fn (&Layout, string, InputCommitReason, mut Window) = unsafe { nil }
	on_enter              fn (&Layout, mut Event, mut Window)                 = unsafe { nil }
	on_key_down           fn (&Layout, mut Event, mut Window)                 = unsafe { nil }
	on_mouse_scroll       fn (&Layout, mut Event, mut Window)                 = unsafe { nil }
	on_blur               fn (&Layout, mut Window)            = unsafe { nil }
	on_click_icon         fn (&Layout, mut Event, mut Window) = unsafe { nil }
	field_id              string
	form_sync_validators  []FormSyncValidator
	form_async_validators []FormAsyncValidator
	form_validate_on      FormValidateOn = .inherit
	form_initial_value    ?string
	scrollbar_cfg_x       &ScrollbarCfg = unsafe { nil }
	scrollbar_cfg_y       &ScrollbarCfg = unsafe { nil }
	tooltip               &TooltipCfg   = unsafe { nil }
	text_style            TextStyle     = gui_theme.input_style.text_style
	placeholder_style     TextStyle     = gui_theme.input_style.placeholder_style
	icon_style            TextStyle     = gui_theme.input_style.icon_style
	radius                f32           = gui_theme.input_style.radius
	radius_border         f32           = gui_theme.input_style.radius_border
	id_focus              u32 // 0 = readonly, >0 = focusable and tabbing order
	id_scroll             u32
	scroll_mode           ScrollMode
	padding               Padding = gui_theme.input_style.padding
	size_border           f32     = gui_theme.input_style.size_border
	color                 Color   = gui_theme.input_style.color
	color_hover           Color   = gui_theme.input_style.color_hover
	color_border          Color   = gui_theme.input_style.color_border
	color_border_focus    Color   = gui_theme.input_style.color_border_focus
	mode                  InputMode // enable multiline
	disabled              bool
	invisible             bool
	is_password           bool // mask input characters with '*'s
}

@[minify]
struct InputRuntimeCfg {
	text                  string
	mode                  InputMode
	mask                  string
	mask_preset           InputMaskPreset
	mask_tokens           []MaskTokenDef
	pre_commit_transform  fn (string, string) ?string                         = unsafe { nil }
	post_commit_normalize fn (string, InputCommitReason) string               = unsafe { nil }
	on_text_changed       fn (&Layout, string, mut Window)                    = unsafe { nil }
	on_text_commit        fn (&Layout, string, InputCommitReason, mut Window) = unsafe { nil }
	on_enter              fn (&Layout, mut Event, mut Window)                 = unsafe { nil }
	on_blur               fn (&Layout, mut Window) = unsafe { nil }
	field_id              string
	form_sync_validators  []FormSyncValidator
	form_async_validators []FormAsyncValidator
	form_validate_on      FormValidateOn = .inherit
	form_initial_value    ?string
	text_style            TextStyle
	width                 f32
	id_focus              u32
	padding               Padding
	size_border           f32
	sizing                Sizing
	is_password           bool
}

fn input_runtime_cfg(cfg InputCfg) InputRuntimeCfg {
	return InputRuntimeCfg{
		text:                  cfg.text
		mode:                  cfg.mode
		mask:                  cfg.mask
		mask_preset:           cfg.mask_preset
		mask_tokens:           cfg.mask_tokens
		pre_commit_transform:  cfg.pre_commit_transform
		post_commit_normalize: cfg.post_commit_normalize
		on_text_changed:       cfg.on_text_changed
		on_text_commit:        cfg.on_text_commit
		on_enter:              cfg.on_enter
		on_blur:               cfg.on_blur
		field_id:              cfg.field_id
		form_sync_validators:  cfg.form_sync_validators
		form_async_validators: cfg.form_async_validators
		form_validate_on:      cfg.form_validate_on
		form_initial_value:    cfg.form_initial_value
		text_style:            cfg.text_style
		width:                 cfg.width
		id_focus:              cfg.id_focus
		padding:               cfg.padding
		size_border:           cfg.size_border
		sizing:                cfg.sizing
		is_password:           cfg.is_password
	}
}

fn (cfg &InputRuntimeCfg) to_input_cfg() InputCfg {
	return InputCfg{
		text:                  cfg.text
		mask:                  cfg.mask
		mask_preset:           cfg.mask_preset
		mask_tokens:           cfg.mask_tokens
		pre_commit_transform:  cfg.pre_commit_transform
		post_commit_normalize: cfg.post_commit_normalize
		on_text_changed:       cfg.on_text_changed
		on_text_commit:        cfg.on_text_commit
		on_enter:              cfg.on_enter
		on_blur:               cfg.on_blur
		field_id:              cfg.field_id
		form_sync_validators:  cfg.form_sync_validators
		form_async_validators: cfg.form_async_validators
		form_validate_on:      cfg.form_validate_on
		form_initial_value:    cfg.form_initial_value
		sizing:                cfg.sizing
		text_style:            cfg.text_style
		width:                 cfg.width
		id_focus:              cfg.id_focus
		padding:               cfg.padding
		size_border:           cfg.size_border
		mode:                  cfg.mode
		is_password:           cfg.is_password
	}
}

fn (cfg &InputRuntimeCfg) form_register(layout &Layout, mut w Window) {
	input_cfg := cfg.to_input_cfg()
	input_cfg.form_register(layout, mut w)
}

fn (cfg &InputRuntimeCfg) form_notify(layout &Layout, value string, trigger FormValidationTrigger, mut w Window) {
	input_cfg := cfg.to_input_cfg()
	input_cfg.form_notify(layout, value, trigger, mut w)
}

fn (cfg &InputRuntimeCfg) commit_text(layout &Layout, reason InputCommitReason, mut w Window) {
	input_cfg := cfg.to_input_cfg()
	input_cfg.commit_text(layout, reason, mut w)
}

fn (cfg &InputRuntimeCfg) delete(mut w Window, is_delete bool) ?string {
	input_cfg := cfg.to_input_cfg()
	return input_cfg.delete(mut w, is_delete)
}

fn (cfg &InputRuntimeCfg) insert(s string, mut w Window) !string {
	input_cfg := cfg.to_input_cfg()
	return input_cfg.insert(s, mut w)
}

fn (cfg &InputRuntimeCfg) cut(mut w Window) ?string {
	input_cfg := cfg.to_input_cfg()
	return input_cfg.cut(mut w)
}

fn (cfg &InputRuntimeCfg) paste(s string, mut w Window) !string {
	input_cfg := cfg.to_input_cfg()
	return input_cfg.paste(s, mut w)
}

fn (cfg &InputRuntimeCfg) undo(mut w Window) string {
	input_cfg := cfg.to_input_cfg()
	return input_cfg.undo(mut w)
}

fn (cfg &InputRuntimeCfg) redo(mut w Window) string {
	input_cfg := cfg.to_input_cfg()
	return input_cfg.redo(mut w)
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
// Masked input:
// - `mask` sets an explicit mask pattern.
// - `mask_preset` selects a built-in mask when `mask` is empty.
// - `mask_tokens` adds or overrides token definitions for `mask`.
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
	runtime_cfg := input_runtime_cfg(cfg)

	mut txt_content := [
		text(
			id_focus:             cfg.id_focus
			sizing:               fill_fill
			text:                 txt
			text_style:           txt_style
			mode:                 mode
			is_password:          cfg.is_password
			placeholder_active:   placeholder_active
			on_key_down_hook:     cfg.on_key_down
			on_mouse_scroll_hook: cfg.on_mouse_scroll
		),
	]

	if cfg.icon.len > 0 {
		txt_content << [
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
	}

	input_a11y_lbl := a11y_label(cfg.a11y_label, cfg.placeholder)
	mut input_a11y := &AccessInfo(unsafe { nil })
	if input_a11y_lbl.len > 0 || cfg.a11y_description.len > 0 || cfg.text.len > 0 {
		input_a11y = &AccessInfo{
			label:       input_a11y_lbl
			description: cfg.a11y_description
			value_text:  cfg.text
		}
	}

	return column(
		name:            'input'
		id:              cfg.id
		id_focus:        cfg.id_focus
		a11y_role:       if cfg.mode == .multiline {
			AccessRole.text_area
		} else {
			AccessRole.text_field
		}
		a11y_state:      if cfg.id_focus == 0 { AccessState.read_only } else { AccessState.none }
		a11y:            input_a11y
		tooltip:         cfg.tooltip
		width:           cfg.width
		height:          cfg.height
		min_width:       cfg.min_width
		max_width:       cfg.max_width
		min_height:      cfg.min_height
		max_height:      cfg.max_height
		disabled:        cfg.disabled
		clip:            true
		color:           cfg.color
		color_border:    cfg.color_border
		size_border:     cfg.size_border
		invisible:       cfg.invisible
		padding:         cfg.padding
		radius:          cfg.radius
		sizing:          cfg.sizing
		on_char:         make_input_on_char(runtime_cfg)
		on_ime_commit:   make_input_on_ime_commit(runtime_cfg)
		on_hover:        fn [color_hover, id_focus] (mut layout Layout, mut e Event, mut w Window) {
			if w.is_focus(id_focus) {
				w.set_mouse_cursor_ibeam()
			} else {
				layout.shape.color = color_hover
			}
		}
		amend_layout:    fn [color_border_focus, runtime_cfg] (mut layout Layout, mut w Window) {
			runtime_cfg.form_register(layout, mut w)
			if layout.shape.id_focus == 0 {
				return
			}
			focused := !layout.shape.disabled && layout.shape.id_focus == w.id_focus()
			was_focused := w.view_state.input_focus_state.get(layout.shape.id_focus) or { false }
			if was_focused && !focused {
				runtime_cfg.commit_text(layout, .blur, mut w)
				if runtime_cfg.on_blur != unsafe { nil } {
					runtime_cfg.on_blur(layout, mut w)
				}
			}
			w.view_state.input_focus_state.set(layout.shape.id_focus, focused)
			if focused {
				layout.shape.color_border = color_border_focus
			}
		}
		id_scroll:       cfg.id_scroll
		scrollbar_cfg_x: cfg.scrollbar_cfg_x
		scrollbar_cfg_y: cfg.scrollbar_cfg_y
		spacing:         0
		content:         [
			row(
				name:     'input interior'
				padding:  padding_none
				sizing:   fill_fill
				v_align:  if cfg.mode == .single_line { .middle } else { .top }
				on_click: fn (layout &Layout, mut e Event, mut w Window) {
					if layout.children.len < 1 {
						return
					}
					ly := layout.children[0]
					if ly.shape.id_focus > 0 {
						w.set_id_focus(ly.shape.id_focus)
					}
				}
				content:  txt_content
			),
		]
	)
}

fn (cfg &InputCfg) active_mask_pattern() string {
	if cfg.mask.len > 0 {
		return cfg.mask
	}
	return input_mask_from_preset(cfg.mask_preset)
}

fn (cfg &InputCfg) active_compiled_mask() ?CompiledInputMask {
	mask := cfg.active_mask_pattern()
	if mask.len == 0 {
		return none
	}
	compiled := compile_input_mask(mask, cfg.mask_tokens) or {
		log.error(err.msg())
		return none
	}
	return compiled
}

fn (cfg &InputCfg) apply_pre_commit_transform(current string, proposed string) ?string {
	if cfg.pre_commit_transform == unsafe { nil } {
		return proposed
	}
	return cfg.pre_commit_transform(current, proposed)
}

fn (cfg &InputCfg) form_adapter_cfg(value string) FormFieldAdapterCfg {
	return FormFieldAdapterCfg{
		field_id:             cfg.field_id
		value:                value
		initial_value:        cfg.form_initial_value
		sync_validators:      cfg.form_sync_validators
		async_validators:     cfg.form_async_validators
		validate_on_override: cfg.form_validate_on
	}
}

fn (cfg &InputCfg) form_register(layout &Layout, mut w Window) {
	if cfg.field_id.len == 0 {
		return
	}
	w.form_register_field(layout, cfg.form_adapter_cfg(cfg.text))
}

fn (cfg &InputCfg) form_notify(layout &Layout, value string, trigger FormValidationTrigger, mut w Window) {
	if cfg.field_id.len == 0 {
		return
	}
	w.form_on_field_event(layout, cfg.form_adapter_cfg(value), trigger)
}

fn (cfg &InputCfg) apply_text_edit(input_state InputState, text string, cursor_pos int, mut w Window) string {
	next_text := cfg.apply_pre_commit_transform(cfg.text, text) or { return cfg.text }
	if next_text == cfg.text {
		return cfg.text
	}
	next_cursor_pos := if next_text == text {
		cursor_pos
	} else {
		int_clamp(cursor_pos, 0, next_text.runes().len)
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
		cursor_pos:    next_cursor_pos
		select_beg:    0
		select_end:    0
		undo:          undo
		cursor_offset: -1 // view_text.v-on_key_down-up/down handler tests for < 0
	})
	w.view_state.input_cursor_on = true
	w.view_state.cursor_on_sticky = true
	return next_text
}

fn (cfg &InputCfg) commit_text(layout &Layout, reason InputCommitReason, mut w Window) {
	mut text := cfg.text
	if cfg.post_commit_normalize != unsafe { nil } {
		text = cfg.post_commit_normalize(cfg.text, reason)
	}
	match reason {
		.blur {
			cfg.form_notify(layout, text, .blur, mut w)
		}
		.enter {
			cfg.form_notify(layout, text, .submit, mut w)
			w.form_request_submit_for_layout(layout)
		}
	}
	if cfg.on_text_changed != unsafe { nil } && text != cfg.text {
		cfg.on_text_changed(layout, text, mut w)
	}
	if cfg.on_text_commit != unsafe { nil } {
		cfg.on_text_commit(layout, text, reason, mut w)
	}
}

fn (cfg &InputCfg) masked_insert(s string, mut w Window, compiled CompiledInputMask) !string {
	input_state := w.view_state.input_state.get(cfg.id_focus) or { InputState{} }
	res := input_mask_insert(cfg.text, input_state.cursor_pos, input_state.select_beg,
		input_state.select_end, s, &compiled)
	if !res.changed {
		return cfg.text
	}
	// Clamp max chars to width for single line fixed inputs.
	if cfg.mode == .single_line && cfg.sizing.width == .fixed {
		ctx := w.ui
		ctx.set_text_cfg(cfg.text_style.to_text_cfg())
		width := ctx.text_width(res.text)
		if width > cfg.width - cfg.padding.width() - (cfg.size_border * 2) {
			return cfg.text
		}
	}
	return cfg.apply_text_edit(input_state, res.text, res.cursor_pos, mut w)
}

fn (cfg &InputCfg) masked_delete(mut w Window, is_delete bool, compiled CompiledInputMask) ?string {
	input_state := w.view_state.input_state.get(cfg.id_focus) or { InputState{} }
	res := if is_delete {
		input_mask_delete(cfg.text, input_state.cursor_pos, input_state.select_beg, input_state.select_end,
			&compiled)
	} else {
		input_mask_backspace(cfg.text, input_state.cursor_pos, input_state.select_beg,
			input_state.select_end, &compiled)
	}
	if !res.changed {
		return cfg.text
	}
	return cfg.apply_text_edit(input_state, res.text, res.cursor_pos, mut w)
}

// delete removes text based on cursor position or selection. If text is
// selected, the entire selection is deleted. Otherwise, it deletes the
// character before (backspace) or after (delete) the cursor. Saves state to
// undo stack before modification. Returns modified text or none if invalid.
fn (cfg &InputCfg) delete(mut w Window, is_delete bool) ?string {
	if compiled := cfg.active_compiled_mask() {
		return cfg.masked_delete(mut w, is_delete, compiled)
	}
	mut text := cfg.text.runes()
	input_state := w.view_state.input_state.get(cfg.id_focus) or { InputState{} }
	mut cursor_pos := int_min(input_state.cursor_pos, text.len)
	if cursor_pos < 0 {
		cursor_pos = text.len
	}
	if input_state.select_beg != input_state.select_end {
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
		if cursor_pos == text.len && is_delete {
			return text.string()
		}
		delete_pos := if is_delete { cursor_pos } else { cursor_pos - 1 }
		if delete_pos < 0 || delete_pos >= text.len {
			return none
		}
		text = arrays.append(text[..delete_pos], text[delete_pos + 1..])
		if !is_delete {
			cursor_pos--
		}
	}
	return cfg.apply_text_edit(input_state, text.string(), cursor_pos, mut w)
}

// insert adds text at the cursor or replaces selection. For single-line
// fixed-width inputs, it validates width constraints. Saves state to undo
// stack before modification. Returns modified text or error.
fn (cfg &InputCfg) insert(s string, mut w Window) !string {
	if s.len == 0 {
		return cfg.text
	}
	if compiled := cfg.active_compiled_mask() {
		return cfg.masked_insert(s, mut w, compiled)
	}
	mut insert_runes := s.runes()
	if insert_runes.len > input_max_insert_runes {
		log.warn('input insert exceeds ${input_max_insert_runes} runes; truncating')
		insert_runes = insert_runes[..input_max_insert_runes].clone()
	}
	insert_text := insert_runes.string()
	// clamp max chars to width of box when single line fixed.
	if cfg.mode == .single_line && cfg.sizing.width == .fixed {
		ctx := w.ui
		ctx.set_text_cfg(cfg.text_style.to_text_cfg())
		width := ctx.text_width(cfg.text + insert_text)
		if width > cfg.width - cfg.padding.width() - (cfg.size_border * 2) {
			return cfg.text
		}
	}
	mut text := cfg.text.runes()
	input_state := w.view_state.input_state.get(cfg.id_focus) or { InputState{} }
	mut cursor_pos := int_min(input_state.cursor_pos, text.len)
	if cursor_pos < 0 {
		text = arrays.append(cfg.text.runes(), insert_runes)
		cursor_pos = text.len
	} else if input_state.select_beg != input_state.select_end {
		beg, end := u32_sort(input_state.select_beg, input_state.select_end)
		if beg >= text.len || end > text.len {
			return error('beg or end out of range (insert)')
		}
		text = arrays.append(arrays.append(text[..beg], insert_runes), text[end..])
		cursor_pos = int_min(int(beg) + insert_runes.len, text.len)
	} else {
		text = arrays.append(arrays.append(text[..cursor_pos], insert_runes), text[cursor_pos..])
		cursor_pos = int_min(cursor_pos + insert_runes.len, text.len)
	}
	return cfg.apply_text_edit(input_state, text.string(), cursor_pos, mut w)
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

// copy copies selected text to clipboard and returns copied text.
// Returns none for password fields or empty/invalid selection.
pub fn (cfg &InputCfg) copy(w &Window) ?string {
	if cfg.is_password {
		return none
	}
	input_state := w.view_state.input_state.get(cfg.id_focus) or { InputState{} }
	if input_state.select_beg != input_state.select_end {
		beg, end := u32_sort(input_state.select_beg, input_state.select_end)
		text_len := utf8_str_visible_length(cfg.text)
		if beg > text_len || end > text_len {
			log.error('beg or end out of range (copy)')
			return none
		}
		if beg >= end {
			return none
		}
		rune_text := cfg.text.runes()
		cpy := rune_text[int(beg)..int(end)]
		to_clipboard(cpy.string())
		return cpy.string()
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

// make_input_on_char creates an on_char handler that captures
// a compact runtime cfg.
fn make_input_on_char(cfg InputRuntimeCfg) fn (&Layout, mut Event, mut Window) {
	return fn [cfg] (layout &Layout, mut event Event, mut w Window) {
		if w.mouse_is_locked() {
			return
		}
		// Suppress char events already handled by IME
		if vglyph.ime_did_handle_key()
			|| (w.text_system != unsafe { nil } && w.text_system.is_composing()) {
			event.is_handled = true
			return
		}
		c := event.char_code
		if cfg.on_text_changed == unsafe { nil } {
			return
		}
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
					if cfg.mode == .single_line || cfg.on_enter != unsafe { nil } {
						cfg.commit_text(layout, .enter, mut w)
					}
					if cfg.on_enter != unsafe { nil } {
						cfg.on_enter(layout, mut event, mut w)
						event.is_handled = true
						return
					}
					if cfg.mode == .single_line {
						event.is_handled = true
						return
					}
					text = cfg.insert('\n', mut w) or {
						log.error(err.msg())
						return
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
		if text != cfg.text {
			cfg.form_notify(layout, text, .change, mut w)
			cfg.on_text_changed(layout, text, mut w)
		}
	}
}

// make_input_on_ime_commit creates a callback that inserts
// IME-committed text into the input field and fires
// on_text_changed.
fn make_input_on_ime_commit(cfg InputRuntimeCfg) fn (&Layout, string, mut Window) {
	return fn [cfg] (layout &Layout, text string, mut w Window) {
		if cfg.on_text_changed == unsafe { nil } {
			return
		}
		new_text := cfg.insert(text, mut w) or {
			log.error(err.msg())
			return
		}
		if new_text != cfg.text {
			cfg.form_notify(layout, new_text, .change, mut w)
			cfg.on_text_changed(layout, new_text, mut w)
		}
	}
}
