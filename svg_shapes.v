module gui

// parse_path_with_style parses a path element with inherited style.
fn parse_path_with_style(elem string, inherited GroupStyle) ?VectorPath {
	mut path := parse_path_element(elem) or { return none }
	path.clip_path_id = parse_clip_path_url(elem) or { '' }
	apply_inherited_style(mut path, inherited)
	return path
}

// parse_rect_with_style parses a rect element with inherited style.
fn parse_rect_with_style(elem string, inherited GroupStyle) ?VectorPath {
	mut path := parse_rect_element(elem) or { return none }
	path.clip_path_id = parse_clip_path_url(elem) or { '' }
	apply_inherited_style(mut path, inherited)
	return path
}

// parse_circle_with_style parses a circle element with inherited style.
fn parse_circle_with_style(elem string, inherited GroupStyle) ?VectorPath {
	mut path := parse_circle_element(elem) or { return none }
	path.clip_path_id = parse_clip_path_url(elem) or { '' }
	apply_inherited_style(mut path, inherited)
	return path
}

// parse_ellipse_with_style parses an ellipse element with inherited style.
fn parse_ellipse_with_style(elem string, inherited GroupStyle) ?VectorPath {
	mut path := parse_ellipse_element(elem) or { return none }
	path.clip_path_id = parse_clip_path_url(elem) or { '' }
	apply_inherited_style(mut path, inherited)
	return path
}

// parse_polygon_with_style parses a polygon/polyline element with inherited style.
fn parse_polygon_with_style(elem string, inherited GroupStyle, close bool) ?VectorPath {
	mut path := parse_polygon_element(elem, close) or { return none }
	path.clip_path_id = parse_clip_path_url(elem) or { '' }
	apply_inherited_style(mut path, inherited)
	return path
}

// parse_line_with_style parses a line element with inherited style.
fn parse_line_with_style(elem string, inherited GroupStyle) ?VectorPath {
	mut path := parse_line_element(elem) or { return none }
	path.clip_path_id = parse_clip_path_url(elem) or { '' }
	apply_inherited_style(mut path, inherited)
	return path
}

// ElementStyle holds common style properties extracted from an SVG element.
struct ElementStyle {
	transform          [6]f32
	stroke_color       Color
	stroke_width       f32
	stroke_cap         StrokeCap
	stroke_join        StrokeJoin
	opacity            f32
	fill_opacity       f32
	stroke_opacity     f32
	stroke_gradient_id string
	stroke_dasharray   []f32
}

// parse_element_style extracts common style properties from an element.
fn parse_element_style(elem string) ElementStyle {
	return ElementStyle{
		transform:          get_transform(elem)
		stroke_color:       get_stroke_color(elem)
		stroke_width:       get_stroke_width(elem)
		stroke_cap:         get_stroke_linecap(elem)
		stroke_join:        get_stroke_linejoin(elem)
		opacity:            parse_opacity_attr(elem, 'opacity', 1.0)
		fill_opacity:       parse_opacity_attr(elem, 'fill-opacity', 1.0)
		stroke_opacity:     parse_opacity_attr(elem, 'stroke-opacity', 1.0)
		stroke_gradient_id: get_stroke_gradient_id(elem)
		stroke_dasharray:   get_stroke_dasharray(elem)
	}
}

// parse_path_element parses a <path> element
fn parse_path_element(elem string) ?VectorPath {
	d := find_attr(elem, 'd') or { return none }
	fill := find_attr_or_style(elem, 'fill') or { '' }
	s := parse_element_style(elem)

	mut path := VectorPath{
		fill_color:         parse_svg_color(fill)
		transform:          s.transform
		stroke_color:       s.stroke_color
		stroke_width:       s.stroke_width
		stroke_cap:         s.stroke_cap
		stroke_join:        s.stroke_join
		opacity:            s.opacity
		fill_opacity:       s.fill_opacity
		stroke_opacity:     s.stroke_opacity
		stroke_gradient_id: s.stroke_gradient_id
		stroke_dasharray:   s.stroke_dasharray
	}
	if gid := parse_fill_url(fill) {
		path.fill_gradient_id = gid
	}
	path.segments = parse_path_d(d)

	if path.segments.len == 0 {
		return none
	}
	return path
}

