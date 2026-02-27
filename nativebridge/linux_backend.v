module nativebridge

import os

const linux_dialog_separator = '\n'

enum LinuxDialogTool {
	zenity
	kdialog
}

struct LinuxCommandResult {
	exit_code int
	stdout    string
	stderr    string
}

// bridge_result_ex_from_legacy wraps a legacy BridgeDialogResult
// into BridgeDialogResultEx with empty bookmark data. Used when
// falling back to zenity/kdialog on Linux.
fn bridge_result_ex_from_legacy(r BridgeDialogResult) BridgeDialogResultEx {
	mut entries := []BridgeBookmarkEntry{cap: r.paths.len}
	for p in r.paths {
		entries << BridgeBookmarkEntry{
			path: p
		}
	}
	return BridgeDialogResultEx{
		status:        r.status
		entries:       entries
		error_code:    r.error_code
		error_message: r.error_message
	}
}

fn linux_open_dialog(cfg BridgeOpenCfg) BridgeDialogResult {
	tool := linux_pick_dialog_tool() or { return linux_dialog_tool_error_result() }
	return match tool {
		.zenity { linux_open_dialog_zenity(cfg) }
		.kdialog { linux_open_dialog_kdialog(cfg) }
	}
}

fn linux_save_dialog(cfg BridgeSaveCfg) BridgeDialogResult {
	tool := linux_pick_dialog_tool() or { return linux_dialog_tool_error_result() }
	mut dialog_result := match tool {
		.zenity { linux_save_dialog_zenity(cfg) }
		.kdialog { linux_save_dialog_kdialog(cfg) }
	}
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
	tool := linux_pick_dialog_tool() or { return linux_dialog_tool_error_result() }
	return match tool {
		.zenity { linux_folder_dialog_zenity(cfg) }
		.kdialog { linux_folder_dialog_kdialog(cfg) }
	}
}

