module gui

import gg

fn test_export_print_job_fails_when_renderers_missing() {
	mut window := Window{}
	window.window_size = gg.Size{
		width:  100
		height: 60
	}
	result := window.export_print_job(PrintJob{
		output_path: 'unused.pdf'
	})
	assert result.status == .error
	assert result.error_code == native_print_error_code_render
}

fn test_default_print_margins_are_half_inch() {
	margins := default_print_margins()
	assert f32_are_close(margins.top, 36.0)
	assert f32_are_close(margins.right, 36.0)
	assert f32_are_close(margins.bottom, 36.0)
	assert f32_are_close(margins.left, 36.0)
}
