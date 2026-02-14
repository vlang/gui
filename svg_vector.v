module gui

import math

// Tessellation and stroke constants
const stroke_cross_tolerance = f32(0.001) // tolerance for detecting straight joins
const stroke_miter_limit = f32(4.0) // SVG default miter limit multiplier
const stroke_round_cap_segments = 8 // segments for round cap semicircle
const curve_degenerate_threshold = f32(0.0001) // threshold for degenerate curves
const closed_path_epsilon = f32(0.0001) // tolerance for closed path detection

// color_inherit is a sentinel color indicating the value should be inherited.
const color_inherit = Color{255, 0, 255, 1}

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

// StrokeCap defines line cap styles.
pub enum StrokeCap as u8 {
	butt
	round
	square
	inherit // sentinel: use inherited value
}

// StrokeJoin defines line join styles.
pub enum StrokeJoin as u8 {
	miter
	round
	bevel
	inherit // sentinel: use inherited value
}

// SvgGradientStop holds one color stop in a linear gradient.
pub struct SvgGradientStop {
pub:
	offset f32
	color  Color
}

// SvgGradientDef holds a parsed <linearGradient> definition.
pub struct SvgGradientDef {
pub:
	x1    f32
	y1    f32
	x2    f32
	y2    f32
	stops []SvgGradientStop
}

// VectorPath represents a single filled path with color.
pub struct VectorPath {
pub mut:
	segments         []PathSegment
	fill_color       Color      = color_inherit
	transform        [6]f32     = [f32(1), 0, 0, 1, 0, 0]! // identity: [a,b,c,d,e,f]
	stroke_color     Color      = color_inherit
	stroke_width     f32        = -1.0 // negative = inherit from parent
	stroke_cap       StrokeCap  = .inherit
	stroke_join      StrokeJoin = .inherit
	clip_path_id     string // references clip_paths key, empty = none
	fill_gradient_id string // references gradients key, empty = flat fill
	opacity          f32 = 1.0
	fill_opacity     f32 = 1.0
	stroke_opacity   f32 = 1.0
}

// VectorGraphic holds the complete parsed vector graphic (e.g., from SVG).
pub struct VectorGraphic {
pub mut:
	width      f32 // viewBox width
	height     f32 // viewBox height
	view_box_x f32 // viewBox min-x offset
	view_box_y f32 // viewBox min-y offset
	paths      []VectorPath
	clip_paths map[string][]VectorPath   // id -> clip geometry
	gradients  map[string]SvgGradientDef // id -> gradient def
}

