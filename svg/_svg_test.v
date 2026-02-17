module svg

// --- Color parsing tests ---

fn test_parse_hex_color_rgb() {
	c := parse_hex_color('#f80')
	assert c.r == 0xff
	assert c.g == 0x88
	assert c.b == 0x00
	assert c.a == 255
}

fn test_parse_hex_color_rrggbb() {
	c := parse_hex_color('#1a2b3c')
	assert c.r == 0x1a
	assert c.g == 0x2b
	assert c.b == 0x3c
	assert c.a == 255
}

fn test_parse_hex_color_rrggbbaa() {
	c := parse_hex_color('#1a2b3c80')
	assert c.r == 0x1a
	assert c.g == 0x2b
	assert c.b == 0x3c
	assert c.a == 0x80
}

fn test_parse_rgb_color_basic() {
	c := parse_rgb_color('rgb(10, 20, 30)')
	assert c.r == 10
	assert c.g == 20
	assert c.b == 30
	assert c.a == 255
}

fn test_parse_rgb_color_clamped() {
	c := parse_rgb_color('rgb(300, -5, 256)')
	assert c.r == 255
	assert c.g == 0
	assert c.b == 255
}

fn test_parse_rgb_color_alpha() {
	c := parse_rgb_color('rgba(100, 150, 200, 0.5)')
	assert c.r == 100
	assert c.g == 150
	assert c.b == 200
	assert c.a == 127 || c.a == 128 // float rounding
}

fn test_parse_svg_color_none() {
	c := parse_svg_color('none')
	assert c.a == 0
}

fn test_parse_svg_color_inherit_sentinel() {
	c := parse_svg_color('')
	assert c == color_inherit
}

fn test_parse_svg_color_named() {
	c := parse_svg_color('red')
	assert c.r == 255
	assert c.g == 0
	assert c.b == 0
}

// --- parse_length tests ---

fn test_parse_length_basic() {
	assert parse_length('42') == 42.0
	assert parse_length('3.14') > 3.13 && parse_length('3.14') < 3.15
	assert parse_length('-5') == -5.0
}

fn test_parse_length_with_units() {
	assert parse_length('100px') == 100.0
	assert parse_length('50em') == 50.0
}

fn test_parse_length_plus_prefix() {
	assert parse_length('+42') == 42.0
}

fn test_parse_length_empty() {
	assert parse_length('') == 0
}

fn test_parse_length_clamped() {
	assert parse_length('9999999') == f32(max_coordinate)
	assert parse_length('-9999999') == f32(-max_coordinate)
}

// --- viewBox parsing tests ---

fn test_viewbox_dimensions() {
	src := '<svg viewBox="0 0 200 100"><rect width="200" height="100"/></svg>'
	vg := parse_svg(src) or { panic(err) }
	assert vg.width == 200
	assert vg.height == 100
	assert vg.view_box_x == 0
	assert vg.view_box_y == 0
}

fn test_viewbox_offset() {
	src := '<svg viewBox="10 20 200 100"></svg>'
	vg := parse_svg(src) or { panic(err) }
	assert vg.view_box_x == 10
	assert vg.view_box_y == 20
	assert vg.width == 200
	assert vg.height == 100
}

fn test_viewbox_offset_applied_to_paths() {
	src := '<svg viewBox="50 50 100 100"><rect x="50" y="50" width="10" height="10"/></svg>'
	vg := parse_svg(src) or { panic(err) }
	// The rect at (50,50) with viewBox origin (50,50) should
	// have transform translating by (-50,-50), so effective
	// position is (0,0) in viewBox space.
	assert vg.paths.len > 0
	t := vg.paths[0].transform
	// Translation components should include -50, -50
	assert t[4] == -50
	assert t[5] == -50
}

// --- Path parsing tests ---

fn test_parse_path_d_move_line() {
	segs := parse_path_d('M 10 20 L 30 40')
	assert segs.len == 2
	assert segs[0].cmd == .move_to
	assert segs[0].points == [f32(10), 20]
	assert segs[1].cmd == .line_to
	assert segs[1].points == [f32(30), 40]
}

fn test_parse_path_d_relative() {
	segs := parse_path_d('m 10 20 l 5 5')
	assert segs.len == 2
	assert segs[0].cmd == .move_to
	assert segs[0].points == [f32(10), 20]
	assert segs[1].cmd == .line_to
	assert segs[1].points == [f32(15), 25]
}

fn test_parse_path_d_horizontal_vertical() {
	segs := parse_path_d('M 0 0 H 10 V 20')
	assert segs.len == 3
	assert segs[1].points == [f32(10), 0]
	assert segs[2].points == [f32(10), 20]
}

fn test_parse_path_d_close() {
	segs := parse_path_d('M 0 0 L 10 0 L 10 10 Z')
	assert segs.len == 4
	assert segs[3].cmd == .close
}

fn test_parse_path_d_cubic() {
	segs := parse_path_d('M 0 0 C 1 2 3 4 5 6')
	assert segs.len == 2
	assert segs[1].cmd == .cubic_to
	assert segs[1].points.len == 6
}

