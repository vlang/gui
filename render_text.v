module gui

import gg
import log
import vglyph

fn text_shape_draw_transform(shape &Shape) ?vglyph.AffineTransform {
	if shape.id_focus > 0 {
		return none
	}
	if !shape.tc.text_style.has_text_transform() {
		return none
	}
	return shape.tc.text_style.effective_text_transform()
}

fn clone_layout_for_draw(src &vglyph.Layout) &vglyph.Layout {
	if src == unsafe { nil } {
		return &vglyph.Layout{}
	}
	return &vglyph.Layout{
		cloned_object_ids:  src.cloned_object_ids.clone()
		items:              src.items.clone()
		glyphs:             src.glyphs.clone()
		char_rects:         src.char_rects.clone()
		char_rect_by_index: src.char_rect_by_index.clone()
		lines:              src.lines.clone()
		log_attrs:          src.log_attrs.clone()
		log_attr_by_index:  src.log_attr_by_index.clone()
		width:              src.width
		height:             src.height
		visual_width:       src.visual_width
		visual_height:      src.visual_height
	}
}

fn password_mask_text_keep_newlines(text string) string {
	mut out := []rune{cap: utf8_str_visible_length(text)}
	for r in text.runes_iterator() {
		if r == `\n` {
			out << `\n`
		} else {
			out << `*`
		}
	}
	return out.string()
}

// render_text renders text including multiline text using vglyph layout.
// If cursor coordinates are present, it draws the input cursor.
// The highlighting of selected text happens here also.
fn render_text(mut shape Shape, clip DrawClip, mut window Window) {
	dr := gg.Rect{
		x:      shape.x
		y:      shape.y
		width:  shape.width
		height: shape.height
	}
	if !rects_overlap(dr, clip) {
		shape.disabled = true
		return
	}
	color := if shape.disabled {
		dim_alpha(shape.tc.text_style.color)
	} else {
		shape.tc.text_style.color
	}
	text_cfg := TextStyle{
		...shape.tc.text_style
		color: color
	}.to_vglyph_cfg()

	has_stroke := shape.tc.text_style.stroke_width > 0
	if shape.has_text_layout() && (color != color_transparent || has_stroke) {
		if transform := text_shape_draw_transform(shape) {
			mut layout_to_draw := clone_layout_for_draw(shape.tc.vglyph_layout)
			if window.text_system != unsafe { nil } {
				mut cfg := text_cfg
				cfg.block.width = shape.tc.last_constraint_width
				cfg.no_hit_testing = true
				text_to_layout := if shape.tc.text_is_password && !shape.tc.text_is_placeholder {
					password_mask_text_keep_newlines(shape.tc.text)
				} else {
					shape.tc.text
				}
				mut transformed_layout := window.text_system.layout_text(text_to_layout,
					cfg) or {
					log.error('Transformed text layout failed at (${shape.x}, ${shape.y}): ${err.msg()}')
					return
				}
				if transformed_layout.lines.len > 0 || text_to_layout.len == 0 {
					layout_to_draw = clone_layout_for_draw(&transformed_layout)
				}
			}
			emit_renderer(DrawLayoutTransformed{
				layout:    layout_to_draw
				x:         shape.x + shape.padding_left()
				y:         shape.y + shape.padding_top()
				transform: transform
				gradient:  shape.tc.text_style.gradient
			}, mut window)
			return
		}
	}

	lh := line_height(shape, mut window)
	beg := int(shape.tc.text_sel_beg)
	end := int(shape.tc.text_sel_end)

	// Convert selection range to byte indices because vglyph uses bytes
	byte_beg := rune_to_byte_index(shape.tc.text, beg)
	byte_end := rune_to_byte_index(shape.tc.text, end)

	has_gradient := shape.tc.text_style.gradient != unsafe { nil }

	if shape.has_text_layout() {
		// Gradient text: emit single DrawLayout for full layout
		if has_gradient && (color != color_transparent || has_stroke) {
			layout_to_draw := clone_layout_for_draw(shape.tc.vglyph_layout)
			emit_renderer(DrawLayout{
				layout:   layout_to_draw
				x:        shape.x + shape.padding_left()
				y:        shape.y + shape.padding_top()
				gradient: shape.tc.text_style.gradient
			}, mut window)
		}

		for line in shape.tc.vglyph_layout.lines {
			draw_x := shape.x + shape.padding_left() + line.rect.x
			draw_y := shape.y + shape.padding_top() + line.rect.y

			// Extract text for this line
			if line.start_index >= shape.tc.text.len {
				continue
			}
			mut line_end := line.start_index + line.length
			if line_end > shape.tc.text.len {
				line_end = shape.tc.text.len
			}

			// Drawing
			draw_rect := gg.Rect{
				x:      draw_x
				y:      draw_y
				width:  shape.width // approximate, or use line.rect.width
				height: lh
			}

			// Cull
			if rects_overlap(clip, draw_rect) && (color != color_transparent || has_stroke) {
				if !has_gradient {
					// Remove newlines for rendering
					mut slice_end := line_end
					if slice_end > line.start_index && shape.tc.text[slice_end - 1] == `\n` {
						slice_end--
					}
					mut render_str := shape.tc.text[line.start_index..slice_end]

					if shape.tc.text_is_password && !shape.tc.text_is_placeholder {
						render_str = password_char.repeat(utf8_str_visible_length(render_str))
					}

					if render_str.len > 0 {
						window.renderers << DrawText{
							x:    draw_x
							y:    draw_y
							text: render_str
							cfg:  text_cfg
						}
					}
				}

				// Draw text selection
				if byte_beg < line_end && byte_end > line.start_index {
					draw_text_selection(mut window, DrawTextSelectionParams{
						shape:    shape
						line:     line
						draw_x:   draw_x
						draw_y:   draw_y
						byte_beg: byte_beg
						byte_end: byte_end
						text_cfg: text_cfg
					})
				}
			}
		}
	}

	render_cursor(shape, clip, mut window)
}

