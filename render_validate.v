module gui

import log
import math

// max_frame_triangle_vertices caps the triangle geometry emitted in a single frame.
// gg sets up sokol-gl with the default descriptor, so every triangle drawn in a frame
// is batched into ONE fixed-capacity vertex buffer (sokol's 64k-vertex default).
// Overflowing that buffer makes sokol-gl silently drop the WHOLE frame's geometry — a
// blank window — with no error surfaced to the application.
//
// The budget is metered in the DRAW pass (render_draw_dispatch.v) at the points where
// triangle geometry is actually emitted to sokol-gl, via admit_triangle_vertices(). It
// covers the only UNBOUNDED contributor — DrawSvg triangle geometry (draw_canvas
// polylines/polygons, SVG paths). Vector chrome (rounded rects, circles, images) shares
// the same buffer but is bounded by the widget count, so it is covered by a fixed
// reserve (the 16k below) rather than metered per-draw. A runaway DrawSvg batch (e.g. a
// plot fed far more points than the canvas has pixels) is skipped — for a clipped group,
// the whole group is skipped atomically — with a one-time warning, instead of blanking.
// DrawSvg.triangles are x,y pairs, so a renderer's vertex count is triangles.len / 2.
const max_frame_triangle_vertices = 49152 // 64k sokol-gl buffer − 16k chrome reserve

// render_guard_warn_once logs a render-guard warning at most once per key per window.
fn render_guard_warn_once(mut w Window, key string, msg string) {
	if w.render_guard_warned.len == 0 {
		w.render_guard_warned = map[string]bool{}
	}
	if !w.render_guard_warned[key] {
		log.warn(msg)
		w.render_guard_warned[key] = true
	}
}

// admit_triangle_vertices reserves `vertices` from this frame's sokol-gl triangle
// budget. Returns true (and accumulates) if it fits, or false (warning once) if drawing
// it would overflow the shared vertex buffer and blank the frame. Called from the draw
// pass at each triangle-emission site; frame_triangle_vertices is reset per draw pass in
// renderers_draw().
fn (mut window Window) admit_triangle_vertices(vertices int) bool {
	if window.frame_triangle_vertices + vertices > max_frame_triangle_vertices {
		render_guard_warn_once(mut window, 'triangle_vertex_budget',
			'renderer guard skipped triangle geometry: per-frame budget (${max_frame_triangle_vertices}) exceeded — sokol-gl buffer would overflow')
		return false
	}
	window.frame_triangle_vertices += vertices
	return true
}

// group_triangle_vertices sums the sokol-gl vertices a stencil-clipped DrawSvg group
// emits in renderers[start..end]: a clip mask is drawn TWICE (stencil write + clear, so
// triangles.len = 2 × triangles.len/2), content once (triangles.len/2). Used to budget a
// clipped group atomically — drawing content without its mask renders it unclipped, so it
// is all-or-nothing.
fn group_triangle_vertices(renderers []Renderer, start int, end int) int {
	mut total := 0
	for idx in start .. end {
		r := renderers[idx]
		if r is DrawSvg {
			if r.is_clip_mask {
				total += r.triangles.len // drawn twice: len/2 vertices × 2: len/2 vertices × 2
			} else {
				total += r.triangles.len / 2
			}
		}
	}
	return total
}

fn f32_is_finite(value f32) bool {
	return !math.is_nan(value) && !math.is_inf(value, 0)
}

fn f32_all_finite(values []f32) bool {
	for value in values {
		if !f32_is_finite(value) {
			return false
		}
	}
	return true
}

@[inline]
fn f32_all_finite2(a f32, b f32) bool {
	return f32_is_finite(a) && f32_is_finite(b)
}

@[inline]
fn f32_all_finite3(a f32, b f32, c f32) bool {
	return f32_is_finite(a) && f32_is_finite(b) && f32_is_finite(c)
}

@[inline]
fn f32_all_finite4(a f32, b f32, c f32, d f32) bool {
	return f32_is_finite(a) && f32_is_finite(b) && f32_is_finite(c) && f32_is_finite(d)
}

@[inline]
fn f32_all_finite5(a f32, b f32, c f32, d f32, e f32) bool {
	return f32_is_finite(a) && f32_is_finite(b) && f32_is_finite(c) && f32_is_finite(d)
		&& f32_is_finite(e)
}

@[inline]
fn f32_all_finite6(a f32, b f32, c f32, d f32, e f32, f f32) bool {
	return f32_is_finite(a) && f32_is_finite(b) && f32_is_finite(c) && f32_is_finite(d)
		&& f32_is_finite(e) && f32_is_finite(f)
}

