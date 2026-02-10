module nativebridge

import os

const linux_dialog_separator = '\n'

struct LinuxCommandResult {
	exit_code int
	stdout    string
	stderr    string
}

fn linux_open_dialog(cfg BridgeOpenCfg) BridgeDialogResult {
	if !os.exists_in_system_path('zenity') {
		return BridgeDialogResult{
			status:        .error
			error_code:    'unsupported'
			error_message: 'zenity is required for native dialogs on Linux'
		}
	}

	mut args := ['--file-selection']
	if cfg.title.trim_space().len > 0 {
		args << '--title=${cfg.title}'
	}
	if cfg.allow_multiple {
		args << '--multiple'
		args << '--separator=${linux_dialog_separator}'
	}
	start := linux_dialog_start_path(cfg.start_dir, '', false)
	if start.len > 0 {
		args << '--filename=${start}'
	}
	filter_arg := linux_filter_arg(cfg.extensions)
	if filter_arg.len > 0 {
		args << '--file-filter=${filter_arg}'
	}

	result := linux_run_command('zenity', args) or {
		return BridgeDialogResult{
			status:        .error
			error_code:    'internal'
			error_message: err.msg()
		}
	}
	return linux_dialog_result_from_command(result)
}

fn linux_save_dialog(cfg BridgeSaveCfg) BridgeDialogResult {
	if !os.exists_in_system_path('zenity') {
		return BridgeDialogResult{
			status:        .error
			error_code:    'unsupported'
			error_message: 'zenity is required for native dialogs on Linux'
		}
	}

	mut args := ['--file-selection', '--save']
	if cfg.title.trim_space().len > 0 {
		args << '--title=${cfg.title}'
	}
	if cfg.confirm_overwrite {
		args << '--confirm-overwrite'
	}
	start := linux_dialog_start_path(cfg.start_dir, cfg.default_name, false)
	if start.len > 0 {
		args << '--filename=${start}'
	}
	filter_arg := linux_filter_arg(cfg.extensions)
	if filter_arg.len > 0 {
		args << '--file-filter=${filter_arg}'
	}

	result := linux_run_command('zenity', args) or {
		return BridgeDialogResult{
			status:        .error
			error_code:    'internal'
			error_message: err.msg()
		}
	}
	mut dialog_result := linux_dialog_result_from_command(result)
	if dialog_result.status != .ok || dialog_result.paths.len == 0 {
		return dialog_result
	}

	mut selected := dialog_result.paths[0]
	if cfg.default_extension.trim_space().len > 0 && os.file_ext(selected).len == 0 {
		selected += '.${cfg.default_extension}'
	}
	if !cfg.confirm_overwrite && os.exists(selected) {
		return BridgeDialogResult{
			status:        .error
			error_code:    'overwrite_disallowed'
			error_message: 'file already exists'
		}
	}
	return BridgeDialogResult{
		status: .ok
		paths:  [selected]
	}
}

fn linux_folder_dialog(cfg BridgeFolderCfg) BridgeDialogResult {
	if !os.exists_in_system_path('zenity') {
		return BridgeDialogResult{
			status:        .error
			error_code:    'unsupported'
			error_message: 'zenity is required for native dialogs on Linux'
		}
	}

	mut args := ['--file-selection', '--directory']
	if cfg.title.trim_space().len > 0 {
		args << '--title=${cfg.title}'
	}
	start := linux_dialog_start_path(cfg.start_dir, '', true)
	if start.len > 0 {
		args << '--filename=${start}'
	}

	result := linux_run_command('zenity', args) or {
		return BridgeDialogResult{
			status:        .error
			error_code:    'internal'
			error_message: err.msg()
		}
	}
	return linux_dialog_result_from_command(result)
}

fn linux_print_pdf_dialog(cfg BridgePrintCfg) BridgePrintResult {
	if !os.exists_in_system_path('lp') {
		return BridgePrintResult{
			status:        .error
			error_code:    'unsupported'
			error_message: 'lp is required for native printing on Linux'
		}
	}
	pdf_path := cfg.pdf_path.trim_space()
	if pdf_path.len == 0 {
		return BridgePrintResult{
			status:        .error
			error_code:    'invalid_cfg'
			error_message: 'pdf_path is required'
		}
	}
	if !os.exists(pdf_path) || os.is_dir(pdf_path) {
		return BridgePrintResult{
			status:        .error
			error_code:    'io_error'
			error_message: 'pdf_path does not exist or is not a file'
		}
	}

	mut args := []string{}
	destination := linux_find_print_destination() or {
		return BridgePrintResult{
			status:        .error
			error_code:    'io_error'
			error_message: err.msg()
		}
	}
	args << '-d'
	args << destination
	title := if cfg.job_name.trim_space().len > 0 {
		cfg.job_name
	} else {
		cfg.title
	}
	if title.trim_space().len > 0 {
		args << '-t'
		args << title
	}
	args << '-o'
	args << if cfg.orientation == 1 { 'orientation-requested=4' } else { 'orientation-requested=3' }
	media := linux_media_from_size(cfg.paper_width, cfg.paper_height)
	if media.len > 0 {
		args << '-o'
		args << 'media=${media}'
	}
	args << pdf_path

	result := linux_run_command('lp', args) or {
		return BridgePrintResult{
			status:        .error
			error_code:    'io_error'
			error_message: err.msg()
		}
	}
	if result.exit_code == 0 {
		return BridgePrintResult{
			status: .ok
		}
	}
	message := linux_error_message(result)
	return BridgePrintResult{
		status:        .error
		error_code:    'io_error'
		error_message: message
	}
}

