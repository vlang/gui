module gui

// render_gradient.v handles gradient and blur rendering. Gradients are packed
// as stop arrays (max gradient_shader_stop_limit=5 stops) passed to the GPU
// shader as uniforms — packing is per-draw-call, not cached. dim_alpha() halves
// alpha for disabled states. draw_blur_rect() and draw_shadow_rect() use the
// blur shader pipeline (lazily initialized). rects_overlap() guards draw calls.
import gg
import sokol.sgl
import math

const gradient_shader_stop_limit = 5

// dim_alpha is used for visually indicating disabled.
fn dim_alpha(color Color) Color {
	return Color{
		...color
		a: color.a / u8(2)
	}
}

// rects_overlap checks if two rectangles overlap.
@[inline]
fn rects_overlap(r1 gg.Rect, r2 gg.Rect) bool {
	return r1.x < (r2.x + r2.width) && r2.x < (r1.x + r1.width) && r1.y < (r2.y + r2.height)
		&& r2.y < (r1.y + r1.height)
}

// draw_blur_rect draws a blurred rounded rectangle.
// It is similar to draw_shadow_rect but the blur is "filled".
pub fn draw_blur_rect(x f32, y f32, w f32, h f32, radius f32, blur f32, c gg.Color, mut window Window) {
	if c.a == 0 {
		return
	}

	scale := window.ui.scale
	padding := blur * 1.5

	sx := (x - padding) * scale
	sy := (y - padding) * scale
	sw := (w + padding * 2) * scale
	sh := (h + padding * 2) * scale

	r := radius * scale
	b := blur * scale

	init_blur_pipeline(mut window)

	// Since we used vs_shadow which expects 'tm' uniform (offset), we must provide it even if 0.
	sgl.matrix_mode_texture()
	sgl.push_matrix()
	sgl.load_identity()
	// No offset for generic blur
	sgl.translate(0, 0, 0)

	sgl.load_pipeline(window.pip.blur)
	sgl.c4b(c.r, c.g, c.b, c.a)

	z_val := pack_shader_params(r, b)

	draw_quad(sx, sy, sw, sh, z_val)
	sgl.load_default_pipeline()
	sgl.c4b(255, 255, 255, 255) // Reset color state

	sgl.pop_matrix()
	sgl.matrix_mode_modelview()
}

// angle_to_direction converts CSS angle (degrees) to unit direction vector
// CSS: 0deg=top, clockwise. Math: 0rad=right, counter-clockwise.
fn angle_to_direction(css_degrees f32) (f32, f32) {
	rad := (90.0 - css_degrees) * math.pi / 180.0
	return f32(math.cos(rad)), -f32(math.sin(rad))
}

// gradient_direction computes direction vector from Gradient config
// Handles both explicit angle and direction keywords
fn gradient_direction(gradient &Gradient, width f32, height f32) (f32, f32) {
	// If explicit angle provided, use it
	if angle := gradient.angle {
		return angle_to_direction(angle)
	}

	// Convert direction keyword to angle
	css_angle := match gradient.direction {
		.to_top { f32(0.0) }
		.to_right { f32(90.0) }
		.to_bottom { f32(180.0) }
		.to_left { f32(270.0) }
		.to_top_right { 90.0 - f32(math.atan2(height, width)) * 180.0 / math.pi }
		.to_bottom_right { 90.0 + f32(math.atan2(height, width)) * 180.0 / math.pi }
		.to_bottom_left { 270.0 - f32(math.atan2(height, width)) * 180.0 / math.pi }
		.to_top_left { 270.0 + f32(math.atan2(height, width)) * 180.0 / math.pi }
	}
	return angle_to_direction(css_angle)
}

// pack_rgb packs Red, Green, Blue into a single f32 (up to 16.7M, safe for f32 mantissa).
fn pack_rgb(c Color) f32 {
	return f32(c.r) + f32(c.g) * 256.0 + f32(c.b) * 65536.0
}