// parse_rect_element converts <rect> to path
fn parse_rect_element(elem string) ?VectorPath {
	x := (find_attr(elem, 'x') or { '0' }).f32()
	y := (find_attr(elem, 'y') or { '0' }).f32()
	w := (find_attr(elem, 'width') or { return none }).f32()
	h := (find_attr(elem, 'height') or { return none }).f32()
	mut rx := (find_attr(elem, 'rx') or { '0' }).f32()
	mut ry := (find_attr(elem, 'ry') or { '0' }).f32()
	fill := find_attr_or_style(elem, 'fill') or { '' }
	s := parse_element_style(elem)

	if rx == 0 && ry > 0 {
		rx = ry
	}
	if ry == 0 && rx > 0 {
		ry = rx
	}

	mut segments := []PathSegment{}

	if rx == 0 && ry == 0 {
		// Simple rectangle
		segments << PathSegment{.move_to, [x, y]}
		segments << PathSegment{.line_to, [x + w, y]}
		segments << PathSegment{.line_to, [x + w, y + h]}
		segments << PathSegment{.line_to, [x, y + h]}
		segments << PathSegment{.close, []}
	} else {
		// Rounded rectangle using arcs
		if rx > w / 2 {
			rx = w / 2
		}
		if ry > h / 2 {
			ry = h / 2
		}
		segments << PathSegment{.move_to, [x + rx, y]}
		segments << PathSegment{.line_to, [x + w - rx, y]}
		segments << arc_to_cubic(x + w - rx, y, rx, ry, 0, false, true, x + w, y + ry)
		segments << PathSegment{.line_to, [x + w, y + h - ry]}
		segments << arc_to_cubic(x + w, y + h - ry, rx, ry, 0, false, true, x + w - rx,
			y + h)
		segments << PathSegment{.line_to, [x + rx, y + h]}
		segments << arc_to_cubic(x + rx, y + h, rx, ry, 0, false, true, x, y + h - ry)
		segments << PathSegment{.line_to, [x, y + ry]}
		segments << arc_to_cubic(x, y + ry, rx, ry, 0, false, true, x + rx, y)
		segments << PathSegment{.close, []}
	}

	mut vp := VectorPath{
		segments:           segments
		fill_color:         parse_svg_color(fill)
		transform:          s.transform
		stroke_color:       s.stroke_color
		stroke_width:       s.stroke_width
		stroke_cap:         s.stroke_cap
		stroke_join:        s.stroke_join
		opacity:            s.opacity
		fill_opacity:       s.fill_opacity
		stroke_opacity:     s.stroke_opacity
		stroke_gradient_id: s.stroke_gradient_id
		stroke_dasharray:   s.stroke_dasharray
	}
	if gid := parse_fill_url(fill) {
		vp.fill_gradient_id = gid
	}
	return vp
}

// parse_circle_element converts <circle> to path
fn parse_circle_element(elem string) ?VectorPath {
	cx := (find_attr(elem, 'cx') or { '0' }).f32()
	cy := (find_attr(elem, 'cy') or { '0' }).f32()
	r := (find_attr(elem, 'r') or { return none }).f32()
	fill := find_attr_or_style(elem, 'fill') or { '' }

	return ellipse_to_path(cx, cy, r, r, elem, fill, parse_element_style(elem))
}

// parse_ellipse_element converts <ellipse> to path
fn parse_ellipse_element(elem string) ?VectorPath {
	cx := (find_attr(elem, 'cx') or { '0' }).f32()
	cy := (find_attr(elem, 'cy') or { '0' }).f32()
	rx := (find_attr(elem, 'rx') or { return none }).f32()
	ry := (find_attr(elem, 'ry') or { return none }).f32()
	fill := find_attr_or_style(elem, 'fill') or { '' }

	return ellipse_to_path(cx, cy, rx, ry, elem, fill, parse_element_style(elem))
}

