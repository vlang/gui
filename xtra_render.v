module gui

// Optimized versions of rectangle drawing functions from `gg`
//
import gg
import sokol.sgl
import log

// The cos/sin values were generated with the following code:
//
// for idx in 0 .. 31 {
//     rad := f32(math.radians(idx * 3))
//     cos_values[idx] = math.cosf(rad)
//     sin_values[idx] = math.sinf(rad)
// }

const cos_values = [f32(1.0), 0.9986295, 0.9945219, 0.98768836, 0.9781476, 0.9659258, 0.95105654,
	0.9335804, 0.9135454, 0.8910065, 0.8660254, 0.83867055, 0.809017, 0.7771459, 0.7431448,
	0.70710677, 0.66913056, 0.6293204, 0.58778524, 0.544639, 0.49999997, 0.45399052, 0.4067366,
	0.35836798, 0.30901697, 0.25881907, 0.20791166, 0.15643449, 0.10452842, 0.052335974,
	-4.371139e-08]!

const sin_values = [f32(0.0), 0.05233596, 0.104528464, 0.15643448, 0.2079117, 0.25881904, 0.309017,
	0.35836795, 0.40673664, 0.45399052, 0.5, 0.54463905, 0.58778524, 0.6293204, 0.6691306, 0.70710677,
	0.74314487, 0.777146, 0.809017, 0.8386706, 0.86602545, 0.8910065, 0.9135455, 0.9335804,
	0.95105654, 0.9659258, 0.9781476, 0.98768836, 0.9945219, 0.9986295, 1.0]!

const num_segments = 31

struct RoundedRectParams {
	r      f32
	sx     f32
	sy     f32
	width  f32
	height f32
	ltx    f32
	lty    f32
	rtx    f32
	rty    f32
	rbx    f32
	rby    f32
	lbx    f32
	lby    f32
	dxs    [num_segments]f32
	dys    [num_segments]f32
}

fn draw_rounded_rect_filled(x f32, y f32, w f32, h f32, radius f32, c gg.Color, ctx &gg.Context) {
	if w <= 0 || h <= 0 || radius < 0 {
		log.info('draw_rounded_rect_filled: invalid arguments: w=${w}, h=${h}, radius=${radius}')
		return
	}

	p := setup_rounded_rect_draw(x, y, w, h, radius, c, ctx)

	if p.r != 0 {
		// left top quarter
		sgl.c4b(c.r, c.g, c.b, 10)
		// Small offset to minimize visible seams on some platforms
		sgl_arc_triangle_strip_with_offset(p.ltx, p.lty, p.dxs, p.dys, -1, -1, -1, -1)

		sgl.c4b(c.r, c.g, c.b, c.a)
		sgl_arc_triangle_strip(p.ltx, p.lty, p.dxs, p.dys, -1, -1)

		// right top quarter
		sgl_arc_triangle_strip(p.rtx, p.rty, p.dxs, p.dys, 1, -1)

		// right bottom quarter
		sgl_arc_triangle_strip(p.rbx, p.rby, p.dxs, p.dys, 1, 1)

		// left bottom quarter
		sgl_arc_triangle_strip(p.lbx, p.lby, p.dxs, p.dys, -1, 1)
	}

	// Separate drawing is to prevent transparent color overlap
	// top rectangle
	sgl.begin_quads()
	sgl.v2f(p.ltx, p.sy)
	sgl.v2f(p.rtx, p.sy)
	sgl.v2f(p.rtx, p.rty)
	sgl.v2f(p.ltx, p.lty)
	sgl.end()
	// middle rectangle
	sgl.begin_quads()
	sgl.v2f(p.sx, p.lty)
	sgl.v2f(p.rtx + p.r, p.rty)
	sgl.v2f(p.rbx + p.r, p.rby)
	sgl.v2f(p.sx, p.lby)
	sgl.end()
	// bottom rectangle
	sgl.begin_quads()
	sgl.v2f(p.lbx, p.lby)
	sgl.v2f(p.rbx, p.rby)
	sgl.v2f(p.rbx, p.rby + p.r)
	sgl.v2f(p.lbx, p.lby + p.r)
	sgl.end()
}