fn draw_text_selection(mut window Window, params DrawTextSelectionParams) {
	shape := params.shape
	line := params.line
	draw_x := params.draw_x
	draw_y := params.draw_y
	byte_beg := params.byte_beg
	byte_end := params.byte_end
	text_cfg := params.text_cfg

	// Intersection
	i_start := int_max(byte_beg, line.start_index)
	i_end := int_min(byte_end, line.start_index + line.length)

	if i_start < i_end {
		if shape.tc.text_is_password {
			// Password fields still need measurement because the rendered text (*)
			// is different from the logical text.
			pre_text := shape.tc.text[line.start_index..i_start]
			sel_text := shape.tc.text[i_start..i_end]

			pw_pre := password_char.repeat(utf8_str_visible_length(pre_text))
			start_x_offset := window.text_system.text_width(pw_pre, text_cfg) or { 0 }

			pw_sel := password_char.repeat(utf8_str_visible_length(sel_text))
			sel_width := window.text_system.text_width(pw_sel, text_cfg) or { 0 }

			window.renderers << DrawRect{
				x:     draw_x + start_x_offset
				y:     draw_y
				w:     sel_width
				h:     line.rect.height
				color: gg.Color{
					...text_cfg.style.color
					a: 60
				}
			}
		} else {
			// Optimization: Use cached layout geometry
			// Get rect for start char
			r_start := shape.tc.vglyph_layout.get_char_rect(i_start) or { gg.Rect{} }

			// Get rect for end char (or end of line)
			x_end := if i_end < (line.start_index + line.length) && shape.tc.text[i_end] != `\n` {
				r_end := shape.tc.vglyph_layout.get_char_rect(i_end) or {
					gg.Rect{
						x: line.rect.width
					}
				}
				r_end.x
			} else {
				// End of selection is end of line (or newline)
				line.rect.width
			}

			sel_width := x_end - r_start.x

			window.renderers << DrawRect{
				x:     draw_x + r_start.x
				y:     draw_y
				w:     sel_width
				h:     line.rect.height
				color: gg.Color{
					...text_cfg.style.color
					a: 60
				}
			}
		}
	}
}

// render_cursor figures out where the darn cursor goes using vglyph.
fn render_cursor(shape &Shape, clip DrawClip, mut window Window) {
	if window.is_focus(shape.id_focus) && shape.shape_type == .text
		&& window.view_state.input_cursor_on {
		input_state := window.view_state.input_state.get(shape.id_focus) or { InputState{} }
		cursor_pos := if shape.tc.text_is_placeholder {
			0
		} else {
			int_min(input_state.cursor_pos, shape.tc.text.runes().len)
		}

		if cursor_pos >= 0 {
			byte_idx := rune_to_byte_index(shape.tc.text, cursor_pos)

			// Use vglyph to get the rect
			rect := if shape.has_text_layout() {
				shape.tc.vglyph_layout.get_char_rect(byte_idx) or {
					// If not found, check if it's at the very end
					if byte_idx >= shape.tc.text.len && shape.tc.vglyph_layout.lines.len > 0 {
						last_line := shape.tc.vglyph_layout.lines.last()
						// Correction: use layout logic relative to shape
						gg.Rect{
							x:      last_line.rect.x + last_line.rect.width
							y:      last_line.rect.y
							height: last_line.rect.height
						}
					} else {
						gg.Rect{
							height: line_height(shape, mut window)
						} // Fallback
					}
				}
			} else {
				gg.Rect{
					height: line_height(shape, mut window)
				}
			}
			cx := shape.x + shape.padding_left() + rect.x
			cy := shape.y + shape.padding_top() + rect.y
			ch := rect.height

			// Draw cursor line
			window.renderers << DrawRect{
				x:     cx
				y:     cy
				w:     1.5 // slightly thicker
				h:     ch
				color: shape.tc.text_style.color.to_gx_color()
				style: .fill
			}
		}
	}

	// Draw IME composition underlines when composing
	if window.is_focus(shape.id_focus) && shape.has_text_layout()
		&& window.text_system != unsafe { nil } && window.text_system.is_composing()
		&& !shape.tc.text_is_password {
		render_composition(shape, mut window)
	}
}

// render_composition draws clause underlines for active IME
// preedit text. Thick underline for selected clause, thin for
// others.
fn render_composition(shape &Shape, mut window Window) {
	cs := window.text_system.composition
	clause_rects := cs.get_clause_rects(*shape.tc.vglyph_layout)
	text_color := shape.tc.text_style.color.to_gx_color()
	underline_color := gg.Color{
		r: text_color.r
		g: text_color.g
		b: text_color.b
		a: 178 // ~70% opacity
	}

	ox := shape.x + shape.padding_left()
	oy := shape.y + shape.padding_top()

	for cr in clause_rects {
		thickness := if cr.style == .selected {
			f32(2.0)
		} else {
			f32(1.0)
		}
		for rect in cr.rects {
			window.renderers << DrawRect{
				x:     ox + rect.x
				y:     oy + rect.y + rect.height - thickness
				w:     rect.width
				h:     thickness
				color: underline_color
				style: .fill
			}
		}
	}
}
