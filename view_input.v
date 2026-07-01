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
const ns_input_private_scroll_x = 'gui.input.private_scroll.x'

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
	// last_click_frame records the frame of the last click for double-click
	// detection.
	last_click_frame u64
	// reveal_cursor defers caret scrolling until a fresh post-edit layout exists.
	reveal_cursor bool
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
	pre_commit_transform  fn (string, string) ?string                         = unsafe { nil } // called before commit; return none to reject
	post_commit_normalize fn (string, InputCommitReason) string               = unsafe { nil } // canonicalise committed text (e.g. trim)
	on_text_changed       fn (&Layout, string, mut Window)                    = unsafe { nil } // fires on every keystroke (live)
	on_text_commit        fn (&Layout, string, InputCommitReason, mut Window) = unsafe { nil } // fires on enter or blur
	on_enter              fn (&Layout, mut Event, mut Window)                 = unsafe { nil } // enter key; fires before on_text_commit
	on_key_down           fn (&Layout, mut Event, mut Window)                 = unsafe { nil }
	on_mouse_scroll       fn (&Layout, mut Event, mut Window)                 = unsafe { nil }
	on_blur               fn (&Layout, mut Window)            = unsafe { nil }
	on_click_icon         fn (&Layout, mut Event, mut Window) = unsafe { nil }
	field_id              string // form field name; links input to form validation
	form_sync_validators  []FormSyncValidator
	form_async_validators []FormAsyncValidator
	form_validate_on      FormValidateOn = .inherit // override when validation fires
	form_initial_value    ?string // used for dirty-state detection
	scrollbar_cfg_x       &ScrollbarCfg = unsafe { nil }
	scrollbar_cfg_y       &ScrollbarCfg = unsafe { nil }
	tooltip               &TooltipCfg   = unsafe { nil }
	text_style            TextStyle     = gui_theme.input_style.text_style
	placeholder_style     TextStyle     = gui_theme.input_style.placeholder_style
	icon_style            TextStyle     = gui_theme.input_style.icon_style
	radius                f32           = gui_theme.input_style.radius
	radius_border         f32           = gui_theme.input_style.radius_border
	id_focus              u32 // 0 = readonly; >0 = focusable, also sets tab order
	id_scroll             u32 // non-zero enables scrolling; must be unique per window
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
	private_scroll_key    string
	text_scroll_id        u32
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
		private_scroll_key:    input_private_scroll_key(cfg)
		text_scroll_id:        input_text_scroll_id(cfg)
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
// - alt+right: moves to start of word (option+right on Mac)
// - alt+down: moves to end of paragraph (option+down on Mac)
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
	text_scroll_id := input_text_scroll_id(cfg)

	// Capture values needed for callbacks by copy to avoid dangling reference to cfg
	color_border_focus := cfg.color_border_focus
	color_hover := cfg.color_hover
	id_focus := cfg.id_focus
	on_click_icon := cfg.on_click_icon
	runtime_cfg := input_runtime_cfg(cfg)
	mut root_scrollbar_cfg_x := &ScrollbarCfg(unsafe { nil })
	mut root_scrollbar_cfg_y := &ScrollbarCfg(unsafe { nil })
	if cfg.mode == .multiline {
		root_scrollbar_cfg_x = cfg.scrollbar_cfg_x
		root_scrollbar_cfg_y = cfg.scrollbar_cfg_y
	}
	mut text_scrollbar_cfg_x := input_hidden_scrollbar_cfg()
	mut text_scrollbar_cfg_y := input_hidden_scrollbar_cfg()
	if text_scroll_id > 0 {
		text_scrollbar_cfg_x = cfg.scrollbar_cfg_x
		text_scrollbar_cfg_y = cfg.scrollbar_cfg_y
	}

	txt_view := text(
		id_focus:             cfg.id_focus
		sizing:               fill_fill
		text:                 txt
		text_style:           txt_style
		text_scroll_key:      if cfg.mode == .single_line && text_scroll_id == 0 {
			runtime_cfg.private_scroll_key
		} else {
			''
		}
		mode:                 mode
		is_password:          cfg.is_password
		placeholder_active:   placeholder_active
		on_key_down_hook:     cfg.on_key_down
		on_mouse_scroll_hook: cfg.on_mouse_scroll
	)
	mut txt_content := []View{cap: 2}
	if cfg.mode == .single_line {
		txt_content << row(
			name:            'input text viewport'
			id_scroll:       text_scroll_id
			scroll_mode:     .horizontal_only
			scrollbar_cfg_x: text_scrollbar_cfg_x
			scrollbar_cfg_y: text_scrollbar_cfg_y
			padding:         padding_none
			clip:            true
			sizing:          fill_fill
			content:         [txt_view]
		)
	} else {
		txt_content << txt_view
	}

	if cfg.icon.len > 0 {
		txt_content << [
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
			mut focused := false
			if layout.shape.id_focus > 0 {
				focused = !layout.shape.disabled && layout.shape.id_focus == w.id_focus()
				was_focused := state_map[u32, bool](mut w, ns_input_focus, cap_many).get(layout.shape.id_focus) or {
					false
				}
				if was_focused && !focused {
					runtime_cfg.commit_text(layout, .blur, mut w)
					if runtime_cfg.on_blur != unsafe { nil } {
						runtime_cfg.on_blur(layout, mut w)
					}
				}
				if focused && !was_focused {
					input_mark_cursor_reveal(layout.shape.id_focus, mut w)
				}
				mut ifs := state_map[u32, bool](mut w, ns_input_focus, cap_many)
				ifs.set(layout.shape.id_focus, focused)
				if focused {
					layout.shape.color_border = color_border_focus
				}
			}
			input_apply_post_layout_scroll(mut layout, mut w, runtime_cfg, focused)
		}
		id_scroll:       if cfg.mode == .multiline { cfg.id_scroll } else { u32(0) }
		scrollbar_cfg_x: root_scrollbar_cfg_x
		scrollbar_cfg_y: root_scrollbar_cfg_y
		spacing:         0
		content:         [
			row(
				name:     'input interior'
				padding:  padding_none
				sizing:   fill_fill
				v_align:  if cfg.mode == .single_line { .middle } else { .top }
				on_click: fn (layout &Layout, mut e Event, mut w Window) {
					if ly := layout.find_layout(fn (ly Layout) bool {
						return ly.shape.id_focus > 0 && ly.shape.shape_type == .text
					})
					{
						w.set_id_focus(ly.shape.id_focus)
					}
				}
				content:  txt_content
			),
		]
	)
}

