module gui

// resolve_gradient maps objectBoundingBox gradient coords to
// absolute coordinates using the given bounding box.
fn resolve_gradient(g SvgGradientDef, min_x f32, min_y f32, max_x f32, max_y f32) SvgGradientDef {
	if !g.object_bounding_box {
		return g
	}
	w := max_x - min_x
	h := max_y - min_y
	return SvgGradientDef{
		...g
		x1:                  min_x + g.x1 * w
		y1:                  min_y + g.y1 * h
		x2:                  min_x + g.x2 * w
		y2:                  min_y + g.y2 * h
		object_bounding_box: false
	}
}

// bbox_from_triangles computes axis-aligned bounding box from
// triangle vertices (flat x,y pairs).
fn bbox_from_triangles(tris []f32) (f32, f32, f32, f32) {
	if tris.len < 2 {
		return 0, 0, 0, 0
	}
	mut min_x := tris[0]
	mut min_y := tris[1]
	mut max_x := min_x
	mut max_y := min_y
	mut i := 2
	for i < tris.len {
		x := tris[i]
		y := tris[i + 1]
		if x < min_x {
			min_x = x
		}
		if x > max_x {
			max_x = x
		}
		if y < min_y {
			min_y = y
		}
		if y > max_y {
			max_y = y
		}
		i += 2
	}
	return min_x, min_y, max_x, max_y
}

// project_onto_gradient computes parameter t for vertex (vx,vy) on
// gradient axis (x1,y1)->(x2,y2). Clamped to [0,1].
fn project_onto_gradient(vx f32, vy f32, g SvgGradientDef) f32 {
	dx := g.x2 - g.x1
	dy := g.y2 - g.y1
	len_sq := dx * dx + dy * dy
	if len_sq == 0 {
		return 0
	}
	t := ((vx - g.x1) * dx + (vy - g.y1) * dy) / len_sq
	if t < 0 {
		return 0
	}
	if t > 1 {
		return 1
	}
	return t
}

// interpolate_gradient returns the color at parameter t along gradient
// stops. Clamps to first/last stop outside range.
fn interpolate_gradient(stops []SvgGradientStop, t f32) Color {
	if stops.len == 0 {
		return Color{0, 0, 0, 255}
	}
	if t <= stops[0].offset || stops.len == 1 {
		return stops[0].color
	}
	last := stops[stops.len - 1]
	if t >= last.offset {
		return last.color
	}
	// Find surrounding stops
	for i := 0; i < stops.len - 1; i++ {
		s0 := stops[i]
		s1 := stops[i + 1]
		if t >= s0.offset && t <= s1.offset {
			range_ := s1.offset - s0.offset
			if range_ <= 0 {
				return s0.color
			}
			f := (t - s0.offset) / range_
			return Color{
				r: u8(f32(s0.color.r) + (f32(s1.color.r) - f32(s0.color.r)) * f)
				g: u8(f32(s0.color.g) + (f32(s1.color.g) - f32(s0.color.g)) * f)
				b: u8(f32(s0.color.b) + (f32(s1.color.b) - f32(s0.color.b)) * f)
				a: u8(f32(s0.color.a) + (f32(s1.color.a) - f32(s0.color.a)) * f)
			}
		}
	}
	return last.color
}

// subdivide_gradient_tris splits triangles at gradient stop
// boundaries so per-vertex colors accurately represent multi-stop
// gradients. Without this, GPU linear interpolation between
// vertices skips intermediate color stops.
fn subdivide_gradient_tris(tris []f32, grad SvgGradientDef) []f32 {
	if grad.stops.len <= 2 {
		return tris
	}
	mut stop_ts := []f32{cap: grad.stops.len}
	for s in grad.stops {
		if s.offset > 0.001 && s.offset < 0.999 {
			stop_ts << s.offset
		}
	}
	if stop_ts.len == 0 {
		return tris
	}
	mut result := []f32{cap: tris.len * 2}
	mut i := 0
	for i < tris.len - 5 {
		split_tri_at_stops(tris[i], tris[i + 1], tris[i + 2], tris[i + 3], tris[i + 4],
			tris[i + 5], grad, stop_ts, mut result)
		i += 6
	}
	return result
}

