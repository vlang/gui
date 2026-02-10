module gui

import os

// native_print_dialog opens the system print dialog for either the current
// view (exported to temporary PDF first) or a prepared PDF path.
pub fn (mut w Window) native_print_dialog(cfg NativePrintDialogCfg) {
	cfg_cpy := cfg
	w.queue_command(fn [cfg_cpy] (mut w Window) {
		native_print_dialog_impl(mut w, cfg_cpy)
	})
}

// export_pdf exports the current renderer list to a single-page PDF.
pub fn (mut w Window) export_pdf(cfg PdfExportCfg) PdfExportResult {
	validate_pdf_export_cfg(cfg) or {
		return pdf_export_error_result(cfg.path, native_print_error_code_invalid_cfg,
			err.msg())
	}

	mut source_width := cfg.source_width
	mut source_height := cfg.source_height
	mut renderers := []Renderer{}

	w.lock()
	renderers = w.renderers.clone()
	if source_width <= 0 {
		source_width = f32(w.window_size.width)
	}
	if source_height <= 0 {
		source_height = f32(w.window_size.height)
	}
	w.unlock()

	if renderers.len == 0 {
		return pdf_export_error_result(cfg.path, native_print_error_code_render, 'no renderers available for export')
	}
	if source_width <= 0 || source_height <= 0 {
		return pdf_export_error_result(cfg.path, native_print_error_code_invalid_cfg,
			'source dimensions must be positive')
	}

	content := pdf_render_document(renderers, source_width, source_height, cfg) or {
		return pdf_export_error_result(cfg.path, native_print_error_code_render, err.msg())
	}

	dir := os.dir(cfg.path)
	if dir.len > 0 && dir != '.' {
		os.mkdir_all(dir) or {
			return pdf_export_error_result(cfg.path, native_print_error_code_io, err.msg())
		}
	}

	os.write_file(cfg.path, content) or {
		return pdf_export_error_result(cfg.path, native_print_error_code_io, err.msg())
	}

	return pdf_export_ok_result(cfg.path)
}
