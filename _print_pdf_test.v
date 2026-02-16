module gui

import gg
import os
import time
import vglyph

fn test_pdf_render_document_includes_core_sections() {
	renderers := [
		Renderer(DrawClip{
			x:      0
			y:      0
			width:  140
			height: 80
		}),
		Renderer(DrawRect{
			x:     8
			y:     10
			w:     70
			h:     24
			color: gg.Color{
				r: 20
				g: 70
				b: 130
				a: 210
			}
			style: .fill
		}),
		Renderer(DrawText{
			text: 'print smoke'
			x:    12
			y:    16
			cfg:  vglyph.TextConfig{
				style: vglyph.TextStyle{
					size:  12
					color: gg.Color{
						r: 255
						g: 255
						b: 255
						a: 255
					}
				}
			}
		}),
	]

	pdf := pdf_render_document(renderers, 200, 120, PrintJob{
		output_path: 'unused.pdf'
		paper:       .letter
	}) or { panic(err.msg()) }

	assert pdf.starts_with('%PDF-1.4')
	assert pdf.contains('/Type /Catalog')
	assert pdf.contains('/Type /Page')
	assert pdf.contains('/ExtGState')
	assert pdf.contains('stream')
	assert pdf.contains('W n')
}

fn test_export_pdf_writes_file() {
	mut window := Window{}
	window.window_size = gg.Size{
		width:  220
		height: 140
	}
	window.renderers = [
		Renderer(DrawRect{
			x:     10
			y:     10
			w:     120
			h:     60
			color: gg.Color{
				r: 90
				g: 160
				b: 220
				a: 255
			}
			style: .fill
		}),
	]

	path := os.join_path(os.temp_dir(), 'gui_print_test_${time.now().unix_micro()}.pdf')
	result := window.export_print_job(PrintJob{
		output_path: path
	})
	assert result.is_ok()

	bytes := os.read_bytes(path) or { panic(err.msg()) }
	assert bytes.len > 80
	assert bytes[0] == `%`

	os.rm(path) or {}
}

fn test_pdf_render_document_honors_svg_clip_groups() {
	renderers := [
		Renderer(DrawSvg{
			triangles:    [f32(0), 0, 30, 0, 0, 30]
			color:        gg.Color{255, 0, 0, 255}
			x:            10
			y:            10
			scale:        1
			is_clip_mask: true
			clip_group:   4
		}),
		Renderer(DrawSvg{
			triangles:  [f32(0), 0, 40, 0, 0, 40]
			color:      gg.Color{0, 0, 255, 255}
			x:          20
			y:          20
			scale:      1
			clip_group: 4
		}),
	]

	pdf := pdf_render_document(renderers, 100, 100, PrintJob{
		output_path: 'unused.pdf'
	}) or { panic(err.msg()) }

	assert pdf.contains('W n')
	assert !pdf.contains('1 0 0 rg')
	assert pdf.contains('0 0 1 rg')
}

fn test_pdf_render_document_supports_transformed_layout_text() {
	layout := &vglyph.Layout{
		items: [
			vglyph.Item{
				run_text: 'tilt'
				ft_face:  unsafe { nil }
				x:        12
				y:        24
				ascent:   9
				descent:  3
				color:    gg.Color{220, 120, 40, 255}
			},
		]
	}

	renderers := [
		Renderer(DrawLayoutTransformed{
			layout:    layout
			x:         14
			y:         16
			transform: vglyph.AffineTransform{
				xx: 0.9
				xy: -0.2
				yx: 0.3
				yy: 1.1
				x0: 4
				y0: 3
			}
		}),
	]

	pdf := pdf_render_document(renderers, 120, 90, PrintJob{
		output_path: 'unused.pdf'
	}) or { panic(err.msg()) }

	assert pdf.contains(' cm')
	assert pdf.contains('(tilt) Tj')
}

