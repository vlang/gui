module gui

// parse_filter_url extracts filter ID from
// filter="url(#id)" attribute.
fn parse_filter_url(elem string) ?string {
	val := find_attr(elem, 'filter') or { return none }
	hash_pos := find_index(val, '#', 0) or { return none }
	end_pos := find_index(val, ')', hash_pos) or { return none }
	if end_pos > hash_pos + 1 {
		return val[hash_pos + 1..end_pos]
	}
	return none
}

// parse_clip_path_url extracts clip path ID from
// clip-path="url(#id)" attribute.
fn parse_clip_path_url(elem string) ?string {
	val := find_attr(elem, 'clip-path') or { return none }
	// Expected format: url(#id)
	hash_pos := find_index(val, '#', 0) or { return none }
	end_pos := find_index(val, ')', hash_pos) or { return none }
	if end_pos > hash_pos + 1 {
		return val[hash_pos + 1..end_pos]
	}
	return none
}

// parse_defs_clip_paths extracts <clipPath> definitions from
// <defs> blocks. Returns map of id -> clip geometry paths.
fn parse_defs_clip_paths(content string) map[string][]VectorPath {
	mut clip_paths := map[string][]VectorPath{}
	mut pos := 0

	for pos < content.len {
		// Find next <clipPath
		cp_start := find_index(content, '<clipPath', pos) or { break }
		// Find end of opening tag
		tag_end := find_index(content, '>', cp_start) or { break }
		opening_tag := content[cp_start..tag_end + 1]
		is_self_closing := content[tag_end - 1] == `/`

		// Extract id attribute
		clip_id := find_attr(opening_tag, 'id') or {
			pos = tag_end + 1
			continue
		}

		if is_self_closing {
			pos = tag_end + 1
			continue
		}

		// Find closing </clipPath>
		cp_content_start := tag_end + 1
		cp_end := find_closing_tag(content, 'clipPath', cp_content_start)
		if cp_end <= cp_content_start {
			pos = tag_end + 1
			continue
		}

		// Parse shapes inside <clipPath> as paths
		cp_content := content[cp_content_start..cp_end]
		default_style := GroupStyle{
			transform: identity_transform
		}
		mut state := ParseState{}
		paths := parse_svg_content(cp_content, default_style, 0, mut state)
		if paths.len > 0 {
			clip_paths[clip_id] = paths
		}

		// Skip past </clipPath>
		close_end := find_index(content, '>', cp_end) or { break }
		pos = close_end + 1
	}

	return clip_paths
}

// parse_defs_gradients extracts <linearGradient> definitions from
// <defs> blocks. Returns map of id -> SvgGradientDef.
fn parse_defs_gradients(content string) map[string]SvgGradientDef {
	mut gradients := map[string]SvgGradientDef{}
	mut pos := 0

	for pos < content.len {
		lg_start := find_index(content, '<linearGradient', pos) or { break }
		tag_end := find_index(content, '>', lg_start) or { break }
		opening_tag := content[lg_start..tag_end + 1]
		is_self_closing := content[tag_end - 1] == `/`

		grad_id := find_attr(opening_tag, 'id') or {
			pos = tag_end + 1
			continue
		}

		units := find_attr(opening_tag, 'gradientUnits') or { 'objectBoundingBox' }
		is_obb := units != 'userSpaceOnUse'
		x1_str := find_attr(opening_tag, 'x1') or { '0' }
		y1_str := find_attr(opening_tag, 'y1') or { '0' }
		x2_str := find_attr(opening_tag, 'x2') or { '0' }
		y2_str := find_attr(opening_tag, 'y2') or { '0' }
		x1 := parse_gradient_coord(x1_str, is_obb)
		y1 := parse_gradient_coord(y1_str, is_obb)
		x2 := parse_gradient_coord(x2_str, is_obb)
		y2 := parse_gradient_coord(y2_str, is_obb)

		if is_self_closing {
			gradients[grad_id] = SvgGradientDef{
				x1:                  x1
				y1:                  y1
				x2:                  x2
				y2:                  y2
				object_bounding_box: is_obb
			}
			pos = tag_end + 1
			continue
		}

		// Find closing </linearGradient>
		lg_content_start := tag_end + 1
		lg_end := find_closing_tag(content, 'linearGradient', lg_content_start)
		if lg_end <= lg_content_start {
			pos = tag_end + 1
			continue
		}

		// Parse <stop> elements
		lg_content := content[lg_content_start..lg_end]
		stops := parse_gradient_stops(lg_content)

		gradients[grad_id] = SvgGradientDef{
			x1:                  x1
			y1:                  y1
			x2:                  x2
			y2:                  y2
			stops:               stops
			object_bounding_box: is_obb
		}

		close_end := find_index(content, '>', lg_end) or { break }
		pos = close_end + 1
	}

	return gradients
}

// parse_gradient_coord parses a gradient coordinate value.
// For objectBoundingBox gradients, percentages are converted to
// fractions (e.g. "100%" -> 1.0). Plain numbers stay as-is.
fn parse_gradient_coord(s string, is_obb bool) f32 {
	trimmed := s.trim_space()
	if is_obb && trimmed.ends_with('%') {
		return trimmed[..trimmed.len - 1].f32() / 100.0
	}
	return trimmed.f32()
}

