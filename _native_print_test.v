module gui

import nativebridge
import os
import time

fn test_nativebridge_print_module_loads() {
	_ = nativebridge.BridgePrintStatus.ok
}

fn test_print_supported_matches_platform() {
	$if macos || linux {
		assert print_job_supported()
	} $else {
		assert !print_job_supported()
	}
}

fn test_validate_print_job_requires_pdf_path_for_prepared_content() {
	validate_print_job(PrintJob{
		source: PrintJobSource{
			kind: .pdf_path
		}
	}) or {
		assert err.msg().contains('pdf_path')
		return
	}
	assert false
}

fn test_validate_print_job_requires_positive_copies() {
	validate_print_job(PrintJob{
		copies: 0
	}) or {
		assert err.msg().contains('copies')
		return
	}
	assert false
}

fn test_validate_export_print_job_requires_path() {
	validate_export_print_job(PrintJob{}) or {
		assert err.msg().contains('output_path')
		return
	}
	assert false
}

fn test_print_job_resolve_pdf_path_for_prepared_file() {
	path := os.join_path(os.temp_dir(), 'gui_native_print_${time.now().unix_micro()}.pdf')
	os.write_file(path, '%PDF-1.4\n%%EOF\n') or { panic(err.msg()) }
	defer {
		os.rm(path) or {}
	}

	mut window := Window{}
	resolved := print_job_resolve_pdf_path(mut window, PrintJob{
		source: PrintJobSource{
			kind:     .pdf_path
			pdf_path: path
		}
	}) or { panic(err.msg()) }
	assert resolved == path
}

fn test_print_page_ranges_normalize_merges_overlaps() {
	ranges := normalize_print_page_ranges([
		PrintPageRange{ from: 1, to: 3 },
		PrintPageRange{
			from: 2
			to:   5
		},
		PrintPageRange{
			from: 8
			to:   8
		},
	])
	assert ranges.len == 2
	assert ranges[0].from == 1
	assert ranges[0].to == 5
	assert ranges[1].from == 8
	assert ranges[1].to == 8
}

$if !(macos || linux) {
	fn test_nativebridge_print_stub_returns_unsupported() {
		result := nativebridge.print_pdf_dialog(nativebridge.BridgePrintCfg{})
		assert result.status == .error
		assert result.error_code == 'unsupported'
	}
}
