module gui

import gg
import log
import svg
import time

fn emit_error_placeholder(x f32, y f32, w f32, h f32, mut window Window) {
	if w <= 0 || h <= 0 {
		return
	}
	emit_renderer(DrawRect{
		x:     x
		y:     y
		w:     w
		h:     h
		color: magenta.to_gx_color()
		style: .fill
	}, mut window)
	emit_renderer(DrawStrokeRect{
		x:         x
		y:         y
		w:         w
		h:         h
		radius:    0
		color:     white.to_gx_color()
		thickness: 1
	}, mut window)
}

@[inline]
fn emit_svg_path_renderer(path CachedSvgPath, tint Color, x f32, y f32, scale f32, mut window Window) {
	has_vcols := path.vertex_colors.len > 0
	color := if tint.a > 0 && !has_vcols {
		tint
	} else {
		rgba(path.color.r, path.color.g, path.color.b, path.color.a)
	}
	vertex_colors := if has_vcols && tint.a == 0 {
		unsafe { path.vertex_colors }
	} else {
		path.vertex_colors[..0]
	}
	emit_renderer(DrawSvg{
		triangles:     path.triangles
		color:         color.to_gx_color()
		vertex_colors: vertex_colors
		x:             x
		y:             y
		scale:         scale
		is_clip_mask:  path.is_clip_mask
		clip_group:    path.clip_group
	}, mut window)
}

@[inline]
fn emit_cached_svg_text_draw(draw CachedSvgTextDraw, shape_x f32, shape_y f32, mut window Window) {
	emit_renderer(DrawText{
		text: draw.text
		cfg:  draw.cfg
		x:    shape_x + draw.x
		y:    shape_y + draw.y
	}, mut window)
}

// render_svg renders an SVG shape
fn render_svg(mut shape Shape, clip DrawClip, mut window Window) {
	dr := gg.Rect{
		x:      shape.x
		y:      shape.y
		width:  shape.width
		height: shape.height
	}
	if !rects_overlap(dr, clip) {
		shape.disabled = true
		return
	}

	cached := window.load_svg(shape.resource, shape.width, shape.height) or {
		log.error('${@FILE_LINE} > ${err.msg()}')
		emit_error_placeholder(shape.x, shape.y, shape.width, shape.height, mut window)
		return
	}

	color := if shape.disabled { dim_alpha(shape.color) } else { shape.color }

	// Clip SVG content to shape bounds (viewBox overflow)
	emit_renderer(DrawClip{
		x:      shape.x
		y:      shape.y
		width:  shape.width
		height: shape.height
	}, mut window)

	if cached.has_animations {
		render_svg_animated(cached, color, shape, mut window)
	} else {
		for tpath in cached.render_paths {
			emit_svg_path_renderer(tpath, color, shape.x, shape.y, cached.scale, mut window)
		}
	}

	// Emit text elements
	for draw in cached.text_draws {
		emit_cached_svg_text_draw(draw, shape.x, shape.y, mut window)
	}
	// Emit textPath elements
	for tp in cached.text_paths {
		render_svg_text_path(tp, cached.defs_paths, shape.x, shape.y, cached.scale, mut
			window)
	}

	// Emit filtered groups
	for i, fg in cached.filtered_groups {
		emit_renderer(DrawFilterBegin{
			group_idx: i
			x:         shape.x
			y:         shape.y
			scale:     cached.scale
			cached:    cached
		}, mut window)
		for tpath in fg.render_paths {
			emit_svg_path_renderer(tpath, color, shape.x, shape.y, cached.scale, mut window)
		}
		for draw in fg.text_draws {
			emit_cached_svg_text_draw(draw, shape.x, shape.y, mut window)
		}
		for tp in fg.text_paths {
			render_svg_text_path(tp, cached.defs_paths, shape.x, shape.y, cached.scale, mut
				window)
		}
		emit_renderer(DrawFilterEnd{}, mut window)
	}

	// Restore parent clip
	emit_renderer(clip, mut window)
}