// split_tri_at_stops recursively splits a triangle at gradient
// stop boundaries and appends resulting sub-triangles to result.
fn split_tri_at_stops(ax f32, ay f32, bx f32, by f32, cx f32, cy f32, grad SvgGradientDef, stop_ts []f32, mut result []f32) {
	ta := project_onto_gradient(ax, ay, grad)
	tb := project_onto_gradient(bx, by, grad)
	tc := project_onto_gradient(cx, cy, grad)

	mut t_min := ta
	if tb < t_min {
		t_min = tb
	}
	if tc < t_min {
		t_min = tc
	}
	mut t_max := ta
	if tb > t_max {
		t_max = tb
	}
	if tc > t_max {
		t_max = tc
	}

	// Find first stop that splits this triangle
	for t_s in stop_ts {
		if t_s > t_min + 1e-4 && t_s < t_max - 1e-4 {
			// Sort vertices by t (bubble sort)
			mut p0x := ax
			mut p0y := ay
			mut t0 := ta
			mut p1x := bx
			mut p1y := by
			mut t1 := tb
			mut p2x := cx
			mut p2y := cy
			mut t2 := tc
			if t0 > t1 {
				p0x, p0y, t0, p1x, p1y, t1 = p1x, p1y, t1, p0x, p0y, t0
			}
			if t1 > t2 {
				p1x, p1y, t1, p2x, p2y, t2 = p2x, p2y, t2, p1x, p1y, t1
			}
			if t0 > t1 {
				p0x, p0y, t0, p1x, p1y, t1 = p1x, p1y, t1, p0x, p0y, t0
			}
			// Intersection on edge p0-p2
			f02 := if t2 - t0 > 1e-6 {
				(t_s - t0) / (t2 - t0)
			} else {
				f32(0.5)
			}
			i1x := p0x + f02 * (p2x - p0x)
			i1y := p0y + f02 * (p2y - p0y)

			if t_s < t1 - 1e-4 {
				// Split line crosses edges p0-p1 and p0-p2
				f01 := if t1 - t0 > 1e-6 {
					(t_s - t0) / (t1 - t0)
				} else {
					f32(0.5)
				}
				i2x := p0x + f01 * (p1x - p0x)
				i2y := p0y + f01 * (p1y - p0y)
				split_tri_at_stops(p0x, p0y, i2x, i2y, i1x, i1y, grad, stop_ts, mut result)
				split_tri_at_stops(i2x, i2y, p1x, p1y, i1x, i1y, grad, stop_ts, mut result)
				split_tri_at_stops(p1x, p1y, p2x, p2y, i1x, i1y, grad, stop_ts, mut result)
			} else if t_s > t1 + 1e-4 {
				// Split line crosses edges p1-p2 and p0-p2
				f12 := if t2 - t1 > 1e-6 {
					(t_s - t1) / (t2 - t1)
				} else {
					f32(0.5)
				}
				i2x := p1x + f12 * (p2x - p1x)
				i2y := p1y + f12 * (p2y - p1y)
				split_tri_at_stops(p0x, p0y, p1x, p1y, i1x, i1y, grad, stop_ts, mut result)
				split_tri_at_stops(p1x, p1y, i2x, i2y, i1x, i1y, grad, stop_ts, mut result)
				split_tri_at_stops(i1x, i1y, i2x, i2y, p2x, p2y, grad, stop_ts, mut result)
			} else {
				// t_s ~ t1, split through vertex p1
				split_tri_at_stops(p0x, p0y, p1x, p1y, i1x, i1y, grad, stop_ts, mut result)
				split_tri_at_stops(p1x, p1y, p2x, p2y, i1x, i1y, grad, stop_ts, mut result)
			}
			return
		}
	}
	// No split needed, emit triangle
	result << ax
	result << ay
	result << bx
	result << by
	result << cx
	result << cy
}