// ellipse_to_path converts an ellipse to a path using 4 cubic beziers
fn ellipse_to_path(cx f32, cy f32, rx f32, ry f32, elem string, fill string, s ElementStyle) VectorPath {
	// Approximate circle with 4 cubic beziers (kappa = 4*(sqrt(2)-1)/3)
	k := f32(0.5522847498)
	kx := rx * k
	ky := ry * k

	mut segments := []PathSegment{}
	segments << PathSegment{.move_to, [cx, cy - ry]}
	segments << PathSegment{.cubic_to, [cx + kx, cy - ry, cx + rx, cy - ky, cx + rx, cy]}
	segments << PathSegment{.cubic_to, [cx + rx, cy + ky, cx + kx, cy + ry, cx, cy + ry]}
	segments << PathSegment{.cubic_to, [cx - kx, cy + ry, cx - rx, cy + ky, cx - rx, cy]}
	segments << PathSegment{.cubic_to, [cx - rx, cy - ky, cx - kx, cy - ry, cx, cy - ry]}
	segments << PathSegment{.close, []}

	mut vp := VectorPath{
		segments:           segments
		fill_color:         parse_svg_color(fill)
		transform:          s.transform
		stroke_color:       s.stroke_color
		stroke_width:       s.stroke_width
		stroke_cap:         s.stroke_cap
		stroke_join:        s.stroke_join
		opacity:            s.opacity
		fill_opacity:       s.fill_opacity
		stroke_opacity:     s.stroke_opacity
		stroke_gradient_id: s.stroke_gradient_id
		stroke_dasharray:   s.stroke_dasharray
	}
	if gid := parse_fill_url(fill) {
		vp.fill_gradient_id = gid
	}
	return vp
}

// parse_polygon_element converts <polygon> or <polyline> to path
fn parse_polygon_element(elem string, close bool) ?VectorPath {
	points_str := find_attr(elem, 'points') or { return none }
	fill := find_attr_or_style(elem, 'fill') or { '' }
	s := parse_element_style(elem)

	numbers := parse_number_list(points_str)
	// Validate: need at least 2 points (4 coords) and even count for x,y pairs
	if numbers.len < 4 || numbers.len % 2 != 0 {
		return none
	}

	mut segments := []PathSegment{}
	segments << PathSegment{.move_to, [numbers[0], numbers[1]]}
	for i := 2; i < numbers.len - 1; i += 2 {
		segments << PathSegment{.line_to, [numbers[i], numbers[i + 1]]}
	}
	if close {
		segments << PathSegment{.close, []}
	}

	mut vp := VectorPath{
		segments:           segments
		fill_color:         parse_svg_color(fill)
		transform:          s.transform
		stroke_color:       s.stroke_color
		stroke_width:       s.stroke_width
		stroke_cap:         s.stroke_cap
		stroke_join:        s.stroke_join
		opacity:            s.opacity
		fill_opacity:       s.fill_opacity
		stroke_opacity:     s.stroke_opacity
		stroke_gradient_id: s.stroke_gradient_id
		stroke_dasharray:   s.stroke_dasharray
	}
	if gid := parse_fill_url(fill) {
		vp.fill_gradient_id = gid
	}
	return vp
}

// parse_line_element converts <line> to path.
// Returns none for degenerate lines (both endpoints identical).
fn parse_line_element(elem string) ?VectorPath {
	x1 := (find_attr(elem, 'x1') or { '0' }).f32()
	y1 := (find_attr(elem, 'y1') or { '0' }).f32()
	x2 := (find_attr(elem, 'x2') or { '0' }).f32()
	y2 := (find_attr(elem, 'y2') or { '0' }).f32()

	if x1 == x2 && y1 == y2 {
		return none
	}

	s := parse_element_style(elem)
	return VectorPath{
		segments:           [
			PathSegment{.move_to, [x1, y1]},
			PathSegment{.line_to, [x2, y2]},
		]
		fill_color:         color_transparent
		transform:          s.transform
		stroke_color:       s.stroke_color
		stroke_width:       s.stroke_width
		stroke_cap:         s.stroke_cap
		stroke_join:        s.stroke_join
		opacity:            s.opacity
		fill_opacity:       s.fill_opacity
		stroke_opacity:     s.stroke_opacity
		stroke_gradient_id: s.stroke_gradient_id
		stroke_dasharray:   s.stroke_dasharray
	}
}
