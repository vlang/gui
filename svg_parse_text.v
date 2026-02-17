module gui

import encoding.html

// parse_text_element parses a <text> element and its <tspan> children.
fn parse_text_element(elem string, body string, inherited GroupStyle, mut state ParseState) {
	style := merge_group_style(elem, inherited)
	// Base position
	base_x := parse_length(find_attr(elem, 'x') or { '0' })
	base_y := parse_length(find_attr(elem, 'y') or { '0' })
	// Font attributes (fall back to inherited group style)
	font_family_raw := find_attr_or_style(elem, 'font-family') or { style.font_family }
	// Strip CSS fallbacks: "Arial, sans-serif" → "Arial"
	font_family := if font_family_raw.contains(',') {
		font_family_raw.all_before(',').trim_space().trim('\'"')
	} else {
		font_family_raw.trim_space().trim('\'"')
	}
	fs_fallback := if style.font_size.len > 0 { style.font_size } else { '16' }
	font_size := parse_length(find_attr_or_style(elem, 'font-size') or { fs_fallback })
	fw := find_attr_or_style(elem, 'font-weight') or { style.font_weight }
	bold := fw == 'bold' || fw.f32() >= 600
	fst := find_attr_or_style(elem, 'font-style') or { style.font_style }
	italic := fst == 'italic' || fst == 'oblique'
	// Text decoration
	td := find_attr_or_style(elem, 'text-decoration') or { '' }
	underline := td.contains('underline')
	strikethrough := td.contains('line-through')
	// Fill → text color (default black); detect gradient url()
	fill_str := find_attr_or_style(elem, 'fill') or { style.fill }
	fill_gradient_id := parse_fill_url(fill_str) or { '' }
	color := if fill_gradient_id.len > 0 {
		black
	} else if fill_str.len > 0 && fill_str != 'none' {
		parse_svg_color(fill_str)
	} else if fill_str == 'none' {
		color_transparent
	} else {
		black
	}
	// Stroke
	stroke_str := find_attr_or_style(elem, 'stroke') or { style.stroke }
	stroke_color_raw := if stroke_str.len > 0 && stroke_str != 'none' {
		parse_svg_color(stroke_str)
	} else {
		color_transparent
	}
	stroke_opacity := parse_opacity_attr(elem, 'stroke-opacity', style.stroke_opacity)
	stroke_color := if stroke_opacity < 1.0 {
		Color{stroke_color_raw.r, stroke_color_raw.g, stroke_color_raw.b, u8(f32(stroke_color_raw.a) * stroke_opacity)}
	} else {
		stroke_color_raw
	}
	stroke_width_str := find_attr_or_style(elem, 'stroke-width') or { style.stroke_width }
	stroke_width := if stroke_width_str.len > 0 {
		parse_length(stroke_width_str)
	} else {
		f32(0)
	}
	// Anchor
	ta_fallback := if style.text_anchor.len > 0 { style.text_anchor } else { 'start' }
	anchor_str := find_attr_or_style(elem, 'text-anchor') or { ta_fallback }
	anchor := match anchor_str {
		'middle' { u8(1) }
		'end' { u8(2) }
		else { u8(0) }
	}
	// Opacity
	elem_opacity := parse_opacity_attr(elem, 'opacity', 1.0)
	opacity := style.opacity * elem_opacity

	// Apply transform to position
	tx, ty := apply_transform(base_x, base_y, style.transform)
	scale := extract_transform_scale(style.transform)
	scaled_size := font_size * scale
	// Letter spacing
	ls_raw := find_attr_or_style(elem, 'letter-spacing') or { '0' }
	letter_spacing := parse_length(ls_raw) * scale

	// Check for textPath children
	if body.contains('<textPath') {
		parse_textpath_element(body, font_family, scaled_size, bold, italic, color, fill_gradient_id,
			opacity, letter_spacing, stroke_color, stroke_width, style, mut state)
		return
	}

	// Check for tspan children
	if body.contains('<tspan') {
		parse_tspan_elements(body, tx, ty, font_family, scaled_size, bold, italic, underline,
			strikethrough, color, fill_gradient_id, anchor, opacity, letter_spacing, stroke_color,
			stroke_width, style, mut state)
	} else {
		plain := extract_plain_text(body)
		if plain.len > 0 {
			state.texts << SvgText{
				text:             plain
				x:                tx
				y:                ty
				font_family:      font_family
				font_size:        scaled_size
				bold:             bold
				italic:           italic
				underline:        underline
				strikethrough:    strikethrough
				color:            color
				anchor:           anchor
				opacity:          opacity
				filter_id:        style.filter_id
				fill_gradient_id: fill_gradient_id
				letter_spacing:   letter_spacing
				stroke_color:     stroke_color
				stroke_width:     stroke_width
			}
		}
	}
}

