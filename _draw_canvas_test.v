module gui

import math

// ---------------------
// Guard clause tests
// ---------------------

fn test_polyline_rejects_too_few_points() {
	mut dc := DrawContext{
		width:  100
		height: 100
	}
	dc.polyline([f32(0), 0], Color{}, 2, .butt, .miter) // 1 point
	assert dc.batches.len == 0
}

fn test_polyline_rejects_zero_width() {
	mut dc := DrawContext{
		width:  100
		height: 100
	}
	dc.polyline([f32(0), 0, 10, 10], Color{}, 0, .butt, .miter)
	assert dc.batches.len == 0
}

fn test_polyline_rejects_negative_width() {
	mut dc := DrawContext{
		width:  100
		height: 100
	}
	dc.polyline([f32(0), 0, 10, 10], Color{}, -1, .butt, .miter)
	assert dc.batches.len == 0
}

fn test_filled_polygon_rejects_too_few_points() {
	mut dc := DrawContext{
		width:  100
		height: 100
	}
	dc.filled_polygon([f32(0), 0, 10, 10], Color{}) // 2 points
	assert dc.batches.len == 0
}

fn test_filled_rect_rejects_zero_width() {
	mut dc := DrawContext{
		width:  100
		height: 100
	}
	dc.filled_rect(0, 0, 0, 10, Color{})
	assert dc.batches.len == 0
}

fn test_filled_rect_rejects_zero_height() {
	mut dc := DrawContext{
		width:  100
		height: 100
	}
	dc.filled_rect(0, 0, 10, 0, Color{})
	assert dc.batches.len == 0
}

fn test_filled_rect_rejects_negative_dimensions() {
	mut dc := DrawContext{
		width:  100
		height: 100
	}
	dc.filled_rect(0, 0, -5, 10, Color{})
	assert dc.batches.len == 0
	dc.filled_rect(0, 0, 10, -5, Color{})
	assert dc.batches.len == 0
}

fn test_rect_rejects_zero_dimensions() {
	mut dc := DrawContext{
		width:  100
		height: 100
	}
	dc.rect(0, 0, 0, 10, Color{}, 2)
	assert dc.batches.len == 0
	dc.rect(0, 0, 10, 0, Color{}, 2)
	assert dc.batches.len == 0
}

fn test_rect_rejects_zero_stroke_width() {
	mut dc := DrawContext{
		width:  100
		height: 100
	}
	dc.rect(0, 0, 10, 10, Color{}, 0)
	assert dc.batches.len == 0
}

fn test_arc_rejects_zero_stroke_width() {
	mut dc := DrawContext{
		width:  100
		height: 100
	}
	dc.arc(50, 50, 20, 20, 0, math.pi, Color{}, 0)
	assert dc.batches.len == 0
}

// ---------------------
// arc_to_polyline tests
// ---------------------

fn test_arc_to_polyline_zero_radius() {
	pts := arc_to_polyline(0, 0, 0, 0, 0, math.pi)
	assert pts.len == 0
}

fn test_arc_to_polyline_negative_radius() {
	pts := arc_to_polyline(0, 0, -5, -5, 0, math.pi)
	assert pts.len == 0
}

fn test_arc_to_polyline_full_circle_start_end() {
	cx := f32(50)
	cy := f32(50)
	r := f32(20)
	pts := arc_to_polyline(cx, cy, r, r, 0, 2 * math.pi)
	assert pts.len >= 10 // at least 5 points
	// First point: (cx + r, cy)
	assert f32_are_close(pts[0], cx + r)
	assert f32_are_close(pts[1], cy)
	// Last point should be close to first (full circle).
	last_x := pts[pts.len - 2]
	last_y := pts[pts.len - 1]
	assert f32_are_close(last_x, cx + r)
	assert f32_are_close(last_y, cy)
}

fn test_arc_to_polyline_half_circle() {
	cx := f32(0)
	cy := f32(0)
	r := f32(10)
	pts := arc_to_polyline(cx, cy, r, r, 0, math.pi)
	assert pts.len >= 8 // at least 4 points
	// Start at (r, 0)
	assert f32_are_close(pts[0], r)
	assert f32_are_close(pts[1], 0)
	// End near (-r, 0)
	last_x := pts[pts.len - 2]
	last_y := pts[pts.len - 1]
	assert f32_are_close(last_x, -r)
	assert f32_are_close(last_y, 0)
}

fn test_arc_to_polyline_quarter_circle() {
	cx := f32(0)
	cy := f32(0)
	r := f32(10)
	pts := arc_to_polyline(cx, cy, r, r, 0, math.pi / 2)
	assert pts.len >= 8
	// Start at (r, 0)
	assert f32_are_close(pts[0], r)
	assert f32_are_close(pts[1], 0)
	// End near (0, r)
	last_x := pts[pts.len - 2]
	last_y := pts[pts.len - 1]
	assert f32_are_close(last_x, 0)
	assert f32_are_close(last_y, r)
}

