module gui

import math

fn test_build_arc_length_table_straight() {
	poly := [f32(0), 0, 3, 0, 7, 0]
	table := build_arc_length_table(poly)
	assert table.len == 3
	assert table[0] == 0
	assert math.abs(table[1] - 3.0) < 0.01
	assert math.abs(table[2] - 7.0) < 0.01
}

fn test_build_arc_length_table_diagonal() {
	poly := [f32(0), 0, 3, 4]
	table := build_arc_length_table(poly)
	assert table.len == 2
	assert table[0] == 0
	assert math.abs(table[1] - 5.0) < 0.01
}

fn test_sample_path_at_endpoints() {
	poly := [f32(0), 0, 100, 0]
	table := build_arc_length_table(poly)
	x0, y0, _ := sample_path_at(poly, table, 0)
	assert math.abs(x0) < 0.01
	assert math.abs(y0) < 0.01
	x1, y1, _ := sample_path_at(poly, table, 100)
	assert math.abs(x1 - 100) < 0.01
	assert math.abs(y1) < 0.01
}

fn test_sample_path_at_midpoint() {
	poly := [f32(0), 0, 100, 0]
	table := build_arc_length_table(poly)
	x, y, _ := sample_path_at(poly, table, 50)
	assert math.abs(x - 50) < 0.01
	assert math.abs(y) < 0.01
}

fn test_sample_path_at_angle_horizontal() {
	poly := [f32(0), 0, 100, 0]
	table := build_arc_length_table(poly)
	_, _, angle := sample_path_at(poly, table, 50)
	assert math.abs(angle) < 0.01
}

fn test_sample_path_at_angle_l_shape() {
	poly := [f32(0), 0, 10, 0, 10, 10]
	table := build_arc_length_table(poly)
	_, _, a1 := sample_path_at(poly, table, 5)
	assert math.abs(a1) < 0.01
	_, _, a2 := sample_path_at(poly, table, 15)
	assert math.abs(a2 - math.pi / 2) < 0.01
}

fn test_sample_path_clamp_beyond() {
	poly := [f32(0), 0, 10, 0]
	table := build_arc_length_table(poly)
	x, _, _ := sample_path_at(poly, table, 999)
	assert math.abs(x - 10) < 0.01
	x2, _, _ := sample_path_at(poly, table, -5)
	assert math.abs(x2) < 0.01
}

fn test_parse_textpath_no_matching_path() {
	// textPath references non-existent path — should still parse
	content := '<svg>
	<text><textPath href="#missing">Ghost</textPath></text></svg>'
	vg := parse_svg(content) or { panic(err) }
	assert vg.text_paths.len == 1
	assert vg.text_paths[0].path_id == 'missing'
}

fn test_parse_textpath_empty_text() {
	content := '<svg><defs>
		<path id="p" d="M0 0 L100 0"/>
	</defs>
	<text><textPath href="#p"></textPath></text></svg>'
	vg := parse_svg(content) or { panic(err) }
	assert vg.text_paths.len == 0
}

fn test_parse_svg_with_textpath_full() {
	// Full SVG matching the example in svg_viewer.v
	content := '<svg viewBox="0 0 400 400">
	<defs>
		<path id="curvePath"
			d="M40 220 Q200 160 360 220" fill="none"/>
	</defs>
	<text font-family="Arial" font-size="13"
		fill="#3399cc" font-weight="600">
		<textPath href="#curvePath" startOffset="50%"
			text-anchor="middle"
			>Text Following a Curved Path</textPath>
	</text></svg>'
	vg := parse_svg(content) or { panic(err) }
	assert vg.defs_paths.len == 1
	assert 'curvePath' in vg.defs_paths
	assert vg.text_paths.len == 1
	tp := vg.text_paths[0]
	assert tp.path_id == 'curvePath'
	assert tp.text == 'Text Following a Curved Path'
	assert tp.is_percent == true
	assert tp.start_offset > 0.49 && tp.start_offset < 0.51
	assert tp.anchor == 1
	assert tp.bold == true // font-weight 600
	assert tp.font_family == 'Arial'
}
