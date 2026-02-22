module gui

// render_text.v handles text shape rendering. It manages the vglyph layout
// cache (keyed by a hash of text, style, and size), password masking,
// placeholder text, cursor rendering (render_cursor reads input_cursor_on
// live — never captured in a closure), and text-transform affine matrices.
// clone_layout_for_draw deep-clones vglyph layouts for renderer lifetime.
import gg
import log
import vglyph

@[inline]
fn hash_combine_u64(seed u64, value u64) u64 {
	return (seed ^ value) * u64(1099511628211)
}

fn transformed_layout_cache_key(shape &Shape, text_hash int, cfg vglyph.TextConfig) u64 {
	ts := shape.tc.text_style
	mut key := u64(1469598103934665603)
	key = hash_combine_u64(key, u64(text_hash))
	key = hash_combine_u64(key, u64(int(cfg.block.width * 1000)))
	key = hash_combine_u64(key, u64(int(ts.size * 1000)))
	key = hash_combine_u64(key, u64(int(ts.letter_spacing * 1000)))
	key = hash_combine_u64(key, u64(ts.typeface))
	key = hash_combine_u64(key, u64(ts.family.hash()))
	key = hash_combine_u64(key, u64(int(ts.rotation_radians * 1000000)))
	if at := ts.affine_transform {
		key = hash_combine_u64(key, u64(int(at.xx * 1000000)))
		key = hash_combine_u64(key, u64(int(at.xy * 1000000)))
		key = hash_combine_u64(key, u64(int(at.yx * 1000000)))
		key = hash_combine_u64(key, u64(int(at.yy * 1000000)))
		key = hash_combine_u64(key, u64(int(at.x0 * 1000000)))
		key = hash_combine_u64(key, u64(int(at.y0 * 1000000)))
	}
	key = hash_combine_u64(key, if shape.tc.text_is_password { u64(1) } else { u64(0) })
	key = hash_combine_u64(key, if shape.tc.text_is_placeholder { u64(1) } else { u64(0) })
	return key
}

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
	// Required lifetime guard:
	// renderers are consumed after this function returns.
	// Never pass `&layout` for a stack-local vglyph.Layout.
	// Keep this deep clone for any non-persistent/local layout.
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

