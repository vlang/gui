module gui

import math
import svg

// Re-export stroke types so users don't need `import svg`.
pub type StrokeCap = svg.StrokeCap
pub type StrokeJoin = svg.StrokeJoin

// DrawCanvasCache holds retained tessellation output keyed by
// widget id + version. Cache hit skips on_draw entirely.
struct DrawCanvasCache {
	version u64
	batches []DrawCanvasTriBatch
}

// DrawCanvasTriBatch is one flat-color triangle batch.
struct DrawCanvasTriBatch {
	triangles []f32
	color     Color
}

// DrawContext is passed to the on_draw callback. Drawing methods
// append tessellated triangle batches which are later emitted as
// DrawSvg renderers.
pub struct DrawContext {
pub:
	width  f32 // canvas content width
	height f32 // canvas content height
mut:
	batches []DrawCanvasTriBatch
}

// polyline draws a stroked open/closed polyline.
// points: flat x,y pairs. width: stroke width.
pub fn (mut dc DrawContext) polyline(points []f32, color Color, width f32, cap StrokeCap, join StrokeJoin) {
	if points.len < 4 || width <= 0 {
		return
	}
	tris := svg.tessellate_stroke([points], width, cap, join)
	if tris.len > 0 {
		dc.batches << DrawCanvasTriBatch{
			triangles: tris
			color:     color
		}
	}
}

// filled_polygon draws a filled polygon.
// points: flat x,y pairs (minimum 3 points = 6 floats).
pub fn (mut dc DrawContext) filled_polygon(points []f32, color Color) {
	if points.len < 6 {
		return
	}
	tris := svg.tessellate_polylines([points])
	if tris.len > 0 {
		dc.batches << DrawCanvasTriBatch{
			triangles: tris
			color:     color
		}
	}
}

// line draws a single line segment.
pub fn (mut dc DrawContext) line(x0 f32, y0 f32, x1 f32, y1 f32, color Color, width f32) {
	dc.polyline([x0, y0, x1, y1], color, width, .butt, .miter)
}

// filled_rect draws a filled rectangle.
pub fn (mut dc DrawContext) filled_rect(x f32, y f32, w f32, h f32, color Color) {
	if w <= 0 || h <= 0 {
		return
	}
	// Two triangles forming a quad.
	dc.batches << DrawCanvasTriBatch{
		triangles: [
			x,
			y,
			x + w,
			y,
			x + w,
			y + h,
			x,
			y,
			x + w,
			y + h,
			x,
			y + h,
		]
		color:     color
	}
}

// rect draws a stroked rectangle.
pub fn (mut dc DrawContext) rect(x f32, y f32, w f32, h f32, color Color, width f32) {
	if w <= 0 || h <= 0 || width <= 0 {
		return
	}
	pts := [x, y, x + w, y, x + w, y + h, x, y + h, x, y]
	dc.polyline(pts, color, width, .butt, .miter)
}

// filled_circle draws a filled circle.
pub fn (mut dc DrawContext) filled_circle(cx f32, cy f32, radius f32, color Color) {
	dc.filled_arc(cx, cy, radius, radius, 0, 2 * math.pi, color)
}

// circle draws a stroked circle.
pub fn (mut dc DrawContext) circle(cx f32, cy f32, radius f32, color Color, width f32) {
	dc.arc(cx, cy, radius, radius, 0, 2 * math.pi, color, width)
}

// arc draws a stroked elliptical arc.
// start/sweep in radians. Positive sweep = counter-clockwise.
pub fn (mut dc DrawContext) arc(cx f32, cy f32, rx f32, ry f32, start f32, sweep f32, color Color, width f32) {
	if width <= 0 {
		return
	}
	pts := arc_to_polyline(cx, cy, rx, ry, start, sweep)
	if pts.len >= 4 {
		dc.polyline(pts, color, width, .butt, .miter)
	}
}

// filled_arc draws a filled elliptical arc (pie slice).
pub fn (mut dc DrawContext) filled_arc(cx f32, cy f32, rx f32, ry f32, start f32, sweep f32, color Color) {
	pts := arc_to_polyline(cx, cy, rx, ry, start, sweep)
	if pts.len < 4 {
		return
	}
	// Close as pie: center → arc → center.
	mut poly := [cx, cy]
	poly << pts
	poly << cx
	poly << cy
	tris := svg.tessellate_polylines([poly])
	if tris.len > 0 {
		dc.batches << DrawCanvasTriBatch{
			triangles: tris
			color:     color
		}
	}
}

// arc_to_polyline converts an elliptical arc to a flat x,y polyline
// via angular subdivision.
fn arc_to_polyline(cx f32, cy f32, rx f32, ry f32, start f32, sweep f32) []f32 {
	r := if rx > ry { rx } else { ry }
	if r <= 0 {
		return []f32{}
	}
	// Number of segments: proportional to arc length.
	n := int(math.ceil(math.abs(sweep) / (2 * math.pi) * 64 * math.sqrt(r / 50 + 1)))
	segments := if n < 4 { 4 } else { n }
	step := sweep / f32(segments)
	mut pts := []f32{cap: (segments + 1) * 2}
	for i in 0 .. segments + 1 {
		a := start + step * f32(i)
		pts << cx + rx * f32(math.cos(a))
		pts << cy + ry * f32(math.sin(a))
	}
	return pts
}
