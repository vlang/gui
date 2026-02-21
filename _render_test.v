module gui

import gg
import math
import svg
import vglyph

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
		shape_type:  .rectangle
		x:           10
		y:           20
		width:       30
		height:      40
		color:       rgb(100, 150, 200)
		radius:      5
		size_border: 0
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
		shape_type:  .circle
		x:           0
		y:           0
		width:       40
		height:      20
		color:       rgb(1, 2, 3)
		size_border: 0
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
			color:       color_transparent
			clip:        true
			padding:     Padding{
				left:   2
				right:  3
				top:    4
				bottom: 5
			}
			size_border: 0
			shape_clip:  make_clip(10, 20, 100, 50)
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

fn test_resolve_clip_radius_keeps_parent_when_child_not_rounded() {
	shape := &Shape{
		clip:   true
		width:  60
		height: 40
		radius: 0
	}
	assert f32_are_close(resolve_clip_radius(12, shape), 12)
}

fn test_resolve_clip_radius_uses_min_for_nested_rounded() {
	shape := &Shape{
		clip:   true
		width:  60
		height: 40
		radius: 8
	}
	assert f32_are_close(resolve_clip_radius(12, shape), 8)
}

fn test_resolve_clip_radius_ignores_non_finite_child_radius() {
	shape := &Shape{
		clip:   true
		width:  60
		height: 40
		radius: f32(math.inf(1))
	}
	assert f32_are_close(resolve_clip_radius(12, shape), 12)
}

fn test_pipelines_image_clip_state_defaults() {
	p := Pipelines{}
	assert !p.image_clip_init_failed
	assert !p.image_clip_fallback_warned
}

fn test_render_shape_opacity_no_text_config_non_text_is_safe() {
	mut w := make_window()
	mut s := Shape{
		shape_type: .rectangle
		x:          0
		y:          0
		width:      20
		height:     10
		color:      rgb(100, 120, 140)
		opacity:    0.5
	}
	clip := make_clip(0, 0, 200, 200)

	render_shape(mut s, color_transparent, clip, mut w)

	assert w.renderers.len == 1
}

fn test_render_shape_text_without_text_config_degrades_safe() {
	mut w := make_window()
	mut s := Shape{
		shape_type: .text
		x:          0
		y:          0
		width:      50
		height:     20
		color:      black
		opacity:    0.5
	}
	clip := make_clip(0, 0, 200, 200)

	render_shape(mut s, color_transparent, clip, mut w)

	assert w.renderers.len == 0
}

fn test_render_text_transformed_non_focusable_uses_draw_layout_transformed() {
	mut w := make_window()
	mut s := Shape{
		shape_type: .text
		x:          10
		y:          20
		width:      120
		height:     24
		tc:         &ShapeTextConfig{
			text:               'abc'
			cached_line_height: 12
			text_style:         TextStyle{
				color:            black
				rotation_radians: 0.4
			}
			vglyph_layout:      &vglyph.Layout{
				lines: [
					vglyph.Line{
						start_index: 0
						length:      3
						rect:        gg.Rect{
							width:  20
							height: 12
						}
					},
				]
			}
		}
	}

	render_text(mut s, make_clip(0, 0, 300, 300), mut w)

	assert w.renderers.len == 1
	r := w.renderers[0]
	match r {
		DrawLayoutTransformed {
			assert f32_are_close(r.x, s.x + s.padding_left())
			assert f32_are_close(r.y, s.y + s.padding_top())
		}
		else {
			assert false, 'expected DrawLayoutTransformed'
		}
	}
}

fn test_render_text_transformed_focusable_falls_back_to_draw_text() {
	mut w := make_window()
	mut s := Shape{
		shape_type: .text
		id_focus:   1
		x:          10
		y:          20
		width:      120
		height:     24
		tc:         &ShapeTextConfig{
			text:               'abc'
			cached_line_height: 12
			text_style:         TextStyle{
				color:            black
				rotation_radians: 0.4
			}
			vglyph_layout:      &vglyph.Layout{
				lines: [
					vglyph.Line{
						start_index: 0
						length:      3
						rect:        gg.Rect{
							width:  20
							height: 12
						}
					},
				]
			}
		}
	}

	render_text(mut s, make_clip(0, 0, 300, 300), mut w)

	assert w.renderers.len == 1
	match w.renderers[0] {
		DrawText {}
		else {
			assert false, 'expected DrawText'
		}
	}
}

