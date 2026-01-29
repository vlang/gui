module gui

import math

// PathCmd defines the type of drawing command in a path segment.
pub enum PathCmd as u8 {
	move_to  // 2 floats: x, y
	line_to  // 2 floats: x, y
	quad_to  // 4 floats: cx, cy, x, y
	cubic_to // 6 floats: c1x, c1y, c2x, c2y, x, y
	close    // 0 floats
}

// PathSegment represents a single command in a vector path.
pub struct PathSegment {
pub:
	cmd    PathCmd
	points []f32
}

// VectorPath represents a single filled path with color.
pub struct VectorPath {
pub mut:
	segments   []PathSegment
	fill_color Color
}

// VectorGraphic holds the complete parsed vector graphic (e.g., from SVG).
pub struct VectorGraphic {
pub mut:
	width  f32 // viewBox width
	height f32 // viewBox height
	paths  []VectorPath
}

// TessellatedPath holds triangulated geometry ready for rendering.
pub struct TessellatedPath {
pub:
	triangles []f32 // x,y pairs forming triangles
	color     Color
}

// get_triangles tessellates all paths in the graphic at the given scale.
pub fn (vg &VectorGraphic) get_triangles(scale f32) []TessellatedPath {
	tolerance := 0.5 / scale // adaptive tolerance based on scale
	mut result := []TessellatedPath{cap: vg.paths.len}
	for path in vg.paths {
		polylines := flatten_path(path, tolerance)
		triangles := tessellate_polylines(polylines)
		if triangles.len > 0 {
			result << TessellatedPath{
				triangles: triangles
				color:     path.fill_color
			}
		}
	}
	return result
}

