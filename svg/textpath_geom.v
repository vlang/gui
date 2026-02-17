module svg

import math

// flatten_defs_path parses a path d attribute and flattens
// to a polyline with coordinates scaled by scale.
pub fn flatten_defs_path(d string, scale f32) []f32 {
	segments := parse_path_d(d)
	if segments.len == 0 {
		return []f32{}
	}
	path := VectorPath{
		segments:  segments
		transform: [scale, f32(0), 0, scale, 0, 0]!
	}
	tolerance := 0.5 / scale
	tol := if tolerance > 0.15 { tolerance } else { f32(0.15) }
	polylines := flatten_path(path, tol)
	if polylines.len == 0 {
		return []f32{}
	}
	return polylines[0]
}

// build_arc_length_table computes cumulative arc lengths along
// a polyline. polyline is [x0,y0, x1,y1, ...]. Returns array
// of same point count where table[i] = cumulative distance
// from point 0 to point i.
pub fn build_arc_length_table(polyline []f32) []f32 {
	n := polyline.len / 2
	if n < 1 {
		return []f32{}
	}
	mut table := []f32{len: n}
	table[0] = 0
	for i := 1; i < n; i++ {
		dx := polyline[i * 2] - polyline[(i - 1) * 2]
		dy := polyline[i * 2 + 1] - polyline[(i - 1) * 2 + 1]
		table[i] = table[i - 1] + math.sqrtf(dx * dx + dy * dy)
	}
	return table
}

// sample_path_at returns (x, y, angle) at distance dist along
// the polyline. Uses binary search on the arc-length table.
// Clamps to endpoints if dist is out of range.
pub fn sample_path_at(polyline []f32, table []f32, dist f32) (f32, f32, f32) {
	n := table.len
	if n < 2 {
		if n == 1 {
			return polyline[0], polyline[1], 0
		}
		return 0, 0, 0
	}
	total := table[n - 1]
	// Clamp before start
	if dist <= 0 {
		dx := polyline[2] - polyline[0]
		dy := polyline[3] - polyline[1]
		return polyline[0], polyline[1], f32(math.atan2(dy, dx))
	}
	// Clamp beyond end
	if dist >= total {
		last := (n - 1) * 2
		prev := (n - 2) * 2
		dx := polyline[last] - polyline[prev]
		dy := polyline[last + 1] - polyline[prev + 1]
		return polyline[last], polyline[last + 1], f32(math.atan2(dy, dx))
	}
	// Binary search for enclosing segment
	mut lo := 0
	mut hi := n - 1
	for lo < hi - 1 {
		mid := (lo + hi) / 2
		if table[mid] <= dist {
			lo = mid
		} else {
			hi = mid
		}
	}
	// Interpolate within segment lo..hi
	seg_len := table[hi] - table[lo]
	t := if seg_len > 0 { (dist - table[lo]) / seg_len } else { f32(0) }
	x0 := polyline[lo * 2]
	y0 := polyline[lo * 2 + 1]
	x1 := polyline[hi * 2]
	y1 := polyline[hi * 2 + 1]
	x := x0 + (x1 - x0) * t
	y := y0 + (y1 - y0) * t
	angle := f32(math.atan2(y1 - y0, x1 - x0))
	return x, y, angle
}
