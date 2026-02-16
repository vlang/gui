module gui

import os
import time
import nativebridge

fn run_print_job_impl(mut w Window, job PrintJob) PrintRunResult {
	validate_print_job(job) or {
		return print_run_error_result(native_print_error_code_invalid_cfg, err.msg())
	}
	if !print_job_supported() {
		return print_run_error_result('unsupported', 'native print is not implemented on this platform')
	}

	pdf_path := print_job_resolve_pdf_path(mut w, job) or {
		code := print_job_resolve_error_code(job.source.kind, err.msg())
		return print_run_error_result(code, err.msg())
	}

	page_width, page_height := print_page_size(job.paper, job.orientation)
	ranges := normalize_print_page_ranges(job.page_ranges)
	bridge_result := nativebridge.print_pdf_dialog(nativebridge.BridgePrintCfg{
		ns_window:     native_dialog_ns_window()
		title:         job.title
		job_name:      job.job_name
		pdf_path:      pdf_path
		paper_width:   page_width
		paper_height:  page_height
		margin_top:    job.margins.top
		margin_right:  job.margins.right
		margin_bottom: job.margins.bottom
		margin_left:   job.margins.left
		orientation:   print_orientation_to_int(job.orientation)
		copies:        job.copies
		page_ranges:   print_page_ranges_to_string(ranges)
		duplex_mode:   int(job.duplex)
		color_mode:    int(job.color_mode)
		scale_mode:    int(job.scale_mode)
	})
	return print_run_result_from_bridge(bridge_result, pdf_path)
}

fn print_job_supported() bool {
	$if macos || linux {
		return true
	} $else {
		return false
	}
}

fn print_job_resolve_error_code(kind PrintJobSourceKind, message string) string {
	if kind == .pdf_path {
		if message.contains('does not exist') || message.contains('directory') {
			return native_print_error_code_io
		}
		return native_print_error_code_invalid_cfg
	}
	return native_print_error_code_render
}

fn print_job_resolve_pdf_path(mut w Window, job PrintJob) !string {
	match job.source.kind {
		.current_view {
			tmp_path := os.join_path(os.temp_dir(), 'v_gui_print_${time.now().unix_micro()}.pdf')
			result := w.export_print_job(PrintJob{
				output_path:   tmp_path
				title:         job.title
				job_name:      job.job_name
				paper:         job.paper
				orientation:   job.orientation
				margins:       job.margins
				source:        job.source
				paginate:      job.paginate
				scale_mode:    job.scale_mode
				header:        job.header
				footer:        job.footer
				source_width:  job.source_width
				source_height: job.source_height
			})
			if !result.is_ok() {
				return error(result.error_message)
			}
			return result.path
		}
		.pdf_path {
			pdf_path := job.source.pdf_path.trim_space()
			if pdf_path.len == 0 {
				return error('pdf_path is required')
			}
			if !os.exists(pdf_path) {
				return error('pdf file does not exist: ${pdf_path}')
			}
			if os.is_dir(pdf_path) {
				return error('pdf path is a directory: ${pdf_path}')
			}
			return pdf_path
		}
	}
}

fn print_orientation_to_int(orientation PrintOrientation) int {
	return if orientation == .landscape { 1 } else { 0 }
}

fn print_run_result_from_bridge(bridge_result nativebridge.BridgePrintResult, pdf_path string) PrintRunResult {
	warnings := bridge_warnings_to_print_warnings(bridge_result.warnings)
	return match bridge_result.status {
		.ok {
			print_run_ok_result(pdf_path, warnings)
		}
		.cancel {
			PrintRunResult{
				status:   .cancel
				warnings: warnings
			}
		}
		.error {
			PrintRunResult{
				status:        .error
				error_code:    bridge_result.error_code
				error_message: bridge_result.error_message
				warnings:      warnings
			}
		}
	}
}

fn bridge_warnings_to_print_warnings(items []string) []PrintWarning {
	mut out := []PrintWarning{cap: items.len}
	for item in items {
		if item.trim_space().len == 0 {
			continue
		}
		out << PrintWarning{
			code:    'unsupported_option'
			message: item
		}
	}
	return out
}

fn print_page_ranges_to_string(ranges []PrintPageRange) string {
	if ranges.len == 0 {
		return ''
	}
	mut parts := []string{cap: ranges.len}
	for range in ranges {
		if range.from == range.to {
			parts << range.from.str()
		} else {
			parts << '${range.from}-${range.to}'
		}
	}
	return parts.join(',')
}
