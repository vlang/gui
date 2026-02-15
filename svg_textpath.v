module gui

import math
import vglyph

// flatten_defs_path parses a path d attribute and flattens
// to a polyline with coordinates scaled by scale.
fn flatten_defs_path(d string, scale f32) []f32 {
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
fn build_arc_length_table(polyline []f32) []f32 {
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
fn sample_path_at(polyline []f32, table []f32, dist f32) (f32, f32, f32) {
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

// render_svg_text_path places text along a referenced path
// and emits a DrawLayoutPlaced renderer.
fn render_svg_text_path(tp SvgTextPath, defs_paths map[string]string, shape_x f32, shape_y f32, scale f32, gradients map[string]SvgGradientDef, mut window Window) {
	d := defs_paths[tp.path_id] or { return }
	polyline := flatten_defs_path(d, scale)
	if polyline.len < 4 {
		return
	}
	table := build_arc_length_table(polyline)
	total_len := table[table.len - 1]
	if total_len <= 0 {
		return
	}
	// Build text config
	typeface := match true {
		tp.bold && tp.italic { vglyph.Typeface.bold_italic }
		tp.bold { vglyph.Typeface.bold }
		tp.italic { vglyph.Typeface.italic }
		else { vglyph.Typeface.regular }
	}
	text_style := TextStyle{
		family:         tp.font_family
		size:           tp.font_size * scale
		typeface:       typeface
		color:          if tp.opacity < 1.0 {
			Color{tp.color.r, tp.color.g, tp.color.b, u8(f32(tp.color.a) * tp.opacity)}
		} else {
			tp.color
		}
		letter_spacing: tp.letter_spacing * scale
		stroke_width:   tp.stroke_width * scale
		stroke_color:   if tp.opacity < 1.0 {
			Color{tp.stroke_color.r, tp.stroke_color.g, tp.stroke_color.b, u8(f32(tp.stroke_color.a) * tp.opacity)}
		} else {
			tp.stroke_color
		}
	}
	cfg := text_style.to_vglyph_cfg()
	layout := window.text_system.layout_text(tp.text, cfg) or { return }
	glyph_infos := layout.glyph_positions()
	if glyph_infos.len == 0 {
		return
	}
	// Compute total advance
	mut total_advance := f32(0)
	for gi in glyph_infos {
		total_advance += gi.advance
	}
	// Resolve startOffset
	mut offset := if tp.is_percent {
		tp.start_offset * total_len
	} else {
		tp.start_offset * scale
	}
	// text-anchor adjustment
	if tp.anchor == 1 {
		offset -= total_advance / 2
	} else if tp.anchor == 2 {
		offset -= total_advance
	}
	// method=stretch: scale advances
	advance_scale := if tp.method == 1 && total_advance > 0 {
		remaining := total_len - offset
		if remaining > 0 {
			remaining / total_advance
		} else {
			f32(1)
		}
	} else {
		f32(1)
	}
	// Place glyphs
	mut placements := []vglyph.GlyphPlacement{cap: glyph_infos.len}
	mut cur_advance := f32(0)
	for gi in glyph_infos {
		advance := gi.advance * advance_scale
		center_dist := offset + cur_advance + advance / 2
		px, py, angle := sample_path_at(polyline, table, center_dist)
		// Shift back by half advance along tangent
		cos_a := math.cosf(angle)
		sin_a := math.sinf(angle)
		gx := px - cos_a * advance / 2 + shape_x
		gy := py - sin_a * advance / 2 + shape_y
		mut final_angle := angle
		if tp.side == 1 {
			final_angle += math.pi
		}
		placements << vglyph.GlyphPlacement{
			x:     gx
			y:     gy
			angle: final_angle
		}
		cur_advance += advance
	}
	cloned := clone_layout_for_draw(&layout)
	window.renderers << DrawLayoutPlaced{
		layout:     cloned
		placements: placements
	}
}
