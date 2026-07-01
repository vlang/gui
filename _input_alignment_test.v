module gui

import gg
import vglyph

struct InputAlignmentTestState {
mut:
	changed_text string
}

fn first_text_shape_from_view(mut view View) Shape {
	mut w := Window{}
	layout := generate_layout(mut view, mut w)
	shape := layout.find_shape(fn (ly Layout) bool {
		return ly.shape.shape_type == .text
	}) or {
		assert false, 'expected generated view to contain a text shape'
		return Shape{}
	}
	return shape
}

fn arranged_view_layout(mut view View, mut w Window) Layout {
	mut layout := generate_layout(mut view, mut w)
	layouts := layout_arrange(mut layout, mut w)
	assert layouts.len > 0
	return layouts[0]
}

fn generated_text_layout(root &Layout, id_focus u32) Layout {
	return root.find_layout(fn [id_focus] (ly Layout) bool {
		return ly.shape.shape_type == .text && ly.shape.id_focus == id_focus
	}) or {
		assert false, 'expected generated input text layout'
		return Layout{}
	}
}

fn generated_text_viewport(text_layout Layout) Layout {
	if text_layout.parent == unsafe { nil } {
		assert false, 'expected generated input text viewport'
		return Layout{}
	}
	return *text_layout.parent
}

fn generated_text_shape_by_text(root &Layout, text string) Shape {
	return root.find_shape(fn [text] (ly Layout) bool {
		return ly.shape.shape_type == .text && ly.shape.tc != unsafe { nil }
			&& ly.shape.tc.text == text
	}) or {
		assert false, 'expected generated text shape ${text}'
		return Shape{}
	}
}

fn generated_text_layout_by_text(root &Layout, text string) Layout {
	return root.find_layout(fn [text] (ly Layout) bool {
		return ly.shape.shape_type == .text && ly.shape.tc != unsafe { nil }
			&& ly.shape.tc.text == text
	}) or {
		assert false, 'expected generated text layout ${text}'
		return Layout{}
	}
}

fn synthetic_single_line_layout(text string, line_x f32, char_width f32) &vglyph.Layout {
	mut char_rects := []vglyph.CharRect{cap: text.len}
	mut char_rect_by_index := map[int]int{}
	for idx in 0 .. text.len {
		char_rect_by_index[idx] = idx
		char_rects << vglyph.CharRect{
			index: idx
			rect:  gg.Rect{
				x:      line_x + (char_width * f32(idx))
				y:      0
				width:  char_width
				height: 10
			}
		}
	}
	mut log_attrs := []vglyph.LogAttr{cap: text.len + 1}
	mut log_attr_by_index := map[int]int{}
	for idx in 0 .. text.len + 1 {
		log_attr_by_index[idx] = idx
		log_attrs << vglyph.LogAttr{
			is_cursor_position: true
		}
	}
	return &vglyph.Layout{
		lines:              [
			vglyph.Line{
				start_index: 0
				length:      text.len
				rect:        gg.Rect{
					x:      line_x
					y:      0
					width:  char_width * f32(text.len)
					height: 10
				}
			},
		]
		char_rects:         char_rects
		char_rect_by_index: char_rect_by_index
		log_attrs:          log_attrs
		log_attr_by_index:  log_attr_by_index
	}
}

fn attach_generated_text_geometry(mut layout Layout, id_focus u32, shape_width f32, line_x f32, char_width f32, text string) bool {
	if layout.shape.shape_type == .text && layout.shape.id_focus == id_focus {
		layout.shape.width = shape_width
		layout.shape.height = 10
		layout.shape.tc.text = text
		layout.shape.tc.text_mode = .single_line
		layout.shape.tc.vglyph_layout = synthetic_single_line_layout(text, line_x, char_width)
		return true
	}
	for mut child in layout.children {
		if attach_generated_text_geometry(mut child, id_focus, shape_width, line_x, char_width,
			text)
		{
			return true
		}
	}
	return false
}

fn attach_generated_text_geometry_by_text(mut layout Layout, expected_text string, shape_width f32, line_x f32, char_width f32, text string) bool {
	if layout.shape.shape_type == .text && layout.shape.tc != unsafe { nil }
		&& layout.shape.tc.text == expected_text {
		layout.shape.width = shape_width
		layout.shape.height = 10
		layout.shape.tc.text = text
		layout.shape.tc.text_mode = .single_line
		layout.shape.tc.vglyph_layout = synthetic_single_line_layout(text, line_x, char_width)
		return true
	}
	for mut child in layout.children {
		if attach_generated_text_geometry_by_text(mut child, expected_text, shape_width, line_x,
			char_width, text)
		{
			return true
		}
	}
	return false
}

