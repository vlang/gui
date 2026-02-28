module svg

import math

// tessellate_polylines converts polylines to triangles using ear clipping with hole support.
pub fn tessellate_polylines(polylines [][]f32) []f32 {
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

// merge_hole connects a hole to the outer contour using a bridge edge.
// This creates a single polygon that can be triangulated with ear clipping.
//
// Algorithm: Bridge Edge Method
// 1. Find rightmost point in hole (most likely to be visible from outer contour)
// 2. Cast ray rightward to find closest intersection with outer contour edges
// 3. Check direct visibility from hole point to outer vertices
// 4. Connect via bridge: outer[0..bridge] + hole + outer[bridge..]
//
// Handles complex polygons with overflow protection (max 1M vertices).
// For polygons exceeding limit, returns outer only (hole is skipped).
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

	// Build merged polygon: outer[0..best_idx] + hole[hole_idx..] + hole\n[0..hole_idx] + outer[best_idx..]
	// Guard against overflow: clamp capacity to reasonable limit (2M vertices = 8MB)
	max_verts := 1000000
	est_cap := outer.len + hole.len + 4
	if est_cap / 2 > max_verts {
		// Polygon too complex, return outer only (skip hole merge)
		return outer.clone()
	}
	mut result := []f32{cap: est_cap}

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
fn ear_clip(polygon_ []f32) []f32 {
	mut n := polygon_.len / 2
	if n < 3 {
		return []f32{}
	}
	// Strip trailing first==last duplicate (closed-path artifact)
	if n > 3 {
		lx := polygon_[(n - 1) * 2]
		ly := polygon_[(n - 1) * 2 + 1]
		fx := polygon_[0]
		fy := polygon_[1]
		if f32_abs(lx - fx) < closed_path_epsilon && f32_abs(ly - fy) < closed_path_epsilon {
			n--
		}
	}
	if n < 3 {
		return []f32{}
	}
	polygon := polygon_[..n * 2]
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
		// Skip vertices that are coordinate-coincident with
		// a triangle vertex (duplicate points from zero-length
		// segments). Exact f32 equality is correct here since
		// duplicates are bitwise identical values.
		if (px == ax && py == ay) || (px == bx && py == by) || (px == cx && py == cy) {
			continue
		}
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

	denom := dot00 * dot11 - dot01 * dot01
	if f32_abs(denom) < 1e-10 {
		return false // degenerate triangle (zero area)
	}
	inv_denom := 1.0 / denom
	u := (dot11 * dot02 - dot01 * dot12) * inv_denom
	v := (dot00 * dot12 - dot01 * dot02) * inv_denom

	return u >= 0 && v >= 0 && (u + v) < 1
}