fn transform_is_finite(transform DrawLayoutTransformed) bool {
	return f32_all_finite6(transform.transform.xx, transform.transform.xy, transform.transform.yx,
		transform.transform.yy, transform.transform.x0, transform.transform.y0)
}

fn renderer_kind(r Renderer) string {
	return match r {
		DrawClip { 'DrawClip' }
		DrawRect { 'DrawRect' }
		DrawStrokeRect { 'DrawStrokeRect' }
		DrawGradient { 'DrawGradient' }
		DrawCustomShader { 'DrawCustomShader' }
		DrawCircle { 'DrawCircle' }
		DrawText { 'DrawText' }
		DrawLayout { 'DrawLayout' }
		DrawLayoutTransformed { 'DrawLayoutTransformed' }
		DrawLayoutPlaced { 'DrawLayoutPlaced' }
		DrawImage { 'DrawImage' }
		DrawSvg { 'DrawSvg' }
		DrawFilterComposite { 'DrawFilterComposite' }
		DrawLine { 'DrawLine' }
		DrawNone { 'DrawNone' }
		DrawShadow { 'DrawShadow' }
		DrawBlur { 'DrawBlur' }
		DrawGradientBorder { 'DrawGradientBorder' }
		DrawFilterBegin { 'DrawFilterBegin' }
		DrawFilterEnd { 'DrawFilterEnd' }
	}
}

fn renderer_valid_for_draw(r Renderer) bool {
	return match r {
		DrawClip {
			f32_all_finite4(r.x, r.y, r.width, r.height) && r.width >= 0 && r.height >= 0
		}
		DrawRect {
			f32_all_finite5(r.x, r.y, r.w, r.h, r.radius) && r.w >= 0 && r.h >= 0
		}
		DrawStrokeRect {
			f32_all_finite6(r.x, r.y, r.w, r.h, r.radius, r.thickness) && r.w >= 0 && r.h >= 0
				&& r.thickness > 0
		}
		DrawGradient {
			f32_all_finite5(r.x, r.y, r.w, r.h, r.radius) && r.w >= 0 && r.h >= 0
				&& r.gradient != unsafe { nil }
		}
		DrawCustomShader {
			f32_all_finite5(r.x, r.y, r.w, r.h, r.radius) && r.w > 0 && r.h > 0
				&& r.shader != unsafe { nil }
		}
		DrawCircle {
			f32_all_finite3(r.x, r.y, r.radius) && r.radius > 0
		}
		DrawText {
			f32_all_finite2(r.x, r.y) && r.text.len > 0
		}
		DrawLayout {
			f32_all_finite2(r.x, r.y) && r.layout != unsafe { nil }
		}
		DrawLayoutTransformed {
			f32_all_finite2(r.x, r.y) && r.layout != unsafe { nil } && transform_is_finite(r)
		}
		DrawLayoutPlaced {
			r.layout != unsafe { nil }
		}
		DrawImage {
			f32_all_finite4(r.x, r.y, r.w, r.h) && r.w > 0 && r.h > 0 && r.img != unsafe { nil }
				&& f32_is_finite(r.clip_radius)
		}
		DrawSvg {
			if !f32_all_finite3(r.x, r.y, r.scale) {
				false
			} else if r.scale <= 0 {
				false
			} else if r.triangles.len == 0 || r.triangles.len % 6 != 0 {
				false
			} else if !f32_all_finite(r.triangles) {
				false
			} else if r.vertex_colors.len > 0 && r.vertex_colors.len * 2 != r.triangles.len {
				false
			} else {
				true
			}
		}
		DrawFilterComposite {
			f32_all_finite4(r.x, r.y, r.width, r.height) && r.width > 0 && r.height > 0
				&& r.layers > 0
		}
		else {
			true
		}
	}
}

fn guard_renderer_or_skip(r Renderer, mut w Window) bool {
	if renderer_valid_for_draw(r) {
		return true
	}

	kind := renderer_kind(r)
	render_guard_warn_once(mut w, kind, 'renderer guard skipped invalid renderer: ${kind}')
	return false
}

fn emit_renderer_if_valid(r Renderer, mut window Window) bool {
	if !renderer_valid_for_draw(r) {
		return false
	}
	// Triangle-vertex budgeting happens in the DRAW pass (render_draw_dispatch.v), at
	// the actual sokol-gl emission sites — not here — so it meters real emissions and
	// budgets clipped groups atomically. See max_frame_triangle_vertices.
	window.renderers << r
	return true
}

fn emit_renderer(r Renderer, mut window Window) {
	if emit_renderer_if_valid(r, mut window) {
		return
	}
	guard_renderer_or_skip(r, mut window)
}