// parse_tspan_elements iterates <tspan> children inside a <text> body.
fn parse_tspan_elements(body string, base_x f32, base_y f32, parent_family string, parent_size f32, parent_bold bool, parent_italic bool, parent_underline bool, parent_strikethrough bool, parent_color Color, parent_gradient_id string, parent_anchor u8, parent_opacity f32, parent_letter_spacing f32, parent_stroke_color Color, parent_stroke_width f32, style GroupStyle, mut state ParseState) {
	mut current_y := base_y
	mut search_pos := 0

	for search_pos < body.len {
		tspan_start := find_index(body, '<tspan', search_pos) or { break }
		tag_end := find_index(body, '>', tspan_start) or { break }
		tspan_elem := body[tspan_start..tag_end + 1]

		// Extract text content between > and </tspan>
		content_start := tag_end + 1
		content_end := find_index(body, '</tspan', content_start) or { break }
		text := html.unescape(body[content_start..content_end].trim_space(), all: true)

		// Close tag end
		close_end := find_index(body, '>', content_end) or { break }
		search_pos = close_end + 1

		if text.len == 0 {
			continue
		}

		// tspan x overrides base_x
		tx := if x_attr := find_attr(tspan_elem, 'x') {
			px, _ := apply_transform(parse_length(x_attr), 0, style.transform)
			px
		} else {
			base_x
		}
		// Accumulate dy
		if dy_attr := find_attr(tspan_elem, 'dy') {
			dy_val := parse_length(dy_attr)
			scale := extract_transform_scale(style.transform)
			current_y += dy_val * scale
		}
		// Per-tspan overrides; detect gradient url()
		fill_str := find_attr_or_style(tspan_elem, 'fill') or { '' }
		tspan_gradient_id := parse_fill_url(fill_str) or { '' }
		fill_gradient_id := if tspan_gradient_id.len > 0 {
			tspan_gradient_id
		} else {
			parent_gradient_id
		}
		color := if tspan_gradient_id.len > 0 {
			black
		} else if fill_str.len > 0 && fill_str != 'none' {
			parse_svg_color(fill_str)
		} else {
			parent_color
		}
		fw := find_attr_or_style(tspan_elem, 'font-weight') or { '' }
		bold := if fw.len > 0 {
			fw == 'bold' || fw.f32() >= 600
		} else {
			parent_bold
		}
		fi := find_attr_or_style(tspan_elem, 'font-style') or { '' }
		italic := if fi.len > 0 {
			fi == 'italic' || fi == 'oblique'
		} else {
			parent_italic
		}
		td := find_attr_or_style(tspan_elem, 'text-decoration') or { '' }
		underline := if td.len > 0 { td.contains('underline') } else { parent_underline }
		strikethrough := if td.len > 0 {
			td.contains('line-through')
		} else {
			parent_strikethrough
		}
		ls_str := find_attr_or_style(tspan_elem, 'letter-spacing') or { '' }
		letter_spacing := if ls_str.len > 0 {
			scale := extract_transform_scale(style.transform)
			parse_length(ls_str) * scale
		} else {
			parent_letter_spacing
		}
		// Per-tspan stroke overrides
		ts_stroke_str := find_attr_or_style(tspan_elem, 'stroke') or { '' }
		stroke_color := if ts_stroke_str.len > 0 && ts_stroke_str != 'none' {
			parse_svg_color(ts_stroke_str)
		} else if ts_stroke_str == 'none' {
			color_transparent
		} else {
			parent_stroke_color
		}
		ts_sw_str := find_attr_or_style(tspan_elem, 'stroke-width') or { '' }
		stroke_width := if ts_sw_str.len > 0 {
			parse_length(ts_sw_str)
		} else {
			parent_stroke_width
		}

		state.texts << SvgText{
			text:             text
			x:                tx
			y:                current_y
			font_family:      parent_family
			font_size:        parent_size
			bold:             bold
			italic:           italic
			underline:        underline
			strikethrough:    strikethrough
			color:            color
			anchor:           parent_anchor
			opacity:          parent_opacity
			filter_id:        style.filter_id
			fill_gradient_id: fill_gradient_id
			letter_spacing:   letter_spacing
			stroke_color:     stroke_color
			stroke_width:     stroke_width
		}
	}

	// Also capture plain text before the first tspan
	plain := extract_plain_text(body)
	if plain.len > 0 {
		state.texts << SvgText{
			text:             plain
			x:                base_x
			y:                base_y
			font_family:      parent_family
			font_size:        parent_size
			bold:             parent_bold
			italic:           parent_italic
			underline:        parent_underline
			strikethrough:    parent_strikethrough
			color:            parent_color
			anchor:           parent_anchor
			opacity:          parent_opacity
			filter_id:        style.filter_id
			fill_gradient_id: parent_gradient_id
			letter_spacing:   parent_letter_spacing
			stroke_color:     parent_stroke_color
			stroke_width:     parent_stroke_width
		}
	}
}

