module gui

import math

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