fn attach_generated_text_geometry_by_text_index(mut layout Layout, expected_text string, target_index int, shape_width f32, line_x f32, char_width f32, text string) bool {
	mut seen := [0]
	return attach_generated_text_geometry_by_text_index_rec(mut layout, expected_text,
		target_index, shape_width, line_x, char_width, text, mut seen)
}

fn attach_generated_text_geometry_by_text_index_rec(mut layout Layout, expected_text string, target_index int, shape_width f32, line_x f32, char_width f32, text string, mut seen []int) bool {
	if layout.shape.shape_type == .text && layout.shape.tc != unsafe { nil }
		&& layout.shape.tc.text == expected_text {
		if seen[0] == target_index {
			layout.shape.width = shape_width
			layout.shape.height = 10
			layout.shape.tc.text = text
			layout.shape.tc.text_mode = .single_line
			layout.shape.tc.vglyph_layout = synthetic_single_line_layout(text, line_x, char_width)
			return true
		}
		seen[0]++
	}
	for mut child in layout.children {
		if attach_generated_text_geometry_by_text_index_rec(mut child, expected_text, target_index,
			shape_width, line_x, char_width, text, mut seen)
		{
			return true
		}
	}
	return false
}

fn collect_text_scrolls_by_text(layout &Layout, text string, mut scrolls []f32) {
	if layout.shape.shape_type == .text && layout.shape.tc != unsafe { nil }
		&& layout.shape.tc.text == text {
		scrolls << layout.shape.tc.text_scroll_x
	}
	for child in layout.children {
		collect_text_scrolls_by_text(&child, text, mut scrolls)
	}
}

fn set_generated_text_y(mut layout Layout, id_focus u32, y f32) bool {
	if layout.shape.shape_type == .text && layout.shape.id_focus == id_focus {
		layout.shape.y = y
		return true
	}
	for mut child in layout.children {
		if set_generated_text_y(mut child, id_focus, y) {
			return true
		}
	}
	return false
}

fn generated_input_private_scroll_x(cfg InputCfg, mut w Window) f32 {
	return state_map[string, f32](mut w, ns_input_private_scroll_x, cap_scroll).get(input_private_scroll_key(cfg)) or {
		f32(0)
	}
}

fn test_input_default_alignment_remains_left() {
	cfg := InputCfg{}
	assert cfg.text_style.align == .left
	assert cfg.placeholder_style.align == .left
}

fn test_single_line_default_input_has_no_public_scroll_id() {
	cfg := InputCfg{
		id:       'amount'
		id_focus: 9301
		mode:     .single_line
	}
	assert input_text_scroll_id(cfg) == 0
	assert input_text_scroll_id(InputCfg{
		id_focus:  9301
		id_scroll: 77
		mode:      .single_line
	}) == 77
}

fn test_input_private_scroll_key_prefers_stable_input_identity() {
	id_cfg := InputCfg{
		id:       'amount'
		id_focus: 9301
		text:     '12'
		mode:     .single_line
	}
	assert input_private_scroll_key(id_cfg) == input_private_scroll_key(InputCfg{
		...id_cfg
		text: '123456'
	})
	assert input_private_scroll_key(id_cfg) != input_private_scroll_key(InputCfg{
		id:       'other'
		id_focus: 9301
		mode:     .single_line
	})
	field_cfg := InputCfg{
		field_id: 'amount'
		id_focus: 9302
		text:     '12'
		mode:     .single_line
	}
	assert input_private_scroll_key(field_cfg) == input_private_scroll_key(InputCfg{
		...field_cfg
		text: '123456'
	})
	focus_cfg := InputCfg{
		id_focus: 9303
		text:     '12'
		mode:     .single_line
	}
	assert input_private_scroll_key(focus_cfg) == input_private_scroll_key(InputCfg{
		...focus_cfg
		text: '123456'
	})
	readonly_cfg := InputCfg{
		text: '12'
		mode: .single_line
	}
	assert input_private_scroll_key(readonly_cfg) == ''
	assert input_private_scroll_key(InputCfg{
		...readonly_cfg
		text: '123'
	}) == ''
}

fn test_input_text_style_alignment_passes_to_text_shape() {
	mut view := input(
		text:              '42'
		placeholder:       'placeholder'
		text_style:        TextStyle{
			align: .right
		}
		placeholder_style: TextStyle{
			align: .center
		}
	)
	shape := first_text_shape_from_view(mut view)
	assert shape.tc.text == '42'
	assert shape.tc.text_style.align == .right
	assert shape.sizing.width == .fill
}

