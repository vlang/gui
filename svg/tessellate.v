module svg

import math

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
// apply_dasharray splits polylines into dash segments according to the
// SVG stroke-dasharray pattern (alternating dash/gap lengths, cycling).
// Each "on" (dash) segment becomes a separate open polyline.
fn apply_dasharray(polylines [][]f32, dasharray []f32) [][]f32 {
	if dasharray.len == 0 {
		return polylines
	}
	mut result := [][]f32{}
	for poly in polylines {
		if poly.len < 4 {
			continue
		}
		mut dash_idx := 0 // index into dasharray
		mut drawing := true // true = dash (on), false = gap (off)
		mut remaining := dasharray[0] // distance left in current dash/gap
		mut current := []f32{cap: poly.len}
		// Start with the first point
		mut px := poly[0]
		mut py := poly[1]
		if drawing {
			current << px
			current << py
		}
		mut i := 2
		for i < poly.len {
			nx := poly[i]
			ny := poly[i + 1]
			dx := nx - px
			dy := ny - py
			seg_len := math.sqrtf(dx * dx + dy * dy)
			if seg_len < 1e-6 {
				i += 2
				continue
			}
			mut consumed := f32(0)
			for consumed < seg_len - 1e-6 {
				avail := seg_len - consumed
				if remaining <= avail {
					// Transition within this segment
					t := (consumed + remaining) / seg_len
					ix := px + t * dx
					iy := py + t * dy
					if drawing {
						current << ix
						current << iy
						if current.len >= 4 {
							result << current
						}
						current = []f32{cap: poly.len}
					} else {
						current << ix
						current << iy
					}
					consumed += remaining
					drawing = !drawing
					dash_idx = (dash_idx + 1) % dasharray.len
					remaining = dasharray[dash_idx]
				} else {
					// Remaining dash/gap extends beyond segment
					remaining -= avail
					if drawing {
						current << nx
						current << ny
					}
					break
				}
			}
			px = nx
			py = ny
			i += 2
		}
		// Flush any trailing dash
		if drawing && current.len >= 4 {
			result << current
		}
	}
	return result
}

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
							color:        SvgColor{255, 255, 255, 255}
							is_clip_mask: true
							clip_group:   clip_group
							group_id:     path.group_id
						}
					}
				}
			}
		}

		polylines := flatten_path(path, tolerance)
		// Tessellate fill
		has_gradient := path.fill_gradient_id.len > 0
		if path.fill_color.a > 0 || has_gradient {
			raw_tris := tessellate_polylines(polylines)
			if raw_tris.len > 0 {
				if has_gradient {
					if g := vg.gradients[path.fill_gradient_id] {
						grad := if g.object_bounding_box {
							bx0, by0, bx1, by1 := bbox_from_triangles(raw_tris)
							resolve_gradient(g, bx0, by0, bx1, by1)
						} else {
							g
						}
						fill_tris := subdivide_gradient_tris(raw_tris, grad)
						n_verts := fill_tris.len / 2
						mut vcols := []SvgColor{cap: n_verts}
						opacity := path.opacity * path.fill_opacity
						for vi := 0; vi < n_verts; vi++ {
							vx := fill_tris[vi * 2]
							vy := fill_tris[vi * 2 + 1]
							t := project_onto_gradient(vx, vy, grad)
							mut c := interpolate_gradient(grad.stops, t)
							if opacity < 1.0 {
								c = apply_opacity(c, opacity)
							}
							vcols << c
						}
						result << TessellatedPath{
							triangles:     fill_tris
							color:         path.fill_color
							vertex_colors: vcols
							clip_group:    clip_group
							group_id:      path.group_id
						}
					}
				} else {
					result << TessellatedPath{
						triangles:  raw_tris
						color:      path.fill_color
						clip_group: clip_group
						group_id:   path.group_id
					}
				}
			}
		}
		// Tessellate stroke
		has_stroke_gradient := path.stroke_gradient_id.len > 0
		if (path.stroke_color.a > 0 || has_stroke_gradient) && path.stroke_width > 0 {
			stroke_width := path.stroke_width * scale
			stroke_polylines := if path.stroke_dasharray.len > 0 {
				apply_dasharray(polylines, path.stroke_dasharray)
			} else {
				polylines
			}
			raw_stroke := tessellate_stroke(stroke_polylines, stroke_width, path.stroke_cap,
				path.stroke_join)
			if raw_stroke.len > 0 {
				if has_stroke_gradient {
					if g := vg.gradients[path.stroke_gradient_id] {
						grad := if g.object_bounding_box {
							bx0, by0, bx1, by1 := bbox_from_triangles(raw_stroke)
							resolve_gradient(g, bx0, by0, bx1, by1)
						} else {
							g
						}
						s_tris := subdivide_gradient_tris(raw_stroke, grad)
						n_verts := s_tris.len / 2
						mut vcols := []SvgColor{cap: n_verts}
						opacity := path.opacity * path.stroke_opacity
						for vi := 0; vi < n_verts; vi++ {
							vx := s_tris[vi * 2]
							vy := s_tris[vi * 2 + 1]
							t := project_onto_gradient(vx, vy, grad)
							mut c := interpolate_gradient(grad.stops, t)
							if opacity < 1.0 {
								c = apply_opacity(c, opacity)
							}
							vcols << c
						}
						result << TessellatedPath{
							triangles:     s_tris
							color:         path.stroke_color
							vertex_colors: vcols
							clip_group:    clip_group
							group_id:      path.group_id
						}
					}
				} else {
					result << TessellatedPath{
						triangles:  raw_stroke
						color:      path.stroke_color
						clip_group: clip_group
						group_id:   path.group_id
					}
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