fn test_arc_to_polyline_negative_sweep() {
	cx := f32(0)
	cy := f32(0)
	r := f32(10)
	pts := arc_to_polyline(cx, cy, r, r, 0, -math.pi / 2)
	assert pts.len >= 8
	// Start at (r, 0), end near (0, -r)
	assert f32_are_close(pts[0], r)
	assert f32_are_close(pts[1], 0)
	last_x := pts[pts.len - 2]
	last_y := pts[pts.len - 1]
	assert f32_are_close(last_x, 0)
	assert f32_are_close(last_y, -r)
}

fn test_arc_to_polyline_elliptical() {
	cx := f32(0)
	cy := f32(0)
	rx := f32(20)
	ry := f32(10)
	pts := arc_to_polyline(cx, cy, rx, ry, 0, math.pi / 2)
	assert pts.len >= 8
	// Start at (rx, 0)
	assert f32_are_close(pts[0], rx)
	assert f32_are_close(pts[1], 0)
	// End near (0, ry)
	last_x := pts[pts.len - 2]
	last_y := pts[pts.len - 1]
	assert f32_are_close(last_x, 0)
	assert f32_are_close(last_y, ry)
}

fn test_arc_to_polyline_min_segments() {
	// Even a tiny arc should produce at least 4 segments + 1 = 5
	// points (10 floats).
	pts := arc_to_polyline(0, 0, 1, 1, 0, 0.01)
	assert pts.len >= 10
}

fn test_arc_to_polyline_segment_count_scales_with_radius() {
	small := arc_to_polyline(0, 0, 5, 5, 0, 2 * math.pi)
	large := arc_to_polyline(0, 0, 200, 200, 0, 2 * math.pi)
	// Larger radius should produce more segments.
	assert large.len > small.len
}

// ---------------------
// Primitive output tests
// ---------------------

fn test_polyline_produces_triangles() {
	mut dc := DrawContext{
		width:  100
		height: 100
	}
	clr := Color{255, 0, 0, 255}
	dc.polyline([f32(0), 0, 50, 50, 100, 0], clr, 2, .butt, .miter)
	assert dc.batches.len == 1
	assert dc.batches[0].color == clr
	// Triangles array must have length divisible by 6
	// (each triangle = 3 vertices * 2 coords).
	assert dc.batches[0].triangles.len > 0
	assert dc.batches[0].triangles.len % 6 == 0
}

fn test_filled_polygon_produces_triangles() {
	mut dc := DrawContext{
		width:  100
		height: 100
	}
	clr := Color{0, 0, 255, 255}
	// Triangle polygon: 3 points = 6 floats.
	dc.filled_polygon([f32(0), 0, 100, 0, 50, 100], clr)
	assert dc.batches.len == 1
	assert dc.batches[0].color == clr
	assert dc.batches[0].triangles.len == 6
}

fn test_filled_rect_exact_triangles() {
	mut dc := DrawContext{
		width:  100
		height: 100
	}
	c := Color{10, 20, 30, 255}
	dc.filled_rect(5, 10, 20, 30, c)
	assert dc.batches.len == 1
	assert dc.batches[0].color == c
	tris := dc.batches[0].triangles
	// Two triangles = 12 floats.
	assert tris.len == 12
	// Triangle 1: top-left, top-right, bottom-right.
	assert tris[0] == f32(5) && tris[1] == f32(10)
	assert tris[2] == f32(25) && tris[3] == f32(10)
	assert tris[4] == f32(25) && tris[5] == f32(40)
	// Triangle 2: top-left, bottom-right, bottom-left.
	assert tris[6] == f32(5) && tris[7] == f32(10)
	assert tris[8] == f32(25) && tris[9] == f32(40)
	assert tris[10] == f32(5) && tris[11] == f32(40)
}

fn test_line_produces_batch() {
	mut dc := DrawContext{
		width:  100
		height: 100
	}
	dc.line(0, 0, 100, 100, Color{255, 255, 255, 255}, 3)
	assert dc.batches.len == 1
	assert dc.batches[0].triangles.len > 0
	assert dc.batches[0].triangles.len % 6 == 0
}

fn test_rect_produces_batch() {
	mut dc := DrawContext{
		width:  100
		height: 100
	}
	dc.rect(10, 10, 80, 60, Color{0, 255, 0, 255}, 2)
	assert dc.batches.len == 1
	assert dc.batches[0].triangles.len > 0
}

fn test_filled_circle_produces_batch() {
	mut dc := DrawContext{
		width:  100
		height: 100
	}
	dc.filled_circle(50, 50, 20, Color{255, 0, 0, 255})
	assert dc.batches.len == 1
	assert dc.batches[0].triangles.len > 0
	assert dc.batches[0].triangles.len % 6 == 0
}

fn test_circle_produces_batch() {
	mut dc := DrawContext{
		width:  100
		height: 100
	}
	dc.circle(50, 50, 20, Color{0, 0, 255, 255}, 2)
	assert dc.batches.len == 1
	assert dc.batches[0].triangles.len > 0
}

