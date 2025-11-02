module gui

import gg
import sokol.sgl

// The cosf/sinf values were generated with the following code:
//
// for idx in 0 .. 31 {
//     rad := f32(math.radians(idx * 3))
//     cosf_values[idx] = math.cosf(rad)
//     sinf_values[idx] = math.sinf(rad)
// }

const cosf_values = [f32(1.0), 0.9986295, 0.9945219, 0.98768836, 0.9781476, 0.9659258, 0.95105654,
	0.9335804, 0.9135454, 0.8910065, 0.8660254, 0.83867055, 0.809017, 0.7771459, 0.7431448,
	0.70710677, 0.66913056, 0.6293204, 0.58778524, 0.544639, 0.49999997, 0.45399052, 0.4067366,
	0.35836798, 0.30901697, 0.25881907, 0.20791166, 0.15643449, 0.10452842, 0.052335974,
	-4.371139e-08, 0.0]!

const sinf_values = [f32(0.0), 0.05233596, 0.104528464, 0.15643448, 0.2079117, 0.25881904, 0.309017,
	0.35836795, 0.40673664, 0.45399052, 0.5, 0.54463905, 0.58778524, 0.6293204, 0.6691306, 0.70710677,
	0.74314487, 0.777146, 0.809017, 0.8386706, 0.86602545, 0.8910065, 0.9135455, 0.9335804,
	0.95105654, 0.9659258, 0.9781476, 0.98768836, 0.9945219, 0.9986295, 1.0, 0.0]!

fn draw_rounded_rect_filled(x f32, y f32, w f32, h f32, radius f32, c gg.Color, ctx &gg.Context) {
	if w <= 0 || h <= 0 || radius < 0 {
		return
	}

	// if c.a != 255 {
	sgl.load_pipeline(ctx.pipeline.alpha)
	//}
	sgl.c4b(c.r, c.g, c.b, c.a)

	mut new_radius := radius
	if w >= h && radius > h / 2 {
		new_radius = h / 2
	} else if radius > w / 2 {
		new_radius = w / 2
	}
	r := new_radius * ctx.scale
	sx := x * ctx.scale // start point x
	sy := y * ctx.scale
	width := w * ctx.scale
	height := h * ctx.scale
	// circle center coordinates
	ltx := sx + r
	lty := sy + r
	rtx := sx + width - r
	rty := lty
	rbx := rtx
	rby := sy + height - r
	lbx := ltx
	lby := rby

	// calc radians
	mut dxs := [32]f32{}
	mut dys := [32]f32{}
	for i in 0 .. 31 {
		dxs[i] = r * cosf_values[i]
		dys[i] = r * sinf_values[i]
	}

	if r != 0 {
		// left top quarter
		sgl.c4b(c.r, c.g, c.b, 10)

		sgl.begin_triangle_strip()
		for i in 0 .. 31 {
			sgl.v2f(ltx - dxs[i] - 1, lty - dys[i] - 1)
			sgl.v2f(ltx, lty)
		}
		sgl.end()

		sgl.c4b(c.r, c.g, c.b, c.a)
		sgl.begin_triangle_strip()
		for i in 0 .. 31 {
			sgl.v2f(ltx - dxs[i], lty - dys[i])
			sgl.v2f(ltx, lty)
		}
		sgl.end()

		// right top quarter
		sgl.begin_triangle_strip()
		for i in 0 .. 31 {
			sgl.v2f(rtx + dxs[i], rty - dys[i])
			sgl.v2f(rtx, rty)
		}
		sgl.end()

		// right bottom quarter
		sgl.begin_triangle_strip()
		for i in 0 .. 31 {
			sgl.v2f(rbx + dxs[i], rby + dys[i])
			sgl.v2f(rbx, rby)
		}
		sgl.end()

		// left bottom quarter
		sgl.begin_triangle_strip()
		for i in 0 .. 31 {
			sgl.v2f(lbx - dxs[i], lby + dys[i])
			sgl.v2f(lbx, lby)
		}
		sgl.end()
	}

	// Separate drawing is to prevent transparent color overlap
	// top rectangle
	sgl.begin_quads()
	sgl.v2f(ltx, sy)
	sgl.v2f(rtx, sy)
	sgl.v2f(rtx, rty)
	sgl.v2f(ltx, lty)
	sgl.end()
	// middle rectangle
	sgl.begin_quads()
	sgl.v2f(sx, lty)
	sgl.v2f(rtx + r, rty)
	sgl.v2f(rbx + r, rby)
	sgl.v2f(sx, lby)
	sgl.end()
	// bottom rectangle
	sgl.begin_quads()
	sgl.v2f(lbx, lby)
	sgl.v2f(rbx, rby)
	sgl.v2f(rbx, rby + r)
	sgl.v2f(lbx, rby + r)
	sgl.end()
}