fn get_password_mask(mut tc ShapeTextConfig) string {
	h := tc.text.hash()
	if tc.cached_pw_hash == h && tc.cached_pw_mask.len > 0 {
		return tc.cached_pw_mask
	}
	tc.cached_pw_mask = password_mask_text_keep_newlines(tc.text)
	tc.cached_pw_hash = h
	return tc.cached_pw_mask
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

@[inline]
fn password_mask_slice(mask string, text string, start_byte int, end_byte int) string {
	if mask.len == 0 || end_byte <= start_byte {
		return ''
	}
	mut start := byte_to_rune_index(text, start_byte)
	mut end := byte_to_rune_index(text, end_byte)
	if start < 0 {
		start = 0
	}
	if start > mask.len {
		start = mask.len
	}
	if end < start {
		end = start
	}
	if end > mask.len {
		end = mask.len
	}
	return mask[start..end]
}

struct RenderTextStyleState {
	color        Color
	stroke_color Color
	text_cfg     vglyph.TextConfig
	has_stroke   bool
	has_gradient bool
}

struct RenderTextSelectionState {
	line_height   f32
	byte_beg      int
	byte_end      int
	password_mask string
}

fn render_text_style_state(shape &Shape) RenderTextStyleState {
	mut color := if shape.disabled {
		dim_alpha(shape.tc.text_style.color)
	} else {
		shape.tc.text_style.color
	}
	mut stroke_color := if shape.disabled {
		dim_alpha(shape.tc.text_style.stroke_color)
	} else {
		shape.tc.text_style.stroke_color
	}
	if shape.opacity < 1.0 {
		color = color.with_opacity(shape.opacity)
		stroke_color = stroke_color.with_opacity(shape.opacity)
	}
	text_cfg := TextStyle{
		...shape.tc.text_style
		color:        color
		stroke_color: stroke_color
	}.to_vglyph_cfg()
	return RenderTextStyleState{
		color:        color
		stroke_color: stroke_color
		text_cfg:     text_cfg
		has_stroke:   shape.tc.text_style.stroke_width > 0 && stroke_color.a > 0
		has_gradient: shape.tc.text_style.gradient != unsafe { nil }
	}
}

fn render_text_selection_state(mut shape Shape, mut window Window) RenderTextSelectionState {
	beg := int(shape.tc.text_sel_beg)
	end := int(shape.tc.text_sel_end)
	return RenderTextSelectionState{
		line_height:   line_height(shape, mut window)
		byte_beg:      rune_to_byte_index(shape.tc.text, beg)
		byte_end:      rune_to_byte_index(shape.tc.text, end)
		password_mask: if shape.tc.text_is_password && !shape.tc.text_is_placeholder {
			get_password_mask(mut shape.tc)
		} else {
			''
		}
	}
}

fn render_text_try_transformed(mut shape Shape, style_state RenderTextStyleState, mut window Window) bool {
	if !shape.has_text_layout()
		|| (style_state.color == color_transparent && !style_state.has_stroke) {
		return false
	}
	if transform := text_shape_draw_transform(shape) {
		mut layout_to_draw := shape.tc.vglyph_layout
		if window.text_system != unsafe { nil } {
			mut cfg := style_state.text_cfg
			cfg.block.width = shape.tc.last_constraint_width
			cfg.no_hit_testing = true
			text_to_layout := if shape.tc.text_is_password && !shape.tc.text_is_placeholder {
				get_password_mask(mut shape.tc)
			} else {
				shape.tc.text
			}
			cache_key := transformed_layout_cache_key(shape, text_to_layout.hash(), cfg)
			if shape.tc.cached_transform_layout != unsafe { nil }
				&& shape.tc.cached_transform_key == cache_key {
				layout_to_draw = shape.tc.cached_transform_layout
			} else {
				mut transformed_layout := window.text_system.layout_text(text_to_layout,
					cfg) or {
					log.error('Transformed text layout failed at (${shape.x}, ${shape.y}): ${err.msg()}')
					return true
				}
				if transformed_layout.lines.len > 0 || text_to_layout.len == 0 {
					// `transformed_layout` is local; draw renderer needs
					// a heap-owned copy that outlives this function.
					shape.tc.cached_transform_layout = clone_layout_for_draw(&transformed_layout)
					shape.tc.cached_transform_key = cache_key
					layout_to_draw = shape.tc.cached_transform_layout
				}
			}
		}
		emit_renderer(DrawLayoutTransformed{
			layout:    layout_to_draw
			x:         shape.x + shape.padding_left()
			y:         shape.y + shape.padding_top()
			transform: transform
			gradient:  shape.tc.text_style.gradient
		}, mut window)
		return true
	}
	return false
}

fn render_text_layout_lines(mut shape Shape, clip DrawClip, style_state RenderTextStyleState, selection_state RenderTextSelectionState, mut window Window) {
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
			height: selection_state.line_height
		}

		// Cull
		if rects_overlap(clip, draw_rect)
			&& (style_state.color != color_transparent || style_state.has_stroke) {
			if !style_state.has_gradient {
				// Remove newlines for rendering
				mut slice_end := line_end
				if slice_end > line.start_index && shape.tc.text[slice_end - 1] == `\n` {
					slice_end--
				}
				render_str := if selection_state.password_mask.len > 0 {
					password_mask_slice(selection_state.password_mask, shape.tc.text,
						line.start_index, slice_end)
				} else {
					shape.tc.text[line.start_index..slice_end]
				}

				if render_str.len > 0 {
					emit_renderer(DrawText{
						x:    draw_x
						y:    draw_y
						text: render_str
						cfg:  style_state.text_cfg
					}, mut window)
				}
			}

			// Draw text selection
			if selection_state.byte_beg < line_end && selection_state.byte_end > line.start_index {
				draw_text_selection(mut window, DrawTextSelectionParams{
					shape:         shape
					line:          line
					draw_x:        draw_x
					draw_y:        draw_y
					byte_beg:      selection_state.byte_beg
					byte_end:      selection_state.byte_end
					password_mask: selection_state.password_mask
					text_cfg:      style_state.text_cfg
				})
			}
		}
	}
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
	style_state := render_text_style_state(&shape)
	if render_text_try_transformed(mut shape, style_state, mut window) {
		return
	}

	selection_state := render_text_selection_state(mut shape, mut window)

	if shape.has_text_layout() {
		// Gradient text: emit single DrawLayout for full layout
		if style_state.has_gradient
			&& (style_state.color != color_transparent || style_state.has_stroke) {
			emit_renderer(DrawLayout{
				layout:   shape.tc.vglyph_layout
				x:        shape.x + shape.padding_left()
				y:        shape.y + shape.padding_top()
				gradient: shape.tc.text_style.gradient
			}, mut window)
		}
		render_text_layout_lines(mut shape, clip, style_state, selection_state, mut window)
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
	password_mask := params.password_mask
	text_cfg := params.text_cfg

	// Intersection
	i_start := int_max(byte_beg, line.start_index)
	i_end := int_min(byte_end, line.start_index + line.length)

	if i_start < i_end {
		if shape.tc.text_is_password && password_mask.len > 0 {
			// Password fields still need measurement because the rendered text (*)
			// is different from the logical text.
			pw_pre := password_mask_slice(password_mask, shape.tc.text, line.start_index,
				i_start)
			start_x_offset := window.text_system.text_width(pw_pre, text_cfg) or { 0 }

			pw_sel := password_mask_slice(password_mask, shape.tc.text, i_start, i_end)
			sel_width := window.text_system.text_width(pw_sel, text_cfg) or { 0 }

			emit_renderer(DrawRect{
				x:     draw_x + start_x_offset
				y:     draw_y
				w:     sel_width
				h:     line.rect.height
				color: gg.Color{
					...text_cfg.style.color
					a: 60
				}
			}, mut window)
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

			emit_renderer(DrawRect{
				x:     draw_x + r_start.x
				y:     draw_y
				w:     sel_width
				h:     line.rect.height
				color: gg.Color{
					...text_cfg.style.color
					a: 60
				}
			}, mut window)
		}
	}
}