fn input_hidden_scrollbar_cfg() &ScrollbarCfg {
	return &ScrollbarCfg{
		overflow: .hidden
	}
}

fn input_text_scroll_id(cfg InputCfg) u32 {
	if cfg.mode == .single_line && cfg.id_scroll > 0 {
		return cfg.id_scroll
	}
	return 0
}

fn input_private_scroll_key(cfg InputCfg) string {
	if cfg.id.len > 0 {
		return 'id:${cfg.id}'
	}
	if cfg.field_id.len > 0 {
		return 'field:${cfg.field_id}'
	}
	if cfg.id_focus > 0 {
		return 'focus:${cfg.id_focus}'
	}
	return ''
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

@[inline]
fn input_state_or_default(id_focus u32, mut w Window) InputState {
	return state_map[u32, InputState](mut w, ns_input, cap_many).get(id_focus) or { InputState{} }
}

@[inline]
fn input_memento_from_state(text string, input_state InputState) InputMemento {
	return InputMemento{
		text:          text
		cursor_pos:    input_state.cursor_pos
		select_beg:    input_state.select_beg
		select_end:    input_state.select_end
		cursor_offset: input_state.cursor_offset
	}
}

@[inline]
fn input_push_memento(mut stack BoundedStack[InputMemento], text string, input_state InputState) BoundedStack[InputMemento] {
	stack.push(input_memento_from_state(text, input_state))
	return stack
}

@[inline]
fn input_state_from_memento(memento InputMemento, undo BoundedStack[InputMemento], redo BoundedStack[InputMemento]) InputState {
	return InputState{
		cursor_pos:    memento.cursor_pos
		select_beg:    memento.select_beg
		select_end:    memento.select_end
		cursor_offset: memento.cursor_offset
		undo:          undo
		redo:          redo
	}
}

fn input_state_with_reveal(input_state InputState, reveal bool) InputState {
	return InputState{
		...input_state
		reveal_cursor: reveal
	}
}

fn input_mark_cursor_reveal(id_focus u32, mut w Window) {
	if id_focus == 0 {
		return
	}
	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	input_state := imap.get(id_focus) or { InputState{} }
	imap.set(id_focus, input_state_with_reveal(input_state, true))
}

fn input_apply_post_layout_scroll(mut layout Layout, mut w Window, cfg InputRuntimeCfg, focused bool) {
	id_focus := layout.shape.id_focus
	text_layout := input_find_text_layout(layout, id_focus) or { return }
	if cfg.mode == .single_line && cfg.text_scroll_id == 0 {
		mut reveal_cursor := false
		mut reveal_cursor_pos := 0
		if id_focus > 0 {
			input_state := state_map[u32, InputState](mut w, ns_input, cap_many).get(id_focus) or {
				InputState{}
			}
			reveal_cursor = input_state.reveal_cursor
			reveal_cursor_pos = input_state.cursor_pos
		}
		mut changed := false
		if private_changed := input_apply_private_text_scroll_after_layout(text_layout, mut layout, mut
			w, cfg.private_scroll_key, focused)
		{
			changed = private_changed
		}
		if reveal_cursor {
			if vertical_changed := input_scroll_cursor_vertical_into_view_in_layout(reveal_cursor_pos,
				text_layout, mut layout, mut w)
			{
				changed = changed || vertical_changed
			}
		}
		if changed {
			w.update_window()
		}
		return
	}
	if id_focus > 0 {
		input_state := state_map[u32, InputState](mut w, ns_input, cap_many).get(id_focus) or {
			InputState{}
		}
		if input_state.reveal_cursor {
			changed := input_scroll_cursor_into_view_in_layout(input_state.cursor_pos, text_layout, mut
				layout, mut w, cfg.mode) or { return }
			mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
			imap.set(id_focus, input_state_with_reveal(input_state, false))
			if changed {
				w.update_window()
			}
			return
		}
	}
	if cfg.mode == .single_line && !focused
		&& input_apply_rest_alignment_scroll(text_layout, mut layout, mut w) {
		w.update_window()
	}
}

fn input_find_text_layout(layout &Layout, id_focus u32) ?Layout {
	if id_focus > 0 {
		return layout.find_layout(fn [id_focus] (ly Layout) bool {
			return ly.shape.id_focus == id_focus && ly.shape.shape_type == .text
		})
	}
	return layout.find_layout(fn (ly Layout) bool {
		return ly.shape.shape_type == .text && ly.shape.tc != unsafe { nil }
	})
}

fn input_apply_private_text_scroll_after_layout(text_layout Layout, mut root Layout, mut w Window, scroll_key string, focused bool) ?bool {
	shape := text_layout.shape
	if shape.tc == unsafe { nil } || shape.tc.text_mode != .single_line {
		return none
	}
	mut current_x := shape.tc.text_scroll_x
	if scroll_key.len > 0 {
		current_x = state_map[string, f32](mut w, ns_input_private_scroll_x, cap_scroll).get(scroll_key) or {
			shape.tc.text_scroll_x
		}
	}
	mut target_x := current_x
	mut clear_reveal := false
	if root.shape.id_focus > 0 {
		input_state := state_map[u32, InputState](mut w, ns_input, cap_many).get(root.shape.id_focus) or {
			InputState{}
		}
		if input_state.reveal_cursor {
			target_x = text_private_cursor_scroll_x(input_state.cursor_pos, &text_layout,
				current_x, mut w) or { return none }
			clear_reveal = true
		} else if !focused {
			target_x = input_private_rest_scroll_x(text_layout, current_x, mut w)
		}
	} else {
		target_x = input_private_rest_scroll_x(text_layout, current_x, mut w)
	}
	viewport := text_private_scroll_viewport(&text_layout) or { return none }
	target_x = text_private_clamp_scroll_x(target_x, &text_layout, viewport, mut w)

	mut changed := false
	if !f32_are_close(target_x, current_x) {
		if scroll_key.len > 0 {
			mut sx := state_map[string, f32](mut w, ns_input_private_scroll_x, cap_scroll)
			sx.set(scroll_key, target_x)
			changed = true
		}
	}
	if clear_reveal {
		input_state := state_map[u32, InputState](mut w, ns_input, cap_many).get(root.shape.id_focus) or {
			InputState{}
		}
		mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
		imap.set(root.shape.id_focus, input_state_with_reveal(input_state, false))
	}
	input_set_text_scroll_x(mut root, root.shape.id_focus, target_x)
	return changed
}

fn input_private_rest_scroll_x(text_layout Layout, current_x f32, mut w Window) f32 {
	shape := text_layout.shape
	if shape.tc.text_style.align == .left {
		return 0
	}
	viewport := text_private_scroll_viewport(&text_layout) or { return current_x }
	max_offset := text_private_scroll_max_x(&text_layout, viewport, mut w)
	if f32_are_close(max_offset, 0) {
		return 0
	}
	if shape.tc.text_style.align == .right {
		return max_offset
	}
	return 0
}

fn input_scroll_cursor_into_view_in_layout(cursor_pos int, text_layout Layout, mut root Layout, mut w Window, mode InputMode) ?bool {
	shape := text_layout.shape
	id_scroll_container := shape.id_scroll_container
	if id_scroll_container == 0 {
		return none
	}
	mut changed := false
	current_x := state_map[u32, f32](mut w, ns_scroll_x, cap_scroll).get(id_scroll_container) or {
		f32(0)
	}
	target_x := cursor_pos_to_scroll_x_in_layout(cursor_pos, shape, root, mut w)
	if target_x == -1 {
		return none
	}
	if target_x != -1 && !f32_are_close(target_x, current_x) {
		mut sx := state_map[u32, f32](mut w, ns_scroll_x, cap_scroll)
		sx.set(id_scroll_container, target_x)
		if mode == .single_line {
			input_shift_explicit_scroll_contents(mut root, id_scroll_container,
				target_x - current_x, 0)
		}
		changed = true
	}
	if mode == .single_line {
		return changed
	}
	current_y := state_map[u32, f32](mut w, ns_scroll_y, cap_scroll).get(id_scroll_container) or {
		f32(0)
	}
	target_y := cursor_pos_to_scroll_y_in_layout(cursor_pos, shape, root, mut w)
	if target_y == -1 {
		return none
	}
	if target_y != -1 && !f32_are_close(target_y, current_y) {
		mut sy := state_map[u32, f32](mut w, ns_scroll_y, cap_scroll)
		sy.set(id_scroll_container, target_y)
		changed = true
	}
	return changed
}

fn input_scroll_cursor_vertical_into_view_in_layout(cursor_pos int, text_layout Layout, mut root Layout, mut w Window) ?bool {
	shape := text_layout.shape
	id_scroll_container := shape.id_scroll_container
	if id_scroll_container == 0 {
		return none
	}
	current_y := state_map[u32, f32](mut w, ns_scroll_y, cap_scroll).get(id_scroll_container) or {
		f32(0)
	}
	scroll_container := input_scroll_container_for_text(text_layout, root, id_scroll_container) or {
		return none
	}
	target_y := input_cursor_pos_to_scroll_y_in_container(cursor_pos, shape, scroll_container,
		id_scroll_container, mut w)
	if target_y == -1 {
		return none
	}
	if f32_are_close(target_y, current_y) {
		return false
	}
	mut sy := state_map[u32, f32](mut w, ns_scroll_y, cap_scroll)
	sy.set(id_scroll_container, target_y)
	return true
}

fn input_scroll_container_for_text(text_layout Layout, root &Layout, id_scroll_container u32) ?Layout {
	if scroll_container := find_layout_by_id_scroll(root, id_scroll_container) {
		return scroll_container
	}
	mut parent := text_layout.parent
	for parent != unsafe { nil } {
		if parent.shape.id_scroll == id_scroll_container {
			return *parent
		}
		parent = parent.parent
	}
	parent = root.parent
	for parent != unsafe { nil } {
		if parent.shape.id_scroll == id_scroll_container {
			return *parent
		}
		parent = parent.parent
	}
	return none
}

fn input_cursor_pos_to_scroll_y_in_container(cursor_pos int, shape &Shape, scroll_container Layout, id_scroll_container u32, mut w Window) f32 {
	scroll_view_height := scroll_container.shape.height - scroll_container.shape.padding_height()
	byte_idx := rune_to_byte_index(shape.tc.text, cursor_pos)
	if !shape.has_text_layout() {
		return -1
	}
	rect := shape.tc.vglyph_layout.get_char_rect(byte_idx) or {
		if byte_idx <= 0 {
			return -1
		}
		shape.tc.vglyph_layout.get_char_rect(byte_idx - 1) or { return -1 }
	}

	current_scroll_y := state_map[u32, f32](mut w, ns_scroll_y, cap_scroll).get(id_scroll_container) or {
		f32(0)
	}

	shape_y_in_content := shape.y - current_scroll_y - scroll_container.shape.y
	padding_top := scroll_container.shape.padding_top()
	cursor_top := shape_y_in_content - padding_top + rect.y
	cursor_bottom := cursor_top + rect.height

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

fn input_apply_rest_alignment_scroll(text_layout Layout, mut root Layout, mut w Window) bool {
	shape := text_layout.shape
	if shape.tc.text_style.align == .left || shape.id_scroll_container == 0 {
		return false
	}
	scroll_container := find_layout_by_id_scroll(root, shape.id_scroll_container) or {
		return false
	}
	max_offset := f32_min(0, scroll_container.shape.width - scroll_container.shape.padding_width() -
		content_width(scroll_container))
	if f32_are_close(max_offset, 0) {
		return false
	}
	target_x := match shape.tc.text_style.align {
		.right { max_offset }
		else { f32(0) }
	}

	current_x := state_map[u32, f32](mut w, ns_scroll_x, cap_scroll).get(shape.id_scroll_container) or {
		f32(0)
	}
	if f32_are_close(target_x, current_x) {
		return false
	}
	mut sx := state_map[u32, f32](mut w, ns_scroll_x, cap_scroll)
	sx.set(shape.id_scroll_container, target_x)
	input_shift_explicit_scroll_contents(mut root, shape.id_scroll_container, target_x - current_x,
		0)
	return true
}

fn input_shift_explicit_scroll_contents(mut layout Layout, id_scroll u32, dx f32, dy f32) bool {
	if layout.shape.id_scroll == id_scroll {
		for mut child in layout.children {
			if child.shape.over_draw || child.shape.scrollbar_orientation != .none {
				continue
			}
			input_shift_layout_tree(mut child, dx, dy)
		}
		return true
	}
	for mut child in layout.children {
		if input_shift_explicit_scroll_contents(mut child, id_scroll, dx, dy) {
			return true
		}
	}
	return false
}

fn input_set_text_scroll_x(mut layout Layout, id_focus u32, scroll_x f32) bool {
	if layout.shape.shape_type == .text && (id_focus == 0 || layout.shape.id_focus == id_focus) {
		if layout.shape.tc != unsafe { nil } {
			layout.shape.tc.text_scroll_x = scroll_x
		}
		return true
	}
	for mut child in layout.children {
		if input_set_text_scroll_x(mut child, id_focus, scroll_x) {
			return true
		}
	}
	return false
}

fn input_shift_layout_tree(mut layout Layout, dx f32, dy f32) {
	layout.shape.x += dx
	layout.shape.y += dy
	layout.shape.shape_clip.x += dx
	layout.shape.shape_clip.y += dy
	for mut child in layout.children {
		input_shift_layout_tree(mut child, dx, dy)
	}
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
	undo = input_push_memento(mut undo, cfg.text, input_state)
	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	imap.set(cfg.id_focus, InputState{
		cursor_pos:    next_cursor_pos
		select_beg:    0
		select_end:    0
		undo:          undo
		cursor_offset: -1 // view_text.v-on_key_down-up/down handler tests for < 0
		reveal_cursor: true
	})
	w.view_state.input_cursor_on = true
	w.view_state.cursor_on_sticky = true
	return next_text
}

fn (cfg &InputCfg) commit_text(layout &Layout, reason InputCommitReason, mut w Window) {
	mut edited_text := cfg.text
	if cfg.post_commit_normalize != unsafe { nil } {
		edited_text = cfg.post_commit_normalize(cfg.text, reason)
	}
	match reason {
		.blur {
			cfg.form_notify(layout, edited_text, .blur, mut w)
		}
		.enter {
			cfg.form_notify(layout, edited_text, .submit, mut w)
			w.form_request_submit_for_layout(layout)
		}
	}

	if cfg.on_text_changed != unsafe { nil } && edited_text != cfg.text {
		cfg.on_text_changed(layout, edited_text, mut w)
	}
	if cfg.on_text_commit != unsafe { nil } {
		cfg.on_text_commit(layout, edited_text, reason, mut w)
	}
}

fn (cfg &InputCfg) masked_insert(s string, mut w Window, compiled CompiledInputMask) !string {
	input_state := input_state_or_default(cfg.id_focus, mut w)
	res := input_mask_insert(cfg.text, input_state.cursor_pos, input_state.select_beg,
		input_state.select_end, s, &compiled)
	if !res.changed {
		return cfg.text
	}
	return cfg.apply_text_edit(input_state, res.text, res.cursor_pos, mut w)
}

fn (cfg &InputCfg) masked_delete(mut w Window, forward_delete bool, compiled CompiledInputMask) ?string {
	input_state := input_state_or_default(cfg.id_focus, mut w)
	res := if forward_delete {
		input_mask_delete(cfg.text, input_state.cursor_pos, input_state.select_beg,
			input_state.select_end, &compiled)
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
fn (cfg &InputCfg) delete(mut w Window, forward_delete bool) ?string {
	if compiled := cfg.active_compiled_mask() {
		return cfg.masked_delete(mut w, forward_delete, compiled)
	}
	mut runes := cfg.text.runes()
	input_state := input_state_or_default(cfg.id_focus, mut w)
	mut cursor_pos := int_min(input_state.cursor_pos, runes.len)
	if cursor_pos < 0 {
		cursor_pos = runes.len
	}
	if input_state.select_beg != input_state.select_end {
		beg, end := u32_sort(input_state.select_beg, input_state.select_end)
		if beg >= runes.len || end > runes.len {
			log.error('beg or end out of range (delete)')
			return none
		}
		runes = arrays.append(runes[..beg], runes[end..])
		cursor_pos = int_min(int(beg), runes.len)
	} else {
		if cursor_pos == 0 && !forward_delete {
			return runes.string()
		}
		if cursor_pos == runes.len && forward_delete {
			return runes.string()
		}
		delete_pos := if forward_delete { cursor_pos } else { cursor_pos - 1 }
		if delete_pos < 0 || delete_pos >= runes.len {
			return none
		}
		runes = arrays.append(runes[..delete_pos], runes[delete_pos + 1..])
		if !forward_delete {
			cursor_pos--
		}
	}
	return cfg.apply_text_edit(input_state, runes.string(), cursor_pos, mut w)
}

// insert adds text at the cursor or replaces selection. Saves state to undo
// stack before modification. Returns modified text or error.
fn (cfg &InputCfg) insert(insert_text string, mut w Window) !string {
	if insert_text.len == 0 {
		return cfg.text
	}
	if compiled := cfg.active_compiled_mask() {
		return cfg.masked_insert(insert_text, mut w, compiled)
	}
	mut insert_runes := insert_text.runes()
	if insert_runes.len > input_max_insert_runes {
		log.warn('input insert exceeds ${input_max_insert_runes} runes; truncating')
		insert_runes = insert_runes[..input_max_insert_runes].clone()
	}
	mut runes := cfg.text.runes()
	input_state := input_state_or_default(cfg.id_focus, mut w)
	mut cursor_pos := int_min(input_state.cursor_pos, runes.len)
	if cursor_pos < 0 {
		runes = arrays.append(cfg.text.runes(), insert_runes)
		cursor_pos = runes.len
	} else if input_state.select_beg != input_state.select_end {
		beg, end := u32_sort(input_state.select_beg, input_state.select_end)
		if beg >= runes.len || end > runes.len {
			return error('beg or end out of range (insert)')
		}
		runes = arrays.append(arrays.append(runes[..beg], insert_runes), runes[end..])
		cursor_pos = int_min(int(beg) + insert_runes.len, runes.len)
	} else {
		runes = arrays.append(arrays.append(runes[..cursor_pos], insert_runes), runes[cursor_pos..])
		cursor_pos = int_min(cursor_pos + insert_runes.len, runes.len)
	}
	return cfg.apply_text_edit(input_state, runes.string(), cursor_pos, mut w)
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
	input_state := state_read_or[u32, InputState](w, ns_input, cfg.id_focus, InputState{})
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
	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	input_state := imap.get(cfg.id_focus) or { InputState{} }
	mut undo := input_state.undo
	memento := undo.pop() or { return cfg.text }
	mut redo := input_state.redo
	redo = input_push_memento(mut redo, cfg.text, input_state)
	imap.set(cfg.id_focus, input_state_with_reveal(input_state_from_memento(memento, undo, redo),
		true))
	return memento.text
}

// redo reapplies a previously undone operation. Returns restored text or
// current text if stack empty.
pub fn (cfg &InputCfg) redo(mut w Window) string {
	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	input_state := imap.get(cfg.id_focus) or { InputState{} }
	mut redo := input_state.redo
	memento := redo.pop() or { return cfg.text }
	mut undo := input_state.undo
	undo = input_push_memento(mut undo, cfg.text, input_state)
	imap.set(cfg.id_focus, input_state_with_reveal(input_state_from_memento(memento, undo, redo),
		true))
	return memento.text
}

// make_input_on_char creates an on_char handler that captures
// a compact runtime cfg.
// reason: closure capture — InputCfg is @[heap]; capturing it directly would
// cause GC false retention. InputRuntimeCfg holds only the needed fields.
// See CLAUDE.md §GC / Boehm False-Retention Rules.
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
		mut edited_text := cfg.text
		if event.modifiers == .ctrl_shift {
			match c {
				ctrl_z { edited_text = cfg.redo(mut w) }
				else {}
			}
		} else if event.modifiers == .super_shift {
			match c {
				cmd_z { edited_text = cfg.redo(mut w) }
				else {}
			}
		} else if event.modifiers == .ctrl {
			match c {
				ctrl_v { edited_text = cfg.paste(from_clipboard(), mut w) or { return } }
				ctrl_x { edited_text = cfg.cut(mut w) or { return } }
				ctrl_z { edited_text = cfg.undo(mut w) }
				else {}
			}
		} else if event.modifiers == .super {
			match c {
				cmd_v { edited_text = cfg.paste(from_clipboard(), mut w) or { return } }
				cmd_x { edited_text = cfg.cut(mut w) or { return } }
				cmd_z { edited_text = cfg.undo(mut w) }
				else {}
			}
		} else {
			match c {
				bsp_char {
					edited_text = cfg.delete(mut w, false) or { return }
				}
				del_char {
					$if macos {
						edited_text = cfg.delete(mut w, false) or { return }
					} $else {
						edited_text = cfg.delete(mut w, true) or { return }
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
					edited_text = cfg.insert('\n', mut w) or {
						log.error(err.msg())
						return
					}
				}
				0...0x1F { // non-printable
					return
				}
				else {
					edited_text = cfg.insert(rune(c).str(), mut w) or {
						log.error(err.msg())
						return
					}
				}
			}
		}
		event.is_handled = true
		if edited_text != cfg.text {
			cfg.form_notify(layout, edited_text, .change, mut w)
			cfg.on_text_changed(layout, edited_text, mut w)
		}
	}
}

// make_input_on_ime_commit creates a callback that inserts
// IME-committed text into the input field and fires
// on_text_changed.
// reason: closure capture — same pattern as make_input_on_char.
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
