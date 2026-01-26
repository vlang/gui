module gui

import gg

// Helpers
fn make_window() Window {
	// Minimal window; we do not touch window.ui in these tests
	mut w := Window{}
	// ensure clean renderers
	w.renderers = []
	return w
}

fn make_clip(x f32, y f32, w f32, h f32) DrawClip {
	return gg.Rect{
		x:      x
		y:      y
		width:  w
		height: h
	}
}

// -----------------------------
// rects_overlap basic behavior
// -----------------------------
fn test_rects_overlap() {
	a := make_clip(0, 0, 10, 10)
	b := make_clip(5, 5, 10, 10)
	c := make_clip(10, 0, 5, 5) // touches edge at x=10

	assert rects_overlap(a, b)
	assert !rects_overlap(a, c) // touching edge is not overlapping (strict <)
}

// -----------------------------
// dim_alpha halves the alpha
// -----------------------------
fn test_dim_alpha() {
	c := rgba(10, 20, 30, 201)
	d := dim_alpha(c)
	assert d.r == c.r
	assert d.g == c.g
	assert d.b == c.b
	// Integer division by 2
	assert d.a == u8(201 / 2)
}

// --------------------------------------------
// render_rectangle emits a single DrawRect
// --------------------------------------------
fn test_render_rectangle_inside_clip() {
	mut w := make_window()
	mut s := Shape{
		shape_type:   .rectangle
		x:            10
		y:            20
		width:        30
		height:       40
		color:        rgb(100, 150, 200)
		radius:       5
		border_width: 0
	}
	clip := make_clip(0, 0, 200, 200)

	render_rectangle(mut s, clip, mut w)

	assert w.renderers.len == 1
	r := w.renderers[0]
	match r {
		DrawRect {
			assert r.x == s.x
			assert r.y == s.y
			assert r.w == s.width
			assert r.h == s.height
			assert r.style == .fill
			assert r.is_rounded
			assert r.radius == s.radius
			assert r.color == s.color.to_gx_color()
		}
		else {
			assert false, 'expected DrawRect'
		}
	}
}

fn test_render_rectangle_outside_clip_disables_shape() {
	mut w := make_window()
	mut s := Shape{
		shape_type: .rectangle
		x:          100
		y:          100
		width:      20
		height:     20
		color:      rgb(10, 10, 10)
	}
	clip := make_clip(0, 0, 50, 50)

	render_rectangle(mut s, clip, mut w)

	assert w.renderers.len == 0
	assert s.disabled
}

// ----------------------------------------
// render_circle emits a single DrawCircle
// ----------------------------------------
fn test_render_circle_inside_clip() {
	mut w := make_window()
	mut s := Shape{
		shape_type:   .circle
		x:            0
		y:            0
		width:        40
		height:       20
		color:        rgb(1, 2, 3)
		border_width: 0
	}
	clip := make_clip(-10, -10, 100, 100)

	render_circle(mut s, clip, mut w)

	assert w.renderers.len == 1
	c := w.renderers[0]
	match c {
		DrawCircle {
			// Center should be at (x + w/2, y + h/2)
			assert f32_are_close(c.x, s.x + s.width / 2)
			assert f32_are_close(c.y, s.y + s.height / 2)
			// Radius is half of the shortest side
			assert f32_are_close(c.radius, f32_min(s.width, s.height) / 2)
			assert c.color == s.color.to_gx_color()
		}
		else {
			assert false, 'expected DrawCircle'
		}
	}
}

// --------------------------------------------------------
// render_layout: clip push before children, pop after
// --------------------------------------------------------
fn test_render_layout_clip_push_pop() {
	mut w := make_window()
	mut root := Layout{
		shape:    &Shape{
			// Keep it invisible as a container to avoid text/container drawing
			color:        color_transparent
			clip:         true
			padding:      Padding{
				left:   2
				right:  3
				top:    4
				bottom: 5
			}
			border_width: 0
			shape_clip:   make_clip(10, 20, 100, 50)
		}
		children: []
	}

	initial_clip := make_clip(0, 0, 400, 400)
	bg := rgb(0, 0, 0)

	render_layout(mut root, bg, initial_clip, mut w)

	// Expect two clips: computed shape_clip (with padding applied), then pop back to initial
	assert w.renderers.len == 2
	sc_push := w.renderers[0]
	sc_pop := w.renderers[1]

	match sc_push {
		DrawClip {
			assert f32_are_close(sc_push.x, 10 + 2)
			assert f32_are_close(sc_push.y, 20 + 4)
			assert f32_are_close(sc_push.width, 100 - (2 + 3))
			assert f32_are_close(sc_push.height, 50 - (4 + 5))
		}
		else {
			assert false, 'expected first renderer to be DrawClip (push)'
		}
	}
	match sc_pop {
		DrawClip {
			assert f32_are_close(sc_pop.x, initial_clip.x)
			assert f32_are_close(sc_pop.y, initial_clip.y)
			assert f32_are_close(sc_pop.width, initial_clip.width)
			assert f32_are_close(sc_pop.height, initial_clip.height)
		}
		else {
			assert false, 'expected second renderer to be DrawClip (pop)'
		}
	}
}
