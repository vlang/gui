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

	pdf := pdf_render_document(renderers, 200, 120, PdfExportCfg{
		path:  'unused.pdf'
		paper: .letter
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
	result := window.export_pdf(PdfExportCfg{
		path: path
	})
	assert result.is_ok()

	bytes := os.read_bytes(path) or { panic(err.msg()) }
	assert bytes.len > 80
	assert bytes[0] == `%`

	os.rm(path) or {}
}