// render_cursor figures out where the darn cursor goes using vglyph.
// input_cursor_on is read live here — never captured in a closure — so the
// blink animation (render-only path) toggles it and triggers a re-render
// without rebuilding the layout tree.
fn render_cursor(shape &Shape, clip DrawClip, mut window Window) {
	if window.is_focus(shape.id_focus) && shape.shape_type == .text
		&& window.view_state.input_cursor_on {
		input_state := state_map[u32, InputState](mut window, ns_input, cap_many).get(shape.id_focus) or {
			InputState{}
		}
		cursor_pos := if shape.tc.text_is_placeholder {
			0
		} else {
			int_min(input_state.cursor_pos, utf8_str_visible_length(shape.tc.text))
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
			emit_renderer(DrawRect{
				x:     cx
				y:     cy
				w:     1.5 // slightly thicker
				h:     ch
				color: color_with_opacity(shape.tc.text_style.color, shape.opacity).to_gx_color()
				style: .fill
			}, mut window)
		}
	}

	// Draw IME composition underlines when composing
	if window.is_focus(shape.id_focus) && shape.has_text_layout()
		&& window.text_system != unsafe { nil } && window.text_system.is_composing()
		&& !shape.tc.text_is_password {
		render_composition(shape, mut window)
	}
}

@[inline]
fn color_with_opacity(c Color, opacity f32) Color {
	if opacity < 1.0 {
		return c.with_opacity(opacity)
	}
	return c
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
			emit_renderer(DrawRect{
				x:     ox + rect.x
				y:     oy + rect.y + rect.height - thickness
				w:     rect.width
				h:     thickness
				color: underline_color
				style: .fill
			}, mut window)
		}
	}
}