// flatten_path converts bezier curves to polylines with given tolerance.
fn flatten_path(path VectorPath, tolerance f32) [][]f32 {
	mut polylines := [][]f32{}
	mut current := []f32{}
	mut x := f32(0)
	mut y := f32(0)
	mut start_x := f32(0)
	mut start_y := f32(0)

	for seg in path.segments {
		match seg.cmd {
			.move_to {
				if current.len >= 4 {
					polylines << current
				}
				current = []f32{}
				x = seg.points[0]
				y = seg.points[1]
				start_x = x
				start_y = y
				current << x
				current << y
			}
			.line_to {
				x = seg.points[0]
				y = seg.points[1]
				current << x
				current << y
			}
			.quad_to {
				cx := seg.points[0]
				cy := seg.points[1]
				ex := seg.points[2]
				ey := seg.points[3]
				flatten_quad(x, y, cx, cy, ex, ey, tolerance, mut current)
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
				flatten_cubic(x, y, c1x, c1y, c2x, c2y, ex, ey, tolerance, mut current)
				x = ex
				y = ey
			}
			.close {
				if current.len >= 2 {
					// close path by connecting to start
					if x != start_x || y != start_y {
						current << start_x
						current << start_y
					}
				}
				if current.len >= 6 {
					polylines << current
				}
				current = []f32{}
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

// flatten_quad flattens a quadratic bezier curve using recursive subdivision.
fn flatten_quad(x0 f32, y0 f32, cx f32, cy f32, x1 f32, y1 f32, tolerance f32, mut points []f32) {
	// Calculate flatness using distance from control point to midpoint of line
	mx := (x0 + x1) / 2
	my := (y0 + y1) / 2
	dx := cx - mx
	dy := cy - my
	d := math.sqrtf(dx * dx + dy * dy)

	if d <= tolerance {
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

		flatten_quad(x0, y0, ax, ay, abx, aby, tolerance, mut points)
		flatten_quad(abx, aby, bx, by, x1, y1, tolerance, mut points)
	}
}

// flatten_cubic flattens a cubic bezier curve using recursive subdivision.
fn flatten_cubic(x0 f32, y0 f32, c1x f32, c1y f32, c2x f32, c2y f32, x1 f32, y1 f32, tolerance f32, mut points []f32) {
	// Check flatness using distance of control points from line
	dx := x1 - x0
	dy := y1 - y0
	d := math.sqrtf(dx * dx + dy * dy)

	if d < 0.0001 {
		// Degenerate case
		points << x1
		points << y1
		return
	}

	// Distance of control points from line
	d1 := f32_abs((c1x - x0) * dy - (c1y - y0) * dx) / d
	d2 := f32_abs((c2x - x0) * dy - (c2y - y0) * dx) / d

	if d1 + d2 <= tolerance {
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

		flatten_cubic(x0, y0, ax, ay, abx, aby, mx, my, tolerance, mut points)
		flatten_cubic(mx, my, bcx, bcy, cx, cy, x1, y1, tolerance, mut points)
	}
}

// tessellate_polylines converts polylines to triangles using ear clipping with hole support.
fn tessellate_polylines(polylines [][]f32) []f32 {
	if polylines.len == 0 {
		return []f32{}
	}
	if polylines.len == 1 {
		// Single contour, no holes
		if polylines[0].len >= 6 {
			return ear_clip(polylines[0])
		}
		return []f32{}
	}

	// Multiple contours - need to handle holes
	// Compute areas and classify as outer or hole
	mut contours := []Contour{cap: polylines.len}
	for poly in polylines {
		if poly.len >= 6 {
			area := polygon_area(poly)
			contours << Contour{
				points:  poly
				area:    area
				is_hole: false // will be determined later
			}
		}
	}

	if contours.len == 0 {
		return []f32{}
	}

	// Sort by absolute area descending (largest first = outer contour)
	contours.sort(a.abs_area() > b.abs_area())

	// First contour is outer, rest are potential holes
	mut outer := contours[0].points.clone()
	// Ensure outer is counter-clockwise (positive area)
	if contours[0].area < 0 {
		outer = reverse_polygon(outer)
	}

	// Process holes
	for i := 1; i < contours.len; i++ {
		mut hole := contours[i].points.clone()
		// Ensure hole is clockwise (negative area when outer is CCW)
		if polygon_area(hole) > 0 {
			hole = reverse_polygon(hole)
		}
		// Merge hole into outer contour
		outer = merge_hole(outer, hole)
	}

	return ear_clip(outer)
}

// Contour represents a polygon contour with its computed area.
struct Contour {
	points []f32
	area   f32
mut:
	is_hole bool
}

// abs_area returns the absolute value of the contour's signed area.
fn (c &Contour) abs_area() f32 {
	return if c.area < 0 { -c.area } else { c.area }
}

// reverse_polygon reverses the winding order of a polygon.
fn reverse_polygon(poly []f32) []f32 {
	n := poly.len / 2
	mut result := []f32{cap: poly.len}
	for i := n - 1; i >= 0; i-- {
		result << poly[i * 2]
		result << poly[i * 2 + 1]
	}
	return result
}

// merge_hole connects a hole to the outer contour using a bridge.
// This creates a single polygon that can be triangulated with ear clipping.
fn merge_hole(outer []f32, hole []f32) []f32 {
	// Find the rightmost point in the hole
	mut hole_idx := 0
	mut max_x := hole[0]
	n_hole := hole.len / 2
	for i := 1; i < n_hole; i++ {
		if hole[i * 2] > max_x {
			max_x = hole[i * 2]
			hole_idx = i
		}
	}
	hole_x := hole[hole_idx * 2]
	hole_y := hole[hole_idx * 2 + 1]

	// Find the closest visible point on the outer contour
	// Cast a ray to the right from hole point and find intersection
	n_outer := outer.len / 2
	mut best_idx := 0
	mut best_dist := f32(1e30)

	for i := 0; i < n_outer; i++ {
		x1 := outer[i * 2]
		y1 := outer[i * 2 + 1]
		j := (i + 1) % n_outer
		x2 := outer[j * 2]
		y2 := outer[j * 2 + 1]

		// Check if edge crosses the horizontal ray from hole point
		if (y1 <= hole_y && y2 > hole_y) || (y2 <= hole_y && y1 > hole_y) {
			// Compute x intersection
			t := (hole_y - y1) / (y2 - y1)
			ix := x1 + t * (x2 - x1)
			if ix >= hole_x {
				dist := ix - hole_x
				if dist < best_dist {
					best_dist = dist
					// Use the vertex that's more suitable for bridge
					if f32_abs(y1 - hole_y) < f32_abs(y2 - hole_y) {
						best_idx = i
					} else {
						best_idx = j
					}
				}
			}
		}
	}

	// Also check direct vertex visibility (for convex cases)
	for i := 0; i < n_outer; i++ {
		x := outer[i * 2]
		y := outer[i * 2 + 1]
		if x >= hole_x {
			dx := x - hole_x
			dy := y - hole_y
			dist := dx * dx + dy * dy
			if dist < best_dist * best_dist {
				// Check if this vertex is visible from hole point
				if is_vertex_visible(outer, i, hole_x, hole_y) {
					best_dist = math.sqrtf(dist)
					best_idx = i
				}
			}
		}
	}

	// Build merged polygon: outer[0..best_idx] + hole[hole_idx..] + hole[0..hole_idx] + outer[best_idx..]
	mut result := []f32{cap: outer.len + hole.len + 4}

	// Add outer vertices up to and including bridge point
	for i := 0; i <= best_idx; i++ {
		result << outer[i * 2]
		result << outer[i * 2 + 1]
	}

	// Add hole vertices starting from hole bridge point
	for i := 0; i < n_hole; i++ {
		idx := (hole_idx + i) % n_hole
		result << hole[idx * 2]
		result << hole[idx * 2 + 1]
	}

	// Close the hole back to bridge point
	result << hole[hole_idx * 2]
	result << hole[hole_idx * 2 + 1]

	// Continue with outer vertices after bridge point
	for i := best_idx; i < n_outer; i++ {
		result << outer[i * 2]
		result << outer[i * 2 + 1]
	}

	return result
}

// is_vertex_visible checks if outer vertex at idx is visible from point (px, py)
fn is_vertex_visible(outer []f32, idx int, px f32, py f32) bool {
	vx := outer[idx * 2]
	vy := outer[idx * 2 + 1]
	n := outer.len / 2

	// Check if line segment from (px,py) to (vx,vy) intersects any edge
	for i := 0; i < n; i++ {
		j := (i + 1) % n
		// Skip edges adjacent to the target vertex
		if i == idx || j == idx {
			continue
		}
		x1 := outer[i * 2]
		y1 := outer[i * 2 + 1]
		x2 := outer[j * 2]
		y2 := outer[j * 2 + 1]

		if segments_intersect(px, py, vx, vy, x1, y1, x2, y2) {
			return false
		}
	}
	return true
}

// segments_intersect checks if line segment (ax,ay)-(bx,by) intersects (cx,cy)-(dx,dy)
fn segments_intersect(ax f32, ay f32, bx f32, by f32, cx f32, cy f32, dx f32, dy f32) bool {
	d1 := cross_product_sign(cx, cy, dx, dy, ax, ay)
	d2 := cross_product_sign(cx, cy, dx, dy, bx, by)
	d3 := cross_product_sign(ax, ay, bx, by, cx, cy)
	d4 := cross_product_sign(ax, ay, bx, by, dx, dy)

	if ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) && ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0)) {
		return true
	}
	return false
}

// cross_product_sign returns the sign of cross product (b-a) x (c-a)
fn cross_product_sign(ax f32, ay f32, bx f32, by f32, cx f32, cy f32) f32 {
	return (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)
}

// ear_clip implements the ear clipping algorithm for polygon triangulation.
// Input: flat array of x,y coordinates (polygon must be simple, non-self-intersecting)
// Output: flat array of x,y coordinates forming triangles
fn ear_clip(polygon []f32) []f32 {
	n := polygon.len / 2
	if n < 3 {
		return []f32{}
	}
	if n == 3 {
		return polygon.clone()
	}

	// Build vertex index list
	mut indices := []int{cap: n}
	// Determine winding order
	if polygon_area(polygon) > 0 {
		// Counter-clockwise, reverse for clockwise
		for i := n - 1; i >= 0; i-- {
			indices << i
		}
	} else {
		for i := 0; i < n; i++ {
			indices << i
		}
	}

	mut triangles := []f32{cap: (n - 2) * 6}
	mut count := 2 * n
	mut v := n - 1

	for indices.len > 2 {
		if count <= 0 {
			break // failed to find ear
		}
		count--

		// Get three consecutive vertices
		mut u := v
		if u >= indices.len {
			u = 0
		}
		v = u + 1
		if v >= indices.len {
			v = 0
		}
		mut w := v + 1
		if w >= indices.len {
			w = 0
		}

		if is_ear(polygon, indices, u, v, w) {
			// Output triangle
			a := indices[u]
			b := indices[v]
			c := indices[w]

			triangles << polygon[a * 2]
			triangles << polygon[a * 2 + 1]
			triangles << polygon[b * 2]
			triangles << polygon[b * 2 + 1]
			triangles << polygon[c * 2]
			triangles << polygon[c * 2 + 1]

			// Remove vertex v
			indices.delete(v)
			count = 2 * indices.len
		}
	}

	return triangles
}

// polygon_area calculates signed area of polygon (positive = CCW, negative = CW)
fn polygon_area(polygon []f32) f32 {
	n := polygon.len / 2
	mut area := f32(0)
	mut j := n - 1
	for i := 0; i < n; i++ {
		area += (polygon[j * 2] + polygon[i * 2]) * (polygon[j * 2 + 1] - polygon[i * 2 + 1])
		j = i
	}
	return area / 2
}

// is_ear checks if vertex v forms a valid ear (convex and no other vertices inside)
fn is_ear(polygon []f32, indices []int, u int, v int, w int) bool {
	ax := polygon[indices[u] * 2]
	ay := polygon[indices[u] * 2 + 1]
	bx := polygon[indices[v] * 2]
	by := polygon[indices[v] * 2 + 1]
	cx := polygon[indices[w] * 2]
	cy := polygon[indices[w] * 2 + 1]

	// Check if triangle is convex (cross product > 0)
	cross := (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)
	if cross <= 0 {
		return false
	}

	// Check if any other vertex is inside the triangle
	for i := 0; i < indices.len; i++ {
		if i == u || i == v || i == w {
			continue
		}
		px := polygon[indices[i] * 2]
		py := polygon[indices[i] * 2 + 1]
		if point_in_triangle(px, py, ax, ay, bx, by, cx, cy) {
			return false
		}
	}

	return true
}

// point_in_triangle checks if point p is inside triangle abc
fn point_in_triangle(px f32, py f32, ax f32, ay f32, bx f32, by f32, cx f32, cy f32) bool {
	// Barycentric coordinate check
	v0x := cx - ax
	v0y := cy - ay
	v1x := bx - ax
	v1y := by - ay
	v2x := px - ax
	v2y := py - ay

	dot00 := v0x * v0x + v0y * v0y
	dot01 := v0x * v1x + v0y * v1y
	dot02 := v0x * v2x + v0y * v2y
	dot11 := v1x * v1x + v1y * v1y
	dot12 := v1x * v2x + v1y * v2y

	inv_denom := 1.0 / (dot00 * dot11 - dot01 * dot01)
	u := (dot11 * dot02 - dot01 * dot12) * inv_denom
	v := (dot00 * dot12 - dot01 * dot02) * inv_denom

	return u >= 0 && v >= 0 && (u + v) < 1
}

// arc_to_cubic converts an SVG arc to cubic bezier curves.
// Returns array of cubic bezier control points.
pub fn arc_to_cubic(x1 f32, y1 f32, rx f32, ry f32, phi f32, large_arc bool, sweep bool, x2 f32, y2 f32) []PathSegment {
	if rx == 0 || ry == 0 {
		return [PathSegment{
			cmd:    .line_to
			points: [x2, y2]
		}]
	}

	mut rx_ := f32_abs(rx)
	mut ry_ := f32_abs(ry)
	phi_rad := phi * math.pi / 180.0

	cos_phi := math.cosf(phi_rad)
	sin_phi := math.sinf(phi_rad)

	// Step 1: Compute (x1', y1')
	dx := (x1 - x2) / 2
	dy := (y1 - y2) / 2
	x1p := cos_phi * dx + sin_phi * dy
	y1p := -sin_phi * dx + cos_phi * dy

	// Correct radii if needed
	lambda := (x1p * x1p) / (rx_ * rx_) + (y1p * y1p) / (ry_ * ry_)
	if lambda > 1 {
		sqrt_lambda := math.sqrtf(lambda)
		rx_ *= sqrt_lambda
		ry_ *= sqrt_lambda
	}

	// Step 2: Compute (cx', cy')
	rx2 := rx_ * rx_
	ry2 := ry_ * ry_
	x1p2 := x1p * x1p
	y1p2 := y1p * y1p

	mut sq := (rx2 * ry2 - rx2 * y1p2 - ry2 * x1p2) / (rx2 * y1p2 + ry2 * x1p2)
	if sq < 0 {
		sq = 0
	}
	mut coef := math.sqrtf(sq)
	if large_arc == sweep {
		coef = -coef
	}

	cxp := coef * rx_ * y1p / ry_
	cyp := -coef * ry_ * x1p / rx_

	// Step 3: Compute (cx, cy) from (cx', cy')
	cx := cos_phi * cxp - sin_phi * cyp + (x1 + x2) / 2
	cy := sin_phi * cxp + cos_phi * cyp + (y1 + y2) / 2

	// Step 4: Compute theta1 and dtheta
	theta1 := vector_angle(1, 0, (x1p - cxp) / rx_, (y1p - cyp) / ry_)
	mut dtheta := vector_angle((x1p - cxp) / rx_, (y1p - cyp) / ry_, (-x1p - cxp) / rx_,
		(-y1p - cyp) / ry_)

	if !sweep && dtheta > 0 {
		dtheta -= 2 * math.pi
	} else if sweep && dtheta < 0 {
		dtheta += 2 * math.pi
	}

	// Split arc into segments of at most 90 degrees
	n_segs := int(math.ceil(f32_abs(dtheta) / (math.pi / 2)))
	d_theta := dtheta / f32(n_segs)

	mut segments := []PathSegment{cap: n_segs}
	mut theta := theta1

	for _ in 0 .. n_segs {
		seg := arc_segment_to_cubic(cx, cy, rx_, ry_, phi_rad, theta, d_theta)
		segments << seg
		theta += d_theta
	}

	return segments
}

// vector_angle computes the angle between two vectors
fn vector_angle(ux f32, uy f32, vx f32, vy f32) f32 {
	n := math.sqrtf(ux * ux + uy * uy) * math.sqrtf(vx * vx + vy * vy)
	if n == 0 {
		return 0
	}
	mut c := (ux * vx + uy * vy) / n
	if c < -1 {
		c = -1
	}
	if c > 1 {
		c = 1
	}
	angle := f32(math.acos(c))
	if ux * vy - uy * vx < 0 {
		return -angle
	}
	return angle
}

// arc_segment_to_cubic converts an arc segment to a cubic bezier
fn arc_segment_to_cubic(cx f32, cy f32, rx f32, ry f32, phi f32, theta f32, dtheta f32) PathSegment {
	t := math.tanf(dtheta / 4) * 4 / 3

	cos_theta := math.cosf(theta)
	sin_theta := math.sinf(theta)
	cos_theta2 := math.cosf(theta + dtheta)
	sin_theta2 := math.sinf(theta + dtheta)

	cos_phi := math.cosf(phi)
	sin_phi := math.sinf(phi)

	// Start point derivative
	x1 := rx * cos_theta
	y1 := ry * sin_theta
	dx1 := -rx * sin_theta * t
	dy1 := ry * cos_theta * t

	// End point and derivative
	x2 := rx * cos_theta2
	y2 := ry * sin_theta2
	dx2 := -rx * sin_theta2 * t
	dy2 := ry * cos_theta2 * t

	// Transform to original coordinate system
	p1x := cos_phi * (x1 + dx1) - sin_phi * (y1 + dy1) + cx
	p1y := sin_phi * (x1 + dx1) + cos_phi * (y1 + dy1) + cy
	p2x := cos_phi * (x2 - dx2) - sin_phi * (y2 - dy2) + cx
	p2y := sin_phi * (x2 - dx2) + cos_phi * (y2 - dy2) + cy
	ex := cos_phi * x2 - sin_phi * y2 + cx
	ey := sin_phi * x2 + cos_phi * y2 + cy

	return PathSegment{
		cmd:    .cubic_to
		points: [p1x, p1y, p2x, p2y, ex, ey]
	}
}
