module gui

import gg
import log

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

	for tpath in cached.render_paths {
		emit_svg_path_renderer(tpath, color, shape.x, shape.y, cached.scale, mut window)
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

// draw_error_placeholder draws a magenta box with a white cross.
fn draw_error_placeholder(x f32, y f32, w f32, h f32, mut window Window) {
	draw_rounded_rect_filled(x, y, w, h, 0, magenta.to_gx_color(), mut window)
	draw_rounded_rect_empty(x, y, w, h, 0, 1.0, white.to_gx_color(), mut window)
	window.ui.draw_line(x, y, x + w, y + h, white.to_gx_color())
	window.ui.draw_line(x + w, y, x, y + h, white.to_gx_color())
}