fn test_input_placeholder_style_alignment_passes_to_text_shape() {
	mut view := input(
		text:              ''
		placeholder:       'placeholder'
		text_style:        TextStyle{
			align: .right
		}
		placeholder_style: TextStyle{
			align: .center
		}
	)
	shape := first_text_shape_from_view(mut view)
	assert shape.tc.text == 'placeholder'
	assert shape.tc.text_is_placeholder
	assert shape.tc.text_style.align == .center
}

fn test_generated_input_text_alignment_uses_text_viewport() {
	cfg := InputCfg{
		id:         'value'
		id_focus:   9302
		text:       '42'
		sizing:     fixed_fixed
		width:      120
		height:     24
		text_style: TextStyle{
			align: .right
		}
	}
	mut view := input(cfg)
	mut w := Window{}
	root := arranged_view_layout(mut view, mut w)
	text_layout := generated_text_layout(&root, cfg.id_focus)
	viewport := generated_text_viewport(text_layout)
	assert text_layout.shape.tc.text == '42'
	assert text_layout.shape.tc.text_style.align == .right
	assert text_layout.shape.id_scroll_container == 0
	assert viewport.shape.id_scroll == 0
	assert viewport.shape.scroll_mode == .horizontal_only
	assert viewport.shape.clip
	assert viewport.children.len == 1
	assert viewport.children[0].shape.shape_type == .text
	if found_scroll := root.find_layout(fn (ly Layout) bool {
		return ly.shape.id_scroll > 0
	})
	{
		_ = found_scroll
		assert false, 'default single-line input should not generate public scroll ids'
	}
	if found_scrollbar := root.find_layout(fn (ly Layout) bool {
		return ly.shape.scrollbar_orientation != .none
	})
	{
		_ = found_scrollbar
		assert false, 'single-line input viewport should hide internal scrollbars'
	}
}

fn test_generated_input_placeholder_alignment_uses_placeholder_style() {
	cfg := InputCfg{
		id:                'placeholder'
		id_focus:          9303
		text:              ''
		placeholder:       'amount'
		sizing:            fixed_fixed
		width:             120
		height:            24
		text_style:        TextStyle{
			align: .right
		}
		placeholder_style: TextStyle{
			align: .center
		}
	}
	mut view := input(cfg)
	mut w := Window{}
	root := arranged_view_layout(mut view, mut w)
	text_layout := generated_text_layout(&root, cfg.id_focus)
	assert text_layout.shape.tc.text == 'amount'
	assert text_layout.shape.tc.text_is_placeholder
	assert text_layout.shape.tc.text_style.align == .center
	assert text_layout.shape.id_scroll_container == 0
}

fn test_numeric_input_alignment_defaults_and_passes_styles_through() {
	default_cfg := NumericInputCfg{}
	assert default_cfg.text_style.align == .left
	assert default_cfg.placeholder_style.align == .left

	mut text_view := numeric_input(
		text:       '12.30'
		step_cfg:   NumericStepCfg{
			show_buttons: false
		}
		text_style: TextStyle{
			align: .right
		}
	)
	text_shape := first_text_shape_from_view(mut text_view)
	assert text_shape.tc.text == '12.30'
	assert text_shape.tc.text_style.align == .right

	mut placeholder_view := numeric_input(
		text:              ''
		placeholder:       'amount'
		step_cfg:          NumericStepCfg{
			show_buttons: false
		}
		text_style:        TextStyle{
			align: .right
		}
		placeholder_style: TextStyle{
			align: .center
		}
	)
	placeholder_shape := first_text_shape_from_view(mut placeholder_view)
	assert placeholder_shape.tc.text == 'amount'
	assert placeholder_shape.tc.text_is_placeholder
	assert placeholder_shape.tc.text_style.align == .center
}

fn test_explicit_single_line_input_scroll_id_scrolls_text_only_not_icon() {
	cfg := InputCfg{
		id:              'with-icon'
		id_focus:        9304
		id_scroll:       123
		text:            '123'
		icon:            'i'
		sizing:          fixed_fixed
		width:           120
		height:          24
		scrollbar_cfg_x: input_hidden_scrollbar_cfg()
		scrollbar_cfg_y: input_hidden_scrollbar_cfg()
	}
	mut view := input(cfg)
	mut w := Window{}
	root := arranged_view_layout(mut view, mut w)
	text_layout := generated_text_layout(&root, cfg.id_focus)
	icon_shape := generated_text_shape_by_text(&root, 'i')
	assert root.shape.id_scroll == 0
	assert text_layout.shape.id_scroll_container == 123
	assert icon_shape.id_scroll_container == 0
	scroll_layout := find_layout_by_id_scroll(root, 123) or {
		assert false, 'expected explicit text viewport'
		return
	}
	assert scroll_layout.children.len == 1
	assert scroll_layout.children[0].shape.shape_type == .text
}

