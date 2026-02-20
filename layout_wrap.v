module gui

// layout_wrap restructures wrap containers into column-of-rows.
// Called after layout_fill_widths (widths resolved) and before
// layout_wrap_text. Greedy line-breaking groups children into
// implicit row layouts, then changes the container axis to
// top_to_bottom so downstream passes handle multi-row height
// and positioning naturally.
fn layout_wrap(mut layout Layout) {
	for mut child in layout.children {
		layout_wrap(mut child)
	}

	if !layout.shape.wrap || layout.shape.axis != .left_to_right {
		return
	}

	available := layout.shape.width - layout.shape.padding_width()
	if available <= 0 {
		return
	}

	spacing := layout.shape.spacing

	mut rows := [][]Layout{cap: 4}
	mut current_row := []Layout{cap: layout.children.len}
	mut row_width := f32(0)

	for child in layout.children {
		if child.shape.float || child.shape.shape_type == .none || child.shape.over_draw {
			current_row << child
			continue
		}

		child_w := child.shape.width
		gap := if row_width > 0 { spacing } else { f32(0) }

		if row_width + gap + child_w > available && current_row.len > 0 {
			rows << current_row
			current_row = []Layout{cap: 4}
			row_width = 0
		}

		current_row << child
		row_width += (if row_width > 0 { spacing } else { f32(0) }) + child_w
	}
	if current_row.len > 0 {
		rows << current_row
	}

	if rows.len <= 1 {
		return
	}

	layout.shape.axis = .top_to_bottom

	mut new_children := []Layout{cap: rows.len}
	for row_children in rows {
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