// parse_gradient_stops extracts <stop> elements from gradient content.
fn parse_gradient_stops(content string) []SvgGradientStop {
	mut stops := []SvgGradientStop{}
	mut pos := 0

	for pos < content.len {
		stop_start := find_index(content, '<stop', pos) or { break }
		stop_end := find_index(content, '>', stop_start) or { break }
		stop_elem := content[stop_start..stop_end + 1]

		offset_str := find_attr_or_style(stop_elem, 'offset') or { '0' }
		mut offset := if offset_str.ends_with('%') {
			offset_str[..offset_str.len - 1].f32() / 100.0
		} else {
			offset_str.f32()
		}
		if offset < 0 {
			offset = 0
		}
		if offset > 1 {
			offset = 1
		}

		color_str := find_attr_or_style(stop_elem, 'stop-color') or { '#000000' }
		mut color := parse_svg_color(color_str)
		if color == color_inherit {
			color = black
		}

		// Apply stop-opacity
		stop_opacity := parse_opacity_attr(stop_elem, 'stop-opacity', 1.0)
		if stop_opacity < 1.0 {
			color = apply_opacity(color, stop_opacity)
		}

		stops << SvgGradientStop{
			offset: offset
			color:  color
		}

		pos = stop_end + 1
	}

	return stops
}

// parse_defs_filters extracts <filter> definitions from SVG content.
// Returns map of id -> SvgFilter.
fn parse_defs_filters(content string) map[string]SvgFilter {
	mut filters := map[string]SvgFilter{}
	mut pos := 0

	for pos < content.len {
		f_start := find_index(content, '<filter', pos) or { break }
		tag_end := find_index(content, '>', f_start) or { break }
		opening_tag := content[f_start..tag_end + 1]
		is_self_closing := content[tag_end - 1] == `/`

		filter_id := find_attr(opening_tag, 'id') or {
			pos = tag_end + 1
			continue
		}

		if is_self_closing {
			pos = tag_end + 1
			continue
		}

		// Find closing </filter>
		f_content_start := tag_end + 1
		f_end := find_closing_tag(content, 'filter', f_content_start)
		if f_end <= f_content_start {
			pos = tag_end + 1
			continue
		}

		f_content := content[f_content_start..f_end]

		// Extract stdDeviation from feGaussianBlur
		mut std_dev := f32(0)
		if gb_start := find_index(f_content, '<feGaussianBlur', 0) {
			gb_end := find_index(f_content, '>', gb_start) or { 0 }
			if gb_end > gb_start {
				gb_elem := f_content[gb_start..gb_end + 1]
				std_dev = (find_attr(gb_elem, 'stdDeviation') or { '0' }).f32()
			}
		}

		if std_dev <= 0 {
			close_end := find_index(content, '>', f_end) or { break }
			pos = close_end + 1
			continue
		}

		// Count feMergeNode entries
		mut blur_layers := 0
		mut keep_source := false
		mut merge_pos := 0
		for merge_pos < f_content.len {
			mn_start := find_index(f_content, '<feMergeNode', merge_pos) or { break }
			mn_end := find_index(f_content, '>', mn_start) or { break }
			mn_elem := f_content[mn_start..mn_end + 1]
			in_val := find_attr(mn_elem, 'in') or { '' }
			if in_val == 'SourceGraphic' {
				keep_source = true
			} else {
				blur_layers++
			}
			merge_pos = mn_end + 1
		}
		if blur_layers == 0 {
			blur_layers = 1
		}

		filters[filter_id] = SvgFilter{
			id:          filter_id
			std_dev:     std_dev
			blur_layers: blur_layers
			keep_source: keep_source
		}

		close_end := find_index(content, '>', f_end) or { break }
		pos = close_end + 1
	}

	return filters
}

// parse_defs_paths extracts <path> elements with id attributes
// from <defs> blocks. Returns map of id -> d attribute string.
fn parse_defs_paths(content string) map[string]string {
	mut paths := map[string]string{}
	mut pos := 0
	for pos < content.len {
		defs_start := find_index(content, '<defs', pos) or { break }
		defs_tag_end := find_index(content, '>', defs_start) or { break }
		is_self_closing := content[defs_tag_end - 1] == `/`
		if is_self_closing {
			pos = defs_tag_end + 1
			continue
		}
		defs_content_start := defs_tag_end + 1
		defs_end := find_closing_tag(content, 'defs', defs_content_start)
		if defs_end <= defs_content_start {
			pos = defs_tag_end + 1
			continue
		}
		defs_body := content[defs_content_start..defs_end]
		mut ppos := 0
		for ppos < defs_body.len {
			p_start := find_index(defs_body, '<path', ppos) or { break }
			p_end := find_index(defs_body, '>', p_start) or { break }
			p_elem := defs_body[p_start..p_end + 1]
			pid := find_attr(p_elem, 'id') or {
				ppos = p_end + 1
				continue
			}
			d := find_attr(p_elem, 'd') or {
				ppos = p_end + 1
				continue
			}
			paths[pid] = d
			ppos = p_end + 1
		}
		close_end := find_index(content, '>', defs_end) or { break }
		pos = close_end + 1
	}
	return paths
}