fn test_render_rtf_uniform_transform_uses_draw_layout_transformed() {
	mut w := make_window()
	mut s := Shape{
		shape_type: .rtf
		id:         'rtf-uniform'
		x:          5
		y:          7
		width:      140
		height:     40
		tc:         &ShapeTextConfig{
			rich_text:     &RichText{
				runs: [
					RichTextRun{
						text:  'A'
						style: TextStyle{
							color:            black
							rotation_radians: 0.2
						}
					},
					RichTextRun{
						text:  'B'
						style: TextStyle{
							color:            black
							rotation_radians: 0.2
						}
					},
				]
			}
			vglyph_layout: &vglyph.Layout{}
		}
	}

	render_rtf(mut s, make_clip(0, 0, 300, 300), mut w)

	assert w.renderers.len == 1
	match w.renderers[0] {
		DrawLayoutTransformed {}
		else {
			assert false, 'expected DrawLayoutTransformed'
		}
	}
}

fn test_render_rtf_mixed_transform_falls_back_to_draw_layout() {
	mut w := make_window()
	mut s := Shape{
		shape_type: .rtf
		id:         'rtf-mixed'
		x:          5
		y:          7
		width:      140
		height:     40
		tc:         &ShapeTextConfig{
			rich_text:     &RichText{
				runs: [
					RichTextRun{
						text:  'A'
						style: TextStyle{
							color:            black
							rotation_radians: 0.2
						}
					},
					RichTextRun{
						text:  'B'
						style: TextStyle{
							color: black
						}
					},
				]
			}
			vglyph_layout: &vglyph.Layout{}
		}
	}

	render_rtf(mut s, make_clip(0, 0, 300, 300), mut w)

	assert w.renderers.len == 1
	match w.renderers[0] {
		DrawLayout {}
		else {
			assert false, 'expected DrawLayout'
		}
	}
}

fn test_render_rtf_transform_with_inline_object_falls_back_to_draw_layout() {
	mut w := make_window()
	mut s := Shape{
		shape_type: .rtf
		id:         'rtf-inline'
		x:          5
		y:          7
		width:      140
		height:     40
		tc:         &ShapeTextConfig{
			rich_text:     &RichText{
				runs: [
					RichTextRun{
						text:  'A'
						style: TextStyle{
							color:            black
							rotation_radians: 0.2
						}
					},
				]
			}
			vglyph_layout: &vglyph.Layout{
				items: [
					vglyph.Item{
						ft_face:   unsafe { nil }
						is_object: true
						object_id: 'math1'
					},
				]
			}
		}
	}

	render_rtf(mut s, make_clip(0, 0, 300, 300), mut w)

	assert w.renderers.len == 1
	match w.renderers[0] {
		DrawLayout {}
		else {
			assert false, 'expected DrawLayout'
		}
	}
}

fn test_renderer_guard_valid_draw_rect() {
	assert renderer_valid_for_draw(Renderer(DrawRect{
		x:     1
		y:     2
		w:     20
		h:     10
		color: gg.Color{255, 255, 255, 255}
		style: .fill
	}))
}

fn test_renderer_guard_draw_gradient_allows_zero_size_noop() {
	gradient := &Gradient{
		stops: [GradientStop{
			color: black
			pos:   0.0
		}]
	}
	assert renderer_valid_for_draw(Renderer(DrawGradient{
		x:        21
		y:        66
		w:        0
		h:        0
		radius:   5.5
		gradient: gradient
	}))
}

fn test_renderer_guard_draw_stroke_rect_allows_zero_size_noop() {
	assert renderer_valid_for_draw(Renderer(DrawStrokeRect{
		x:         106
		y:         29
		w:         241.5
		h:         0
		radius:    5.5
		color:     gg.Color{255, 255, 255, 255}
		thickness: 1.5
	}))
}

fn test_renderer_guard_draw_rect_allows_zero_size_noop() {
	assert renderer_valid_for_draw(Renderer(DrawRect{
		x:      244.75
		y:      312.1875
		w:      0
		h:      29.09375
		radius: 5.5
		color:  gg.Color{255, 255, 255, 255}
		style:  .fill
	}))
}

fn test_renderer_guard_invalid_draw_svg_odd_triangle_count() {
	assert !renderer_valid_for_draw(Renderer(DrawSvg{
		triangles: [f32(0), 0, 10, 0, 0, 10, 5]
		color:     gg.Color{255, 0, 0, 255}
		x:         0
		y:         0
		scale:     1
	}))
}

fn test_renderer_guard_invalid_draw_svg_vertex_colors_count_mismatch() {
	assert !renderer_valid_for_draw(Renderer(DrawSvg{
		triangles:     [f32(0), 0, 10, 0, 0, 10]
		color:         gg.Color{255, 255, 255, 255}
		vertex_colors: [gg.Color{255, 0, 0, 255}, gg.Color{0, 255, 0, 255},
			gg.Color{0, 0, 255, 255}, gg.Color{255, 255, 0, 255}]
		x:             0
		y:             0
		scale:         1
	}))
}

