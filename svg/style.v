module svg

// find_tag_name_end finds the end of a tag name.
fn find_tag_name_end(s string, start int) int {
	mut i := start
	for i < s.len {
		c := s[i]
		if c == ` ` || c == `\t` || c == `\n` || c == `\r` || c == `>` || c == `/` {
			break
		}
		i++
	}
	return i
}

// find_closing_tag finds the position of the closing tag for a given element.
fn find_closing_tag(content string, tag string, start int) int {
	close_tag := '</${tag}'
	open_tag := '<${tag}'
	mut depth := 1
	mut pos := start
	mut iterations := 0

	for pos < content.len && depth > 0 {
		iterations++
		if iterations > max_elements {
			break
		}
		// Find next < character
		next := find_index(content, '<', pos) or { break }

		// Check for closing tag
		if next + close_tag.len <= content.len && content[next..next + close_tag.len] == close_tag {
			depth--
			if depth == 0 {
				return next
			}
			pos = next + close_tag.len
			continue
		}

		// Check for opening tag (nested)
		if next + open_tag.len <= content.len && content[next..next + open_tag.len] == open_tag {
			// Make sure it's actually the tag and not something like <glyph
			end_pos := next + open_tag.len
			if end_pos < content.len {
				c := content[end_pos]
				if c == ` ` || c == `\t` || c == `\n` || c == `>` || c == `/` {
					depth++
				}
			}
		}

		pos = next + 1
	}

	return content.len
}

// merge_group_style merges element attributes with inherited style.
fn merge_group_style(elem string, inherited GroupStyle) GroupStyle {
	// Get element's transform and compose with inherited
	elem_transform := get_transform(elem)
	combined_transform := matrix_multiply(inherited.transform, elem_transform)

	// Inherit or override style properties
	fill := find_attr_or_style(elem, 'fill') or { inherited.fill }
	stroke := find_attr_or_style(elem, 'stroke') or { inherited.stroke }
	stroke_width := find_attr_or_style(elem, 'stroke-width') or { inherited.stroke_width }
	stroke_cap := find_attr_or_style(elem, 'stroke-linecap') or { inherited.stroke_cap }
	stroke_join := find_attr_or_style(elem, 'stroke-linejoin') or { inherited.stroke_join }
	clip_path_id := parse_clip_path_url(elem) or { inherited.clip_path_id }
	filter_id := parse_filter_url(elem) or { inherited.filter_id }
	font_family := find_attr_or_style(elem, 'font-family') or { inherited.font_family }
	font_size := find_attr_or_style(elem, 'font-size') or { inherited.font_size }
	font_weight := find_attr_or_style(elem, 'font-weight') or { inherited.font_weight }
	font_style := find_attr_or_style(elem, 'font-style') or { inherited.font_style }
	text_anchor := find_attr_or_style(elem, 'text-anchor') or { inherited.text_anchor }

	// Opacity: group opacity multiplies with inherited
	elem_opacity := parse_opacity_attr(elem, 'opacity', 1.0)
	group_opacity := inherited.opacity * elem_opacity
	fill_opacity := parse_opacity_attr(elem, 'fill-opacity', inherited.fill_opacity)
	stroke_opacity := parse_opacity_attr(elem, 'stroke-opacity', inherited.stroke_opacity)

	return GroupStyle{
		transform:      combined_transform
		fill:           fill
		stroke:         stroke
		stroke_width:   stroke_width
		stroke_cap:     stroke_cap
		stroke_join:    stroke_join
		clip_path_id:   clip_path_id
		filter_id:      filter_id
		font_family:    font_family
		font_size:      font_size
		font_weight:    font_weight
		font_style:     font_style
		text_anchor:    text_anchor
		opacity:        group_opacity
		fill_opacity:   fill_opacity
		stroke_opacity: stroke_opacity
	}
}

// apply_inherited_style applies inherited style to a path.
fn apply_inherited_style(mut path VectorPath, inherited GroupStyle) {
	// Compose transforms
	path.transform = matrix_multiply(inherited.transform, path.transform)

	// Apply clip path from element or inherit from group
	if path.clip_path_id.len == 0 && inherited.clip_path_id.len > 0 {
		path.clip_path_id = inherited.clip_path_id
	}

	// Apply filter from group
	if path.filter_id.len == 0 && inherited.filter_id.len > 0 {
		path.filter_id = inherited.filter_id
	}

	// Apply inherited fill if element doesn't specify one (uses sentinel)
	if path.fill_gradient_id.len > 0 {
		// Gradient fill — keep fill_color transparent; gradient takes precedence
	} else if path.fill_color == color_inherit {
		if inherited.fill.len > 0 {
			if gid := parse_fill_url(inherited.fill) {
				path.fill_gradient_id = gid
			} else {
				path.fill_color = parse_svg_color(inherited.fill)
			}
		} else {
			path.fill_color = color_black // SVG default
		}
	}

	// Apply inherited stroke if element doesn't specify one (uses sentinel)
	if path.stroke_color == color_inherit {
		if inherited.stroke.len > 0 {
			path.stroke_color = parse_svg_color(inherited.stroke)
		} else {
			path.stroke_color = color_transparent
		}
	}
	if inherited.stroke_width.len > 0 && path.stroke_width < 0 {
		path.stroke_width = parse_length(inherited.stroke_width)
	}
	if path.stroke_width < 0 {
		path.stroke_width = 1.0 // SVG default
	}
	if inherited.stroke_cap.len > 0 && path.stroke_cap == .inherit {
		path.stroke_cap = match inherited.stroke_cap {
			'round' { StrokeCap.round }
			'square' { StrokeCap.square }
			else { StrokeCap.butt }
		}
	}
	if path.stroke_cap == .inherit {
		path.stroke_cap = .butt
	}
	if inherited.stroke_join.len > 0 && path.stroke_join == .inherit {
		path.stroke_join = match inherited.stroke_join {
			'round' { StrokeJoin.round }
			'bevel' { StrokeJoin.bevel }
			else { StrokeJoin.miter }
		}
	}
	if path.stroke_join == .inherit {
		path.stroke_join = .miter
	}

	// Apply opacity: element opacity * group opacity * fill/stroke-opacity
	combined_opacity := inherited.opacity * path.opacity
	fill_opacity := if path.fill_opacity < 1.0 {
		path.fill_opacity
	} else {
		inherited.fill_opacity
	}
	stroke_opacity := if path.stroke_opacity < 1.0 {
		path.stroke_opacity
	} else {
		inherited.stroke_opacity
	}
	path.fill_color = apply_opacity(path.fill_color, combined_opacity * fill_opacity)
	path.stroke_color = apply_opacity(path.stroke_color, combined_opacity * stroke_opacity)
}