fn test_parse_path_d_quad() {
	segs := parse_path_d('M 0 0 Q 5 5 10 0')
	assert segs.len == 2
	assert segs[1].cmd == .quad_to
	assert segs[1].points.len == 4
}

fn test_parse_path_d_arc_degenerate() {
	// Zero radii should produce line_to
	segs := parse_path_d('M 0 0 A 0 0 0 0 0 10 10')
	assert segs.len >= 2
	assert segs[1].cmd == .line_to
}

// --- Element parsing tests ---

fn test_parse_rect_element() {
	p := parse_rect_element('<rect x="5" y="10" width="100" height="50"/>') or {
		panic('rect parse failed')
	}
	assert p.segments.len == 5 // move + 3 lines + close
	assert p.segments[0].cmd == .move_to
	assert p.segments[4].cmd == .close
}

fn test_parse_circle_element() {
	p := parse_circle_element('<circle cx="50" cy="50" r="25"/>') or {
		panic('circle parse failed')
	}
	// Circle uses 4 cubic beziers + close
	assert p.segments.len == 6
	assert p.segments[0].cmd == .move_to
	assert p.segments[5].cmd == .close
}

fn test_parse_polygon_element() {
	p := parse_polygon_element('<polygon points="0,0 10,0 10,10 0,10"/>', true) or {
		panic('polygon parse failed')
	}
	assert p.segments.len == 5 // move + 3 lines + close
}

fn test_parse_line_element() {
	p := parse_line_element('<line x1="0" y1="0" x2="100" y2="100"/>') or {
		panic('line parse failed')
	}
	assert p.segments.len == 2
	assert p.fill_color.a == 0 // lines have transparent fill
}

fn test_parse_line_element_degenerate() {
	// Degenerate line (0,0 -> 0,0) should return none
	result := parse_line_element('<line x1="0" y1="0" x2="0" y2="0"/>')
	assert result == none
}

// --- Style attribute tests ---

fn test_find_style_property() {
	style := 'fill:red;stroke:blue;stroke-width:2'
	assert (find_style_property(style, 'fill') or { '' }) == 'red'
	assert (find_style_property(style, 'stroke') or { '' }) == 'blue'
	assert (find_style_property(style, 'stroke-width') or { '' }) == '2'
	assert (find_style_property(style, 'opacity') or { 'none' }) == 'none'
}

fn test_find_style_property_with_spaces() {
	style := 'fill: #ff0000 ; stroke: blue'
	assert (find_style_property(style, 'fill') or { '' }) == '#ff0000'
	assert (find_style_property(style, 'stroke') or { '' }) == 'blue'
}

fn test_style_attribute_fill() {
	src := '<svg viewBox="0 0 10 10"><rect style="fill:red" width="10" height="10"/></svg>'
	vg := parse_svg(src) or { panic(err) }
	assert vg.paths.len == 1
	assert vg.paths[0].fill_color.r == 255
	assert vg.paths[0].fill_color.g == 0
}

fn test_style_overrides_presentation_attr() {
	// Inline style has higher specificity than presentation attribute
	elem := '<rect fill="blue" style="fill:red" width="10" height="10"/>'
	p := parse_rect_element(elem) or { panic('parse failed') }
	// style="fill:red" should win over fill="blue"
	assert p.fill_color.r == 255
}

// --- Opacity tests ---

fn test_parse_opacity_attr() {
	elem := '<rect opacity="0.5" width="10" height="10"/>'
	assert parse_opacity_attr(elem, 'opacity', 1.0) > 0.49
	assert parse_opacity_attr(elem, 'opacity', 1.0) < 0.51
}

fn test_opacity_applied_to_fill() {
	src := '<svg viewBox="0 0 10 10"><rect fill="red" opacity="0.5" width="10" height="10"/></svg>'
	vg := parse_svg(src) or { panic(err) }
	assert vg.paths.len == 1
	// opacity 0.5 * fill_color alpha 255 ≈ 127
	a := vg.paths[0].fill_color.a
	assert a >= 126 && a <= 128
}

fn test_fill_opacity() {
	src := '<svg viewBox="0 0 10 10"><rect fill="red" fill-opacity="0.5" width="10" height="10"/></svg>'
	vg := parse_svg(src) or { panic(err) }
	assert vg.paths.len == 1
	a := vg.paths[0].fill_color.a
	assert a >= 126 && a <= 128
}

fn test_apply_opacity_no_change() {
	c := SvgColor{255, 0, 0, 200}
	result := apply_opacity(c, 1.0)
	assert result.a == 200
}

fn test_apply_opacity_half() {
	c := SvgColor{255, 0, 0, 200}
	result := apply_opacity(c, 0.5)
	assert result.a == 100
}

// --- Transform parsing tests ---

fn test_parse_transform_translate() {
	m := parse_transform('translate(10, 20)')
	assert m[4] == 10
	assert m[5] == 20
}

fn test_parse_transform_scale() {
	m := parse_transform('scale(2)')
	assert m[0] == 2
	assert m[3] == 2
}

fn test_parse_transform_rotate() {
	m := parse_transform('rotate(90)')
	// cos(90°) ≈ 0, sin(90°) ≈ 1
	assert f32_abs(m[0]) < 0.01
	assert f32_abs(m[1] - 1.0) < 0.01
}

