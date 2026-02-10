module gui

import nativebridge
import os
import time

fn test_nativebridge_print_module_loads() {
	_ = nativebridge.BridgePrintStatus.ok
}

fn test_native_print_supported_matches_platform() {
	$if macos {
		assert native_print_supported()
	} $else {
		assert !native_print_supported()
	}
}

fn test_validate_native_print_cfg_requires_pdf_path_for_prepared_content() {
	validate_native_print_cfg(NativePrintDialogCfg{
		content: NativePrintContent{
			kind: .prepared_pdf_path
		}
	}) or {
		assert err.msg().contains('pdf_path')
		return
	}
	assert false
}

fn test_validate_pdf_export_cfg_requires_path() {
	validate_pdf_export_cfg(PdfExportCfg{}) or {
		assert err.msg().contains('path')
		return
	}
	assert false
}

fn test_native_print_resolve_pdf_path_for_prepared_file() {
	path := os.join_path(os.temp_dir(), 'gui_native_print_${time.now().unix_micro()}.pdf')
	os.write_file(path, '%PDF-1.4\n%%EOF\n') or { panic(err.msg()) }
	defer {
		os.rm(path) or {}
	}

	mut window := Window{}
	resolved := native_print_resolve_pdf_path(mut window, NativePrintDialogCfg{
		content: NativePrintContent{
			kind:     .prepared_pdf_path
			pdf_path: path
		}
	}) or { panic(err.msg()) }
	assert resolved == path
}

$if !macos {
	fn test_nativebridge_print_stub_returns_unsupported() {
		result := nativebridge.print_pdf_dialog(nativebridge.BridgePrintCfg{})
		assert result.status == .error
		assert result.error_code == 'unsupported'
	}
}
