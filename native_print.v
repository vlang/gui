module gui

import os

// export_print_job exports renderer output to PDF using PrintJob settings.
pub fn (mut w Window) export_print_job(job PrintJob) PrintExportResult {
	validate_export_print_job(job) or {
		return print_export_error_result(job.output_path, native_print_error_code_invalid_cfg,
			err.msg())
	}

	mut source_width := job.source_width
	mut source_height := job.source_height
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
		return print_export_error_result(job.output_path, native_print_error_code_render,
			'no renderers available for export')
	}
	if source_width <= 0 || source_height <= 0 {
		return print_export_error_result(job.output_path, native_print_error_code_invalid_cfg,
			'source dimensions must be positive')
	}

	content := pdf_render_document(renderers, source_width, source_height, job) or {
		return print_export_error_result(job.output_path, native_print_error_code_render,
			err.msg())
	}

	dir := os.dir(job.output_path)
	if dir.len > 0 && dir != '.' {
		os.mkdir_all(dir) or {
			return print_export_error_result(job.output_path, native_print_error_code_io,
				err.msg())
		}
	}

	os.write_file(job.output_path, content) or {
		return print_export_error_result(job.output_path, native_print_error_code_io,
			err.msg())
	}

	return print_export_ok_result(job.output_path)
}

// run_print_job runs native print flow for the provided PrintJob.
pub fn (mut w Window) run_print_job(job PrintJob) PrintRunResult {
	return run_print_job_impl(mut w, job)
}