// pack_alpha_pos packs Alpha (0..255) and Position (0.0..1.0) into a single f32.
// Position precision is 1/10000.
fn pack_alpha_pos(c Color, pos f32) f32 {
	return f32(c.a) + f32(math.floor(pos * 10000.0)) * 256.0
}

@[inline]
fn clamp_unit(value f32) f32 {
	if value < 0 {
		return 0
	}
	if value > 1 {
		return 1
	}
	return value
}

@[inline]
fn f32_to_u8_saturated(value f32) u8 {
	clamped := math.max(0.0, math.min(value, 255.0))
	return u8(int(math.round(f64(clamped))))
}

fn lerp_color_premultiplied(a Color, b Color, t f32) Color {
	clamped_t := clamp_unit(t)
	a_alpha := f32(a.a) / 255.0
	b_alpha := f32(b.a) / 255.0
	a_r := (f32(a.r) / 255.0) * a_alpha
	a_g := (f32(a.g) / 255.0) * a_alpha
	a_b := (f32(a.b) / 255.0) * a_alpha
	b_r := (f32(b.r) / 255.0) * b_alpha
	b_g := (f32(b.g) / 255.0) * b_alpha
	b_b := (f32(b.b) / 255.0) * b_alpha
	alpha := a_alpha + (b_alpha - a_alpha) * clamped_t
	p_r := a_r + (b_r - a_r) * clamped_t
	p_g := a_g + (b_g - a_g) * clamped_t
	p_b := a_b + (b_b - a_b) * clamped_t
	if alpha <= 0.0001 {
		return Color{0, 0, 0, 0}
	}
	r := (p_r / alpha) * 255.0
	g := (p_g / alpha) * 255.0
	bl := (p_b / alpha) * 255.0
	return Color{
		r: f32_to_u8_saturated(r)
		g: f32_to_u8_saturated(g)
		b: f32_to_u8_saturated(bl)
		a: f32_to_u8_saturated(alpha * 255.0)
	}
}

fn sample_gradient_stop_color(stops []GradientStop, pos f32) Color {
	if stops.len == 0 {
		return Color{0, 0, 0, 0}
	}
	if pos <= stops[0].pos {
		return stops[0].color
	}
	for i in 1 .. stops.len {
		left := stops[i - 1]
		right := stops[i]
		if pos > right.pos {
			continue
		}
		span := right.pos - left.pos
		if span <= 0.0001 {
			return right.color
		}
		local_t := (pos - left.pos) / span
		return lerp_color_premultiplied(left.color, right.color, local_t)
	}
	return stops[stops.len - 1].color
}

fn normalize_gradient_stops_for_shader(stops []GradientStop) []GradientStop {
	if stops.len == 0 {
		return []GradientStop{}
	}
	mut normalized := []GradientStop{cap: stops.len}
	for stop in stops {
		normalized << GradientStop{
			color: stop.color
			pos:   clamp_unit(stop.pos)
		}
	}
	normalized.sort(a.pos < b.pos)
	if normalized.len <= gradient_shader_stop_limit {
		return normalized
	}
	mut sampled := []GradientStop{cap: gradient_shader_stop_limit}
	for i in 0 .. gradient_shader_stop_limit {
		sample_pos := f32(i) / f32(gradient_shader_stop_limit - 1)
		sampled << GradientStop{
			color: sample_gradient_stop_color(normalized, sample_pos)
			pos:   sample_pos
		}
	}
	return sampled
}

fn normalize_gradient_stops_for_shader_into(stops []GradientStop, mut normalized []GradientStop, mut sampled []GradientStop) []GradientStop {
	if stops.len == 0 {
		normalized.clear()
		sampled.clear()
		return []GradientStop{}
	}
	normalized.clear()
	if normalized.cap < stops.len {
		normalized = []GradientStop{cap: stops.len}
	}
	for stop in stops {
		normalized << GradientStop{
			color: stop.color
			pos:   clamp_unit(stop.pos)
		}
	}
	normalized.sort(a.pos < b.pos)
	if normalized.len <= gradient_shader_stop_limit {
		sampled.clear()
		return normalized
	}
	sampled.clear()
	if sampled.cap < gradient_shader_stop_limit {
		sampled = []GradientStop{cap: gradient_shader_stop_limit}
	}
	for i in 0 .. gradient_shader_stop_limit {
		sample_pos := f32(i) / f32(gradient_shader_stop_limit - 1)
		sampled << GradientStop{
			color: sample_gradient_stop_color(normalized, sample_pos)
			pos:   sample_pos
		}
	}
	return sampled
}

