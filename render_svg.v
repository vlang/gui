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

	// Center SVG content within container (aspect-preserving scale
	// may leave unused space in one dimension).
	sx := shape.x + (shape.width - cached.width * cached.scale) / 2
	sy := shape.y + (shape.height - cached.height * cached.scale) / 2

	// Clip to the scaled viewBox area, not the full container.
	// SVG elements beyond the viewBox must be clipped.
	emit_renderer(DrawClip{
		x:      sx
		y:      sy
		width:  cached.width * cached.scale
		height: cached.height * cached.scale
	}, mut window)

	if cached.has_animations {
		render_svg_animated(cached, color, shape.resource, sx, sy, mut window)
	} else {
		for tpath in cached.render_paths {
			emit_svg_path_renderer(tpath, color, sx, sy, cached.scale, mut window)
		}
	}

	// Emit text elements
	for draw in cached.text_draws {
		emit_cached_svg_text_draw(draw, sx, sy, mut window)
	}
	// Emit textPath elements
	for tp in cached.text_paths {
		render_svg_text_path(tp, cached.defs_paths, sx, sy, cached.scale, mut window)
	}

	// Emit filtered groups
	for i, fg in cached.filtered_groups {
		emit_renderer(DrawFilterBegin{
			group_idx: i
			x:         sx
			y:         sy
			scale:     cached.scale
			cached:    cached
		}, mut window)
		for tpath in fg.render_paths {
			emit_svg_path_renderer(tpath, color, sx, sy, cached.scale, mut window)
		}
		for draw in fg.text_draws {
			emit_cached_svg_text_draw(draw, sx, sy, mut window)
		}
		for tp in fg.text_paths {
			render_svg_text_path(tp, cached.defs_paths, sx, sy, cached.scale, mut window)
		}
		emit_renderer(DrawFilterEnd{}, mut window)
	}

	// Restore parent clip
	emit_renderer(clip, mut window)
}

// render_svg_animated emits paths with per-group animation transforms.
fn render_svg_animated(cached &CachedSvg, color Color, res_key string, sx f32, sy f32, mut window Window) {
	now_ns := time.now().unix_nano()
	// Update staleness tracker so animation loop knows SVG is alive.
	mut anim_seen := state_map[string, i64](mut window, ns_svg_anim_seen, cap_moderate)
	mut anim_start := state_map[string, i64](mut window, ns_svg_anim_start, cap_moderate)
	anim_seen.set(res_key, now_ns)
	start_ns := if v := anim_start.get(res_key) {
		v
	} else {
		anim_start.set(res_key, now_ns)
		now_ns
	}
	elapsed_s := f32(now_ns - start_ns) / 1_000_000_000.0
	mut anim_vals := window.scratch.take_svg_anim_vals()
	mut transform_tris := window.scratch.take_svg_transform_tris()
	window.scratch.svg_group_matrices.clear()
	window.scratch.svg_group_opacities.clear()
	defer {
		window.scratch.put_svg_anim_vals(mut anim_vals)
		window.scratch.put_svg_transform_tris(mut transform_tris)
		window.scratch.trim_svg_group_maps()
	}

	// Evaluate animations: build transform matrix and opacity
	// per group_id. Currently last-wins if a group has multiple
	// animateTransform elements. Composing via matrix multiply
	// would be correct but V has a compiler bug with
	// map[string][6]f32: passing the map to a helper function
	// while assigning to it, or using `in`/optional access on
	// fixed-array-valued maps, silently produces wrong results
	// (zero matrix instead of identity → geometry collapses).
	// Do NOT extract a compose helper or use `if gid in
	// group_matrices { matrix_multiply(...) }` until the V
	// compiler issue is resolved.
	for anim in cached.animations {
		vals_len := svg.evaluate_animation_into(anim, elapsed_s, mut anim_vals)
		if vals_len == 0 {
			continue
		}
		match anim.anim_type {
			.rotate {
				angle := anim_vals[0]
				cx := if vals_len >= 2 { anim_vals[1] } else { f32(0) }
				cy := if vals_len >= 3 { anim_vals[2] } else { f32(0) }
				m := svg.build_rotation_matrix(angle, cx, cy)
				window.scratch.svg_group_matrices[anim.target_id] = m
			}
			.scale {
				asx := anim_vals[0]
				asy := if vals_len >= 2 { anim_vals[1] } else { asx }
				m := svg.build_scale_matrix(asx, asy)
				window.scratch.svg_group_matrices[anim.target_id] = m
			}
			.translate {
				tx := anim_vals[0]
				ty := if vals_len >= 2 { anim_vals[1] } else { f32(0) }
				m := svg.build_translate_matrix(tx, ty)
				window.scratch.svg_group_matrices[anim.target_id] = m
			}
			.opacity {
				window.scratch.svg_group_opacities[anim.target_id] = anim_vals[0]
			}
		}
	}

	for tpath in cached.render_paths {
		gid := tpath.group_id
		has_matrix := gid in window.scratch.svg_group_matrices
		has_opacity := gid in window.scratch.svg_group_opacities
		if gid.len > 0 && (has_matrix || has_opacity) {
			tris := if has_matrix {
				// Build in scratch then clone so renderer data stays stable.
				transform_tris = apply_transform_to_triangles_into(tpath.triangles, window.scratch.svg_group_matrices[gid], mut
					transform_tris)
				transform_tris.clone()
			} else {
				tpath.triangles
			}
			c := if has_opacity {
				opacity := window.scratch.svg_group_opacities[gid]
				gg.Color{tpath.color.r, tpath.color.g, tpath.color.b, u8(f32(tpath.color.a) * opacity)}
			} else {
				tpath.color
			}
			emit_svg_path_renderer(CachedSvgPath{
				...tpath
				triangles: tris
				color:     c
			}, color, sx, sy, cached.scale, mut window)
		} else {
			emit_svg_path_renderer(tpath, color, sx, sy, cached.scale, mut window)
		}
	}
}

// apply_transform_to_triangles applies affine matrix m to triangle
// vertices. Triangles are in viewBox space; matrix operates in
// viewBox space (e.g. rotation center from SVG attributes).
fn apply_transform_to_triangles(tris []f32, m [6]f32) []f32 {
	mut out := []f32{}
	return apply_transform_to_triangles_into(tris, m, mut out)
}

fn apply_transform_to_triangles_into(tris []f32, m [6]f32, mut out []f32) []f32 {
	out.clear()
	if tris.len == 0 {
		return out
	}
	if out.cap < tris.len {
		out = []f32{cap: tris.len}
	}
	mut i := 0
	for i < tris.len - 1 {
		x := tris[i]
		y := tris[i + 1]
		out << m[0] * x + m[2] * y + m[4]
		out << m[1] * x + m[3] * y + m[5]
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