// find_index finds the index of substr in s starting from pos, returns none if not found.
// Optimized for single-char searches (common case in attribute parsing).
fn find_index(s string, substr string, pos int) ?int {
	// Fast path for single-char search (30+ uses in parsing)
	if substr.len == 1 {
		target := substr[0]
		for i := pos; i < s.len; i++ {
			if s[i] == target {
				return i
			}
		}
		return none
	}

	// General case for multi-char substrings
	for i := pos; i <= s.len - substr.len; i++ {
		mut found := true
		for j := 0; j < substr.len; j++ {
			if s[i + j] != substr[j] {
				found = false
				break
			}
		}
		if found {
			return i
		}
	}
	return none
}

// find_style_property extracts a CSS property from a style attribute.
// e.g., from "fill:red;stroke:blue" extracts "red" for name="fill".
fn find_style_property(style string, name string) ?string {
	// Search for "name:" possibly preceded by ; or start of string
	mut pos := 0
	for pos < style.len {
		// Find property name
		idx := find_index(style, name, pos) or { return none }
		// Verify it's at start or after ; and whitespace
		valid_start := idx == 0 || style[idx - 1] == `;` || style[idx - 1] == ` `
			|| style[idx - 1] == `\t`
		if !valid_start {
			pos = idx + name.len
			continue
		}
		// Find the colon after name
		mut colon := idx + name.len
		// Skip whitespace between name and colon
		for colon < style.len && (style[colon] == ` ` || style[colon] == `\t`) {
			colon++
		}
		if colon >= style.len || style[colon] != `:` {
			pos = colon
			continue
		}
		// Extract value until ; or end
		val_start := colon + 1
		val_end := find_index(style, ';', val_start) or { style.len }
		if val_end > val_start {
			return style[val_start..val_end].trim_space()
		}
		return none
	}
	return none
}

// find_attr_or_style checks inline style first (higher specificity),
// then falls back to presentation attribute per SVG spec.
fn find_attr_or_style(elem string, name string) ?string {
	if style := find_attr(elem, 'style') {
		if val := find_style_property(style, name) {
			return val
		}
	}
	return find_attr(elem, name)
}

// find_attr extracts an attribute value from an element string.
// Ensures attribute name is preceded by whitespace to avoid
// matching substrings. Zero-allocation byte-level matching.
fn find_attr(elem string, name string) ?string {
	mut pos := 0
	for pos < elem.len {
		// Find attribute name
		idx := find_index(elem, name, pos) or { return none }
		// Verify preceded by whitespace
		if idx == 0 || (elem[idx - 1] != ` ` && elem[idx - 1] != `\t` && elem[idx - 1] != `\n`
			&& elem[idx - 1] != `\r`) {
			pos = idx + name.len
			continue
		}
		// Check for '=' after name
		eq := idx + name.len
		if eq >= elem.len || elem[eq] != `=` {
			pos = eq
			continue
		}
		// Check for quote character
		q := eq + 1
		if q >= elem.len {
			return none
		}
		quote := elem[q]
		if quote != `"` && quote != `'` {
			pos = q
			continue
		}
		// Find closing quote
		start := q + 1
		end := find_index(elem, quote.ascii_str(), start) or { return none }
		if end > start {
			attr_len := end - start
			if attr_len > max_attr_len {
				return none
			}
			return elem[start..end]
		}
		return none
	}
	return none
}

// clamp_byte clamps an int to 0..255.
@[inline]
fn clamp_byte(v int) int {
	if v < 0 {
		return 0
	}
	if v > 255 {
		return 255
	}
	return v
}

// clamp_viewbox_dim clamps dimension to prevent extreme allocations
fn clamp_viewbox_dim(v f32) f32 {
	if v < 0 {
		return 0
	}
	if v > max_viewbox_dim {
		return max_viewbox_dim
	}
	return v
}

// parse_length parses a CSS length value (ignores units for now).
// Clamps to max_coordinate to prevent overflow/OOM.
fn parse_length(s string) f32 {
	mut end := 0
	for end < s.len {
		c := s[end]
		if (c >= `0` && c <= `9`) || c == `.` || c == `-` || c == `+` {
			end++
		} else {
			break
		}
	}
	if end == 0 {
		return 0
	}
	value := s[..end].f32()
	// Clamp to prevent integer overflow in downstream operations
	if value > max_coordinate {
		return max_coordinate
	}
	if value < -max_coordinate {
		return -max_coordinate
	}
	return value
}