fn test_explicit_single_line_input_preserves_text_viewport_scrollbar_cfg() {
	scroll_id := u32(125)
	cfg := InputCfg{
		id:              'with-visible-scrollbar-and-icon'
		id_focus:        9317
		id_scroll:       scroll_id
		text:            '123'
		icon:            'i'
		sizing:          fixed_fixed
		width:           120
		height:          24
		scrollbar_cfg_x: &ScrollbarCfg{
			id:       'explicit-x-scrollbar'
			overflow: .visible
			size:     13
		}
		scrollbar_cfg_y: input_hidden_scrollbar_cfg()
	}
	mut view := input(cfg)
	mut w := Window{}
	root := arranged_view_layout(mut view, mut w)
	text_layout := generated_text_layout(&root, cfg.id_focus)
	icon_shape := generated_text_shape_by_text(&root, 'i')
	scroll_layout := find_layout_by_id_scroll(root, scroll_id) or {
		assert false, 'expected explicit text viewport'
		return
	}
	horizontal_scrollbar := scroll_layout.find_layout(fn (ly Layout) bool {
		return ly.shape.scrollbar_orientation == .horizontal
			&& ly.shape.id == 'explicit-x-scrollbar'
	}) or {
		assert false, 'expected caller horizontal scrollbar config on text viewport'
		return
	}
	_ = horizontal_scrollbar
	if vertical_scrollbar := scroll_layout.find_layout(fn (ly Layout) bool {
		return ly.shape.scrollbar_orientation == .vertical
	})
	{
		_ = vertical_scrollbar
		assert false, 'caller hidden vertical scrollbar config should be preserved'
	}
	assert root.shape.id_scroll == 0
	assert text_layout.shape.id_scroll_container == scroll_id
	assert icon_shape.id_scroll_container == 0
}

fn test_explicit_single_line_input_scroll_shift_skips_scrollbar_overlay() {
	scroll_id := u32(126)
	mut root := Layout{
		shape:    &Shape{}
		children: [
			Layout{
				shape:    &Shape{
					id_scroll: scroll_id
				}
				children: [
					Layout{
						shape: &Shape{
							shape_type: .text
							x:          10
						}
					},
					Layout{
						shape:    &Shape{
							id:                    'explicit-shift-x-scrollbar'
							scrollbar_orientation: .horizontal
							over_draw:             true
							x:                     20
						}
						children: [
							Layout{
								shape: &Shape{
									id: 'thumb'
									x:  25
								}
							},
						]
					},
				]
			},
		]
	}
	assert input_shift_explicit_scroll_contents(mut root, scroll_id, -30, 0)
	assert f32_are_close(root.children[0].children[0].shape.x, -20)
	assert f32_are_close(root.children[0].children[1].shape.x, 20)
	assert f32_are_close(root.children[0].children[1].children[0].shape.x, 25)
}

fn test_explicit_center_aligned_overflow_rests_without_trailing_scroll() {
	id_focus := u32(9315)
	scroll_id := u32(124)
	mut w := Window{}
	cfg := InputCfg{
		id_focus:        id_focus
		id_scroll:       scroll_id
		text:            '123456'
		mode:            .single_line
		sizing:          fixed_fixed
		width:           100
		height:          24
		scrollbar_cfg_x: input_hidden_scrollbar_cfg()
		scrollbar_cfg_y: input_hidden_scrollbar_cfg()
		text_style:      TextStyle{
			align: .center
		}
	}
	mut view := input(cfg)
	mut root := arranged_view_layout(mut view, mut w)
	assert attach_generated_text_geometry(mut root, id_focus, 240, 0, 40, cfg.text)
	layout_amend(mut root, mut w)
	scroll_x := state_map[u32, f32](mut w, ns_scroll_x, cap_scroll).get(scroll_id) or { f32(0) }
	assert f32_are_close(scroll_x, 0)
}

