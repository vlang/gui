module gui

import gg
import sokol.sgl
import log

// renderers_draw walks the array of renderers and draws them.
// This function and renderer_draw constitute the entire
// draw logic of GUI
fn renderers_draw(mut window Window) {
	renderers := window.renderers

	mut i := 0
	for i < renderers.len {
		renderer := renderers[i]
		if !guard_renderer_or_skip(renderer, mut window) {
			i++
			continue
		}
		// Batch consecutive DrawSvg with same color, position, scale
		if renderer is DrawSvg {
			// Handle stencil clip groups
			if renderer.clip_group > 0 {
				i = draw_clipped_svg_group(renderers, i, mut window)
				continue
			}
			// Per-vertex colored SVGs cannot batch
			if renderer.vertex_colors.len > 0 {
				draw_triangles_gradient(renderer.triangles, renderer.vertex_colors, renderer.x,
					renderer.y, renderer.scale, mut window)
				i++
				continue
			}
			color := renderer.color
			x := renderer.x
			y := renderer.y
			scale := renderer.scale
			start := i
			i++
			// Collect consecutive matching DrawSvg (non-clipped, non-gradient)
			for i < renderers.len {
				candidate := renderers[i]
				if !guard_renderer_or_skip(candidate, mut window) {
					i++
					continue
				}
				if candidate is DrawSvg {
					svg := candidate
					if svg.clip_group == 0 && svg.vertex_colors.len == 0 && svg.color == color
						&& svg.x == x && svg.y == y && svg.scale == scale {
						i++
						continue
					}
				}
				break
			}
			draw_svg_batch(renderers, start, i, color, x, y, scale, mut window)
		} else {
			renderer_draw(renderer, mut window)
			i++
		}
	}
	window.text_system.commit()
}

// draw_svg_batch draws consecutive flat-color DrawSvg renderers in one SGL batch.
fn draw_svg_batch(renderers []Renderer, start int, end int, c gg.Color, x f32, y f32, tri_scale f32, mut window Window) {
	if start < 0 || end <= start || end > renderers.len {
		return
	}

	scale := window.ui.scale
	sgl.load_pipeline(window.ui.pipeline.alpha)
	sgl.begin_triangles()
	sgl.c4b(c.r, c.g, c.b, c.a)

	for idx in start .. end {
		renderer := renderers[idx]
		if !guard_renderer_or_skip(renderer, mut window) {
			continue
		}
		if renderer is DrawSvg {
			mut i := 0
			for i < renderer.triangles.len - 5 {
				x0 := (x + renderer.triangles[i] * tri_scale) * scale
				y0 := (y + renderer.triangles[i + 1] * tri_scale) * scale
				x1 := (x + renderer.triangles[i + 2] * tri_scale) * scale
				y1 := (y + renderer.triangles[i + 3] * tri_scale) * scale
				x2 := (x + renderer.triangles[i + 4] * tri_scale) * scale
				y2 := (y + renderer.triangles[i + 5] * tri_scale) * scale
				sgl.v2f(x0, y0)
				sgl.v2f(x1, y1)
				sgl.v2f(x2, y2)
				i += 6
			}
		}
	}

	sgl.end()
}

// draw_clipped_svg_group renders a stencil-clipped SVG group.
// Collects all DrawSvg renderers sharing the same clip_group,
// draws mask geometry to stencil, then draws content with
// stencil test.
fn draw_clipped_svg_group(renderers []Renderer, idx int, mut window Window) int {
	if idx >= renderers.len {
		return idx
	}
	if !guard_renderer_or_skip(renderers[idx], mut window) {
		return idx + 1
	}
	first := renderers[idx] as DrawSvg
	group := first.clip_group

	group_start := idx
	mut group_end := group_start
	mut has_mask := false
	mut has_content := false

	// Collect all renderers in this clip group
	for group_end < renderers.len {
		candidate := renderers[group_end]
		if !guard_renderer_or_skip(candidate, mut window) {
			group_end++
			continue
		}
		if candidate is DrawSvg {
			svg := candidate
			if svg.clip_group == group {
				if svg.is_clip_mask {
					has_mask = true
				} else {
					has_content = true
				}
				group_end++
				continue
			}
		}
		break
	}

	if !has_content {
		return group_end
	}

	if !has_mask {
		// No mask — draw content unclipped
		for i in group_start .. group_end {
			candidate := renderers[i]
			if !guard_renderer_or_skip(candidate, mut window) {
				continue
			}
			if candidate is DrawSvg && !candidate.is_clip_mask {
				draw_triangles(candidate.triangles, candidate.color, candidate.x, candidate.y,
					candidate.scale, mut window)
			}
		}
		return group_end
	}

	init_stencil_pipelines(mut window)

	// Step 1: Write clip mask to stencil buffer (ref=1)
	sgl.load_pipeline(window.pip.stencil_write)
	for i in group_start .. group_end {
		candidate := renderers[i]
		if !guard_renderer_or_skip(candidate, mut window) {
			continue
		}
		if candidate is DrawSvg && candidate.is_clip_mask {
			draw_triangles_raw(candidate.triangles, candidate.x, candidate.y, candidate.scale, mut
				window)
		}
	}

	// Step 2: Draw content where stencil == 1
	sgl.load_pipeline(window.pip.stencil_test)
	for i in group_start .. group_end {
		candidate := renderers[i]
		if !guard_renderer_or_skip(candidate, mut window) {
			continue
		}
		if candidate is DrawSvg && !candidate.is_clip_mask {
			sgl.c4b(candidate.color.r, candidate.color.g, candidate.color.b, candidate.color.a)
			draw_triangles_raw(candidate.triangles, candidate.x, candidate.y, candidate.scale, mut
				window)
		}
	}

	// Step 3: Clear stencil by re-drawing mask with ref=0
	sgl.load_pipeline(window.pip.stencil_clear)
	for i in group_start .. group_end {
		candidate := renderers[i]
		if !guard_renderer_or_skip(candidate, mut window) {
			continue
		}
		if candidate is DrawSvg && candidate.is_clip_mask {
			draw_triangles_raw(candidate.triangles, candidate.x, candidate.y, candidate.scale, mut
				window)
		}
	}

	sgl.load_default_pipeline()
	return group_end
}

