module gui

// layout_wrap_text runs after widths are set. Wrapping changes min-height,
// so this runs before height calculation.
fn layout_wrap_text(mut layout Layout, mut w Window) {
	text_wrap(mut layout.shape, mut w)
	for mut child in layout.children {
		layout_wrap_text(mut child, mut w)
	}
}

// layout_adjust_scroll_offsets ensures scroll offsets are in range.
// Scroll offsets can go out of range during window resizing.
fn layout_adjust_scroll_offsets(mut layout Layout, mut w Window) {
	id_scroll := layout.shape.id_scroll
	if id_scroll > 0 {
		max_offset_x := f32_min(0, layout.shape.width - layout.shape.padding_width() - content_width(layout))
		offset_x := w.view_state.scroll_x.get(id_scroll) or { f32(0) }
		w.view_state.scroll_x.set(id_scroll, f32_clamp(offset_x, max_offset_x, 0))

		max_offset_y := f32_min(0, layout.shape.height - layout.shape.padding_height() - content_height(layout))
		offset_y := w.view_state.scroll_y.get(id_scroll) or { f32(0) }
		w.view_state.scroll_y.set(id_scroll, f32_clamp(offset_y, max_offset_y, 0))
	}
	for mut child in layout.children {
		layout_adjust_scroll_offsets(mut child, mut w)
	}
}

// layout_positions sets positions and handles alignment. Alignment only
// affects x/y positions, not sizes.
fn layout_positions(mut layout Layout, offset_x f32, offset_y f32, w &Window) {
	layout.shape.x += offset_x
	layout.shape.y += offset_y

	axis := layout.shape.axis
	spacing := layout.shape.spacing

	if layout.shape.id_scroll > 0 {
		layout.shape.clip = true
	}

	mut x := layout.shape.x + layout.shape.padding_left()
	mut y := layout.shape.y + layout.shape.padding_top()

	if layout.shape.id_scroll > 0 {
		x += w.view_state.scroll_x.get(layout.shape.id_scroll) or { f32(0) }
		y += w.view_state.scroll_y.get(layout.shape.id_scroll) or { f32(0) }
	}

	// Eventually start/end will be culture dependent
	h_align := match layout.shape.h_align {
		.start { HorizontalAlign.left }
		.left { HorizontalAlign.left }
		.center { HorizontalAlign.center }
		.end { HorizontalAlign.right }
		.right { HorizontalAlign.right }
	}

	// alignment along the axis
	match axis {
		.left_to_right {
			if h_align != .left {
				mut remaining := layout.shape.width - layout.shape.padding_width()
				remaining -= layout.spacing()
				for child in layout.children {
					remaining -= child.shape.width
				}
				if h_align == .center {
					remaining /= 2
				}
				x += remaining
			}
		}
		.top_to_bottom {
			if layout.shape.v_align != .top {
				mut remaining := layout.shape.height - layout.shape.padding_height()
				remaining -= layout.spacing()
				for child in layout.children {
					remaining -= child.shape.height
				}
				if layout.shape.v_align == .middle {
					remaining /= 2
				}
				y += remaining
			}
		}
		.none {}
	}

	for mut child in layout.children {
		// alignment across the axis
		mut x_align := f32(0)
		mut y_align := f32(0)
		match axis {
			.left_to_right {
				remaining := layout.shape.height - child.shape.height - layout.shape.padding_height()
				if remaining > 0 {
					match layout.shape.v_align {
						.top {}
						.middle { y_align = remaining / 2 }
						else { y_align = remaining }
					}
				}
			}
			.top_to_bottom {
				remaining := layout.shape.width - child.shape.width - layout.shape.padding_width()
				if remaining > 0 {
					match h_align {
						.left {}
						.center { x_align = remaining / 2 }
						else { x_align = remaining }
					}
				}
			}
			.none {}
		}

		layout_positions(mut child, x + x_align, y + y_align, w)

		if child.shape.shape_type != .none {
			match axis {
				.left_to_right { x += child.shape.width + spacing }
				.top_to_bottom { y += child.shape.height + spacing }
				.none {}
			}
		}
	}
}

// layout_disables walks the Layout and disables any children
// that have a disabled ancestor.
fn layout_disables(mut layout Layout, disabled bool) {
	mut is_disabled := disabled || layout.shape.disabled
	layout.shape.disabled = is_disabled
	for mut child in layout.children {
		layout_disables(mut child, is_disabled)
	}
}

// layout_scroll_containers identifies which text views are in a
// scrollable container (row, column).
fn layout_scroll_containers(mut layout Layout, id_scroll_container u32) {
	for mut ly in layout.children {
		id := match ly.shape.id_scroll > 0 {
			true { ly.shape.id_scroll }
			else { id_scroll_container }
		}
		layout_scroll_containers(mut ly, id)
		// Motivation: `text` views are not directly scrollable but must live inside
		// a scrollable container. Selecting text can push selection outside the
		// visible region. Use `id_scroll_container` to track the parent.
		if ly.shape.shape_type == .text {
			ly.shape.id_scroll_container = id_scroll_container
		}
	}
}

// layout_set_shape_clips - shape_clips are used for hit testing.
fn layout_set_shape_clips(mut layout Layout, clip DrawClip) {
	shape_clip := DrawClip{
		x:      layout.shape.x
		y:      layout.shape.y
		width:  layout.shape.width
		height: layout.shape.height
	}

	layout.shape.shape_clip = rect_intersection(shape_clip, clip) or { DrawClip{} }

	for mut child in layout.children {
		layout_set_shape_clips(mut child, layout.shape.shape_clip)
	}
}

// layout_amend handles layout problems resolvable only after sizing/positioning,
// such as mouse-over events affecting appearance. Avoid altering sizes here.
fn layout_amend(mut layout Layout, mut w Window) {
	for mut child in layout.children {
		layout_amend(mut child, mut w)
	}
	if layout.shape.amend_layout != unsafe { nil } {
		layout.shape.amend_layout(mut layout, mut w)
	}
}

// layout_hover encapsulates hover handling logic.
fn layout_hover(mut layout Layout, mut w Window) bool {
	if w.mouse_is_locked() {
		return false
	}
	for mut child in layout.children {
		is_handled := layout_hover(mut child, mut w)
		if is_handled {
			return true
		}
	}
	if layout.shape.on_hover != unsafe { nil } {
		if layout.shape.disabled {
			return false
		}
		if w.dialog_cfg.visible && !layout_in_dialog_layout(layout) {
			return false
		}
		ctx := w.context()
		if layout.shape.point_in_shape(ctx.mouse_pos_x, ctx.mouse_pos_y) {
			// fake an event to get mouse button states.
			mouse_button := match true {
				ctx.mbtn_mask & 0x01 > 0 { MouseButton.left }
				ctx.mbtn_mask & 0x02 > 0 { MouseButton.right }
				ctx.mbtn_mask & 0x04 > 0 { MouseButton.middle }
				else { MouseButton.invalid }
			}
			mut ev := Event{
				frame_count:   ctx.frame
				typ:           .invalid
				modifiers:     unsafe { Modifier(ctx.key_modifiers) }
				mouse_button:  mouse_button
				mouse_x:       ctx.mouse_pos_x
				mouse_y:       ctx.mouse_pos_y
				mouse_dx:      ctx.mouse_dx
				mouse_dy:      ctx.mouse_dy
				scroll_x:      ctx.scroll_x
				scroll_y:      ctx.scroll_y
				window_width:  ctx.width
				window_height: ctx.height
			}
			layout.shape.on_hover(mut layout, mut ev, mut w)
			return ev.is_handled
		}
	}
	return false
}
