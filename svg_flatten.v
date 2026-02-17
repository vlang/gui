module gui

import math

// flatten_path converts bezier curves to polylines with given tolerance.
fn flatten_path(path VectorPath, tolerance f32) [][]f32 {
	mut polylines := [][]f32{}
	// Estimate capacity: 2 floats per segment + curve expansion (~8 points per curve)
	estimated_cap := path.segments.len * 16
	mut current := []f32{cap: estimated_cap}
	mut x := f32(0)
	mut y := f32(0)
	mut start_x := f32(0)
	mut start_y := f32(0)
	has_transform := !is_identity_transform(path.transform)

	for seg in path.segments {
		match seg.cmd {
			.move_to {
				if current.len >= 4 {
					polylines << current
				}
				current = []f32{cap: estimated_cap}
				x = seg.points[0]
				y = seg.points[1]
				start_x = x
				start_y = y
				if has_transform {
					tx, ty := apply_transform(x, y, path.transform)
					current << tx
					current << ty
				} else {
					current << x
					current << y
				}
			}
			.line_to {
				x = seg.points[0]
				y = seg.points[1]
				if has_transform {
					tx, ty := apply_transform(x, y, path.transform)
					// Skip consecutive duplicate points
					// (zero-length segments).
					if current.len >= 2 && tx == current[current.len - 2]
						&& ty == current[current.len - 1] {
					} else {
						current << tx
						current << ty
					}
				} else {
					if current.len >= 2 && x == current[current.len - 2]
						&& y == current[current.len - 1] {
					} else {
						current << x
						current << y
					}
				}
			}
			.quad_to {
				cx := seg.points[0]
				cy := seg.points[1]
				ex := seg.points[2]
				ey := seg.points[3]
				if has_transform {
					tx, ty := apply_transform(x, y, path.transform)
					tcx, tcy := apply_transform(cx, cy, path.transform)
					tex, tey := apply_transform(ex, ey, path.transform)
					flatten_quad(tx, ty, tcx, tcy, tex, tey, tolerance, mut current)
				} else {
					flatten_quad(x, y, cx, cy, ex, ey, tolerance, mut current)
				}
				x = ex
				y = ey
			}
			.cubic_to {
				c1x := seg.points[0]
				c1y := seg.points[1]
				c2x := seg.points[2]
				c2y := seg.points[3]
				ex := seg.points[4]
				ey := seg.points[5]
				if has_transform {
					tx, ty := apply_transform(x, y, path.transform)
					tc1x, tc1y := apply_transform(c1x, c1y, path.transform)
					tc2x, tc2y := apply_transform(c2x, c2y, path.transform)
					tex, tey := apply_transform(ex, ey, path.transform)
					flatten_cubic(tx, ty, tc1x, tc1y, tc2x, tc2y, tex, tey, tolerance, mut
						current)
				} else {
					flatten_cubic(x, y, c1x, c1y, c2x, c2y, ex, ey, tolerance, mut current)
				}
				x = ex
				y = ey
			}
			.close {
				if current.len >= 2 {
					// close path by connecting to start
					if x != start_x || y != start_y {
						if has_transform {
							tx, ty := apply_transform(start_x, start_y, path.transform)
							current << tx
							current << ty
						} else {
							current << start_x
							current << start_y
						}
					}
				}
				if current.len >= 6 {
					polylines << current
				}
				current = []f32{cap: estimated_cap}
				x = start_x
				y = start_y
			}
		}
	}

	if current.len >= 6 {
		polylines << current
	}

	return polylines
}

// Max recursion depth for curve flattening (16 levels = 65536 segments max)
const max_flatten_depth = 16

// flatten_quad flattens a quadratic bezier curve using recursive subdivision.
fn flatten_quad(x0 f32, y0 f32, cx f32, cy f32, x1 f32, y1 f32, tolerance f32, mut points []f32) {
	flatten_quad_recursive(x0, y0, cx, cy, x1, y1, tolerance, 0, mut points)
}

// flatten_quad_recursive is the depth-limited recursive implementation.
fn flatten_quad_recursive(x0 f32, y0 f32, cx f32, cy f32, x1 f32, y1 f32, tolerance f32, depth int, mut points []f32) {
	// Calculate flatness using distance from control point to midpoint of line
	mx := (x0 + x1) / 2
	my := (y0 + y1) / 2
	dx := cx - mx
	dy := cy - my
	d := math.sqrtf(dx * dx + dy * dy)

	if d <= tolerance || depth >= max_flatten_depth {
		points << x1
		points << y1
	} else {
		// Subdivide
		ax := (x0 + cx) / 2
		ay := (y0 + cy) / 2
		bx := (cx + x1) / 2
		by := (cy + y1) / 2
		abx := (ax + bx) / 2
		aby := (ay + by) / 2

		flatten_quad_recursive(x0, y0, ax, ay, abx, aby, tolerance, depth + 1, mut points)
		flatten_quad_recursive(abx, aby, bx, by, x1, y1, tolerance, depth + 1, mut points)
	}
}

// flatten_cubic flattens a cubic bezier curve using recursive subdivision.
fn flatten_cubic(x0 f32, y0 f32, c1x f32, c1y f32, c2x f32, c2y f32, x1 f32, y1 f32, tolerance f32, mut points []f32) {
	flatten_cubic_recursive(x0, y0, c1x, c1y, c2x, c2y, x1, y1, tolerance, 0, mut points)
}

// flatten_cubic_recursive is the depth-limited recursive implementation.
fn flatten_cubic_recursive(x0 f32, y0 f32, c1x f32, c1y f32, c2x f32, c2y f32, x1 f32, y1 f32, tolerance f32, depth int, mut points []f32) {
	// Check flatness using distance of control points from line
	dx := x1 - x0
	dy := y1 - y0
	d := math.sqrtf(dx * dx + dy * dy)

	if d < curve_degenerate_threshold {
		// Degenerate case
		points << x1
		points << y1
		return
	}

	// Distance of control points from line
	d1 := f32_abs((c1x - x0) * dy - (c1y - y0) * dx) / d
	d2 := f32_abs((c2x - x0) * dy - (c2y - y0) * dx) / d

	if d1 + d2 <= tolerance || depth >= max_flatten_depth {
		points << x1
		points << y1
	} else {
		// Subdivide using de Casteljau
		ax := (x0 + c1x) / 2
		ay := (y0 + c1y) / 2
		bx := (c1x + c2x) / 2
		by := (c1y + c2y) / 2
		cx := (c2x + x1) / 2
		cy := (c2y + y1) / 2
		abx := (ax + bx) / 2
		aby := (ay + by) / 2
		bcx := (bx + cx) / 2
		bcy := (by + cy) / 2
		mx := (abx + bcx) / 2
		my := (aby + bcy) / 2

		flatten_cubic_recursive(x0, y0, ax, ay, abx, aby, mx, my, tolerance, depth + 1, mut
			points)
		flatten_cubic_recursive(mx, my, bcx, bcy, cx, cy, x1, y1, tolerance, depth + 1, mut
			points)
	}
}