fn test_generated_single_line_default_scroll_reveals_cursor_after_paste() {
	id_focus := u32(9305)
	mut w := Window{}
	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	imap.set(id_focus, InputState{
		cursor_pos: 2
	})
	cfg_before := InputCfg{
		id_focus: id_focus
		text:     '12'
		mode:     .single_line
		sizing:   fixed_fixed
		width:    100
		height:   24
	}
	got := cfg_before.paste('3456', mut w) or {
		assert false
		return
	}
	assert got == '123456'
	assert input_state_or_default(id_focus, mut w).reveal_cursor

	cfg_after := InputCfg{
		...cfg_before
		text: got
	}
	mut view := input(cfg_after)
	mut root := arranged_view_layout(mut view, mut w)
	assert attach_generated_text_geometry(mut root, id_focus, 240, 0, 40, got)
	before_layout := generated_text_layout(&root, id_focus)
	layout_amend(mut root, mut w)
	scroll_x := generated_input_private_scroll_x(cfg_after, mut w)
	after_layout := generated_text_layout(&root, id_focus)
	assert after_layout.shape.id_scroll_container == 0
	assert scroll_x < 0
	assert f32_are_close(after_layout.shape.x, before_layout.shape.x)
	assert f32_are_close(after_layout.shape.tc.text_scroll_x, scroll_x)
	assert !input_state_or_default(id_focus, mut w).reveal_cursor
	assert w.refresh_layout
}

fn test_generated_right_aligned_overflow_rests_on_trailing_side() {
	id_focus := u32(9306)
	mut w := Window{}
	cfg := InputCfg{
		id_focus:   id_focus
		text:       '123456'
		mode:       .single_line
		sizing:     fixed_fixed
		width:      100
		height:     24
		text_style: TextStyle{
			align: .right
		}
	}
	mut view := input(cfg)
	mut root := arranged_view_layout(mut view, mut w)
	assert attach_generated_text_geometry(mut root, id_focus, 240, 0, 40, cfg.text)
	layout_amend(mut root, mut w)
	scroll_x := generated_input_private_scroll_x(cfg, mut w)
	text_layout := generated_text_layout(&root, id_focus)
	assert scroll_x < 0
	assert f32_are_close(text_layout.shape.tc.text_scroll_x, scroll_x)
}

fn test_generated_center_aligned_overflow_rests_without_trailing_scroll() {
	id_focus := u32(9312)
	mut w := Window{}
	cfg := InputCfg{
		id_focus:   id_focus
		text:       '123456'
		mode:       .single_line
		sizing:     fixed_fixed
		width:      100
		height:     24
		text_style: TextStyle{
			align: .center
		}
	}
	mut view := input(cfg)
	mut root := arranged_view_layout(mut view, mut w)
	assert attach_generated_text_geometry(mut root, id_focus, 240, 0, 40, cfg.text)
	layout_amend(mut root, mut w)
	text_layout := generated_text_layout(&root, id_focus)
	scroll_x := generated_input_private_scroll_x(cfg, mut w)
	assert f32_are_close(scroll_x, 0)
	assert f32_are_close(text_layout.shape.tc.text_scroll_x, 0)
}

fn test_generated_keyboard_cursor_reveal_uses_private_text_scroll_state() {
	id_focus := u32(9313)
	mut w := Window{}
	w.set_id_focus(id_focus)
	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	imap.set(id_focus, InputState{
		cursor_pos: 5
	})
	cfg := InputCfg{
		id_focus: id_focus
		text:     '123456'
		mode:     .single_line
		sizing:   fixed_fixed
		width:    100
		height:   24
	}
	mut view := input(cfg)
	mut root := arranged_view_layout(mut view, mut w)
	assert attach_generated_text_geometry(mut root, id_focus, 240, 0, 40, cfg.text)
	w.layout = root
	text_layout := generated_text_layout(&w.layout, id_focus)
	mut event := Event{
		key_code: .right
	}
	text_layout.shape.events.on_keydown(&text_layout, mut event, mut w)
	private_x := generated_input_private_scroll_x(cfg, mut w)
	public_zero_x := state_map[u32, f32](mut w, ns_scroll_x, cap_scroll).get(0) or { f32(9999) }
	state := input_state_or_default(id_focus, mut w)
	assert event.is_handled
	assert state.cursor_pos == 6
	assert private_x < 0
	assert public_zero_x == 9999
}

fn test_generated_private_scroll_clamp_includes_nonzero_line_origin() {
	id_focus := u32(9316)
	mut w := Window{}
	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	imap.set(id_focus, InputState{
		cursor_pos:    6
		reveal_cursor: true
	})
	cfg := InputCfg{
		id_focus: id_focus
		text:     '123456'
		mode:     .single_line
		sizing:   fixed_fixed
		width:    100
		height:   24
	}
	mut view := input(cfg)
	mut root := arranged_view_layout(mut view, mut w)
	assert attach_generated_text_geometry(mut root, id_focus, 270, 30, 40, cfg.text)
	layout_amend(mut root, mut w)
	text_layout := generated_text_layout(&root, id_focus)
	viewport := generated_text_viewport(text_layout)
	view_width := viewport.shape.width - viewport.shape.padding_width()
	expected_scroll_x := f32_min(0, view_width - 270)
	private_x := generated_input_private_scroll_x(cfg, mut w)
	assert f32_are_close(private_x, expected_scroll_x)
	assert f32_are_close(text_layout.shape.tc.text_scroll_x, expected_scroll_x)
}