fn linux_open_dialog_zenity(cfg BridgeOpenCfg) BridgeDialogResult {
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

fn linux_save_dialog_zenity(cfg BridgeSaveCfg) BridgeDialogResult {
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
	return linux_dialog_result_from_command(result)
}

fn linux_folder_dialog_zenity(cfg BridgeFolderCfg) BridgeDialogResult {
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

fn linux_open_dialog_kdialog(cfg BridgeOpenCfg) BridgeDialogResult {
	mut args := []string{}
	if cfg.title.trim_space().len > 0 {
		args << '--title'
		args << cfg.title
	}
	args << '--getopenfilename'
	start := linux_dialog_start_path(cfg.start_dir, '', false)
	if start.len > 0 {
		args << start
	}
	filter := linux_kdialog_filter_arg(cfg.extensions)
	if filter.len > 0 {
		args << filter
	}
	if cfg.allow_multiple {
		args << '--multiple'
		args << '--separate-output'
	}
	result := linux_run_command('kdialog', args) or {
		return BridgeDialogResult{
			status:        .error
			error_code:    'internal'
			error_message: err.msg()
		}
	}
	return linux_dialog_result_from_command(result)
}

fn linux_save_dialog_kdialog(cfg BridgeSaveCfg) BridgeDialogResult {
	mut args := []string{}
	if cfg.title.trim_space().len > 0 {
		args << '--title'
		args << cfg.title
	}
	args << '--getsavefilename'
	start := linux_dialog_start_path(cfg.start_dir, cfg.default_name, false)
	if start.len > 0 {
		args << start
	}
	filter := linux_kdialog_filter_arg(cfg.extensions)
	if filter.len > 0 {
		args << filter
	}
	result := linux_run_command('kdialog', args) or {
		return BridgeDialogResult{
			status:        .error
			error_code:    'internal'
			error_message: err.msg()
		}
	}
	return linux_dialog_result_from_command(result)
}

fn linux_folder_dialog_kdialog(cfg BridgeFolderCfg) BridgeDialogResult {
	mut args := []string{}
	if cfg.title.trim_space().len > 0 {
		args << '--title'
		args << cfg.title
	}
	args << '--getexistingdirectory'
	start := linux_dialog_start_path(cfg.start_dir, '', true)
	if start.len > 0 {
		args << start
	}
	result := linux_run_command('kdialog', args) or {
		return BridgeDialogResult{
			status:        .error
			error_code:    'internal'
			error_message: err.msg()
		}
	}
	return linux_dialog_result_from_command(result)
}

fn linux_print_pdf_dialog(cfg BridgePrintCfg) BridgePrintResult {
	pdf_path := cfg.pdf_path.trim_space()
	if pdf_path.len == 0 {
		return BridgePrintResult{
			status:        .error
			error_code:    'invalid_cfg'
			error_message: 'pdf_path is required'
			warnings:      []string{}
		}
	}
	if !os.exists(pdf_path) || os.is_dir(pdf_path) {
		return BridgePrintResult{
			status:        .error
			error_code:    'io_error'
			error_message: 'pdf_path does not exist or is not a file'
			warnings:      []string{}
		}
	}

	warnings := linux_print_capability_warnings(cfg)
	if os.exists_in_system_path('xdg-open') {
		return linux_open_pdf_for_print('xdg-open', [pdf_path], warnings)
	}
	if os.exists_in_system_path('gio') {
		return linux_open_pdf_for_print('gio', ['open', pdf_path], warnings)
	}
	if os.exists_in_system_path('lp') {
		return linux_print_pdf_direct(cfg, pdf_path, warnings)
	}
	return BridgePrintResult{
		status:        .error
		error_code:    'unsupported'
		error_message: 'native printing on Linux requires xdg-open, gio, or lp'
		warnings:      warnings
	}
}

fn linux_open_pdf_for_print(command string, args []string, warnings []string) BridgePrintResult {
	result := linux_run_command(command, args) or {
		return BridgePrintResult{
			status:        .error
			error_code:    'io_error'
			error_message: err.msg()
			warnings:      warnings
		}
	}
	if result.exit_code == 0 {
		return BridgePrintResult{
			status:   .cancel
			warnings: warnings
		}
	}
	return BridgePrintResult{
		status:        .error
		error_code:    'io_error'
		error_message: linux_error_message(result)
		warnings:      warnings
	}
}

fn linux_print_pdf_direct(cfg BridgePrintCfg, pdf_path string, warnings []string) BridgePrintResult {
	mut args := []string{}
	destination := linux_find_print_destination() or {
		return BridgePrintResult{
			status:        .error
			error_code:    'io_error'
			error_message: err.msg()
			warnings:      warnings
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
	if cfg.copies > 1 {
		args << '-n'
		args << cfg.copies.str()
	}
	if cfg.page_ranges.trim_space().len > 0 {
		args << '-P'
		args << cfg.page_ranges
	}
	match cfg.duplex_mode {
		2 {
			args << '-o'
			args << 'sides=two-sided-long-edge'
		}
		3 {
			args << '-o'
			args << 'sides=two-sided-short-edge'
		}
		1 {
			args << '-o'
			args << 'sides=one-sided'
		}
		else {}
	}
	match cfg.color_mode {
		2 {
			args << '-o'
			args << 'ColorModel=Gray'
		}
		1 {
			args << '-o'
			args << 'ColorModel=RGB'
		}
		else {}
	}
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
			warnings:      warnings
		}
	}
	if result.exit_code == 0 {
		return BridgePrintResult{
			status:   .ok
			warnings: warnings
		}
	}
	message := linux_error_message(result)
	return BridgePrintResult{
		status:        .error
		error_code:    'io_error'
		error_message: message
		warnings:      warnings
	}
}

fn linux_print_capability_warnings(cfg BridgePrintCfg) []string {
	mut warnings := []string{}
	if cfg.page_ranges.len > 0 {
		warnings << 'page_ranges may be ignored when using opener-based print flow'
	}
	if cfg.copies > 1 {
		warnings << 'copies may be ignored when using opener-based print flow'
	}
	if cfg.duplex_mode != 0 {
		warnings << 'duplex may be ignored when using opener-based print flow'
	}
	if cfg.color_mode != 0 {
		warnings << 'color mode may be ignored when using opener-based print flow'
	}
	if cfg.scale_mode != 0 {
		warnings << 'scale mode may be ignored on Linux backend'
	}
	return warnings
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
		default_destination := linux_parse_lpstat_default(default_result.stdout + '\n' +
			default_result.stderr)
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

fn linux_pick_dialog_tool() !LinuxDialogTool {
	if os.exists_in_system_path('zenity') {
		return .zenity
	}
	if os.exists_in_system_path('kdialog') {
		return .kdialog
	}
	return error('no supported Linux native dialog tool found')
}

fn linux_dialog_tool_error_result() BridgeDialogResult {
	return BridgeDialogResult{
		status:        .error
		error_code:    'unsupported'
		error_message: 'native dialogs on Linux require zenity or kdialog'
	}
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

fn linux_kdialog_filter_arg(extensions []string) string {
	pattern := linux_filter_arg(extensions)
	if pattern.len == 0 {
		return ''
	}
	return '${pattern} | Files'
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
		if line.len == 0 {
			continue
		}
		if line.contains(':') {
			candidate := line.all_after(':').trim_space()
			if candidate.len > 0 {
				return candidate
			}
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

// --- Alert/confirm dialog (zenity/kdialog) ---

fn linux_alert_tool_error_result() BridgeAlertResult {
	return BridgeAlertResult{
		status:        .error
		error_code:    'unsupported'
		error_message: 'native alert dialogs on Linux require zenity or kdialog'
	}
}

fn linux_alert_result_from_command(result LinuxCommandResult) BridgeAlertResult {
	if result.exit_code == 0 {
		return BridgeAlertResult{
			status: .ok
		}
	}
	// zenity: 1=No/Cancel, 5=timeout; kdialog: 1=No/Cancel
	if result.exit_code in [1, 5] && result.stderr.trim_space().len == 0 {
		return BridgeAlertResult{
			status: .cancel
		}
	}
	return BridgeAlertResult{
		status:        .error
		error_code:    'internal'
		error_message: linux_error_message(result)
	}
}

// level: 0=info, 1=warning, 2=critical
fn linux_zenity_message_flag(level int) string {
	return match level {
		2 { '--error' }
		1 { '--warning' }
		else { '--info' }
	}
}

fn linux_kdialog_message_args(level int, title string, body string) []string {
	mut args := []string{}
	if title.trim_space().len > 0 {
		args << '--title'
		args << title
	}
	match level {
		2 { args << '--error' }
		1 { args << '--sorry' }
		else { args << '--msgbox' }
	}
	args << body
	return args
}

fn linux_message_dialog(cfg BridgeMessageCfg) BridgeAlertResult {
	tool := linux_pick_dialog_tool() or { return linux_alert_tool_error_result() }
	return match tool {
		.zenity {
			linux_message_dialog_zenity(cfg)
		}
		.kdialog {
			linux_message_dialog_kdialog(cfg)
		}
	}
}

fn linux_confirm_dialog(cfg BridgeConfirmCfg) BridgeAlertResult {
	tool := linux_pick_dialog_tool() or { return linux_alert_tool_error_result() }
	return match tool {
		.zenity {
			linux_confirm_dialog_zenity(cfg)
		}
		.kdialog {
			linux_confirm_dialog_kdialog(cfg)
		}
	}
}

fn linux_message_dialog_zenity(cfg BridgeMessageCfg) BridgeAlertResult {
	mut args := [linux_zenity_message_flag(cfg.level)]
	if cfg.title.trim_space().len > 0 {
		args << '--title=${cfg.title}'
	}
	args << '--text=${cfg.body}'
	result := linux_run_command('zenity', args) or {
		return BridgeAlertResult{
			status:        .error
			error_code:    'internal'
			error_message: err.msg()
		}
	}
	return linux_alert_result_from_command(result)
}

fn linux_message_dialog_kdialog(cfg BridgeMessageCfg) BridgeAlertResult {
	args := linux_kdialog_message_args(cfg.level, cfg.title, cfg.body)
	result := linux_run_command('kdialog', args) or {
		return BridgeAlertResult{
			status:        .error
			error_code:    'internal'
			error_message: err.msg()
		}
	}
	return linux_alert_result_from_command(result)
}

fn linux_confirm_dialog_zenity(cfg BridgeConfirmCfg) BridgeAlertResult {
	mut args := ['--question']
	if cfg.title.trim_space().len > 0 {
		args << '--title=${cfg.title}'
	}
	args << '--text=${cfg.body}'
	result := linux_run_command('zenity', args) or {
		return BridgeAlertResult{
			status:        .error
			error_code:    'internal'
			error_message: err.msg()
		}
	}
	return linux_alert_result_from_command(result)
}

fn linux_confirm_dialog_kdialog(cfg BridgeConfirmCfg) BridgeAlertResult {
	mut args := []string{}
	if cfg.title.trim_space().len > 0 {
		args << '--title'
		args << cfg.title
	}
	args << '--yesno'
	args << cfg.body
	result := linux_run_command('kdialog', args) or {
		return BridgeAlertResult{
			status:        .error
			error_code:    'internal'
			error_message: err.msg()
		}
	}
	return linux_alert_result_from_command(result)
}