// parse_textpath_element extracts <textPath> from text body.
fn parse_textpath_element(body string, parent_family string, parent_size f32, parent_bold bool, parent_italic bool, parent_color Color, parent_gradient_id string, parent_opacity f32, parent_letter_spacing f32, parent_stroke_color Color, parent_stroke_width f32, style GroupStyle, mut state ParseState) {
	tp_start := find_index(body, '<textPath', 0) or { return }
	tag_end := find_index(body, '>', tp_start) or { return }
	tp_elem := body[tp_start..tag_end + 1]
	is_self_closing := body[tag_end - 1] == `/`
	text := if is_self_closing {
		''
	} else {
		content_start := tag_end + 1
		content_end := find_index(body, '</textPath', content_start) or { body.len }
		html.unescape(body[content_start..content_end].trim_space(), all: true)
	}
	if text.len == 0 {
		return
	}
	// Extract href (try href first, then xlink:href)
	href_raw := find_attr(tp_elem, 'href') or { find_attr(tp_elem, 'xlink:href') or { return } }
	path_id := if href_raw.starts_with('#') { href_raw[1..] } else { href_raw }
	// startOffset
	offset_str := find_attr(tp_elem, 'startOffset') or { '0' }
	is_percent := offset_str.ends_with('%')
	start_offset := if is_percent {
		offset_str[..offset_str.len - 1].f32() / 100.0
	} else {
		parse_length(offset_str)
	}
	// text-anchor (textPath overrides parent)
	anchor_str := find_attr_or_style(tp_elem, 'text-anchor') or { 'start' }
	anchor := match anchor_str {
		'middle' { u8(1) }
		'end' { u8(2) }
		else { u8(0) }
	}
	// Extended attributes
	spacing_str := find_attr(tp_elem, 'spacing') or { 'auto' }
	spacing := if spacing_str == 'exact' { u8(1) } else { u8(0) }
	method_str := find_attr(tp_elem, 'method') or { 'align' }
	method := if method_str == 'stretch' { u8(1) } else { u8(0) }
	side_str := find_attr(tp_elem, 'side') or { 'left' }
	side := if side_str == 'right' { u8(1) } else { u8(0) }
	// Per-textPath overrides
	fill_str := find_attr_or_style(tp_elem, 'fill') or { '' }
	tp_gradient_id := parse_fill_url(fill_str) or { '' }
	fill_gradient_id := if tp_gradient_id.len > 0 { tp_gradient_id } else { parent_gradient_id }
	color := if tp_gradient_id.len > 0 {
		black
	} else if fill_str.len > 0 && fill_str != 'none' {
		parse_svg_color(fill_str)
	} else {
		parent_color
	}
	fw := find_attr_or_style(tp_elem, 'font-weight') or { '' }
	bold := if fw.len > 0 { fw == 'bold' || fw.f32() >= 600 } else { parent_bold }
	fi := find_attr_or_style(tp_elem, 'font-style') or { '' }
	italic := if fi.len > 0 { fi == 'italic' || fi == 'oblique' } else { parent_italic }
	ls_str := find_attr_or_style(tp_elem, 'letter-spacing') or { '' }
	letter_spacing := if ls_str.len > 0 {
		scale := extract_transform_scale(style.transform)
		parse_length(ls_str) * scale
	} else {
		parent_letter_spacing
	}
	ts_stroke_str := find_attr_or_style(tp_elem, 'stroke') or { '' }
	stroke_color := if ts_stroke_str.len > 0 && ts_stroke_str != 'none' {
		parse_svg_color(ts_stroke_str)
	} else if ts_stroke_str == 'none' {
		color_transparent
	} else {
		parent_stroke_color
	}
	ts_sw_str := find_attr_or_style(tp_elem, 'stroke-width') or { '' }
	stroke_width := if ts_sw_str.len > 0 { parse_length(ts_sw_str) } else { parent_stroke_width }
	font_family_raw := find_attr_or_style(tp_elem, 'font-family') or { '' }
	font_family := if font_family_raw.len > 0 {
		if font_family_raw.contains(',') {
			font_family_raw.all_before(',').trim_space().trim('\'"')
		} else {
			font_family_raw.trim_space().trim('\'"')
		}
	} else {
		parent_family
	}
	state.text_paths << SvgTextPath{
		text:             text
		path_id:          path_id
		start_offset:     start_offset
		is_percent:       is_percent
		anchor:           anchor
		spacing:          spacing
		method:           method
		side:             side
		font_family:      font_family
		font_size:        parent_size
		bold:             bold
		italic:           italic
		color:            color
		opacity:          parent_opacity
		filter_id:        style.filter_id
		fill_gradient_id: fill_gradient_id
		letter_spacing:   letter_spacing
		stroke_color:     stroke_color
		stroke_width:     stroke_width
	}
}
