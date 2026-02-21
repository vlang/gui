module gui

// layout_wrap restructures wrap containers into column-of-rows.
// Called after layout_fill_widths (widths resolved) and before
// layout_wrap_text. Greedy line-breaking groups children into
// implicit row layouts, then changes the container axis to
// top_to_bottom so downstream passes handle multi-row height
// and positioning naturally.
fn layout_wrap(mut layout Layout) {
	mut scratch := ScratchPools{}
	layout_wrap_with_scratch(mut layout, mut scratch)
}

fn layout_wrap_with_scratch(mut layout Layout, mut scratch ScratchPools) {
	for mut child in layout.children {
		layout_wrap_with_scratch(mut child, mut scratch)
	}

	if !layout.shape.wrap || layout.shape.axis != .left_to_right || layout.children.len == 0 {
		return
	}

	available := layout.shape.width - layout.shape.padding_width()
	if available <= 0 {
		return
	}

	spacing := layout.shape.spacing

	mut rows := scratch.take_wrap_rows(layout.children.len)
	defer {
		scratch.put_wrap_rows(mut rows)
	}
	mut row_start := 0
	mut row_width := f32(0)

	for idx, child in layout.children {
		if child.shape.float || child.shape.shape_type == .none || child.shape.over_draw {
			continue
		}

		child_w := child.shape.width
		gap := if row_width > 0 { spacing } else { f32(0) }

		if row_width + gap + child_w > available && idx > row_start {
			rows << WrapRowRange{
				start: row_start
				end:   idx
			}
			row_start = idx
			row_width = 0
		}

		row_width += (if row_width > 0 { spacing } else { f32(0) }) + child_w
	}
	if row_start < layout.children.len {
		rows << WrapRowRange{
			start: row_start
			end:   layout.children.len
		}
	}

	if rows.len <= 1 {
		return
	}

	layout.shape.axis = .top_to_bottom

	mut new_children := []Layout{cap: rows.len}
	for row in rows {
		mut row_children := []Layout{cap: row.end - row.start}
		for i in row.start .. row.end {
			row_children << layout.children[i]
		}
		new_children << Layout{
			shape:    &Shape{
				shape_type: .rectangle
				axis:       .left_to_right
				sizing:     fixed_fit
				width:      available
				spacing:    spacing
				color:      Color{
					a: 0
				}
				h_align:    layout.shape.h_align
				v_align:    layout.shape.v_align
				text_dir:   layout.shape.text_dir
			}
			children: row_children
		}
	}

	layout.children = new_children

	for mut row in layout.children {
		layout_parents(mut row, layout)
	}
}