fn draw_rounded_rect_empty(x f32, y f32, w f32, h f32, radius f32, c gg.Color, ctx &gg.Context) {
	if w <= 0 || h <= 0 || radius < 0 {
		log.info('draw_rounded_rect_empty: invalid arguments: w=${w}, h=${h}, radius=${radius}')
		return
	}
	p := setup_rounded_rect_draw(x, y, w, h, radius, c, ctx)

	if p.r != 0 {
		// left top quarter
		sgl_arc_line_strip(p.ltx, p.lty, p.dxs, p.dys, -1, -1)
		// right top quarter
		sgl_arc_line_strip(p.rtx, p.rty, p.dxs, p.dys, 1, -1)
		// right bottom quarter
		sgl_arc_line_strip(p.rbx, p.rby, p.dxs, p.dys, 1, 1)
		// left bottom quarter
		sgl_arc_line_strip(p.lbx, p.lby, p.dxs, p.dys, -1, 1)
	}

	// Currently don't use 'gg.draw_line()' directly, it will repeatedly execute '*ctx.scale'.
	sgl.begin_lines()

	// top
	sgl.v2f(p.ltx, p.sy)
	sgl.v2f(p.rtx, p.sy)

	// right
	sgl.v2f(p.rtx + p.r, p.rty)
	sgl.v2f(p.rtx + p.r, p.rby)

	// bottom
	// Note: test on native windows, macos, and linux if you need to change the offset literal here,
	// with `v run vlib/gg/testdata/draw_rounded_rect_empty.vv` . Using 1 here, looks good on windows,
	// and on linux with LIBGL_ALWAYS_SOFTWARE=true, but misaligned on native macos and linux.
	$if macos || linux {
		sgl.v2f(p.lbx, p.lby + p.r)
		sgl.v2f(p.rbx, p.rby + p.r)
	} $else {
		sgl.v2f(p.lbx, p.lby + p.r - 0.5)
		sgl.v2f(p.rbx, p.rby + p.r - 0.5)
	}

	// left
	$if macos || linux {
		sgl.v2f(p.sx, p.lty)
		sgl.v2f(p.sx, p.lby)
	} $else {
		sgl.v2f(p.sx + 1, p.lty)
		sgl.v2f(p.sx + 1, p.lby)
	}
	sgl.end()
}

@[direct_array_access]
fn setup_rounded_rect_draw(x f32, y f32, w f32, h f32, radius f32, c gg.Color, ctx &gg.Context) RoundedRectParams {
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
	mut dxs := [num_segments]f32{}
	mut dys := [num_segments]f32{}
	for i in 0 .. num_segments {
		dxs[i] = r * cos_values[i]
		dys[i] = r * sin_values[i]
	}

	return RoundedRectParams{
		r:      r
		sx:     sx
		sy:     sy
		width:  width
		height: height
		ltx:    ltx
		lty:    lty
		rtx:    rtx
		rty:    rty
		rbx:    rbx
		rby:    rby
		lbx:    lbx
		lby:    lby
		dxs:    dxs
		dys:    dys
	}
}

// Utilities for drawing rounded rectangles
// Note: These helpers reduce duplication and keep the behavior identical.
// They only encapsulate the repeated SGL immediate-mode patterns.

// sgl_arc_triangle_strip_with_offset Draw a quarter circle using a triangle strip,
// alternating edge and center vertices.
// The arc is defined by precomputed dxs/dys, and oriented by xmul/ymul.
// An optional offset (ox, oy) allows subtle shifts for AA-like effects where needed.
@[direct_array_access]
fn sgl_arc_triangle_strip_with_offset(cx f32, cy f32, dxs [num_segments]f32,
	dys [num_segments]f32, xmul f32, ymul f32, ox f32, oy f32) {
	sgl.begin_triangle_strip()
	for i in 0 .. num_segments {
		sgl.v2f(cx + xmul * dxs[i] + ox, cy + ymul * dys[i] + oy)
		sgl.v2f(cx, cy)
	}
	sgl.end()
}

// sgl_arc_triangle_strip Convenience wrapper without offset.
fn sgl_arc_triangle_strip(cx f32, cy f32, dxs [num_segments]f32, dys [num_segments]f32, xmul f32, ymul f32) {
	sgl_arc_triangle_strip_with_offset(cx, cy, dxs, dys, xmul, ymul, 0, 0)
}

// sgl_arc_line_strip Draw a quarter circle outline using a line strip.
@[direct_array_access]
fn sgl_arc_line_strip(cx f32, cy f32, dxs [num_segments]f32, dys [num_segments]f32, xmul f32, ymul f32) {
	sgl.begin_line_strip()
	for i in 0 .. num_segments {
		sgl.v2f(cx + xmul * dxs[i], cy + ymul * dys[i])
	}
	sgl.end()
}