// TessellatedPath holds triangulated geometry ready for rendering.
pub struct TessellatedPath {
pub:
	triangles     []f32 // x,y pairs forming triangles
	color         Color
	vertex_colors []Color // per-vertex colors (len = triangles.len/2); empty = flat color
	is_clip_mask  bool    // true = stencil-write geometry
	clip_group    int     // groups clip mask + clipped content (0 = none)
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

// get_triangles tessellates all paths in the graphic into GPU-ready triangle geometry.
//
// This is the core rendering pipeline that converts vector paths into triangles:
//
// 1. **Curve Flattening**: Bezier curves (quadratic and cubic) are recursively subdivided
//    into line segments until they're within `tolerance` of the true curve. The tolerance
//    is adaptive: `0.5 / scale`, so higher scales produce more segments for smooth curves.
//
// 2. **Transform Application**: Each path's affine transform matrix is applied to all
//    coordinates during flattening, baking transforms into the geometry.
//
// 3. **Fill Tessellation**: Closed polylines are triangulated using the ear clipping
//    algorithm. Holes are handled by merging them into the outer contour via bridge edges.
//
// 4. **Stroke Tessellation**: Polylines are expanded into quads perpendicular to the path.
//    Line joins (miter, bevel, round) connect segments at vertices. Line caps (butt,
//    round, square) close open path endpoints. Stroke width is scaled by `scale`.
//
// Parameters:
//   - `scale`: Display scale factor. Affects curve flattening tolerance (higher = smoother)
//     and stroke width. Typically `display_width / viewBox_width`.
//
// Returns:
//   Array of `TessellatedPath`, each containing:
//   - `triangles`: Flat array of f32 x,y pairs forming triangles (every 6 values = 1 triangle)
//   - `color`: Fill or stroke color for this geometry
//
// A single VectorPath may produce two TessellatedPaths: one for fill, one for stroke.
// Paths with transparent fill or stroke (alpha = 0) skip that tessellation.
//
// Example:
// get_triangles tessellates all paths in the vector graphic into GPU-ready triangles.
// Returns triangles in **viewBox coordinate space**, not screen pixels.
// Caller is responsible for transforming to screen coordinates.
//
// The `scale` parameter affects:
// - Stroke width: multiplied by scale to maintain visual thickness at display size
// - Curve flattening tolerance: adjusted for perceptual quality at target scale
// - Does NOT affect output coordinates (those remain in viewBox space)
//
// Example: For 100x100 viewBox rendered at 500x500 pixels (scale=5.0):
// - Output triangles still use 0-100 coordinate range
// - 2px stroke becomes 10px (2 * 5.0) in viewBox units
// - Curves flattened to ~0.3px tolerance for smooth appearance
pub fn (vg &VectorGraphic) get_triangles(scale f32) []TessellatedPath {
	mut result := []TessellatedPath{cap: vg.paths.len * 2}

	// Adaptive tolerance: smaller value = more segments = smoother curves
	// Use 0.25px visual tolerance scaled by matrix
	// Minimum floor of 0.1 prevents infinite recursion on degenerate info
	base_tolerance := 0.5 / scale
	tolerance := if base_tolerance > 0.15 { base_tolerance } else { f32(0.15) }

	mut clip_group_counter := 0

	for path in vg.paths {
		// Determine clip group for this path
		mut clip_group := 0
		if path.clip_path_id.len > 0 {
			if clip_geom := vg.clip_paths[path.clip_path_id] {
				clip_group_counter++
				clip_group = clip_group_counter
				// Tessellate clip mask geometry
				for cp in clip_geom {
					cp_polylines := flatten_path(cp, tolerance)
					clip_tris := tessellate_polylines(cp_polylines)
					if clip_tris.len > 0 {
						result << TessellatedPath{
							triangles:    clip_tris
							color:        Color{255, 255, 255, 255}
							is_clip_mask: true
							clip_group:   clip_group
						}
					}
				}
			}
		}

		polylines := flatten_path(path, tolerance)
		// Tessellate fill
		has_gradient := path.fill_gradient_id.len > 0
		if path.fill_color.a > 0 || has_gradient {
			triangles := tessellate_polylines(polylines)
			if triangles.len > 0 {
				mut vcols := []Color{}
				if has_gradient {
					if grad := vg.gradients[path.fill_gradient_id] {
						n_verts := triangles.len / 2
						vcols = []Color{cap: n_verts}
						opacity := path.opacity * path.fill_opacity
						for vi := 0; vi < n_verts; vi++ {
							vx := triangles[vi * 2]
							vy := triangles[vi * 2 + 1]
							t := project_onto_gradient(vx, vy, grad)
							mut c := interpolate_gradient(grad.stops, t)
							if opacity < 1.0 {
								c = apply_opacity(c, opacity)
							}
							vcols << c
						}
					}
				}
				result << TessellatedPath{
					triangles:     triangles
					color:         path.fill_color
					vertex_colors: vcols
					clip_group:    clip_group
				}
			}
		}
		// Tessellate stroke
		if path.stroke_color.a > 0 && path.stroke_width > 0 {
			stroke_width := path.stroke_width * scale
			stroke_tris := tessellate_stroke(polylines, stroke_width, path.stroke_cap,
				path.stroke_join)
			if stroke_tris.len > 0 {
				result << TessellatedPath{
					triangles:  stroke_tris
					color:      path.stroke_color
					clip_group: clip_group
				}
			}
		}
	}
	return result
}

// apply_transform transforms a point (x, y) by affine matrix [a,b,c,d,e,f].
// Result: (a*x + c*y + e, b*x + d*y + f)
@[inline]
fn apply_transform(x f32, y f32, m [6]f32) (f32, f32) {
	return m[0] * x + m[2] * y + m[4], m[1] * x + m[3] * y + m[5]
}

// is_identity_transform checks if a transform is the identity matrix.
@[inline]
fn is_identity_transform(m [6]f32) bool {
	return m[0] == 1 && m[1] == 0 && m[2] == 0 && m[3] == 1 && m[4] == 0 && m[5] == 0
}

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
					current << tx
					current << ty
				} else {
					current << x
					current << y
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

// tessellate_stroke converts polylines to stroke triangles.
fn tessellate_stroke(polylines [][]f32, width f32, cap StrokeCap, join StrokeJoin) []f32 {
	mut result := []f32{}
	half_w := width / 2

	for poly in polylines {
		// Validate: poly.len must be even and >= 4 for at least 2 points
		if poly.len < 4 || poly.len % 2 != 0 {
			continue
		}
		n := poly.len / 2
		if n < 2 {
			continue
		}

		// Check if path is closed (use epsilon for float comparison)
		dx_close := poly[0] - poly[(n - 1) * 2]
		dy_close := poly[1] - poly[(n - 1) * 2 + 1]
		is_closed := n > 2 && f32_abs(dx_close) < closed_path_epsilon
			&& f32_abs(dy_close) < closed_path_epsilon
		point_count := if is_closed { n - 1 } else { n }

		if point_count < 2 {
			continue
		}

		// Build normals for each segment
		mut normals := []f32{cap: point_count * 2}
		for i := 0; i < point_count - 1; i++ {
			dx := poly[(i + 1) * 2] - poly[i * 2]
			dy := poly[(i + 1) * 2 + 1] - poly[i * 2 + 1]
			len := math.sqrtf(dx * dx + dy * dy)
			if len > 0 {
				normals << -dy / len
				normals << dx / len
			} else {
				normals << 0
				normals << 1
			}
		}
		// For closed paths, last segment connects back to start
		if is_closed {
			dx := poly[0] - poly[(point_count - 1) * 2]
			dy := poly[1] - poly[(point_count - 1) * 2 + 1]
			len := math.sqrtf(dx * dx + dy * dy)
			if len > 0 {
				normals << -dy / len
				normals << dx / len
			} else {
				normals << 0
				normals << 1
			}
		}

		// Generate stroke quads for each segment
		for i := 0; i < point_count - 1; i++ {
			x0 := poly[i * 2]
			y0 := poly[i * 2 + 1]
			x1 := poly[(i + 1) * 2]
			y1 := poly[(i + 1) * 2 + 1]
			nx := normals[i * 2]
			ny := normals[i * 2 + 1]

			// Quad vertices
			ax := x0 + nx * half_w
			ay := y0 + ny * half_w
			bx := x0 - nx * half_w
			by := y0 - ny * half_w
			cx := x1 - nx * half_w
			cy := y1 - ny * half_w
			dx := x1 + nx * half_w
			dy := y1 + ny * half_w

			// Two triangles for the quad
			result << [ax, ay, bx, by, cx, cy, ax, ay, cx, cy, dx, dy]
		}

		// Line joins at interior vertices
		num_normals := normals.len / 2
		if is_closed {
			// For closed paths, join at all vertices
			for i := 0; i < point_count; i++ {
				prev_norm := if i == 0 { num_normals - 1 } else { i - 1 }
				next_norm := i
				if next_norm < num_normals && prev_norm < num_normals {
					add_line_join(poly[i * 2], poly[i * 2 + 1], normals[prev_norm * 2],
						normals[prev_norm * 2 + 1], normals[next_norm * 2], normals[next_norm * 2 +
						1], half_w, join, mut result)
				}
			}
		} else {
			// For open paths, join at interior vertices only (skip first and last)
			for i := 1; i < point_count - 1; i++ {
				if i < num_normals {
					add_line_join(poly[i * 2], poly[i * 2 + 1], normals[(i - 1) * 2],
						normals[(i - 1) * 2 + 1], normals[i * 2], normals[i * 2 + 1],
						half_w, join, mut result)
				}
			}
		}

		// Line caps (only for open paths)
		if !is_closed && normals.len >= 2 {
			// Start cap
			add_line_cap(poly[0], poly[1], -normals[0], -normals[1], normals[0], normals[1],
				half_w, cap, mut result)
			// End cap
			last_idx := (point_count - 1) * 2
			last_norm_idx := (normals.len / 2 - 1) * 2
			add_line_cap(poly[last_idx], poly[last_idx + 1], normals[last_norm_idx], normals[
				last_norm_idx + 1], -normals[last_norm_idx], -normals[last_norm_idx + 1],
				half_w, cap, mut result)
		}
	}

	return result
}

// add_line_join adds triangles for a line join at point (x, y).
fn add_line_join(x f32, y f32, n1x f32, n1y f32, n2x f32, n2y f32, half_w f32, join StrokeJoin, mut result []f32) {
	// Compute cross product to determine turn direction
	cross := n1x * n2y - n1y * n2x

	if f32_abs(cross) < stroke_cross_tolerance {
		// Nearly straight, no join needed
		return
	}

	// Miter calculation
	// The miter point is where the offset lines intersect
	dot := n1x * n2x + n1y * n2y
	miter_len := half_w / math.sqrtf((1 + dot) / 2)
	miter_limit := stroke_miter_limit * half_w

	// Average normal direction for miter
	mx := n1x + n2x
	my := n1y + n2y
	mlen := math.sqrtf(mx * mx + my * my)
	if mlen > 0 {
		mx_norm := mx / mlen
		my_norm := my / mlen

		if join == .miter && miter_len <= miter_limit {
			// Miter join
			if cross > 0 {
				// Left turn - join on right side
				result << [x, y, x - n1x * half_w, y - n1y * half_w, x - mx_norm * miter_len,
					y - my_norm * miter_len]
				result << [x, y, x - mx_norm * miter_len, y - my_norm * miter_len, x - n2x * half_w,
					y - n2y * half_w]
			} else {
				// Right turn - join on left side
				result << [x, y, x + mx_norm * miter_len, y + my_norm * miter_len, x + n1x * half_w,
					y + n1y * half_w]
				result << [x, y, x + n2x * half_w, y + n2y * half_w, x + mx_norm * miter_len,
					y + my_norm * miter_len]
			}
		} else if join == .round {
			// Round join - approximate with arc
			add_round_join(x, y, n1x, n1y, n2x, n2y, half_w, cross > 0, mut result)
		} else {
			// Bevel join (or miter that exceeds limit)
			if cross > 0 {
				result << [x, y, x - n1x * half_w, y - n1y * half_w, x - n2x * half_w,
					y - n2y * half_w]
			} else {
				result << [x, y, x + n2x * half_w, y + n2y * half_w, x + n1x * half_w,
					y + n1y * half_w]
			}
		}
	}
}

// add_round_join adds triangles for a round join.
fn add_round_join(x f32, y f32, n1x f32, n1y f32, n2x f32, n2y f32, half_w f32, left_turn bool, mut result []f32) {
	// Calculate angle between normals
	angle1 := f32(math.atan2(n1y, n1x))
	mut angle2 := f32(math.atan2(n2y, n2x))

	if left_turn {
		if angle2 > angle1 {
			angle2 -= 2 * math.pi
		}
	} else {
		if angle2 < angle1 {
			angle2 += 2 * math.pi
		}
	}

	// Number of segments based on angle
	angle_diff := f32_abs(angle2 - angle1)
	segments := int(math.ceil(angle_diff / (math.pi / 4))) + 1

	if segments < 2 {
		return
	}

	step := (angle2 - angle1) / f32(segments)
	mut prev_x := x + math.cosf(angle1) * half_w * (if left_turn { -1 } else { 1 })
	mut prev_y := y + math.sinf(angle1) * half_w * (if left_turn { -1 } else { 1 })

	for i := 1; i <= segments; i++ {
		angle := angle1 + step * f32(i)
		curr_x := x + math.cosf(angle) * half_w * (if left_turn { -1 } else { 1 })
		curr_y := y + math.sinf(angle) * half_w * (if left_turn { -1 } else { 1 })

		if left_turn {
			result << [x, y, prev_x, prev_y, curr_x, curr_y]
		} else {
			result << [x, y, curr_x, curr_y, prev_x, prev_y]
		}

		prev_x = curr_x
		prev_y = curr_y
	}
}

// add_line_cap adds triangles for a line cap.
fn add_line_cap(x f32, y f32, dx f32, dy f32, nx f32, ny f32, half_w f32, cap StrokeCap, mut result []f32) {
	if cap == .butt {
		// Butt cap - nothing to add
		return
	}

	// Direction along the line (outward from endpoint)
	len := math.sqrtf(dx * dx + dy * dy)
	if len == 0 {
		return
	}
	dir_x := dx / len
	dir_y := dy / len

	if cap == .square {
		// Square cap - extend by half_w
		ex := x + dir_x * half_w
		ey := y + dir_y * half_w
		// Quad for the cap extension
		ax := x + nx * half_w
		ay := y + ny * half_w
		bx := x - nx * half_w
		by := y - ny * half_w
		cx := ex - nx * half_w
		cy := ey - ny * half_w
		dx2 := ex + nx * half_w
		dy2 := ey + ny * half_w

		result << [ax, ay, bx, by, cx, cy, ax, ay, cx, cy, dx2, dy2]
	} else if cap == .round {
		// Round cap - semicircle
		center_x := x
		center_y := y
		segments := stroke_round_cap_segments
		start_angle := f32(math.atan2(ny, nx))

		mut prev_x := center_x + math.cosf(start_angle) * half_w
		mut prev_y := center_y + math.sinf(start_angle) * half_w

		for i := 1; i <= segments; i++ {
			angle := start_angle + math.pi * f32(i) / f32(segments)
			curr_x := center_x + math.cosf(angle) * half_w
			curr_y := center_y + math.sinf(angle) * half_w

			result << [center_x, center_y, prev_x, prev_y, curr_x, curr_y]

			prev_x = curr_x
			prev_y = curr_y
		}
	}
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

	denom := dot00 * dot11 - dot01 * dot01
	if f32_abs(denom) < 1e-10 {
		return false // degenerate triangle (zero area)
	}
	inv_denom := 1.0 / denom
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