fn draw_gradient_rect(x f32, y f32, w f32, h f32, radius f32, gradient &Gradient, mut window Window) {
	if w <= 0 || h <= 0 || gradient.stops.len == 0 {
		return
	}
	mut normalized_stops := window.scratch.take_gradient_norm_stops(gradient.stops.len)
	mut sampled_stops := window.scratch.take_gradient_sample_stops(gradient_shader_stop_limit)
	defer {
		window.scratch.put_gradient_norm_stops(mut normalized_stops)
		window.scratch.put_gradient_sample_stops(mut sampled_stops)
	}

	scale := window.ui.scale
	sx := x * scale
	sy := y * scale
	sw := w * scale
	sh := h * scale
	mut r := radius * scale

	min_dim := if sw < sh { sw } else { sh }
	if r > min_dim / 2.0 {
		r = min_dim / 2.0
	}
	if r < 0 {
		r = 0
	}

	init_gradient_pipeline(mut window)
	stops := normalize_gradient_stops_for_shader_into(gradient.stops, mut normalized_stops, mut
		sampled_stops)
	if stops.len == 0 {
		return
	}
	if gradient.stops.len > gradient_shader_stop_limit && !window.pip.gradient_stop_warned {
		window.pip.gradient_stop_warned = true
		eprintln('warning: gradient has ${gradient.stops.len} stops; resampled to ' +
			'${gradient_shader_stop_limit}')
	}

	// Pack gradient stops into tm matrix via sgl
	sgl.matrix_mode_texture()
	sgl.push_matrix()

	// Pack stops into tm matrix (indices 10-11 reserved
	// for direction/radius metadata)
	mut tm_data := [16]f32{}
	stop_count := stops.len
	for i in 0 .. stop_count {
		stop := stops[i]
		// Each stop takes 2 floats: [packed_rgb, packed_alpha_pos]
		midx := i * 2
		tm_data[midx] = pack_rgb(stop.color)
		tm_data[midx + 1] = pack_alpha_pos(stop.color, stop.pos)
	}

	// tm[3] (index 12..15) stores core metadata

	tm_data[12] = sw / 2.0 // hw

	tm_data[13] = sh / 2.0 // hh

	tm_data[14] = if gradient.type == .radial { f32(1.0) } else { f32(0.0) } // type

	tm_data[15] = f32(stop_count) // count

	// Additional metadata in unused stop slots (Stop 6 slots: 10, 11)

	if gradient.type == .radial {
		target_radius := math.sqrt((sw / 2.0) * (sw / 2.0) + (sh / 2.0) * (sh / 2.0))

		tm_data[11] = f32(target_radius)
	} else {
		dx, dy := gradient_direction(gradient, sw, sh)

		tm_data[10] = dx

		tm_data[11] = dy
	}

	// Load the gradient data matrix

	sgl.load_matrix(tm_data[0..])

	sgl.load_pipeline(window.pip.gradient)
	sgl.c4b(255, 255, 255, 255) // White base color (shader computes actual color)

	z_val := pack_shader_params(r, 0)

	draw_quad(sx, sy, sw, sh, z_val)

	sgl.load_default_pipeline()
	sgl.c4b(255, 255, 255, 255) // Reset color state
	sgl.pop_matrix()
	sgl.matrix_mode_modelview()
}

