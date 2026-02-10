module gui

import gg
import math
import strings

struct PdfRenderContext {
	page_width    f32
	page_height   f32
	source_width  f32
	source_height f32
	scale         f32
	margins       PrintMargins
}

fn (ctx PdfRenderContext) map_x(x f32) f32 {
	return ctx.margins.left + x * ctx.scale
}

fn (ctx PdfRenderContext) map_y(y f32) f32 {
	return ctx.page_height - ctx.margins.top - y * ctx.scale
}

fn (ctx PdfRenderContext) map_rect_y(y f32, h f32) f32 {
	return ctx.page_height - ctx.margins.top - (y + h) * ctx.scale
}

fn pdf_num(value f32) string {
	if math.is_nan(value) || math.is_inf(value, 0) {
		return '0'
	}
	mut s := '${value:.3f}'
	for s.ends_with('0') && s.contains('.') {
		s = s[..s.len - 1]
	}
	if s.ends_with('.') {
		return s[..s.len - 1]
	}
	return s
}

fn pdf_color(value u8) string {
	return pdf_num(f32(value) / 255.0)
}

fn pdf_escape_text(text string) string {
	mut out := strings.new_builder(text.len + 8)
	for ch in text.runes() {
		match ch {
			`\\` {
				out.write_string('\\\\')
			}
			`(` {
				out.write_string('\\(')
			}
			`)` {
				out.write_string('\\)')
			}
			`\r`, `\n`, `\t` {
				out.write_u8(` `)
			}
			else {
				if ch < 32 || ch > 126 {
					out.write_u8(`?`)
				} else {
					out.write_rune(ch)
				}
			}
		}
	}
	return out.bytestr()
}

fn pdf_pad_10(value int) string {
	s := value.str()
	if s.len >= 10 {
		return s
	}
	return '0'.repeat(10 - s.len) + s
}

fn pdf_collect_alphas(renderers []Renderer) []u8 {
	mut seen := map[u8]bool{}
	seen[u8(255)] = true

	for renderer in renderers {
		match renderer {
			DrawRect {
				seen[renderer.color.a] = true
			}
			DrawStrokeRect {
				seen[renderer.color.a] = true
			}
			DrawCircle {
				seen[renderer.color.a] = true
			}
			DrawLine {
				seen[renderer.cfg.color.a] = true
			}
			DrawText {
				seen[renderer.cfg.style.color.a] = true
			}
			DrawSvg {
				seen[renderer.color.a] = true
			}
			DrawLayout {
				for item in renderer.layout.items {
					seen[item.color.a] = true
				}
			}
			else {}
		}
	}

	mut alphas := []u8{cap: seen.len}
	for alpha, _ in seen {
		alphas << alpha
	}
	alphas.sort()
	return alphas
}

fn pdf_extgstate_dict(alphas []u8) string {
	mut out := strings.new_builder(128 + alphas.len * 20)
	out.write_string('/ExtGState << ')
	for alpha in alphas {
		opacity := f32(alpha) / 255.0
		out.write_string('/GS${alpha} << /ca ${pdf_num(opacity)} /CA ${pdf_num(opacity)} >> ')
	}
	out.write_string('>>')
	return out.bytestr()
}

fn pdf_set_fill_color(mut out strings.Builder, color gg.Color) {
	out.writeln('/GS${color.a} gs')
	out.writeln('${pdf_color(color.r)} ${pdf_color(color.g)} ${pdf_color(color.b)} rg')
}

fn pdf_set_stroke_color(mut out strings.Builder, color gg.Color) {
	out.writeln('/GS${color.a} gs')
	out.writeln('${pdf_color(color.r)} ${pdf_color(color.g)} ${pdf_color(color.b)} RG')
}

fn pdf_draw_circle(mut out strings.Builder, ctx PdfRenderContext, x f32, y f32, radius f32, fill bool) {
	if radius <= 0 {
		return
	}
	cx := ctx.map_x(x)
	cy := ctx.map_y(y)
	r := radius * ctx.scale
	k := f32(0.5522847498) * r

	out.writeln('${pdf_num(cx + r)} ${pdf_num(cy)} m')
	out.writeln('${pdf_num(cx + r)} ${pdf_num(cy + k)} ${pdf_num(cx + k)} ${pdf_num(cy + r)} ${pdf_num(cx)} ${pdf_num(
		cy + r)} c')
	out.writeln('${pdf_num(cx - k)} ${pdf_num(cy + r)} ${pdf_num(cx - r)} ${pdf_num(cy + k)} ${pdf_num(cx - r)} ${pdf_num(cy)} c')
	out.writeln('${pdf_num(cx - r)} ${pdf_num(cy - k)} ${pdf_num(cx - k)} ${pdf_num(cy - r)} ${pdf_num(cx)} ${pdf_num(cy - r)} c')
	out.writeln('${pdf_num(cx + k)} ${pdf_num(cy - r)} ${pdf_num(cx + r)} ${pdf_num(cy - k)} ${pdf_num(
		cx + r)} ${pdf_num(cy)} c')
	out.writeln(if fill { 'f' } else { 'S' })
}