fn linux_find_print_destination() !string {
	for key in ['LPDEST', 'PRINTER'] {
		value := os.getenv(key).trim_space()
		if value.len > 0 {
			return value
		}
	}

	if os.exists_in_system_path('lpstat') {
		default_result := linux_run_command('lpstat', ['-d']) or {
			return error('failed to discover print destination: ${err.msg()}')
		}
		default_destination := linux_parse_lpstat_default(default_result.stdout)
		if default_destination.len > 0 {
			return default_destination
		}

		available_result := linux_run_command('lpstat', ['-a']) or {
			return error('failed to discover printers: ${err.msg()}')
		}
		available_destination := linux_parse_lpstat_available(available_result.stdout)
		if available_destination.len > 0 {
			return available_destination
		}
	}

	return error('no print destination found; configure a default printer or set LPDEST')
}

fn linux_dialog_start_path(start_dir string, default_name string, is_directory bool) string {
	dir := start_dir.trim_space()
	name := default_name.trim_space()
	if dir.len > 0 && os.is_dir(dir) {
		if is_directory || name.len == 0 {
			return dir + os.path_separator
		}
		return os.join_path(dir, name)
	}
	return name
}

fn linux_filter_arg(extensions []string) string {
	if extensions.len == 0 {
		return ''
	}
	mut patterns := []string{cap: extensions.len}
	for extension in extensions {
		ext := extension.trim_space()
		if ext.len == 0 {
			continue
		}
		patterns << '*.${ext}'
	}
	return patterns.join(' ')
}

fn linux_dialog_result_from_command(result LinuxCommandResult) BridgeDialogResult {
	if result.exit_code == 0 {
		paths := linux_paths_from_output(result.stdout)
		if paths.len == 0 {
			return BridgeDialogResult{
				status: .cancel
			}
		}
		return BridgeDialogResult{
			status: .ok
			paths:  paths
		}
	}
	if result.exit_code in [1, 5] && result.stderr.trim_space().len == 0 {
		return BridgeDialogResult{
			status: .cancel
		}
	}
	return BridgeDialogResult{
		status:        .error
		error_code:    'internal'
		error_message: linux_error_message(result)
	}
}

fn linux_paths_from_output(output string) []string {
	mut paths := []string{}
	for raw_path in output.split(linux_dialog_separator) {
		path := raw_path.trim_space()
		if path.len == 0 {
			continue
		}
		paths << path
	}
	return paths
}

fn linux_error_message(result LinuxCommandResult) string {
	stderr := result.stderr.trim_space()
	if stderr.len > 0 {
		return stderr
	}
	stdout := result.stdout.trim_space()
	if stdout.len > 0 {
		return stdout
	}
	return 'native command failed with exit code ${result.exit_code}'
}

fn linux_run_command(name string, args []string) !LinuxCommandResult {
	path := os.find_abs_path_of_executable(name)!
	mut process := os.new_process(path)
	process.set_args(args)
	process.set_redirect_stdio()
	process.run()
	stdout := process.stdout_slurp()
	stderr := process.stderr_slurp()
	process.wait()
	exit_code := process.code
	process.close()
	return LinuxCommandResult{
		exit_code: exit_code
		stdout:    stdout
		stderr:    stderr
	}
}

fn linux_media_from_size(width f32, height f32) string {
	pairs := [
		['Letter', '612', '792'],
		['Legal', '612', '1008'],
		['A4', '595', '842'],
		['A3', '842', '1191'],
	]
	for pair in pairs {
		name := pair[0]
		w := pair[1].f32()
		h := pair[2].f32()
		if linux_sizes_match(width, height, w, h) {
			return name
		}
	}
	return ''
}

fn linux_parse_lpstat_default(output string) string {
	for raw_line in output.split_into_lines() {
		line := raw_line.trim_space()
		lower := line.to_lower()
		prefix := 'system default destination:'
		if lower.starts_with(prefix) {
			return line[prefix.len..].trim_space()
		}
	}
	return ''
}

fn linux_parse_lpstat_available(output string) string {
	for raw_line in output.split_into_lines() {
		line := raw_line.trim_space()
		if line.len == 0 {
			continue
		}
		return line.split(' ')[0]
	}
	return ''
}

fn linux_sizes_match(width f32, height f32, expected_w f32, expected_h f32) bool {
	tolerance := f32(3.0)
	normal := linux_abs_diff(width, expected_w) <= tolerance
		&& linux_abs_diff(height, expected_h) <= tolerance
	swapped := linux_abs_diff(height, expected_w) <= tolerance
		&& linux_abs_diff(width, expected_h) <= tolerance
	return normal || swapped
}

fn linux_abs_diff(a f32, b f32) f32 {
	diff := a - b
	return if diff < 0 { -diff } else { diff }
}
