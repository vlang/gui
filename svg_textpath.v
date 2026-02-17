module gui

import svg
import math
import vglyph

// render_svg_text_path places text along a referenced path
// and emits a DrawLayoutPlaced renderer.
fn render_svg_text_path(tp svg.SvgTextPath, defs_paths map[string]string, shape_x f32, shape_y f32, scale f32, gradients map[string]svg.SvgGradientDef, mut window Window) {
	d := defs_paths[tp.path_id] or { return }
	polyline := svg.flatten_defs_path(d, scale)
	if polyline.len < 4 {
		return
	}
	table := svg.build_arc_length_table(polyline)
	total_len := table[table.len - 1]
	if total_len <= 0 {
		return
	}
	// Build text config
	typeface := match true {
		tp.bold && tp.italic { vglyph.Typeface.bold_italic }
		tp.bold { vglyph.Typeface.bold }
		tp.italic { vglyph.Typeface.italic }
		else { vglyph.Typeface.regular }
	}
	text_style := TextStyle{
		family:         tp.font_family
		size:           tp.font_size * scale
		typeface:       typeface
		color:          if tp.opacity < 1.0 {
			Color{tp.color.r, tp.color.g, tp.color.b, u8(f32(tp.color.a) * tp.opacity)}
		} else {
			svg_to_color(tp.color)
		}
		letter_spacing: tp.letter_spacing * scale
		stroke_width:   tp.stroke_width * scale
		stroke_color:   if tp.opacity < 1.0 {
			Color{tp.stroke_color.r, tp.stroke_color.g, tp.stroke_color.b, u8(f32(tp.stroke_color.a) * tp.opacity)}
		} else {
			svg_to_color(tp.stroke_color)
		}
	}
	cfg := text_style.to_vglyph_cfg()
	layout := window.text_system.layout_text(tp.text, cfg) or { return }
	glyph_infos := layout.glyph_positions()
	if glyph_infos.len == 0 {
		return
	}
	// Compute total advance
	mut total_advance := f32(0)
	for gi in glyph_infos {
		total_advance += gi.advance
	}
	// Resolve startOffset
	mut offset := if tp.is_percent {
		tp.start_offset * total_len
	} else {
		tp.start_offset * scale
	}
	// text-anchor adjustment
	if tp.anchor == 1 {
		offset -= total_advance / 2
	} else if tp.anchor == 2 {
		offset -= total_advance
	}
	// method=stretch: scale advances
	advance_scale := if tp.method == 1 && total_advance > 0 {
		remaining := total_len - offset
		if remaining > 0 {
			remaining / total_advance
		} else {
			f32(1)
		}
	} else {
		f32(1)
	}
	// Place glyphs
	mut placements := []vglyph.GlyphPlacement{cap: glyph_infos.len}
	mut cur_advance := f32(0)
	for gi in glyph_infos {
		advance := gi.advance * advance_scale
		center_dist := offset + cur_advance + advance / 2
		px, py, angle := svg.sample_path_at(polyline, table, center_dist)
		cos_a := math.cosf(angle)
		sin_a := math.sinf(angle)
		gx := px - cos_a * advance / 2 + shape_x
		gy := py - sin_a * advance / 2 + shape_y
		mut final_angle := angle
		if tp.side == 1 {
			final_angle += math.pi
		}
		placements << vglyph.GlyphPlacement{
			x:     gx
			y:     gy
			angle: final_angle
		}
		cur_advance += advance
	}
	cloned := clone_layout_for_draw(&layout)
	window.renderers << DrawLayoutPlaced{
		layout:     cloned
		placements: placements
	}
}
