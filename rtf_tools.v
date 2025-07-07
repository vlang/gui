module gui

// spans_size returns the total width and height of span collection
fn spans_size(spans []TextSpan) (f32, f32) {
	// A single line can have multiple spans. The start of a line
	// is when span.x == 0
	mut width := f32(0)
	mut height := f32(0)
	mut w := f32(0)
	mut h := f32(0)
	for span in spans {
		if span.x == 0 {
			width = f32_max(w, width)
			height += h
			w = span.w
			h = span.h
		} else {
			w += span.w
			h = f32_max(h, span.h)
		}
	}
	width = f32_max(w, width)
	height += h
	return width, height
}

// rtf_simple wraps only at new lines. Tabs are not expanded
fn rtf_simple(spans []TextSpan, mut window Window) []TextSpan {
	mut x := f32(0)
	mut y := f32(0)
	mut tspans := []TextSpan{}
	for span in spans {
		for i, line in span.text.split('\n') {
			if i > 0 {
				x = 0
				y += span.style.size + span.style.line_spacing
			}
			width := get_text_width(line, span.style, mut window)
			tspans << TextSpan{
				x:     x
				y:     y
				w:     width
				h:     span.style.size
				text:  line
				style: span.style
			}
			x += width
		}
	}
	return tspans
}

fn rtf_wrap_text(spans []TextSpan, width f32, tab_size u32, mut window Window) []TextSpan {
	mut x := f32(0)
	mut y := f32(0)
	mut h := f32(0)
	mut tspans := []TextSpan{}
	mut tspan := TextSpan{}

	for i, span in spans {
		if i > 0 {
			x += tspan.w
			tspans << tspan
		}

		tspan = TextSpan{
			...span
			x:    x
			y:    y
			h:    span.style.size
			text: ''
		}

		h = f32_max(h, tspan.h)

		for field in split_text(span.text, tab_size) {
			if field == '\n' {
				tspans << tspan
				x = 0
				y += h
				h = span.style.size

				tspan = TextSpan{
					...span
					y:    y
					h:    h
					text: ''
				}
				continue
			}
			if tspan.text.len == 0 {
				field_width := get_text_width(field, tspan.style, mut window)
				if x + field_width > width {
					x = 0
					y += h
					h = span.style.size
					tspan.x = x
					tspan.y = y
					tspan.h = h
				}
				tspan.text = field
				tspan.w = field_width
				continue
			}
			line := tspan.text + field
			line_width := get_text_width(line, tspan.style, mut window)
			if x + line_width > width {
				tspan.w = get_text_width(tspan.text, tspan.style, mut window)
				tspans << tspan
				x = 0
				y += h
				h = span.style.size

				tspan = TextSpan{
					...span
					y:    y
					h:    h
					text: field.trim_space_left()
				}
			} else {
				tspan.text = line
				tspan.w = line_width
			}
		}
	}
	tspans << tspan
	return tspans
}