fn test_generated_private_scroll_clamp_uses_negative_line_origin_right_edge() {
	id_focus := u32(9318)
	mut w := Window{}
	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	imap.set(id_focus, InputState{
		cursor_pos:    6
		reveal_cursor: true
	})
	cfg := InputCfg{
		id_focus: id_focus
		text:     '123456'
		mode:     .single_line
		sizing:   fixed_fixed
		width:    100
		height:   24
	}
	mut view := input(cfg)
	mut root := arranged_view_layout(mut view, mut w)
	assert attach_generated_text_geometry(mut root, id_focus, 200, -40, 40, cfg.text)
	layout_amend(mut root, mut w)
	text_layout := generated_text_layout(&root, id_focus)
	viewport := generated_text_viewport(text_layout)
	view_width := viewport.shape.width - viewport.shape.padding_width()
	expected_scroll_x := f32_min(0, view_width - 200)
	overestimated_scroll_x := f32_min(0, view_width - 240)
	private_x := generated_input_private_scroll_x(cfg, mut w)
	assert !f32_are_close(private_x, overestimated_scroll_x)
	assert f32_are_close(private_x, expected_scroll_x)
	assert f32_are_close(text_layout.shape.tc.text_scroll_x, expected_scroll_x)
}

fn test_generated_selection_geometry_uses_private_text_scroll_offset() {
	id_focus := u32(9310)
	mut w := Window{}
	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	imap.set(id_focus, InputState{
		cursor_pos:    6
		select_beg:    1
		select_end:    6
		reveal_cursor: true
	})
	cfg := InputCfg{
		id_focus: id_focus
		text:     '123456'
		mode:     .single_line
		sizing:   fixed_fixed
		width:    100
		height:   24
	}
	mut view := input(cfg)
	mut root := arranged_view_layout(mut view, mut w)
	assert attach_generated_text_geometry(mut root, id_focus, 240, 0, 40, cfg.text)
	before_layout := generated_text_layout(&root, id_focus)
	assert before_layout.shape.tc.text_sel_beg == 1
	assert before_layout.shape.tc.text_sel_end == 6
	layout_amend(mut root, mut w)
	after_layout := generated_text_layout(&root, id_focus)
	scroll_x := generated_input_private_scroll_x(cfg, mut w)
	assert scroll_x < 0
	assert f32_are_close(after_layout.shape.x, before_layout.shape.x)
	assert f32_are_close(after_layout.shape.tc.text_scroll_x, scroll_x)
	assert after_layout.shape.tc.text_sel_beg == 1
	assert after_layout.shape.tc.text_sel_end == 6
}

fn test_generated_drag_selection_auto_scroll_uses_private_text_scroll_state() {
	id_focus := u32(9314)
	mut w := Window{
		ui: &gg.Context{
			mouse_pos_x: 250
			mouse_pos_y: 5
		}
	}
	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	imap.set(id_focus, InputState{
		cursor_pos: 0
	})
	cfg := InputCfg{
		id_focus: id_focus
		text:     '12'
		mode:     .single_line
		sizing:   fixed_fixed
		width:    100
		height:   24
	}
	mut view := input(cfg)
	mut root := arranged_view_layout(mut view, mut w)
	assert attach_generated_text_geometry(mut root, id_focus, 200, 0, 100, cfg.text)
	w.layout = root
	text_layout := generated_text_layout(&w.layout, id_focus)
	w.ui.mouse_buttons = .left
	w.view_state.mouse_lock = MouseLockCfg{
		cursor_pos: 0
	}
	mut event := Event{
		mouse_x: text_layout.shape.x + 250
		mouse_y: text_layout.shape.y + 5
	}
	text_mouse_move_locked(&text_layout, mut event, mut w, false)
	assert w.has_animation(id_auto_scroll_animation)

	mut an := Animate{
		id:       id_auto_scroll_animation
		callback: fn (mut _ Animate, mut _ Window) {}
	}
	text_auto_scroll_cursor(id_focus, 0, mut an, mut w, false)
	state := input_state_or_default(id_focus, mut w)
	private_x := generated_input_private_scroll_x(cfg, mut w)
	public_zero_x := state_map[u32, f32](mut w, ns_scroll_x, cap_scroll).get(0) or { f32(9999) }
	assert state.cursor_pos == 1
	assert state.select_beg == 0
	assert state.select_end == 1
	assert private_x < 0
	assert public_zero_x == 9999
}

