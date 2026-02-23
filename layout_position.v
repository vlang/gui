module gui

// layout_position.v implements the position and scroll-clamping passes of the
// layout pipeline. layout_positions() assigns x/y to every node, handles RTL
// axis reversal, applies scroll offsets, and resolves h_align/v_align.
// layout_adjust_scroll_offsets() clamps stored offsets when window is resized.
// layout_wrap_text() runs the text-wrap pass after widths are finalized.

// layout_adjust_scroll_offsets ensures scroll offsets are in range.
// Scroll offsets can go out of range during window resizing.
fn layout_adjust_scroll_offsets(mut layout Layout, mut w Window) {
	id_scroll := layout.shape.id_scroll
	if id_scroll > 0 {
		mut sx := state_map[u32, f32](mut w, ns_scroll_x, cap_scroll)
		mut sy := state_map[u32, f32](mut w, ns_scroll_y, cap_scroll)
		max_offset_x := f32_min(0, layout.shape.width - layout.shape.padding_width() - content_width(layout))
		offset_x := sx.get(id_scroll) or { f32(0) }
		sx.set(id_scroll, f32_clamp(offset_x, max_offset_x, 0))

		max_offset_y := f32_min(0, layout.shape.height - layout.shape.padding_height() - content_height(layout))
		offset_y := sy.get(id_scroll) or { f32(0) }
		sy.set(id_scroll, f32_clamp(offset_y, max_offset_y, 0))
	}
	for mut child in layout.children {
		layout_adjust_scroll_offsets(mut child, mut w)
	}
}

// layout_positions sets positions and handles alignment. Alignment only
// affects x/y positions, not sizes.
fn layout_positions(mut layout Layout, offset_x f32, offset_y f32, mut w Window) {
	layout.shape.x += offset_x
	layout.shape.y += offset_y

	axis := layout.shape.axis
	spacing := layout.shape.spacing

	if layout.shape.id_scroll > 0 {
		layout.shape.clip = true
	}

	is_rtl := effective_text_dir(layout.shape) == .rtl

	mut x := if is_rtl && axis == .left_to_right {
		layout.shape.x + layout.shape.width - layout.shape.padding.left - layout.shape.size_border
	} else if is_rtl {
		// Column/none RTL: physical left = end side
		layout.shape.x + layout.shape.padding.right + layout.shape.size_border
	} else {
		layout.shape.x + layout.shape.padding_left()
	}
	mut y := layout.shape.y + layout.shape.padding_top()

	if layout.shape.id_scroll > 0 {
		mut sx := state_map[u32, f32](mut w, ns_scroll_x, cap_scroll)
		mut sy := state_map[u32, f32](mut w, ns_scroll_y, cap_scroll)
		x += sx.get(layout.shape.id_scroll) or { f32(0) }
		y += sy.get(layout.shape.id_scroll) or { f32(0) }
	}

	// Resolve start/end based on text direction
	h_align := match layout.shape.h_align {
		.start {
			if is_rtl { HorizontalAlign.right } else { HorizontalAlign.left }
		}
		.end {
			if is_rtl { HorizontalAlign.left } else { HorizontalAlign.right }
		}
		.left {
			HorizontalAlign.left
		}
		.right {
			HorizontalAlign.right
		}
		.center {
			HorizontalAlign.center
		}
	}

	// alignment along the axis
	match axis {
		.left_to_right {
			if is_rtl {
				if h_align != .right {
					mut remaining := layout.shape.width - layout.shape.padding_width()
					remaining -= layout.spacing()
					for child in layout.children {
						remaining -= child.shape.width
					}
					if h_align == .center {
						remaining /= 2
					}
					x -= remaining
				}
			} else {
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

		if is_rtl && axis == .left_to_right {
			layout_positions(mut child, x - child.shape.width + x_align, y + y_align, mut
				w)
		} else {
			layout_positions(mut child, x + x_align, y + y_align, mut w)
		}

		if child.shape.shape_type != .none {
			match axis {
				.left_to_right {
					if is_rtl {
						x -= child.shape.width + spacing
					} else {
						x += child.shape.width + spacing
					}
				}
				.top_to_bottom {
					y += child.shape.height + spacing
				}
				.none {}
			}
		}
	}
}

// layout_scroll_containers identifies which text views are in a
// scrollable container (row, column).
fn layout_scroll_containers(mut layout Layout, id_scroll_container u32) {
	active_id := if layout.shape.id_scroll > 0 {
		layout.shape.id_scroll
	} else {
		id_scroll_container
	}
	// Motivation: `text` views are not directly scrollable but must live inside
	// a scrollable container. Selecting text can push selection outside the
	// visible region. Use the nearest active container.
	if layout.shape.shape_type == .text {
		layout.shape.id_scroll_container = active_id
	}
	for mut child in layout.children {
		layout_scroll_containers(mut child, active_id)
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