// render_svg_animated emits paths with per-group animation transforms.
fn render_svg_animated(cached &CachedSvg, color Color, shape &Shape, mut window Window) {
	// Get/init animation start time
	res_key := shape.resource
	start_ns := if v := window.view_state.svg_anim_start.get(res_key) {
		v
	} else {
		now_ns := time.now().unix_nano()
		window.view_state.svg_anim_start.set(res_key, now_ns)
		now_ns
	}
	elapsed_s := f32(time.now().unix_nano() - start_ns) / 1_000_000_000.0

	// Evaluate animations: build transform matrix and opacity per group_id
	mut group_matrices := map[string][6]f32{}
	mut group_opacities := map[string]f32{}
	for anim in cached.animations {
		vals := svg.evaluate_animation(anim, elapsed_s)
		if vals.len == 0 {
			continue
		}
		match anim.anim_type {
			.rotate {
				angle := vals[0]
				cx := if vals.len >= 2 { vals[1] } else { f32(0) }
				cy := if vals.len >= 3 { vals[2] } else { f32(0) }
				m := svg.build_rotation_matrix(angle, cx, cy)
				group_matrices[anim.target_id] = m
			}
			.scale {
				sx := vals[0]
				sy := if vals.len >= 2 { vals[1] } else { sx }
				m := svg.build_scale_matrix(sx, sy)
				group_matrices[anim.target_id] = m
			}
			.translate {
				tx := vals[0]
				ty := if vals.len >= 2 { vals[1] } else { f32(0) }
				m := svg.build_translate_matrix(tx, ty)
				group_matrices[anim.target_id] = m
			}
			.opacity {
				group_opacities[anim.target_id] = vals[0]
			}
		}
	}

	for tpath in cached.render_paths {
		gid := tpath.group_id
		has_matrix := gid in group_matrices
		has_opacity := gid in group_opacities
		if gid.len > 0 && (has_matrix || has_opacity) {
			mut anim_path := tpath
			if has_matrix {
				anim_path = CachedSvgPath{
					...tpath
					triangles: apply_transform_to_triangles(tpath.triangles, group_matrices[gid],
						cached.scale)
				}
			}
			if has_opacity {
				opacity := group_opacities[gid]
				c := anim_path.color
				anim_path = CachedSvgPath{
					...anim_path
					color: gg.Color{c.r, c.g, c.b, u8(f32(c.a) * opacity)}
				}
			}
			emit_svg_path_renderer(anim_path, color, shape.x, shape.y, cached.scale, mut
				window)
		} else {
			emit_svg_path_renderer(tpath, color, shape.x, shape.y, cached.scale, mut window)
		}
	}
}

// apply_transform_to_triangles transforms triangle vertices by affine
// matrix m. Triangles are in scaled viewBox coords: divide by scale,
// transform in viewBox space, multiply back by scale.
fn apply_transform_to_triangles(tris []f32, m [6]f32, scale f32) []f32 {
	mut out := []f32{len: tris.len}
	inv_scale := if scale > 0 { 1.0 / scale } else { f32(1) }
	mut i := 0
	for i < tris.len - 1 {
		x := tris[i] * inv_scale
		y := tris[i + 1] * inv_scale
		out[i] = (m[0] * x + m[2] * y + m[4]) * scale
		out[i + 1] = (m[1] * x + m[3] * y + m[5]) * scale
		i += 2
	}
	return out
}

// draw_error_placeholder draws a magenta box with a white cross.
fn draw_error_placeholder(x f32, y f32, w f32, h f32, mut window Window) {
	draw_rounded_rect_filled(x, y, w, h, 0, magenta.to_gx_color(), mut window)
	draw_rounded_rect_empty(x, y, w, h, 0, 1.0, white.to_gx_color(), mut window)
	window.ui.draw_line(x, y, x + w, y + h, white.to_gx_color())
	window.ui.draw_line(x + w, y, x, y + h, white.to_gx_color())
}