fn test_renderer_guard_invalid_draw_filter_composite_non_positive_size_or_layers() {
	assert !renderer_valid_for_draw(Renderer(DrawFilterComposite{
		x:      0
		y:      0
		width:  0
		height: -1
		layers: 0
	}))
}

fn test_renderer_guard_invalid_draw_layout_nil_layout() {
	assert !renderer_valid_for_draw(Renderer(DrawLayout{
		layout: unsafe { nil }
		x:      0
		y:      0
	}))
}

fn test_renderer_guard_invalid_draw_clip_negative_size() {
	assert !renderer_valid_for_draw(Renderer(make_clip(10, 20, -1, 5)))
}

fn test_renderer_guard_draw_text_requires_non_empty_text() {
	assert renderer_valid_for_draw(Renderer(DrawText{
		x:    1
		y:    2
		text: 'ok'
		cfg:  TextStyle{
			color: black
			size:  16
		}.to_vglyph_cfg()
	}))
	assert !renderer_valid_for_draw(Renderer(DrawText{
		x:    1
		y:    2
		text: ''
		cfg:  TextStyle{
			color: black
			size:  16
		}.to_vglyph_cfg()
	}))
}

fn test_renderer_guard_draw_layout_placed_requires_non_nil_layout() {
	assert !renderer_valid_for_draw(Renderer(DrawLayoutPlaced{
		layout:     unsafe { nil }
		placements: []
	}))
	assert renderer_valid_for_draw(Renderer(DrawLayoutPlaced{
		layout:     &vglyph.Layout{}
		placements: []
	}))
}

fn test_find_filter_bracket_range_matched_begin_end() {
	renderers := [
		Renderer(DrawNone{}),
		Renderer(DrawSvg{
			triangles: [f32(0), 0, 10, 0, 0, 10]
			color:     gg.Color{255, 255, 255, 255}
			x:         0
			y:         0
			scale:     1
		}),
		Renderer(DrawFilterEnd{}),
		Renderer(DrawNone{}),
	]
	bracket := find_filter_bracket_range(renderers, 0)

	assert bracket.found_end
	assert bracket.start_idx == 0
	assert bracket.end_idx == 2
	assert bracket.next_idx == 3
}

fn test_find_filter_bracket_range_unmatched_begin_end() {
	renderers := [
		Renderer(DrawNone{}),
		Renderer(DrawNone{}),
	]
	bracket := find_filter_bracket_range(renderers, 0)

	assert !bracket.found_end
	assert bracket.start_idx == 0
	assert bracket.end_idx == 2
	assert bracket.next_idx == 2
}

fn test_render_svg_animated_transformed_paths_do_not_alias_triangle_buffer() {
	mut w := make_window()
	cached := &CachedSvg{
		render_paths:   [
			CachedSvgPath{
				triangles: [f32(0), 0, 10, 0, 0, 10]
				color:     gg.Color{255, 0, 0, 255}
				group_id:  'ring'
			},
			CachedSvgPath{
				triangles: [f32(20), 0, 30, 0, 20, 10]
				color:     gg.Color{0, 255, 0, 255}
				group_id:  'ring'
			},
		]
		animations:     [
			svg.SvgAnimation{
				anim_type: .rotate
				target_id: 'ring'
				from:      [f32(0), 0, 0]
				to:        [f32(0), 0, 0]
				dur:       1
			},
		]
		has_animations: true
		scale:          1
	}

	render_svg_animated(cached, color_transparent, 'anim-buffer-alias', 0, 0, mut w)

	assert w.renderers.len == 2
	r0 := w.renderers[0] as DrawSvg
	r1 := w.renderers[1] as DrawSvg
	assert r0.triangles.len == 6
	assert r1.triangles.len == 6
	assert r0.triangles[0] == 0
	assert r1.triangles[0] == 20
}

fn test_renderer_guard_valid_draw_clip_zero_size() {
	assert renderer_valid_for_draw(Renderer(make_clip(10, 20, 0, 0)))
}

fn test_invalid_clip_is_skipped_and_next_draw_kept() {
	invalid_clip := Renderer(make_clip(10, 20, -5, 10))
	valid_rect := Renderer(DrawRect{
		x:     1
		y:     2
		w:     20
		h:     10
		color: gg.Color{255, 255, 255, 255}
		style: .fill
	})

	mut w := make_window()
	assert !emit_renderer_if_valid(invalid_clip, mut w)
	assert emit_renderer_if_valid(valid_rect, mut w)
	assert w.renderers.len == 1
	match w.renderers[0] {
		DrawRect {}
		else {
			assert false, 'expected DrawRect after invalid clip skip'
		}
	}
}
