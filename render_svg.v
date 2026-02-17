module gui

import gg
import log
import vglyph
import math

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
		draw_error_placeholder(shape.x, shape.y, shape.width, shape.height, mut window)
		return
	}

	color := if shape.disabled { dim_alpha(shape.color) } else { shape.color }

	// Clip SVG content to shape bounds (viewBox overflow)
	window.renderers << DrawClip{
		x:      shape.x
		y:      shape.y
		width:  shape.width
		height: shape.height
	}

	for tpath in cached.triangles {
		// Use shape color if set (monochrome override), otherwise path color
		has_vcols := tpath.vertex_colors.len > 0
		c := if color.a > 0 && !has_vcols { color } else { tpath.color }
		mut gx_vcols := []gg.Color{}
		if has_vcols && color.a == 0 {
			gx_vcols = []gg.Color{cap: tpath.vertex_colors.len}
			for vc in tpath.vertex_colors {
				gx_vcols << vc.to_gx_color()
			}
		}
		window.renderers << DrawSvg{
			triangles:     tpath.triangles
			color:         c.to_gx_color()
			vertex_colors: gx_vcols
			x:             shape.x
			y:             shape.y
			scale:         cached.scale
			is_clip_mask:  tpath.is_clip_mask
			clip_group:    tpath.clip_group
		}
	}

	// Emit text elements
	for svg_txt in cached.texts {
		render_svg_text(svg_txt, shape.x, shape.y, cached.scale, cached.gradients, mut
			window)
	}
	// Emit textPath elements
	for tp in cached.text_paths {
		render_svg_text_path(tp, cached.defs_paths, shape.x, shape.y, cached.scale, cached.gradients, mut
			window)
	}

	// Emit filtered groups
	for i, fg in cached.filtered_groups {
		window.renderers << DrawFilterBegin{
			group_idx: i
			x:         shape.x
			y:         shape.y
			scale:     cached.scale
			cached:    cached
		}
		// Emit DrawSvg for filtered group triangles
		for tpath in fg.triangles {
			has_vcols := tpath.vertex_colors.len > 0
			c := if color.a > 0 && !has_vcols { color } else { tpath.color }
			mut gx_vcols := []gg.Color{}
			if has_vcols && color.a == 0 {
				gx_vcols = []gg.Color{cap: tpath.vertex_colors.len}
				for vc in tpath.vertex_colors {
					gx_vcols << vc.to_gx_color()
				}
			}
			window.renderers << DrawSvg{
				triangles:     tpath.triangles
				color:         c.to_gx_color()
				vertex_colors: gx_vcols
				x:             shape.x
				y:             shape.y
				scale:         cached.scale
				is_clip_mask:  tpath.is_clip_mask
				clip_group:    tpath.clip_group
			}
		}
		// Emit text elements for filtered group
		for svg_txt in fg.texts {
			render_svg_text(svg_txt, shape.x, shape.y, cached.scale, fg.gradients, mut
				window)
		}
		// Emit textPath elements for filtered group
		for tp in fg.text_paths {
			render_svg_text_path(tp, cached.defs_paths, shape.x, shape.y, cached.scale,
				fg.gradients, mut window)
		}
		window.renderers << DrawFilterEnd{}
	}

	// Restore parent clip
	window.renderers << clip
}

// render_svg_text converts an SvgText into a DrawText renderer.
fn render_svg_text(t SvgText, shape_x f32, shape_y f32, scale f32, gradients map[string]SvgGradientDef, mut window Window) {
	if t.text.len == 0 {
		return
	}
	typeface := match true {
		t.bold && t.italic { vglyph.Typeface.bold_italic }
		t.bold { vglyph.Typeface.bold }
		t.italic { vglyph.Typeface.italic }
		else { vglyph.Typeface.regular }
	}
	// Convert SVG gradient def to vglyph gradient config
	gradient := if t.fill_gradient_id.len > 0 {
		if gdef := gradients[t.fill_gradient_id] {
			mut stops := []vglyph.GradientStop{cap: gdef.stops.len}
			for s in gdef.stops {
				stops << vglyph.GradientStop{
					color:    s.color.to_gx_color()
					position: s.offset
				}
			}
			dx := gdef.x2 - gdef.x1
			dy := gdef.y2 - gdef.y1
			dir := if math.abs(dx) >= math.abs(dy) {
				vglyph.GradientDirection.horizontal
			} else {
				vglyph.GradientDirection.vertical
			}
			&vglyph.GradientConfig{
				stops:     stops
				direction: dir
			}
		} else {
			unsafe { &vglyph.GradientConfig(nil) }
		}
	} else {
		unsafe { &vglyph.GradientConfig(nil) }
	}
	text_style := TextStyle{
		family:         t.font_family
		size:           t.font_size * scale
		typeface:       typeface
		color:          if t.opacity < 1.0 {
			Color{t.color.r, t.color.g, t.color.b, u8(f32(t.color.a) * t.opacity)}
		} else {
			t.color
		}
		underline:      t.underline
		strikethrough:  t.strikethrough
		letter_spacing: t.letter_spacing * scale
		gradient:       gradient
		stroke_width:   t.stroke_width * scale
		stroke_color:   if t.opacity < 1.0 {
			Color{t.stroke_color.r, t.stroke_color.g, t.stroke_color.b, u8(f32(t.stroke_color.a) * t.opacity)}
		} else {
			t.stroke_color
		}
	}
	cfg := text_style.to_vglyph_cfg()

	// Measure for anchor adjustment
	tw := window.text_system.text_width(t.text, cfg) or { 0 }
	fh := window.text_system.font_height(cfg) or { t.font_size * scale }
	// Approximate baseline→top: ascent ≈ 80% of font height
	ascent := fh * 0.8

	mut x := shape_x + t.x * scale
	y := shape_y + t.y * scale - ascent

	// text-anchor adjustment
	if t.anchor == 1 {
		x -= tw / 2
	} else if t.anchor == 2 {
		x -= tw
	}

	window.renderers << DrawText{
		text: t.text
		cfg:  cfg
		x:    x
		y:    y
	}
}

// draw_triangles renders triangulated geometry using SGL

// draw_error_placeholder draws a magenta box with a white cross to indicate a missing resource.
fn draw_error_placeholder(x f32, y f32, w f32, h f32, mut window Window) {
	draw_rounded_rect_filled(x, y, w, h, 0, magenta.to_gx_color(), mut window)
	draw_rounded_rect_empty(x, y, w, h, 0, 1.0, white.to_gx_color(), mut window)
	// Draw a white cross
	window.ui.draw_line(x, y, x + w, y + h, white.to_gx_color())
	window.ui.draw_line(x + w, y, x, y + h, white.to_gx_color())
}
