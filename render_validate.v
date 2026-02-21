module gui

import log
import math

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
	$if !prod {
		assert false, 'renderer guard rejected ${kind}'
		return false
	}

	if w.render_guard_warned.len == 0 {
		w.render_guard_warned = map[string]bool{}
	}
	if !w.render_guard_warned[kind] {
		log.warn('renderer guard skipped invalid renderer: ${kind}')
		w.render_guard_warned[kind] = true
	}
	return false
}

fn emit_renderer_if_valid(r Renderer, mut window Window) bool {
	if !renderer_valid_for_draw(r) {
		return false
	}
	window.renderers << r
	return true
}

fn emit_renderer(r Renderer, mut window Window) {
	if emit_renderer_if_valid(r, mut window) {
		return
	}
	guard_renderer_or_skip(r, mut window)
}