fn test_arc_produces_batch() {
	mut dc := DrawContext{
		width:  100
		height: 100
	}
	dc.arc(50, 50, 30, 30, 0, math.pi, Color{}, 2)
	assert dc.batches.len == 1
	assert dc.batches[0].triangles.len > 0
}

fn test_filled_arc_produces_batch() {
	mut dc := DrawContext{
		width:  100
		height: 100
	}
	dc.filled_arc(50, 50, 30, 30, 0, math.pi, Color{})
	assert dc.batches.len == 1
	assert dc.batches[0].triangles.len > 0
	assert dc.batches[0].triangles.len % 6 == 0
}

// ---------------------
// Batch accumulation
// ---------------------

fn test_multiple_draws_produce_multiple_batches() {
	mut dc := DrawContext{
		width:  200
		height: 200
	}
	c1 := Color{255, 0, 0, 255}
	c2 := Color{0, 255, 0, 255}
	c3 := Color{0, 0, 255, 255}
	dc.filled_rect(0, 0, 50, 50, c1)
	dc.line(0, 0, 100, 100, c2, 2)
	dc.filled_circle(100, 100, 10, c3)
	assert dc.batches.len == 3
	assert dc.batches[0].color == c1
	assert dc.batches[1].color == c2
	assert dc.batches[2].color == c3
}

fn test_rejected_draws_leave_batches_unchanged() {
	mut dc := DrawContext{
		width:  100
		height: 100
	}
	dc.filled_rect(0, 0, 10, 10, Color{})
	assert dc.batches.len == 1
	// All of these should be rejected.
	dc.filled_rect(0, 0, 0, 10, Color{})
	dc.polyline([f32(0)], Color{}, 2, .butt, .miter)
	dc.filled_polygon([f32(0), 0], Color{})
	dc.rect(0, 0, 0, 0, Color{}, 1)
	dc.arc(0, 0, 0, 0, 0, 1, Color{}, 1)
	assert dc.batches.len == 1
}

// ---------------------
// Color preservation
// ---------------------

fn test_batch_preserves_color() {
	c := Color{12, 34, 56, 78}
	mut dc := DrawContext{
		width:  100
		height: 100
	}
	dc.filled_rect(0, 0, 10, 10, c)
	assert dc.batches[0].color.r == 12
	assert dc.batches[0].color.g == 34
	assert dc.batches[0].color.b == 56
	assert dc.batches[0].color.a == 78
}

// ---------------------
// filled_arc / filled_circle geometry sanity
// ---------------------

fn test_filled_circle_triangles_near_radius() {
	cx := f32(50)
	cy := f32(50)
	r := f32(20)
	mut dc := DrawContext{
		width:  100
		height: 100
	}
	dc.filled_circle(cx, cy, r, Color{})
	tris := dc.batches[0].triangles
	// Every vertex should be within radius of center (plus
	// tolerance for tessellation).
	for i := 0; i < tris.len; i += 2 {
		dx := tris[i] - cx
		dy := tris[i + 1] - cy
		dist := f32(math.sqrt(dx * dx + dy * dy))
		assert dist <= r + 1.0
	}
}

fn test_filled_arc_includes_center() {
	cx := f32(50)
	cy := f32(50)
	mut dc := DrawContext{
		width:  100
		height: 100
	}
	dc.filled_arc(cx, cy, 20, 20, 0, math.pi / 2, Color{})
	tris := dc.batches[0].triangles
	// At least one vertex should be the center point.
	mut found_center := false
	for i := 0; i < tris.len; i += 2 {
		if f32_are_close(tris[i], cx) && f32_are_close(tris[i + 1], cy) {
			found_center = true
			break
		}
	}
	assert found_center
}

// ---------------------
// DrawCanvasCfg / View creation
// ---------------------

fn test_draw_canvas_returns_view() {
	v := draw_canvas(DrawCanvasCfg{
		id:      'test'
		width:   100
		height:  80
		version: 1
	})
	// Should produce a DrawCanvasView.
	cv := v as DrawCanvasView
	assert cv.id == 'test'
	assert cv.width == 100
	assert cv.height == 80
	assert cv.version == 1
	assert cv.clip == true // default
}

fn test_draw_canvas_cfg_fields_propagate() {
	v := draw_canvas(DrawCanvasCfg{
		id:         'cfg-test'
		version:    42
		width:      200
		height:     150
		min_width:  50
		max_width:  300
		min_height: 40
		max_height: 250
		clip:       false
		radius:     8
		color:      Color{10, 20, 30, 255}
	})
	cv := v as DrawCanvasView
	assert cv.version == 42
	assert cv.min_width == 50
	assert cv.max_width == 300
	assert cv.min_height == 40
	assert cv.max_height == 250
	assert cv.clip == false
	assert cv.radius == 8
	assert cv.color == Color{10, 20, 30, 255}
}