// draw_triangles_raw emits triangle vertices without setting
// color (caller sets pipeline and color).
fn draw_triangles_raw(triangles []f32, x f32, y f32, tri_scale f32, mut window Window) {
	if triangles.len < 6 {
		return
	}
	scale := window.ui.scale
	sgl.begin_triangles()
	mut i := 0
	for i < triangles.len - 5 {
		x0 := (x + triangles[i] * tri_scale) * scale
		y0 := (y + triangles[i + 1] * tri_scale) * scale
		x1 := (x + triangles[i + 2] * tri_scale) * scale
		y1 := (y + triangles[i + 3] * tri_scale) * scale
		x2 := (x + triangles[i + 4] * tri_scale) * scale
		y2 := (y + triangles[i + 5] * tri_scale) * scale
		sgl.v2f(x0, y0)
		sgl.v2f(x1, y1)
		sgl.v2f(x2, y2)
		i += 6
	}
	sgl.end()
}

// renderer_draw draws a single renderer
fn renderer_draw(renderer Renderer, mut window Window) {
	if !guard_renderer_or_skip(renderer, mut window) {
		return
	}
	mut ctx := window.ui
	match renderer {
		DrawRect {
			if renderer.w <= 0 || renderer.h <= 0 {
				return
			}
			if renderer.style == .fill {
				draw_rounded_rect_filled(renderer.x, renderer.y, renderer.w, renderer.h,
					renderer.radius, renderer.color, mut window)
			} else {
				// Fallback for default thickness if DrawRect is used directly (should generally use DrawStrokeRect for strokes now)
				draw_rounded_rect_empty(renderer.x, renderer.y, renderer.w, renderer.h,
					renderer.radius, 1.0, renderer.color, mut window)
			}
		}
		DrawStrokeRect {
			if renderer.w <= 0 || renderer.h <= 0 {
				return
			}
			draw_rounded_rect_empty(renderer.x, renderer.y, renderer.w, renderer.h, renderer.radius,
				renderer.thickness, renderer.color, mut window)
		}
		DrawText {
			window.text_system.draw_text(renderer.x, renderer.y, renderer.text, renderer.cfg) or {
				// Log error with context for debugging
				log.error('Text render failed at (${renderer.x}, ${renderer.y}): ${err.msg()}')

				// Fallback: draw small magenta indicator
				draw_error_placeholder(renderer.x, renderer.y, 10, 10, mut window)
			}
		}
		DrawLayout {
			if renderer.gradient != unsafe { nil } {
				window.text_system.draw_layout_with_gradient(renderer.layout, renderer.x,
					renderer.y, renderer.gradient)
			} else {
				window.text_system.draw_layout(renderer.layout, renderer.x, renderer.y)
			}
		}
		DrawLayoutTransformed {
			if renderer.gradient != unsafe { nil } {
				window.text_system.draw_layout_transformed_with_gradient(renderer.layout,
					renderer.x, renderer.y, renderer.transform, renderer.gradient)
			} else {
				window.text_system.draw_layout_transformed(renderer.layout, renderer.x,
					renderer.y, renderer.transform)
			}
		}
		DrawLayoutPlaced {
			window.text_system.draw_layout_placed(renderer.layout, renderer.placements)
		}
		DrawClip {
			sgl.scissor_rectf(ctx.scale * renderer.x, ctx.scale * renderer.y, ctx.scale * renderer.width,
				ctx.scale * renderer.height, true)
		}
		DrawCircle {
			if renderer.fill {
				ctx.draw_circle_filled(renderer.x, renderer.y, renderer.radius, renderer.color)
			} else {
				ctx.draw_circle_empty(renderer.x, renderer.y, renderer.radius, renderer.color)
			}
		}
		DrawImage {
			ctx.draw_image(renderer.x, renderer.y, renderer.w, renderer.h, renderer.img)
		}
		DrawLine {
			ctx.draw_line_with_config(renderer.x, renderer.y, renderer.x1, renderer.y1,
				renderer.cfg)
		}
		DrawShadow {
			draw_shadow_rect(renderer.x, renderer.y, renderer.width, renderer.height,
				renderer.radius, renderer.blur_radius, renderer.color, renderer.offset_x,
				renderer.offset_y, mut window)
		}
		DrawBlur {
			draw_blur_rect(renderer.x, renderer.y, renderer.width, renderer.height, renderer.radius,
				renderer.blur_radius, renderer.color, mut window)
		}
		DrawGradient {
			draw_gradient_rect(renderer.x, renderer.y, renderer.w, renderer.h, renderer.radius,
				renderer.gradient, mut window)
		}
		DrawGradientBorder {
			draw_gradient_border(renderer.x, renderer.y, renderer.w, renderer.h, renderer.radius,
				renderer.thickness, renderer.gradient, mut window)
		}
		DrawCustomShader {
			draw_custom_shader_rect(renderer.x, renderer.y, renderer.w, renderer.h, renderer.radius,
				renderer.color, renderer.shader, mut window)
		}
		DrawSvg {
			if renderer.vertex_colors.len > 0 {
				draw_triangles_gradient(renderer.triangles, renderer.vertex_colors, renderer.x,
					renderer.y, renderer.scale, mut window)
			} else {
				draw_triangles(renderer.triangles, renderer.color, renderer.x, renderer.y,
					renderer.scale, mut window)
			}
		}
		DrawFilterComposite {
			draw_filter_composite(renderer, mut window)
		}
		DrawFilterBegin {}
		DrawFilterEnd {}
		DrawNone {}
	}
}