fn test_default_single_line_input_inside_outer_scroll_reveals_vertically_and_keeps_private_text_scroll() {
	id_focus := u32(9311)
	outer_scroll_id := u32(8877)
	mut w := Window{}
	cfg := InputCfg{
		id_focus: id_focus
		text:     '123456'
		mode:     .single_line
		sizing:   fixed_fixed
		width:    100
		height:   24
	}
	mut view := column(
		id_scroll:       outer_scroll_id
		sizing:          fixed_fixed
		width:           120
		height:          40
		scrollbar_cfg_x: input_hidden_scrollbar_cfg()
		scrollbar_cfg_y: input_hidden_scrollbar_cfg()
		padding:         padding_none
		content:         [
			column(
				sizing:  fixed_fixed
				width:   100
				height:  160
				padding: padding_none
			),
			input(cfg),
		]
	)
	mut root := arranged_view_layout(mut view, mut w)
	assert root.shape.id_scroll == outer_scroll_id
	assert attach_generated_text_geometry(mut root, id_focus, 240, 0, 40, cfg.text)
	assert set_generated_text_y(mut root, id_focus, 180)
	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	imap.set(id_focus, InputState{
		cursor_pos:    6
		reveal_cursor: true
	})
	layout_amend(mut root, mut w)
	text_layout := generated_text_layout(&root, id_focus)
	private_x := generated_input_private_scroll_x(cfg, mut w)
	outer_x := state_map[u32, f32](mut w, ns_scroll_x, cap_scroll).get(outer_scroll_id) or {
		f32(0)
	}
	outer_y := state_map[u32, f32](mut w, ns_scroll_y, cap_scroll).get(outer_scroll_id) or {
		f32(0)
	}
	assert text_layout.shape.id_scroll_container == outer_scroll_id
	assert private_x < 0
	assert f32_are_close(text_layout.shape.tc.text_scroll_x, private_x)
	assert f32_are_close(outer_x, 0)
	assert outer_y < 0
	assert !input_state_or_default(id_focus, mut w).reveal_cursor
}

fn test_readonly_generated_right_aligned_overflow_gets_passive_rest_scroll() {
	cfg := InputCfg{
		text:       '123456'
		mode:       .single_line
		sizing:     fixed_fixed
		width:      100
		height:     24
		text_style: TextStyle{
			align: .right
		}
	}
	mut view := input(cfg)
	mut w := Window{}
	mut root := arranged_view_layout(mut view, mut w)
	text_layout := generated_text_layout_by_text(&root, cfg.text)
	assert text_layout.shape.id_scroll_container == 0
	assert attach_generated_text_geometry_by_text(mut root, cfg.text, 240, 0, 40, cfg.text)
	layout_amend(mut root, mut w)
	after_text_layout := generated_text_layout_by_text(&root, cfg.text)
	assert input_private_scroll_key(cfg) == ''
	assert after_text_layout.shape.tc.text_scroll_x < 0
	assert f32_are_close(generated_input_private_scroll_x(cfg, mut w), 0)
	assert w.view_state.registry.entry_count(ns_input_private_scroll_x) == 0
	assert !w.refresh_layout
}

fn test_readonly_anonymous_private_scroll_is_layout_local_for_same_text_different_widths() {
	text_value := '123456'
	narrow_cfg := InputCfg{
		text:       text_value
		mode:       .single_line
		sizing:     fixed_fixed
		width:      100
		height:     24
		text_style: TextStyle{
			align: .right
		}
	}
	wide_cfg := InputCfg{
		...narrow_cfg
		width: 180
	}
	mut view := column(
		padding: padding_none
		content: [
			input(narrow_cfg),
			input(wide_cfg),
		]
	)
	mut w := Window{}
	mut root := arranged_view_layout(mut view, mut w)
	assert input_private_scroll_key(narrow_cfg) == ''
	assert input_private_scroll_key(wide_cfg) == ''
	assert attach_generated_text_geometry_by_text_index(mut root, text_value, 0, 240, 0, 40,
		text_value)
	assert attach_generated_text_geometry_by_text_index(mut root, text_value, 1, 240, 0, 40,
		text_value)
	layout_amend(mut root, mut w)

	mut scrolls := []f32{}
	collect_text_scrolls_by_text(&root, text_value, mut scrolls)
	assert scrolls.len == 2
	assert scrolls[0] < scrolls[1]
	assert scrolls[0] < 0
	assert scrolls[1] < 0
	assert w.view_state.registry.entry_count(ns_input_private_scroll_x) == 0
	assert !w.refresh_layout
}