fn pdf_draw_image_placeholder(mut out strings.Builder, ctx PdfRenderContext, image DrawImage) {
	w := image.w * ctx.scale
	h := image.h * ctx.scale
	if w <= 0 || h <= 0 {
		return
	}
	x := ctx.map_x(image.x)
	y := ctx.map_rect_y(image.y, image.h)
	out.writeln('/GS255 gs')
	out.writeln('0.7 0.7 0.7 RG')
	out.writeln('0.5 w')
	out.writeln('${pdf_num(x)} ${pdf_num(y)} ${pdf_num(w)} ${pdf_num(h)} re S')
	out.writeln('${pdf_num(x)} ${pdf_num(y)} m ${pdf_num(x + w)} ${pdf_num(y + h)} l S')
	out.writeln('${pdf_num(x)} ${pdf_num(y + h)} m ${pdf_num(x + w)} ${pdf_num(y)} l S')
}

fn pdf_draw_svg(mut out strings.Builder, ctx PdfRenderContext, renderer DrawSvg) {
	if renderer.color.a == 0 || renderer.triangles.len < 6 {
		return
	}
	pdf_set_fill_color(mut out, renderer.color)
	mut i := 0
	for i < renderer.triangles.len - 5 {
		x0 := ctx.map_x(renderer.x + renderer.triangles[i] * renderer.scale)
		y0 := ctx.map_y(renderer.y + renderer.triangles[i + 1] * renderer.scale)
		x1 := ctx.map_x(renderer.x + renderer.triangles[i + 2] * renderer.scale)
		y1 := ctx.map_y(renderer.y + renderer.triangles[i + 3] * renderer.scale)
		x2 := ctx.map_x(renderer.x + renderer.triangles[i + 4] * renderer.scale)
		y2 := ctx.map_y(renderer.y + renderer.triangles[i + 5] * renderer.scale)
		out.writeln('${pdf_num(x0)} ${pdf_num(y0)} m ${pdf_num(x1)} ${pdf_num(y1)} l ${pdf_num(x2)} ${pdf_num(y2)} l h f')
		i += 6
	}
}

fn pdf_draw_text(mut out strings.Builder, ctx PdfRenderContext, text string, x f32, y f32, size f32, color gg.Color) {
	if text.len == 0 || color.a == 0 {
		return
	}
	mut font_size := size
	if font_size <= 0 {
		font_size = 12
	}
	pdf_set_fill_color(mut out, color)
	pdf_x := ctx.map_x(x)
	pdf_y := ctx.map_y(y + font_size * 0.8)
	escaped := pdf_escape_text(text)
	out.writeln('BT')
	out.writeln('/F1 ${pdf_num(font_size * ctx.scale)} Tf')
	out.writeln('${pdf_num(pdf_x)} ${pdf_num(pdf_y)} Td')
	out.writeln('(${escaped}) Tj')
	out.writeln('ET')
}