fn test_pdf_render_document_svg_gradient_emits_shading_resources() {
	renderers := [
		Renderer(DrawSvg{
			triangles:     [f32(0), 0, 40, 0, 0, 40]
			color:         gg.Color{20, 20, 20, 255}
			vertex_colors: [gg.Color{255, 0, 0, 255}, gg.Color{0, 255, 0, 255},
				gg.Color{0, 0, 255, 255}]
			x:             5
			y:             6
			scale:         1
		}),
	]

	pdf := pdf_render_document(renderers, 100, 100, PrintJob{
		output_path: 'unused.pdf'
	}) or { panic(err.msg()) }

	assert pdf.contains('/Shading <<')
	assert pdf.contains('/ShadingType 4')
	assert pdf.contains('/ColorSpace /DeviceRGB')
	assert pdf.contains('/SH1 sh')
}

fn test_pdf_render_document_svg_gradient_with_clip_group_uses_clip_and_shading() {
	renderers := [
		Renderer(DrawSvg{
			triangles:    [f32(0), 0, 30, 0, 0, 30]
			color:        gg.Color{255, 255, 255, 255}
			x:            0
			y:            0
			scale:        1
			is_clip_mask: true
			clip_group:   9
		}),
		Renderer(DrawSvg{
			triangles:     [f32(0), 0, 40, 0, 0, 40]
			color:         gg.Color{80, 80, 80, 255}
			vertex_colors: [gg.Color{255, 0, 0, 255}, gg.Color{0, 255, 0, 255},
				gg.Color{0, 0, 255, 255}]
			x:             10
			y:             12
			scale:         1
			clip_group:    9
		}),
	]

	pdf := pdf_render_document(renderers, 100, 100, PrintJob{
		output_path: 'unused.pdf'
	}) or { panic(err.msg()) }

	assert pdf.contains('W n')
	assert pdf.contains('/SH1 sh')
}

fn test_pdf_render_document_svg_gradient_malformed_vertex_colors_falls_back_flat() {
	renderers := [
		Renderer(DrawSvg{
			triangles:     [f32(0), 0, 40, 0, 0, 40]
			color:         gg.Color{0, 128, 0, 255}
			vertex_colors: [gg.Color{255, 0, 0, 255}, gg.Color{0, 255, 0, 255}]
			x:             1
			y:             2
			scale:         1
		}),
	]

	pdf := pdf_render_document(renderers, 100, 100, PrintJob{
		output_path: 'unused.pdf'
	}) or { panic(err.msg()) }

	assert !pdf.contains('/ShadingType 4')
	assert pdf.contains('0 0.502 0 rg')
}

fn test_pdf_render_document_svg_gradient_non_uniform_alpha_falls_back_flat() {
	renderers := [
		Renderer(DrawSvg{
			triangles:     [f32(0), 0, 40, 0, 0, 40]
			color:         gg.Color{0, 0, 0, 255}
			vertex_colors: [gg.Color{255, 0, 0, 255}, gg.Color{0, 255, 0, 180},
				gg.Color{0, 0, 255, 255}]
			x:             3
			y:             4
			scale:         1
		}),
	]

	pdf := pdf_render_document(renderers, 100, 100, PrintJob{
		output_path: 'unused.pdf'
	}) or { panic(err.msg()) }

	assert !pdf.contains('/ShadingType 4')
	assert pdf.contains('0 0 0 rg')
}

fn test_pdf_render_document_paginate_emits_multiple_pages_with_header_tokens() {
	renderers := [
		Renderer(DrawRect{
			x:     0
			y:     0
			w:     120
			h:     2000
			color: gg.Color{30, 30, 30, 255}
			style: .fill
		}),
	]
	pdf := pdf_render_document(renderers, 120, 2000, PrintJob{
		output_path: 'unused.pdf'
		paginate:    true
		scale_mode:  .actual_size
		header:      PrintHeaderFooterCfg{
			enabled: true
			left:    'p {page}/{pages}'
		}
	}) or { panic(err.msg()) }
	assert pdf.contains('/Type /Pages')
	assert pdf.contains('/Count 3')
	assert pdf.contains('(p 1/3) Tj')
}