fn test_parse_transform_multiple() {
	m := parse_transform('translate(10,0) scale(2)')
	// translate then scale: scale applied to translation
	assert m[0] == 2
	assert m[4] == 10
}

// --- Tessellation edge case tests ---

fn test_point_in_triangle_degenerate() {
	// Degenerate triangle (all points collinear) should return false
	result := point_in_triangle(5, 5, 0, 0, 10, 10, 20, 20)
	assert result == false
}

fn test_point_in_triangle_zero_area() {
	// All same point
	result := point_in_triangle(0, 0, 0, 0, 0, 0, 0, 0)
	assert result == false
}

fn test_ear_clip_triangle() {
	poly := [f32(0), 0, 10, 0, 5, 10]
	tris := ear_clip(poly)
	assert tris.len == 6 // 1 triangle = 6 floats
}

fn test_ear_clip_square() {
	poly := [f32(0), 0, 10, 0, 10, 10, 0, 10]
	tris := ear_clip(poly)
	assert tris.len == 12 // 2 triangles = 12 floats
}

fn test_ear_clip_degenerate() {
	// Less than 3 points
	tris := ear_clip([f32(0), 0, 1, 1])
	assert tris.len == 0
}

fn test_polygon_area_ccw() {
	// CCW square: positive area
	poly := [f32(0), 0, 10, 0, 10, 10, 0, 10]
	area := polygon_area(poly)
	assert area < 0 // shoelace gives negative for this winding
}

// --- Tokenizer tests ---

fn test_tokenize_path_basic() {
	tokens := tokenize_path('M 10 20 L 30 40')
	assert tokens == ['M', '10', '20', 'L', '30', '40']
}

fn test_tokenize_path_compact() {
	tokens := tokenize_path('M10,20L30,40')
	assert tokens == ['M', '10', '20', 'L', '30', '40']
}

fn test_tokenize_path_negative() {
	tokens := tokenize_path('M10-20')
	assert tokens == ['M', '10', '-20']
}

fn test_tokenize_path_implicit_separator() {
	// "1.5.5" should be two numbers: 1.5 and .5
	tokens := tokenize_path('M1.5.5')
	assert tokens == ['M', '1.5', '.5']
}

fn test_tokenize_path_exponent() {
	tokens := tokenize_path('1e-5 2E+3')
	assert tokens == ['1e-5', '2E+3']
}

// --- find_attr tests ---

fn test_find_attr_double_quotes() {
	result := find_attr('<rect width="100"/>', 'width') or { '' }
	assert result == '100'
}

fn test_find_attr_single_quotes() {
	result := find_attr("<rect width='100'/>", 'width') or { '' }
	assert result == '100'
}

fn test_find_attr_not_found() {
	result := find_attr('<rect width="100"/>', 'height')
	assert result == none
}

fn test_find_attr_substring_no_match() {
	// "stroke-width" should not match "width"
	result := find_attr('<rect stroke-width="2"/>', 'width')
	// Actually find_attr requires whitespace prefix, so
	// stroke-width won't match "width" because "e" precedes it
	assert result == none
}

// --- parse_svg_dimensions tests ---

fn test_parse_svg_dimensions_viewbox() {
	w, h := parse_svg_dimensions('<svg viewBox="0 0 100 200"></svg>')
	assert w == 100
	assert h == 200
}

fn test_parse_svg_dimensions_width_height() {
	w, h := parse_svg_dimensions('<svg width="50" height="80"></svg>')
	assert w == 50
	assert h == 80
}

// --- Integration: full SVG parse ---

fn test_parse_svg_simple_rect() {
	src := '<svg viewBox="0 0 100 100"><rect x="10" y="10" width="80" height="80" fill="#ff0000"/></svg>'
	vg := parse_svg(src) or { panic(err) }
	assert vg.width == 100
	assert vg.height == 100
	assert vg.paths.len == 1
	assert vg.paths[0].fill_color.r == 255
}

fn test_parse_svg_group_inheritance() {
	src := '<svg viewBox="0 0 100 100"><g fill="blue"><rect width="10" height="10"/></g></svg>'
	vg := parse_svg(src) or { panic(err) }
	assert vg.paths.len == 1
	assert vg.paths[0].fill_color.b == 255
}

fn test_parse_svg_group_stroke_inheritance() {
	src := '<svg viewBox="0 0 100 100"><g stroke="red" stroke-width="2"><line x1="0" y1="0" x2="10" y2="10"/></g></svg>'
	vg := parse_svg(src) or { panic(err) }
	assert vg.paths.len == 1
	assert vg.paths[0].stroke_color.r == 255
	assert vg.paths[0].stroke_width == 2.0
}

fn test_parse_svg_empty() {
	src := '<svg viewBox="0 0 100 100"></svg>'
	vg := parse_svg(src) or { panic(err) }
	assert vg.paths.len == 0
}

fn test_get_triangles_empty() {
	vg := VectorGraphic{
		width:  100
		height: 100
	}
	tris := vg.get_triangles(1.0)
	assert tris.len == 0
}
