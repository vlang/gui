module gui

import nativebridge
import os
import time

fn test_nativebridge_print_module_loads() {
	_ = nativebridge.BridgePrintStatus.ok
}

fn test_print_supported_matches_platform() {
	$if macos || linux || windows {
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

fn test_windows_shell_execute_warnings_keep_current_view_export_options_quiet() {
	warnings := print_windows_shell_execute_warnings(PrintJob{
		paper:       .letter
		orientation: .landscape
		margins:     PrintMargins{
			top:    12
			right:  13
			bottom: 14
			left:   15
		}
		scale_mode:  .actual_size
	})
	assert warnings.len == 0
}

fn test_windows_shell_execute_warnings_include_pdf_path_shape_options() {
	warnings := print_windows_shell_execute_warnings(PrintJob{
		paper:       .letter
		orientation: .landscape
		margins:     PrintMargins{
			top:    12
			right:  13
			bottom: 14
			left:   15
		}
		scale_mode:  .actual_size
		source:      PrintJobSource{
			kind:     .pdf_path
			pdf_path: 'existing.pdf'
		}
	})
	joined := warnings.join('\n')
	assert joined.contains('paper size')
	assert joined.contains('orientation')
	assert joined.contains('margins')
	assert joined.contains('scale mode')
}

fn test_windows_shell_execute_warnings_include_pdf_path_title() {
	warnings := print_windows_shell_execute_warnings(PrintJob{
		title:  'Quarterly Report'
		source: PrintJobSource{
			kind:     .pdf_path
			pdf_path: 'existing.pdf'
		}
	})
	assert warnings.join('\n').contains('title')
}

fn test_windows_shell_execute_warnings_include_job_name_for_current_view() {
	warnings := print_windows_shell_execute_warnings(PrintJob{
		job_name: 'Native Job Name'
	})
	assert warnings.join('\n').contains('job name')
}

fn test_windows_shell_execute_warnings_include_print_options() {
	warnings := print_windows_shell_execute_warnings(PrintJob{
		copies:      2
		page_ranges: [PrintPageRange{ from: 1, to: 2 }]
		duplex:      .long_edge
		color_mode:  .grayscale
	})
	joined := warnings.join('\n')
	assert joined.contains('copies')
	assert joined.contains('page ranges')
	assert joined.contains('duplex mode')
	assert joined.contains('color mode')
}

fn test_print_bridge_conversion_keeps_extra_warnings() {
	result := print_run_result_from_bridge_with_warnings(nativebridge.BridgePrintResult{
		status:   .ok
		warnings: ['bridge warning']
	}, 'out.pdf', ['windows warning'])
	assert result.status == .ok
	assert result.warnings.len == 2
	assert result.warnings[0].code == 'unsupported_option'
	assert result.warnings[0].message == 'bridge warning'
	assert result.warnings[1].message == 'windows warning'
}

fn test_print_bridge_conversion_filters_empty_warnings() {
	result := print_run_result_from_bridge_with_warnings(nativebridge.BridgePrintResult{
		status:   .ok
		warnings: ['', ' bridge warning ']
	}, 'out.pdf', ['   ', 'windows warning'])
	assert result.status == .ok
	assert result.warnings.len == 2
	assert result.warnings[0].message == ' bridge warning '
	assert result.warnings[1].message == 'windows warning'
}

fn test_print_bridge_conversion_keeps_cancel_warnings() {
	result := print_run_result_from_bridge_with_warnings(nativebridge.BridgePrintResult{
		status:   .cancel
		warnings: ['bridge warning']
	}, 'out.pdf', ['windows warning'])
	assert result.status == .cancel
	assert result.warnings.len == 2
	assert result.warnings[0].message == 'bridge warning'
	assert result.warnings[1].message == 'windows warning'
}

fn test_print_bridge_conversion_keeps_error_warnings() {
	result := print_run_result_from_bridge_with_warnings(nativebridge.BridgePrintResult{
		status:        .error
		error_code:    'print_failed'
		error_message: 'handler unavailable'
		warnings:      ['bridge warning']
	}, 'out.pdf', ['windows warning'])
	assert result.status == .error
	assert result.error_code == 'print_failed'
	assert result.error_message == 'handler unavailable'
	assert result.warnings.len == 2
	assert result.warnings[0].message == 'bridge warning'
	assert result.warnings[1].message == 'windows warning'
}

$if !(macos || linux || windows) {
	fn test_nativebridge_print_stub_returns_unsupported() {
		result := nativebridge.print_pdf_dialog(nativebridge.BridgePrintCfg{})
		assert result.status == .error
		assert result.error_code == 'unsupported'
	}
}
