module gui

import nativebridge
import sokol.sapp

const native_dialog_error_code_invalid_cfg = 'invalid_cfg'

fn native_open_dialog_impl(mut w Window, cfg NativeOpenDialogCfg) {
	extensions := native_extensions_from_filters(cfg.filters) or {
		native_dispatch_dialog_done(mut w, cfg.on_done, native_dialog_error_result(native_dialog_error_code_invalid_cfg,
			err.msg()))
		return
	}

	bridge_result := nativebridge.open_dialog(nativebridge.BridgeOpenCfg{
		ns_window:      native_dialog_ns_window()
		title:          cfg.title
		start_dir:      cfg.start_dir
		extensions:     extensions
		allow_multiple: cfg.allow_multiple
	})
	native_dispatch_dialog_done(mut w, cfg.on_done, native_result_from_bridge(bridge_result))
}

fn native_save_dialog_impl(mut w Window, cfg NativeSaveDialogCfg) {
	extensions := native_save_extensions(cfg.filters, cfg.default_extension) or {
		native_dispatch_dialog_done(mut w, cfg.on_done, native_dialog_error_result(native_dialog_error_code_invalid_cfg,
			err.msg()))
		return
	}
	default_extension := native_normalize_extension(cfg.default_extension) or {
		native_dispatch_dialog_done(mut w, cfg.on_done, native_dialog_error_result(native_dialog_error_code_invalid_cfg,
			err.msg()))
		return
	}

	bridge_result := nativebridge.save_dialog(nativebridge.BridgeSaveCfg{
		ns_window:         native_dialog_ns_window()
		title:             cfg.title
		start_dir:         cfg.start_dir
		default_name:      cfg.default_name
		default_extension: default_extension
		extensions:        extensions
		confirm_overwrite: cfg.confirm_overwrite
	})
	native_dispatch_dialog_done(mut w, cfg.on_done, native_result_from_bridge(bridge_result))
}

fn native_folder_dialog_impl(mut w Window, cfg NativeFolderDialogCfg) {
	bridge_result := nativebridge.folder_dialog(nativebridge.BridgeFolderCfg{
		ns_window:              native_dialog_ns_window()
		title:                  cfg.title
		start_dir:              cfg.start_dir
		can_create_directories: cfg.can_create_directories
	})
	native_dispatch_dialog_done(mut w, cfg.on_done, native_result_from_bridge(bridge_result))
}

fn native_dialog_ns_window() voidptr {
	$if macos {
		return sapp.macos_get_window()
	}
	return unsafe { nil }
}

fn native_result_from_bridge(bridge_result nativebridge.BridgeDialogResult) NativeDialogResult {
	status := match bridge_result.status {
		.ok { NativeDialogStatus.ok }
		.cancel { NativeDialogStatus.cancel }
		.error { NativeDialogStatus.error }
	}
	return NativeDialogResult{
		status:        status
		paths:         bridge_result.paths.clone()
		error_code:    bridge_result.error_code
		error_message: bridge_result.error_message
	}
}

fn native_dispatch_dialog_done(mut w Window,
	on_done fn (NativeDialogResult, mut Window),
	result NativeDialogResult) {
	result_cpy := result
	w.queue_command(fn [on_done, result_cpy] (mut w Window) {
		on_done(result_cpy, mut w)
	})
}

fn native_dialog_error_result(code string, message string) NativeDialogResult {
	return NativeDialogResult{
		status:        .error
		error_code:    code
		error_message: message
	}
}

fn native_save_extensions(filters []NativeFileFilter, default_extension string) ![]string {
	mut extensions := native_extensions_from_filters(filters) or { return err }
	def_ext := native_normalize_extension(default_extension) or { return err }
	if def_ext.len == 0 {
		return extensions
	}

	for ext in extensions {
		if ext == def_ext {
			return extensions
		}
	}
	extensions << def_ext
	return extensions
}

fn native_extensions_from_filters(filters []NativeFileFilter) ![]string {
	mut extensions := []string{}
	mut seen := map[string]bool{}
	for filter in filters {
		for raw_extension in filter.extensions {
			extension := native_normalize_extension(raw_extension) or { return err }
			if extension.len == 0 {
				continue
			}
			if seen[extension] {
				continue
			}
			seen[extension] = true
			extensions << extension
		}
	}
	return extensions
}

fn native_normalize_extension(raw_extension string) !string {
	mut extension := raw_extension.trim_space().to_lower()
	for extension.starts_with('.') {
		extension = extension[1..]
	}
	if extension.len == 0 {
		return ''
	}
	if !native_is_valid_extension(extension) {
		return error('invalid extension: ${raw_extension}')
	}
	return extension
}

fn native_is_valid_extension(extension string) bool {
	for char_code in extension {
		if char_code >= `a` && char_code <= `z` {
			continue
		}
		if char_code >= `0` && char_code <= `9` {
			continue
		}
		if char_code in [`_`, `-`, `+`] {
			continue
		}
		return false
	}
	return true
}