fn draw_rounded_rect_empty(x f32, y f32, w f32, h f32, radius f32, c gg.Color, ctx &gg.Context) {
	if w <= 0 || h <= 0 || radius < 0 {
		return
	}

	if c.a != 255 {
		sgl.load_pipeline(ctx.pipeline.alpha)
	}
	sgl.c4b(c.r, c.g, c.b, c.a)

	mut new_radius := radius
	if w >= h && radius > h / 2 {
		new_radius = h / 2
	} else if radius > w / 2 {
		new_radius = w / 2
	}
	r := new_radius * ctx.scale
	sx := x * ctx.scale // start point x
	sy := y * ctx.scale
	width := w * ctx.scale
	height := h * ctx.scale
	// circle center coordinates
	ltx := sx + r
	lty := sy + r
	rtx := sx + width - r
	rty := lty
	rbx := rtx
	rby := sy + height - r
	lbx := ltx
	lby := rby

	// calc radians
	mut dxs := [32]f32{}
	mut dys := [32]f32{}
	for i in 0 .. 31 {
		dxs[i] = r * cosf_values[i]
		dys[i] = r * sinf_values[i]
	}

	if r != 0 {
		// left top quarter
		sgl.begin_line_strip()
		for i in 0 .. 31 {
			sgl.v2f(ltx - dxs[i], lty - dys[i])
		}
		sgl.end()
		// right top quarter
		sgl.begin_line_strip()
		for i in 0 .. 31 {
			sgl.v2f(rtx + dxs[i], rty - dys[i])
		}
		sgl.end()
		// right bottom quarter
		sgl.begin_line_strip()
		for i in 0 .. 31 {
			sgl.v2f(rbx + dxs[i], rby + dys[i])
		}
		sgl.end()
		// left bottom quarter
		sgl.begin_line_strip()
		for i in 0 .. 31 {
			sgl.v2f(lbx - dxs[i], lby + dys[i])
		}
		sgl.end()
	}

	// Currently don't use 'gg.draw_line()' directly, it will repeatedly execute '*ctx.scale'.
	sgl.begin_lines()

	// top
	sgl.v2f(ltx, sy)
	sgl.v2f(rtx, sy)

	// right
	sgl.v2f(rtx + r, rty)
	sgl.v2f(rtx + r, rby)

	// bottom
	// Note: test on native windows, macos, and linux if you need to change the offset literal here,
	// with `v run vlib/gg/testdata/draw_rounded_rect_empty.vv` . Using 1 here, looks good on windows,
	// and on linux with LIBGL_ALWAYS_SOFTWARE=true, but misaligned on native macos and linux.
	$if macos || linux {
		sgl.v2f(lbx, lby + r)
		sgl.v2f(rbx, rby + r)
	} $else {
		sgl.v2f(lbx, lby + r - 0.5)
		sgl.v2f(rbx, rby + r - 0.5)
	}

	// left
	$if macos || linux {
		sgl.v2f(sx, lty)
		sgl.v2f(sx, lby)
	} $else {
		sgl.v2f(sx + 1, lty)
		sgl.v2f(sx + 1, lby)
	}
	sgl.end()
}
