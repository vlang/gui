module svg

import math

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