fn pdf_render_stream(renderers []Renderer, ctx PdfRenderContext) string {
	mut out := strings.new_builder(4096)
	mut clip_active := false
	out.writeln('q')

	for renderer in renderers {
		match renderer {
			DrawClip {
				if clip_active {
					out.writeln('Q')
				}
				if renderer.width <= 0 || renderer.height <= 0 {
					clip_active = false
					continue
				}
				x := ctx.map_x(renderer.x)
				y := ctx.map_rect_y(renderer.y, renderer.height)
				w := renderer.width * ctx.scale
				h := renderer.height * ctx.scale
				out.writeln('q')
				out.writeln('${pdf_num(x)} ${pdf_num(y)} ${pdf_num(w)} ${pdf_num(h)} re W n')
				clip_active = true
			}
			DrawRect {
				if renderer.w <= 0 || renderer.h <= 0 || renderer.color.a == 0 {
					continue
				}
				x := ctx.map_x(renderer.x)
				y := ctx.map_rect_y(renderer.y, renderer.h)
				w := renderer.w * ctx.scale
				h := renderer.h * ctx.scale
				if renderer.style == .fill {
					pdf_set_fill_color(mut out, renderer.color)
					out.writeln('${pdf_num(x)} ${pdf_num(y)} ${pdf_num(w)} ${pdf_num(h)} re f')
				} else {
					pdf_set_stroke_color(mut out, renderer.color)
					out.writeln('1 w')
					out.writeln('${pdf_num(x)} ${pdf_num(y)} ${pdf_num(w)} ${pdf_num(h)} re S')
				}
			}
			DrawStrokeRect {
				if renderer.w <= 0 || renderer.h <= 0 || renderer.color.a == 0 {
					continue
				}
				x := ctx.map_x(renderer.x)
				y := ctx.map_rect_y(renderer.y, renderer.h)
				w := renderer.w * ctx.scale
				h := renderer.h * ctx.scale
				pdf_set_stroke_color(mut out, renderer.color)
				line_width := f32_max(0.25, renderer.thickness * ctx.scale)
				out.writeln('${pdf_num(line_width)} w')
				out.writeln('${pdf_num(x)} ${pdf_num(y)} ${pdf_num(w)} ${pdf_num(h)} re S')
			}
			DrawLine {
				if renderer.cfg.color.a == 0 {
					continue
				}
				pdf_set_stroke_color(mut out, renderer.cfg.color)
				line_width := f32_max(0.25, renderer.cfg.thickness * ctx.scale)
				out.writeln('${pdf_num(line_width)} w')
				x0 := ctx.map_x(renderer.x)
				y0 := ctx.map_y(renderer.y)
				x1 := ctx.map_x(renderer.x1)
				y1 := ctx.map_y(renderer.y1)
				out.writeln('${pdf_num(x0)} ${pdf_num(y0)} m ${pdf_num(x1)} ${pdf_num(y1)} l S')
			}
			DrawCircle {
				if renderer.color.a == 0 {
					continue
				}
				if renderer.fill {
					pdf_set_fill_color(mut out, renderer.color)
				} else {
					pdf_set_stroke_color(mut out, renderer.color)
					out.writeln('1 w')
				}
				pdf_draw_circle(mut out, ctx, renderer.x, renderer.y, renderer.radius,
					renderer.fill)
			}
			DrawText {
				pdf_draw_text(mut out, ctx, renderer.text, renderer.x, renderer.y, renderer.cfg.style.size,
					renderer.cfg.style.color)
			}
			DrawLayout {
				for item in renderer.layout.items {
					if item.is_object || item.run_text.trim_space().len == 0 {
						continue
					}
					size := f32(item.ascent + item.descent)
					pdf_draw_text(mut out, ctx, item.run_text, renderer.x + f32(item.x),
						renderer.y + f32(item.y - item.ascent), size, item.color)
				}
			}
			DrawSvg {
				pdf_draw_svg(mut out, ctx, renderer)
			}
			DrawImage {
				pdf_draw_image_placeholder(mut out, ctx, renderer)
			}
			DrawShadow, DrawBlur, DrawGradient, DrawGradientBorder, DrawCustomShader, DrawNone {}
		}
	}

	if clip_active {
		out.writeln('Q')
	}
	out.writeln('Q')
	return out.bytestr()
}

fn pdf_encode(objects []string) string {
	mut out := strings.new_builder(2048)
	out.writeln('%PDF-1.4')

	mut offsets := []int{len: objects.len + 1, init: 0}
	for i, object_body in objects {
		offsets[i + 1] = out.len
		out.writeln('${i + 1} 0 obj')
		out.write_string(object_body)
		if !object_body.ends_with('\n') {
			out.writeln('')
		}
		out.writeln('endobj')
	}

	start_xref := out.len
	out.writeln('xref')
	out.writeln('0 ${offsets.len}')
	out.writeln('0000000000 65535 f ')
	for i in 1 .. offsets.len {
		out.writeln('${pdf_pad_10(offsets[i])} 00000 n ')
	}

	out.writeln('trailer')
	out.writeln('<< /Size ${offsets.len} /Root 1 0 R >>')
	out.writeln('startxref')
	out.writeln('${start_xref}')
	out.writeln('%%EOF')
	return out.bytestr()
}

fn pdf_render_document(renderers []Renderer, source_width f32, source_height f32, cfg PdfExportCfg) !string {
	page_width, page_height := print_page_size(cfg.paper, cfg.orientation)
	content_width := page_width - cfg.margins.left - cfg.margins.right
	content_height := page_height - cfg.margins.top - cfg.margins.bottom
	if content_width <= 0 || content_height <= 0 {
		return error('invalid page/margin configuration')
	}
	if source_width <= 0 || source_height <= 0 {
		return error('source dimensions must be positive')
	}

	mut scale := f32(1.0)
	if cfg.fit_to_page {
		scale_x := content_width / source_width
		scale_y := content_height / source_height
		scale = f32_min(scale_x, scale_y)
	}
	if scale <= 0 {
		return error('computed invalid scale')
	}

	ctx := PdfRenderContext{
		page_width:    page_width
		page_height:   page_height
		source_width:  source_width
		source_height: source_height
		scale:         scale
		margins:       cfg.margins
	}
	alphas := pdf_collect_alphas(renderers)
	extgstate := pdf_extgstate_dict(alphas)
	stream := pdf_render_stream(renderers, ctx)

	page_obj :=
		'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${pdf_num(page_width)} ${pdf_num(page_height)}]' +
		' /Resources << /Font << /F1 << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> >> ' +
		'${extgstate} >> /Contents 4 0 R >>'
	content_obj := '<< /Length ${stream.len} >>\nstream\n${stream}endstream'
	objects := [
		'<< /Type /Catalog /Pages 2 0 R >>',
		'<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
		page_obj,
		content_obj,
	]
	return pdf_encode(objects)
}