fn draw_quad_gradient(x f32, y f32, w f32, h f32, z f32, c1 Color, c2 Color, g_type GradientType) {
	sgl.begin_quads()

	// Top Left
	sgl.t2f(-1.0, -1.0)
	sgl.c4b(c1.r, c1.g, c1.b, c1.a)
	sgl.v3f(x, y, z)

	// Top Right
	sgl.t2f(1.0, -1.0)
	if g_type == .linear {
		sgl.c4b(c2.r, c2.g, c2.b, c2.a)
	} else {
		sgl.c4b(c1.r, c1.g, c1.b, c1.a)
	}
	sgl.v3f(x + w, y, z)

	// Bottom Right
	sgl.t2f(1.0, 1.0)
	sgl.c4b(c2.r, c2.g, c2.b, c2.a)
	sgl.v3f(x + w, y + h, z)

	// Bottom Left
	sgl.t2f(-1.0, 1.0)
	if g_type == .linear {
		sgl.c4b(c1.r, c1.g, c1.b, c1.a)
	} else {
		sgl.c4b(c2.r, c2.g, c2.b, c2.a)
	}
	sgl.v3f(x, y + h, z)

	sgl.end()
}

fn draw_gradient_border(x f32, y f32, w f32, h f32, radius f32, thickness f32, gradient &Gradient, mut window Window) {
	if w <= 0 || h <= 0 {
		return
	}

	// For now, simple implementation: mapping colors to corners for a stroke.
	// Since sgl doesn't have a simple "gradient stroke" primitive that respects rounded corners perfectly
	// without a custom shader that knows about stroke width AND gradient, we will use the existing
	// rounded rect pipeline but with a hack:
	// We use `draw_quad_gradient` logic but applied to the `rounded_rect` pipeline?
	// NO, `rounded_rect_pip` expects a single color in `color0` attribute for the whole quad usually?
	// Wait, `vs_glsl` takes `color0` attribute per vertex.
	// So we CAN pass different colors per vertex to `rounded_rect_pip`!

	scale := window.ui.scale
	sx := x * scale
	sy := y * scale
	sw := w * scale
	sh := h * scale
	mut r := radius * scale

	min_dim := if sw < sh { sw } else { sh }
	if r > min_dim / 2.0 {
		r = min_dim / 2.0
	}
	if r < 0 {
		r = 0
	}

	if !init_rounded_rect_pipeline(mut window) {
		return
	}
	sgl.load_pipeline(window.pip.rounded_rect)

	// Determine colors based on gradient stops (simplification for 2 stops)
	c1 := if gradient.stops.len > 0 {
		gradient.stops[0].color.to_gx_color()
	} else {
		gg.Color{0, 0, 0, 255}
	}
	c2 := if gradient.stops.len > 1 { gradient.stops[1].color.to_gx_color() } else { c1 }

	// Pack params for STROKE (thickness > 0)
	z_val := pack_shader_params(r, thickness * scale)

	// Draw Quad with Per-Vertex Colors
	sgl.begin_quads()

	// Top Left
	sgl.t2f(-1.0, -1.0)
	sgl.c4b(c1.r, c1.g, c1.b, c1.a)
	sgl.v3f(sx, sy, z_val)

	// Top Right
	sgl.t2f(1.0, -1.0)
	if gradient.type == .linear {
		sgl.c4b(c2.r, c2.g, c2.b, c2.a)
	} else {
		sgl.c4b(c1.r, c1.g, c1.b, c1.a)
	}
	sgl.v3f(sx + sw, sy, z_val)

	// Bottom Right
	sgl.t2f(1.0, 1.0)
	sgl.c4b(c2.r, c2.g, c2.b, c2.a)
	sgl.v3f(sx + sw, sy + sh, z_val)

	// Bottom Left
	sgl.t2f(-1.0, 1.0)
	if gradient.type == .linear {
		sgl.c4b(c1.r, c1.g, c1.b, c1.a)
	} else {
		sgl.c4b(c2.r, c2.g, c2.b, c2.a)
	}
	sgl.v3f(sx, sy + sh, z_val)

	sgl.end()
	sgl.load_default_pipeline()
}