fn test_generated_input_edit_reveals_cursor_on_next_layout_amend() {
	id_focus := u32(9309)
	mut state := &InputAlignmentTestState{}
	mut w := Window{
		state: state
	}
	w.set_id_focus(id_focus)
	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	imap.set(id_focus, InputState{
		cursor_pos: 2
	})
	cfg_before := InputCfg{
		id:              'two-frame-edit'
		id_focus:        id_focus
		text:            '12'
		mode:            .single_line
		sizing:          fixed_fixed
		width:           100
		height:          24
		on_text_changed: fn (_ &Layout, text string, mut w Window) {
			mut state := w.state[InputAlignmentTestState]()
			state.changed_text = text
		}
	}
	mut before_view := input(cfg_before)
	before_root := arranged_view_layout(mut before_view, mut w)
	mut event := Event{
		char_code: u32(`3`)
	}
	before_root.shape.events.on_char(&before_root, mut event, mut w)
	assert event.is_handled
	assert state.changed_text == '123'
	assert input_state_or_default(id_focus, mut w).reveal_cursor

	cfg_after := InputCfg{
		...cfg_before
		text: state.changed_text
	}
	mut after_view := input(cfg_after)
	mut after_root := arranged_view_layout(mut after_view, mut w)
	assert input_state_or_default(id_focus, mut w).reveal_cursor
	assert attach_generated_text_geometry(mut after_root, id_focus, 120, 0, 40, state.changed_text)
	layout_amend(mut after_root, mut w)
	scroll_x := generated_input_private_scroll_x(cfg_after, mut w)
	text_layout := generated_text_layout(&after_root, id_focus)
	assert scroll_x < 0
	assert f32_are_close(text_layout.shape.tc.text_scroll_x, scroll_x)
	assert !input_state_or_default(id_focus, mut w).reveal_cursor
}

fn test_generated_password_overflow_reveals_masked_caret() {
	id_focus := u32(9307)
	text_value := 'secret'
	mut w := Window{}
	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	imap.set(id_focus, InputState{
		cursor_pos:    text_value.len
		reveal_cursor: true
	})
	cfg := InputCfg{
		id_focus:    id_focus
		text:        text_value
		mode:        .single_line
		is_password: true
		sizing:      fixed_fixed
		width:       100
		height:      24
		text_style:  TextStyle{
			align: .right
		}
	}
	mut view := input(cfg)
	mut root := arranged_view_layout(mut view, mut w)
	assert attach_generated_text_geometry(mut root, id_focus, 240, 0, 40, text_value)
	layout_amend(mut root, mut w)
	scroll_x := generated_input_private_scroll_x(cfg, mut w)
	text_layout := generated_text_layout(&root, id_focus)
	assert scroll_x < 0
	assert f32_are_close(text_layout.shape.tc.text_scroll_x, scroll_x)
	assert !input_state_or_default(id_focus, mut w).reveal_cursor
}

fn test_multiline_input_preserves_outer_scroll_behavior() {
	cfg := InputCfg{
		id_focus:  9308
		id_scroll: 456
		text:      'line 1\nline 2'
		mode:      .multiline
		sizing:    fixed_fixed
		width:     120
		height:    60
	}
	mut view := input(cfg)
	mut w := Window{}
	root := arranged_view_layout(mut view, mut w)
	text_layout := generated_text_layout(&root, cfg.id_focus)
	assert root.shape.id_scroll == 456
	assert text_layout.shape.id_scroll_container == 456
}

fn test_fixed_width_single_line_insert_allows_overflow_for_scroll_clip() {
	id_focus := u32(9201)
	mut w := Window{}
	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	imap.set(id_focus, InputState{
		cursor_pos: 2
	})
	cfg := InputCfg{
		id_focus: id_focus
		text:     '12'
		mode:     .single_line
		sizing:   fixed_fixed
		width:    10
	}

	got := cfg.insert('3456', mut w) or {
		assert false
		return
	}
	assert got == '123456'
	state := input_state_or_default(id_focus, mut w)
	assert state.cursor_pos == 6
}

fn test_fixed_width_masked_insert_allows_overflow_for_scroll_clip() {
	id_focus := u32(9202)
	mut w := Window{}
	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	imap.set(id_focus, InputState{
		cursor_pos: 2
	})
	cfg := InputCfg{
		id_focus: id_focus
		text:     '12'
		mask:     '999999'
		mode:     .single_line
		sizing:   fixed_fixed
		width:    10
	}

	got := cfg.insert('3456', mut w) or {
		assert false
		return
	}
	assert got == '123456'
	state := input_state_or_default(id_focus, mut w)
	assert state.cursor_pos == 6
}
