module gui

import os
import time
import nativebridge

fn native_print_dialog_impl(mut w Window, cfg NativePrintDialogCfg) {
	validate_native_print_cfg(cfg) or {
		native_dispatch_print_done(mut w, cfg.on_done, native_print_error_result(native_print_error_code_invalid_cfg,
			err.msg()))
		return
	}
	if !native_print_supported() {
		native_dispatch_print_done(mut w, cfg.on_done, native_print_error_result('unsupported',
			'native print is not implemented on this platform'))
		return
	}

	pdf_path := native_print_resolve_pdf_path(mut w, cfg) or {
		code := native_print_resolve_error_code(cfg.content.kind, err.msg())
		native_dispatch_print_done(mut w, cfg.on_done, native_print_error_result(code,
			err.msg()))
		return
	}

	page_width, page_height := print_page_size(cfg.paper, cfg.orientation)
	bridge_result := nativebridge.print_pdf_dialog(nativebridge.BridgePrintCfg{
		ns_window:     native_dialog_ns_window()
		title:         cfg.title
		job_name:      cfg.job_name
		pdf_path:      pdf_path
		paper_width:   page_width
		paper_height:  page_height
		margin_top:    cfg.margins.top
		margin_right:  cfg.margins.right
		margin_bottom: cfg.margins.bottom
		margin_left:   cfg.margins.left
		orientation:   native_orientation_to_int(cfg.orientation)
	})
	result := native_print_result_from_bridge(bridge_result, pdf_path)
	native_dispatch_print_done(mut w, cfg.on_done, result)
}

fn native_print_supported() bool {
	$if macos {
		return true
	} $else {
		return false
	}
}

fn native_print_resolve_error_code(kind NativePrintContentKind, message string) string {
	if kind == .prepared_pdf_path {
		if message.contains('does not exist') || message.contains('directory') {
			return native_print_error_code_io
		}
		return native_print_error_code_invalid_cfg
	}
	return native_print_error_code_render
}

fn native_print_resolve_pdf_path(mut w Window, cfg NativePrintDialogCfg) !string {
	match cfg.content.kind {
		.current_view_pdf {
			tmp_path := os.join_path(os.temp_dir(), 'v_gui_print_${time.now().unix_micro()}.pdf')
			result := w.export_pdf(PdfExportCfg{
				path:        tmp_path
				title:       cfg.title
				job_name:    cfg.job_name
				paper:       cfg.paper
				orientation: cfg.orientation
				margins:     cfg.margins
			})
			if !result.is_ok() {
				return error(result.error_message)
			}
			return result.path
		}
		.prepared_pdf_path {
			pdf_path := cfg.content.pdf_path.trim_space()
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

fn native_orientation_to_int(orientation PrintOrientation) int {
	return if orientation == .landscape { 1 } else { 0 }
}

fn native_print_result_from_bridge(bridge_result nativebridge.BridgePrintResult, pdf_path string) NativePrintResult {
	return match bridge_result.status {
		.ok {
			native_print_ok_result(pdf_path)
		}
		.cancel {
			native_print_cancel_result()
		}
		.error {
			native_print_error_result(bridge_result.error_code, bridge_result.error_message)
		}
	}
}

fn native_dispatch_print_done(mut w Window,
	on_done fn (NativePrintResult, mut Window),
	result NativePrintResult) {
	result_cpy := result
	w.queue_command(fn [on_done, result_cpy] (mut w Window) {
		on_done(result_cpy, mut w)
	})
}