// draw_triangles renders triangulated geometry using SGL
fn draw_triangles(triangles []f32, c gg.Color, x f32, y f32, tri_scale f32, mut window Window) {
	if triangles.len < 6 {
		return
	}

	scale := window.ui.scale

	sgl.load_pipeline(window.ui.pipeline.alpha)
	sgl.begin_triangles()
	sgl.c4b(c.r, c.g, c.b, c.a)

	mut i := 0
	for i < triangles.len - 5 {
		// Triangle vertices
		x0 := (x + triangles[i] * tri_scale) * scale
		y0 := (y + triangles[i + 1] * tri_scale) * scale
		x1 := (x + triangles[i + 2] * tri_scale) * scale
		y1 := (y + triangles[i + 3] * tri_scale) * scale
		x2 := (x + triangles[i + 4] * tri_scale) * scale
		y2 := (y + triangles[i + 5] * tri_scale) * scale

		sgl.v2f(x0, y0)
		sgl.v2f(x1, y1)
		sgl.v2f(x2, y2)

		i += 6
	}

	sgl.end()
}

// draw_triangles_gradient renders triangles with per-vertex colors.
fn draw_triangles_gradient(triangles []f32, vertex_colors []gg.Color, x f32, y f32, tri_scale f32, mut window Window) {
	if triangles.len < 6 || vertex_colors.len < 3 {
		return
	}

	scale := window.ui.scale

	sgl.load_pipeline(window.ui.pipeline.alpha)
	sgl.begin_triangles()

	mut vi := 0 // vertex index into vertex_colors
	mut i := 0
	for i < triangles.len - 5 {
		if vi + 2 < vertex_colors.len {
			c0 := vertex_colors[vi]
			c1 := vertex_colors[vi + 1]
			c2 := vertex_colors[vi + 2]

			x0 := (x + triangles[i] * tri_scale) * scale
			y0 := (y + triangles[i + 1] * tri_scale) * scale
			x1 := (x + triangles[i + 2] * tri_scale) * scale
			y1 := (y + triangles[i + 3] * tri_scale) * scale
			x2 := (x + triangles[i + 4] * tri_scale) * scale
			y2 := (y + triangles[i + 5] * tri_scale) * scale

			sgl.c4b(c0.r, c0.g, c0.b, c0.a)
			sgl.v2f(x0, y0)
			sgl.c4b(c1.r, c1.g, c1.b, c1.a)
			sgl.v2f(x1, y1)
			sgl.c4b(c2.r, c2.g, c2.b, c2.a)
			sgl.v2f(x2, y2)
		}

		i += 6
		vi += 3
	}

	sgl.end()
}
