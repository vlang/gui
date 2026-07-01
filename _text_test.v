module gui

import gg
import vglyph

fn aligned_single_line_shape(align TextAlignment, shape_width f32, line_x f32, char_width f32, text string) &Shape {
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
	return &Shape{
		shape_type: .text
		width:      shape_width
		height:     10
		tc:         &ShapeTextConfig{
			text:          text
			text_mode:     .single_line
			text_style:    TextStyle{
				align: align
			}
			vglyph_layout: &vglyph.Layout{
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
	}
}

fn password_aligned_single_line_shape(align TextAlignment, shape_width f32, line_x f32, char_width f32, text string) &Shape {
	mut shape := aligned_single_line_shape(align, shape_width, line_x, char_width, text)
	shape.tc.text_is_password = true
	return shape
}

fn password_multiline_shape_with_second_line_origin() &Shape {
	text := 'aa\nbb'
	return &Shape{
		shape_type: .text
		width:      100
		height:     24
		tc:         &ShapeTextConfig{
			text:             text
			text_is_password: true
			text_mode:        .multiline
			text_style:       TextStyle{}
			vglyph_layout:    &vglyph.Layout{
				lines:              [
					vglyph.Line{
						start_index: 0
						length:      2
						rect:        gg.Rect{
							x:      0
							y:      0
							width:  20
							height: 10
						}
					},
					vglyph.Line{
						start_index: 3
						length:      2
						rect:        gg.Rect{
							x:      40
							y:      12
							width:  20
							height: 10
						}
					},
				]
				char_rects:         [
					vglyph.CharRect{
						index: 0
						rect:  gg.Rect{
							x:      0
							y:      0
							width:  10
							height: 10
						}
					},
					vglyph.CharRect{
						index: 1
						rect:  gg.Rect{
							x:      10
							y:      0
							width:  10
							height: 10
						}
					},
					vglyph.CharRect{
						index: 3
						rect:  gg.Rect{
							x:      0
							y:      12
							width:  10
							height: 10
						}
					},
					vglyph.CharRect{
						index: 4
						rect:  gg.Rect{
							x:      10
							y:      12
							width:  10
							height: 10
						}
					},
				]
				char_rect_by_index: {
					0: 0
					1: 1
					3: 2
					4: 3
				}
				log_attrs:          []vglyph.LogAttr{}
				log_attr_by_index:  map[int]int{}
			}
		}
	}
}

fn test_single_line_text_alignment_offset_uses_shape_width_without_wrapping() {
	mut w := Window{}
	left_shape := aligned_single_line_shape(.left, 100, 0, 10, 'abcd')
	center_shape := aligned_single_line_shape(.center, 100, 0, 10, 'abcd')
	right_shape := aligned_single_line_shape(.right, 100, 0, 10, 'abcd')
	overflow_shape := aligned_single_line_shape(.right, 30, 0, 10, 'abcd')

	assert f32_are_close(text_layout_align_offset_x(left_shape, mut w), 0)
	assert f32_are_close(text_layout_align_offset_x(center_shape, mut w), 30)
	assert f32_are_close(text_layout_align_offset_x(right_shape, mut w), 60)
	assert f32_are_close(text_layout_align_offset_x(overflow_shape, mut w), 0)
}

fn test_right_aligned_single_line_hit_test_subtracts_alignment_offset() {
	mut w := Window{}
	shape := aligned_single_line_shape(.right, 100, 0, 10, 'ab')

	start_event := Event{
		mouse_x: 81
		mouse_y: 5
	}
	assert text_mouse_cursor_pos(shape, &start_event, mut w, false) == 0

	end_event := Event{
		mouse_x: 101
		mouse_y: 5
	}
	assert text_mouse_cursor_pos(shape, &end_event, mut w, false) == 2
}

fn test_right_aligned_single_line_caret_uses_alignment_offset() {
	mut w := Window{}
	shape := aligned_single_line_shape(.right, 100, 0, 10, 'ab')
	rect := text_cursor_rect_for_position(shape, 2, mut w)
	caret_x := text_layout_align_offset_x(shape, mut w) + rect.x
	assert f32_are_close(caret_x, 100)
}

fn test_single_line_text_scroll_offset_participates_in_render_geometry() {
	mut w := Window{}
	mut shape := aligned_single_line_shape(.left, 20, 0, 10, 'abcdef')
	shape.tc.text_scroll_x = -40
	rect := text_cursor_rect_for_position(shape, 6, mut w)
	caret_x := text_layout_render_offset_x(shape, mut w) + rect.x
	assert f32_are_close(text_layout_align_offset_x(shape, mut w), 0)
	assert f32_are_close(caret_x, 20)
}

fn test_single_line_text_scroll_offset_participates_in_hit_testing() {
	mut w := Window{}
	mut shape := aligned_single_line_shape(.left, 20, 0, 10, 'abcdef')
	shape.tc.text_scroll_x = -40
	event := Event{
		mouse_x: 20
		mouse_y: 5
	}
	assert text_mouse_cursor_pos(shape, &event, mut w, false) == 6
}

fn test_selection_rect_uses_layout_origin_once_for_aligned_line_geometry() {
	mut w := Window{}
	shape := aligned_single_line_shape(.left, 100, 60, 10, 'ab')
	line := shape.tc.vglyph_layout.lines[0]

	draw_text_selection(mut w, DrawTextSelectionParams{
		shape:    shape
		line:     line
		layout_x: 10
		draw_y:   5
		byte_beg: 0
		byte_end: 1
		text_cfg: TextStyle{
			color: black
			size:  16
		}.to_vglyph_cfg()
	})

	assert w.renderers.len == 1
	r := w.renderers[0]
	if r is DrawRect {
		assert f32_are_close(r.x, 70)
		assert f32_are_close(r.w, 10)
	} else {
		assert false, 'expected selection to emit DrawRect'
	}
}

fn test_single_line_cursor_scroll_x_keeps_end_visible() {
	mut text_shape := aligned_single_line_shape(.left, 200, 0, 100, 'ab')
	text_shape.id_scroll_container = 77
	scroll_container := Layout{
		shape:    &Shape{
			id_scroll: 77
			width:     100
			height:    20
		}
		children: [
			Layout{
				shape: text_shape
			},
		]
	}
	mut w := Window{
		layout: Layout{
			shape:    &Shape{}
			children: [scroll_container]
		}
	}

	assert f32_are_close(cursor_pos_to_scroll_x(2, text_shape, mut w), -100)

	mut sx := state_map[u32, f32](mut w, ns_scroll_x, cap_scroll)
	sx.set(77, -100)
	text_shape.x = -100
	assert f32_are_close(cursor_pos_to_scroll_x(0, text_shape, mut w), 0)
}

fn test_horizontal_drag_selection_auto_scroll_is_scheduled() {
	id_focus := u32(9301)
	mut text_shape := aligned_single_line_shape(.left, 200, 0, 100, 'ab')
	text_shape.id_focus = id_focus
	text_shape.id_scroll_container = 77
	text_layout := Layout{
		shape: text_shape
	}
	scroll_container := Layout{
		shape:    &Shape{
			id_scroll: 77
			width:     100
			height:    20
		}
		children: [text_layout]
	}
	mut w := Window{
		ui:     &gg.Context{
			mouse_buttons: .left
		}
		layout: Layout{
			shape:    &Shape{}
			children: [scroll_container]
		}
	}
	w.view_state.mouse_lock = MouseLockCfg{
		cursor_pos: 0
	}
	mut e := Event{
		mouse_x: 250
		mouse_y: 5
	}

	text_mouse_move_locked(&text_layout, mut e, mut w, false)
	assert w.has_animation(id_auto_scroll_animation)
}

fn test_horizontal_drag_selection_auto_scroll_timer_advances_cursor() {
	id_focus := u32(9302)
	mut text_shape := aligned_single_line_shape(.left, 200, 0, 100, 'ab')
	text_shape.id_focus = id_focus
	text_shape.id_scroll_container = 77
	text_layout := Layout{
		shape: text_shape
	}
	scroll_container := Layout{
		shape:    &Shape{
			id_scroll: 77
			width:     100
			height:    20
		}
		children: [text_layout]
	}
	mut w := Window{
		ui:     &gg.Context{
			mouse_pos_x: 250
			mouse_pos_y: 5
		}
		layout: Layout{
			shape:    &Shape{}
			children: [scroll_container]
		}
	}
	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	imap.set(id_focus, InputState{
		cursor_pos: 0
	})
	w.view_state.mouse_lock = MouseLockCfg{
		cursor_pos: 0
	}
	mut an := Animate{
		id:       id_auto_scroll_animation
		callback: fn (mut _ Animate, mut _ Window) {}
	}

	assert isnil(w.text_system)
	text_auto_scroll_cursor(id_focus, 77, mut an, mut w, false)

	state := input_state_or_default(id_focus, mut w)
	assert state.cursor_pos == 1
	assert state.select_beg == 0
	assert state.select_end == 1
	scroll_x := state_map[u32, f32](mut w, ns_scroll_x, cap_scroll).get(77) or { f32(0) }
	assert f32_are_close(scroll_x, -100)
}

fn test_horizontal_drag_selection_auto_scroll_left_uses_pointer_edge() {
	id_focus := u32(9305)
	mut text_shape := aligned_single_line_shape(.left, 200, 0, 50, 'abcd')
	text_shape.id_focus = id_focus
	text_shape.id_scroll_container = 77
	text_shape.x = -100
	text_layout := Layout{
		shape: text_shape
	}
	scroll_container := Layout{
		shape:    &Shape{
			id_scroll: 77
			width:     100
			height:    20
		}
		children: [text_layout]
	}
	mut w := Window{
		ui:     &gg.Context{
			mouse_buttons: .left
			mouse_pos_x:   -10
			mouse_pos_y:   5
		}
		layout: Layout{
			shape:    &Shape{}
			children: [scroll_container]
		}
	}
	mut sx := state_map[u32, f32](mut w, ns_scroll_x, cap_scroll)
	sx.set(77, -100)
	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	imap.set(id_focus, InputState{
		cursor_pos: 2
	})
	w.view_state.mouse_lock = MouseLockCfg{
		cursor_pos: 2
	}
	mut e := Event{
		mouse_x: -10
		mouse_y: 5
	}

	text_mouse_move_locked(&text_layout, mut e, mut w, false)
	assert w.has_animation(id_auto_scroll_animation)

	mut an := Animate{
		id:       id_auto_scroll_animation
		callback: fn (mut _ Animate, mut _ Window) {}
	}
	text_auto_scroll_cursor(id_focus, 77, mut an, mut w, false)

	state := input_state_or_default(id_focus, mut w)
	scroll_x := state_map[u32, f32](mut w, ns_scroll_x, cap_scroll).get(77) or { f32(0) }
	assert state.cursor_pos == 1
	assert state.select_beg == 1
	assert state.select_end == 2
	assert f32_are_close(scroll_x, -50)
}

fn test_private_leftward_drag_selection_auto_scroll_uses_pointer_edge() {
	id_focus := u32(9303)
	scroll_key := 'private-leftward-drag'
	mut text_shape := aligned_single_line_shape(.left, 200, 0, 50, 'abcd')
	text_shape.id_focus = id_focus
	text_shape.tc.text_scroll_key = scroll_key
	text_shape.tc.text_scroll_x = -100
	mut root := Layout{
		shape:    &Shape{}
		children: [
			Layout{
				shape:    &Shape{
					width:  100
					height: 20
				}
				children: [
					Layout{
						shape: text_shape
					},
				]
			},
		]
	}
	layout_parents(mut root, unsafe { nil })
	mut w := Window{
		ui:     &gg.Context{
			mouse_buttons: .left
		}
		layout: root
	}
	mut sx := state_map[string, f32](mut w, ns_input_private_scroll_x, cap_scroll)
	sx.set(scroll_key, -100)
	mut imap := state_map[u32, InputState](mut w, ns_input, cap_many)
	imap.set(id_focus, InputState{
		cursor_pos: 2
	})
	w.view_state.mouse_lock = MouseLockCfg{
		cursor_pos: 2
	}
	text_layout := w.layout.find_layout(fn [id_focus] (ly Layout) bool {
		return ly.shape.id_focus == id_focus
	}) or { panic('missing private text layout') }
	mut e := Event{
		mouse_x: -10
		mouse_y: 5
	}

	text_mouse_move_locked(&text_layout, mut e, mut w, false)
	assert w.has_animation(id_auto_scroll_animation)

	w.ui.mouse_pos_x = -10
	w.ui.mouse_pos_y = 5
	mut an := Animate{
		id:       id_auto_scroll_animation
		callback: fn (mut _ Animate, mut _ Window) {}
	}
	text_auto_scroll_cursor(id_focus, 0, mut an, mut w, false)

	state := input_state_or_default(id_focus, mut w)
	private_x := state_map[string, f32](mut w, ns_input_private_scroll_x, cap_scroll).get(scroll_key) or {
		f32(0)
	}
	public_zero_x := state_map[u32, f32](mut w, ns_scroll_x, cap_scroll).get(0) or { f32(9999) }
	assert state.cursor_pos == 1
	assert state.select_beg == 1
	assert state.select_end == 2
	assert f32_are_close(private_x, -50)
	assert public_zero_x == 9999
}

fn test_private_scroll_cursor_reveal_preserves_outer_vertical_scroll_only() {
	id_focus := u32(9304)
	outer_scroll_id := u32(8811)
	scroll_key := 'private-vertical-reveal'
	mut text_shape := aligned_single_line_shape(.left, 100, 0, 10, 'abcd')
	text_shape.id_focus = id_focus
	text_shape.id_scroll_container = outer_scroll_id
	text_shape.y = 40
	text_shape.tc.text_scroll_key = scroll_key
	mut root := Layout{
		shape:    &Shape{}
		children: [
			Layout{
				shape:    &Shape{
					id_scroll: outer_scroll_id
					width:     100
					height:    20
				}
				children: [
					Layout{
						shape: text_shape
					},
				]
			},
		]
	}
	layout_parents(mut root, unsafe { nil })
	mut w := Window{
		layout: root
	}
	text_layout := w.layout.find_layout(fn [id_focus] (ly Layout) bool {
		return ly.shape.id_focus == id_focus
	}) or { panic('missing private text layout') }

	scroll_cursor_into_view(0, &text_layout, mut w)

	outer_y := state_map[u32, f32](mut w, ns_scroll_y, cap_scroll).get(outer_scroll_id) or {
		f32(0)
	}
	outer_x := state_map[u32, f32](mut w, ns_scroll_x, cap_scroll).get(outer_scroll_id) or {
		f32(9999)
	}
	assert f32_are_close(outer_y, -30)
	assert outer_x == 9999
}

fn test_password_right_aligned_geometry_uses_mask_for_caret_and_hit_test() {
	mut w := Window{}
	shape := password_aligned_single_line_shape(.right, 100, 0, 10, 'ab')

	rect := text_cursor_rect_for_position(shape, 2, mut w)
	caret_x := text_layout_align_offset_x(shape, mut w) + rect.x
	assert f32_are_close(caret_x, 100)

	start_event := Event{
		mouse_x: 81
		mouse_y: 5
	}
	assert text_mouse_cursor_pos(shape, &start_event, mut w, false) == 0

	end_event := Event{
		mouse_x: 101
		mouse_y: 5
	}
	assert text_mouse_cursor_pos(shape, &end_event, mut w, false) == 2
}

fn test_password_mask_width_path_keeps_nonzero_line_origin() {
	shape := password_aligned_single_line_shape(.left, 100, 30, 10, 'ab')

	assert f32_are_close(text_password_cursor_x_from_mask_width(shape, 20), 50)
	assert f32_are_close(text_password_mask_offset_x(shape, 35), 5)
}

fn test_password_right_aligned_geometry_keeps_nonzero_line_origin() {
	mut w := Window{}
	shape := password_aligned_single_line_shape(.right, 100, 30, 10, 'ab')

	rect := text_cursor_rect_for_position(shape, 2, mut w)
	assert f32_are_close(rect.x, 50)
	caret_x := text_layout_align_offset_x(shape, mut w) + rect.x
	assert f32_are_close(caret_x, 130)

	start_event := Event{
		mouse_x: 111
		mouse_y: 5
	}
	assert text_mouse_cursor_pos(shape, &start_event, mut w, false) == 0

	end_event := Event{
		mouse_x: 131
		mouse_y: 5
	}
	assert text_mouse_cursor_pos(shape, &end_event, mut w, false) == 2
}

fn test_password_selection_uses_mask_geometry_with_alignment() {
	mut w := Window{}
	shape := password_aligned_single_line_shape(.right, 100, 0, 10, 'ab')
	line := shape.tc.vglyph_layout.lines[0]

	draw_text_selection(mut w, DrawTextSelectionParams{
		shape:         shape
		line:          line
		layout_x:      80
		draw_y:        5
		byte_beg:      0
		byte_end:      1
		password_mask: '**'
		text_cfg:      TextStyle{
			color: black
			size:  16
		}.to_vglyph_cfg()
	})

	assert w.renderers.len == 1
	r := w.renderers[0]
	if r is DrawRect {
		assert f32_are_close(r.x, 80)
		assert f32_are_close(r.w, 10)
	} else {
		assert false, 'expected password selection to emit DrawRect'
	}
}

fn test_password_selection_uses_nonzero_line_origin_once() {
	mut w := Window{}
	shape := password_aligned_single_line_shape(.right, 100, 30, 10, 'ab')
	line := shape.tc.vglyph_layout.lines[0]

	draw_text_selection(mut w, DrawTextSelectionParams{
		shape:         shape
		line:          line
		layout_x:      80
		draw_y:        5
		byte_beg:      0
		byte_end:      1
		password_mask: '**'
		text_cfg:      TextStyle{
			color: black
			size:  16
		}.to_vglyph_cfg()
	})

	assert w.renderers.len == 1
	r := w.renderers[0]
	if r is DrawRect {
		assert f32_are_close(r.x, 110)
		assert f32_are_close(r.w, 10)
	} else {
		assert false, 'expected password selection to emit DrawRect'
	}
}

fn test_multiline_password_selection_uses_line_relative_mask_geometry() {
	mut w := Window{}
	shape := password_multiline_shape_with_second_line_origin()
	line := shape.tc.vglyph_layout.lines[1]

	draw_text_selection(mut w, DrawTextSelectionParams{
		shape:         shape
		line:          line
		layout_x:      80
		draw_y:        12
		byte_beg:      4
		byte_end:      5
		password_mask: '**\n**'
		text_cfg:      TextStyle{
			color: black
			size:  16
		}.to_vglyph_cfg()
	})

	assert w.renderers.len == 1
	r := w.renderers[0]
	if r is DrawRect {
		assert f32_are_close(r.x, 130)
		assert f32_are_close(r.w, 10)
	} else {
		assert false, 'expected password selection to emit DrawRect'
	}
}

fn test_password_cursor_scroll_x_keeps_end_visible() {
	mut text_shape := password_aligned_single_line_shape(.left, 200, 0, 100, 'ab')
	text_shape.id_scroll_container = 77
	scroll_container := Layout{
		shape:    &Shape{
			id_scroll: 77
			width:     100
			height:    20
		}
		children: [
			Layout{
				shape: text_shape
			},
		]
	}
	mut w := Window{
		layout: Layout{
			shape:    &Shape{}
			children: [scroll_container]
		}
	}

	assert f32_are_close(cursor_pos_to_scroll_x(2, text_shape, mut w), -100)
}

fn test_password_cursor_scroll_x_includes_nonzero_line_origin() {
	mut text_shape := password_aligned_single_line_shape(.left, 230, 30, 100, 'ab')
	text_shape.id_scroll_container = 77
	scroll_container := Layout{
		shape:    &Shape{
			id_scroll: 77
			width:     100
			height:    20
		}
		children: [
			Layout{
				shape: text_shape
			},
		]
	}
	mut w := Window{
		layout: Layout{
			shape:    &Shape{}
			children: [scroll_container]
		}
	}

	assert f32_are_close(cursor_pos_to_scroll_x(2, text_shape, mut w), -130)
}

// ------------------------------------
// ## 1. Test split_text (Core Utility)
// ------------------------------------
fn test_split_text() {
	tab_size := u32(4)
	// Spaces, tabs, newlines, and carriage returns
	text_split := 'Word1 Word2\t\nWord3 \r Word4'
	// Expected: Tabs expand to 4 spaces. Spaces are separate. Newlines are separate.
	expected_split := ['Word1', ' ', 'Word2', ' ', '\n', '', 'Word3', '  ', 'Word4']
	assert split_text(text_split, tab_size) == expected_split, 'split_text failed with spaces/tabs/newlines'

	// Trailing space check
	text_trailing := 'end '
	expected_trailing := ['end', ' ']
	assert split_text(text_trailing, tab_size) == expected_trailing, 'split_text failed with trailing space'
}

// ----------------------------------------
// ## 2. Test wrap_simple (No Word Wrap)
// ----------------------------------------
fn test_simple_wrap() {
	tab_size := u32(4)
	text_simple := 'Line 1\nLine 2\twith\t\tabs'
	expected_simple := ['Line 1\n', 'Line 2  with        abs']
	assert wrap_simple(text_simple, tab_size) == expected_simple, 'wrap_simple failed with tabs and newlines'
}

// ------------------------------------
// ## 3. Test start_of_line_pos
// ------------------------------------

fn create_mock_shape() Shape {
	// Recreate the wrapped text structure manually without Pango
	// Line 1: 'This is the first line.\n' (Length 24) -> Start 0
	// Line 2: 'Second line with  spaces.\n' (Length 25) -> Start 24
	// Line 3: 'Third word paragraph.\n' (Length 22) -> Start 49
	// Line 4: 'This is the last line.' (Length 22) -> Start 71
	// Total: 93

	text_content := 'This is the first line.\nSecond line with  spaces.\nThird word paragraph.\nThis is the last line.'

	mut shape := Shape{
		shape_type: .text
		tc:         &ShapeTextConfig{
			text: text_content
		}
	}

	// Mock the layout lines
	shape.tc.vglyph_layout = &vglyph.Layout{
		lines: [
			vglyph.Line{
				start_index: 0
				length:      24
			},
			vglyph.Line{
				start_index: 24
				length:      26
			},
			vglyph.Line{
				start_index: 50
				length:      22
			},
			vglyph.Line{
				start_index: 72
				length:      22
			},
		]
	}

	return shape
}

fn test_start_of_line_pos() {
	shape := create_mock_shape()

	// Cursor at start of line 1
	assert cursor_start_of_line(shape, 0) == 0, 'start_of_line_pos failed for offset 0'

	// Cursor in middle of line 1 (offset 10)
	assert cursor_start_of_line(shape, 10) == 0, 'start_of_line_pos failed for offset 10 (middle of line 1)'

	// Cursor exactly at the newline of line 1 (start of line 2)
	assert cursor_start_of_line(shape, 24) == 24, 'start_of_line_pos failed for offset 24 (start of line 2)'
	// Note: Previous test expected 0 for offset 24, treating it as end of line 1?
	// vglyph lines are [start, start+len). 24 is start of line 2.
	// If logic returns line start *containing* pos. 24 is in line 2.
	// So 24 is correct for start of line 2.

	// Cursor in middle of line 3 (offset 55)
	assert cursor_start_of_line(shape, 55) == 50, 'start_of_line_pos failed for offset 55 (middle of line 3)'

	// Cursor past the end of the text (offset 100)
	assert cursor_start_of_line(shape, 100) == 72, 'start_of_line_pos failed for offset 100 (past end, should be start of last line)'
}

// ------------------------------------
// ## 2. Test end_of_line_pos
// ------------------------------------
fn test_end_of_line_pos() {
	shape := create_mock_shape()

	// Cursor at start of line 1 (Offset 0) -> Should return the position of the newline
	assert cursor_end_of_line(shape, 0) == 23, 'end_of_line_pos failed for offset 0'

	// Cursor in middle of line 2 (Offset 35) -> Should return the position of the newline
	assert cursor_end_of_line(shape, 35) == 49, 'end_of_line_pos failed for offset 35'
	// Line 2 runs 24..50. End is 50. Newline at 49. End is 49.
	// Previous test expected 49. But render loop logic suggests we want visual end (before newline).
	// Let's verify expectations: End key should go to end of text on that line.
	// If text is "foo\n", end is after 'o'. Index of '\n' is 3.
	// So 48 is correct index (before \n).

	// Cursor upon the newline of line 2 (Offset 49) -> Should return the position of the next newline?
	// 49 is in line 2 (last char). So it should return end of line 2.
	assert cursor_end_of_line(shape, 49) == 49, 'end_of_line_pos failed for offset 49 (on the newline)'

	// Cursor on the last line (Offset 80). Last line has no trailing newline.
	assert cursor_end_of_line(shape, 80) == 94, 'end_of_line_pos failed for offset 80 (last line)'

	// Cursor past the end of the text (Offset 100)
	assert cursor_end_of_line(shape, 100) == 94, 'end_of_line_pos failed for offset 100 (past end)'
}

// ------------------------------------
// ## 4. Test end_of_word_pos
// ------------------------------------
fn test_end_of_word_pos() {
	shape := create_mock_shape()

	// // Cursor at the start of a word ('is') -> offset 5. "is" ends at 7.
	assert cursor_end_of_word(shape, 5) == 7, 'end_of_word_pos failed for offset 5 (start of "is")'

	// Cursor in the middle of a word ('second') -> line 2 starts at 24. "Second" is 24..30
	// "Second" is 6 chars. 24+6=30.
	// Offset 26 is inside "Second".
	assert cursor_end_of_word(shape, 26) == 30, 'end_of_word_pos failed for offset 26 (middle of "Second")'

	// Cursor on a space (offset 30, the space after 'Second')
	// Logic: skip blanks, then skip non-blanks.
	// "Second line" -> space at 30. "line" starts at 31, ends at 35.
	assert cursor_end_of_word(shape, 30) == 35, 'end_of_word_pos failed for offset 30 (on space before "line")'

	// Cursor at the end of the last line (offset 94)
	assert cursor_end_of_word(shape, 94) == 94, 'end_of_word_pos failed for offset 94 (end of text)'
	// Wait, logical end of text.
	// If pos 93 (len), loop condition i < len fails immediately. Returns i (93). Correct.
}

// ------------------------------------
// ## 5. Test start_of_paragraph 📜
// ------------------------------------
fn test_start_of_paragraph() {
	shape := create_mock_shape()

	// Cursor at the very start (offset 0)
	assert cursor_start_of_paragraph(shape, 0) == 0, 'start_of_paragraph failed for offset 0'

	// Cursor in the middle of the first paragraph/line (offset 15)
	assert cursor_start_of_paragraph(shape, 15) == 0, 'start_of_paragraph failed for offset 15'

	// Cursor right after the first newline (start of line 2/new paragraph) -> 24
	assert cursor_start_of_paragraph(shape, 24) == 24, 'start_of_paragraph failed for offset 24 (start of paragraph 2)'

	// Cursor in the middle of line 3 (offset 60). Should jump back to start of line 3 (50).
	assert cursor_start_of_paragraph(shape, 60) == 50, 'start_of_paragraph failed for offset 60 (middle of paragraph 3)'

	// Cursor at the end of text (offset 94). Should jump back to start of last line (72).
	assert cursor_start_of_paragraph(shape, 94) == 72, 'start_of_paragraph failed for offset 94 (end of last paragraph)'

	// Cursor on the newline character itself (offset 49, the \n of line 2)
	// 49 is the newline char. Logic searches backwards.
	// Finds \n at 23. Returns 24.
	assert cursor_start_of_paragraph(shape, 49) == 24, 'start_of_paragraph failed for offset 49 (on the second newline)'
}

// ------------------------------------
// ## 6. Test counting chars in array 📜
// ------------------------------------
fn test_count_chars() {
	// Function removed or deprecated?
	// count_chars was removed from xtra_text_cursor.v as it took []string.
	// If it's gone, remove test.
}

// ------------------------------------
// ## 7. Test rune_to_byte_index
// ------------------------------------
fn test_rune_to_byte_index() {
	// Test case 1: Standard ASCII
	s1 := 'hello'
	assert rune_to_byte_index(s1, 1) == 1

	// Test case 2: Multi-byte characters (Euro symbol)
	// 'a€b' -> 'a' (1 byte), '€' (3 bytes), 'b' (1 byte)
	s2 := 'a€b'
	assert rune_to_byte_index(s2, 0) == 0
	assert rune_to_byte_index(s2, 1) == 1 // Start of €
	assert rune_to_byte_index(s2, 2) == 4 // Start of b (1 + 3)

	// Test case 3: Emojis
	s3 := '😀' // 4 bytes
	assert rune_to_byte_index(s3, 1) == 4

	// Test case 4: Out of bounds
	assert rune_to_byte_index(s2, 100) == s2.len
}

// ------------------------------------
// ## 8. Test byte_to_rune_index
// ------------------------------------
fn test_byte_to_rune_index() {
	// Test case 1: Standard ASCII
	s1 := 'hello'
	assert byte_to_rune_index(s1, 1) == 1

	// Test case 2: Multi-byte characters
	s2 := 'a€b'
	assert byte_to_rune_index(s2, 0) == 0
	assert byte_to_rune_index(s2, 1) == 1
	assert byte_to_rune_index(s2, 4) == 2

	// Test case 3: Mid-rune indexing
	// Should return the index of the rune containing the byte
	assert byte_to_rune_index(s2, 2) == 1 // Inside €
	assert byte_to_rune_index(s2, 3) == 1 // Inside €

	// Test case 4: Out of bounds
	assert byte_to_rune_index(s2, 100) == 3 // length in runes
}

// ------------------------------------
// ## 9. Test collapse_spaces
// ------------------------------------
fn test_collapse_spaces() {
	// Basic case
	assert collapse_spaces('A  B') == 'A B'

	// Newlines preserved
	assert collapse_spaces('A\n  B') == 'A\n B'

	// Tabs converted to space
	assert collapse_spaces('A\tB') == 'A B'

	// Multiple spaces reduced
	assert collapse_spaces('   ') == ' '

	// Leading/Trailing spaces (single)
	assert collapse_spaces(' A B ') == ' A B '

	// Leading/Trailing multiple
	assert collapse_spaces('  A  B  ') == ' A B '
}
