module nativebridge

#flag -I@VMODROOT/nativebridge
#flag darwin -fobjc-arc
#flag darwin -framework AppKit
#flag darwin -framework Foundation
#flag darwin @VMODROOT/nativebridge/dialog_macos.m
#include "@VMODROOT/nativebridge/dialog_bridge.h"

pub enum BridgeDialogStatus {
	ok
	cancel
	error
}

pub struct BridgeDialogResult {
pub:
	status        BridgeDialogStatus
	paths         []string
	error_code    string
	error_message string
}

pub struct BridgeOpenCfg {
pub:
	ns_window      voidptr
	title          string
	start_dir      string
	extensions     []string
	allow_multiple bool
}

pub struct BridgeSaveCfg {
pub:
	ns_window         voidptr
	title             string
	start_dir         string
	default_name      string
	default_extension string
	extensions        []string
	confirm_overwrite bool
}

pub struct BridgeFolderCfg {
pub:
	ns_window              voidptr
	title                  string
	start_dir              string
	can_create_directories bool
}

struct C.GuiNativeDialogResult {
pub:
	status        int
	path_count    int
	paths         &&char
	error_code    &char
	error_message &char
}

fn C.gui_native_open_dialog(voidptr, &char, &char, &char, int) C.GuiNativeDialogResult
fn C.gui_native_save_dialog(voidptr, &char, &char, &char, &char, &char, int) C.GuiNativeDialogResult
fn C.gui_native_folder_dialog(voidptr, &char, &char, int) C.GuiNativeDialogResult
fn C.gui_native_dialog_result_free(C.GuiNativeDialogResult)

fn bridge_dialog_unsupported_result() BridgeDialogResult {
	return BridgeDialogResult{
		status:        .error
		error_code:    'unsupported'
		error_message: 'native dialogs are not implemented on this platform'
	}
}

fn bool_to_int(value bool) int {
	return if value { 1 } else { 0 }
}

fn bridge_status_from_int(value int) BridgeDialogStatus {
	return match value {
		0 { .ok }
		1 { .cancel }
		else { .error }
	}
}

fn bridge_dialog_result_from_c(c_result C.GuiNativeDialogResult) BridgeDialogResult {
	status := bridge_status_from_int(c_result.status)
	mut paths := []string{}
	if c_result.path_count > 0 && c_result.paths != unsafe { nil } {
		paths = []string{cap: c_result.path_count}
		for i in 0 .. c_result.path_count {
			c_path := unsafe { c_result.paths[i] }
			if c_path != unsafe { nil } {
				paths << unsafe { cstring_to_vstring(c_path) }
			}
		}
	}

	error_code := if c_result.error_code != unsafe { nil } {
		unsafe { cstring_to_vstring(c_result.error_code) }
	} else {
		''
	}
	error_message := if c_result.error_message != unsafe { nil } {
		unsafe { cstring_to_vstring(c_result.error_message) }
	} else {
		''
	}

	C.gui_native_dialog_result_free(c_result)

	return BridgeDialogResult{
		status:        status
		paths:         paths
		error_code:    error_code
		error_message: error_message
	}
}

pub fn open_dialog(cfg BridgeOpenCfg) BridgeDialogResult {
	$if macos {
		extensions := cfg.extensions.join(',')
		c_result := C.gui_native_open_dialog(cfg.ns_window, cfg.title.str, cfg.start_dir.str,
			extensions.str, bool_to_int(cfg.allow_multiple))
		return bridge_dialog_result_from_c(c_result)
	} $else {
		return bridge_dialog_unsupported_result()
	}
}

pub fn save_dialog(cfg BridgeSaveCfg) BridgeDialogResult {
	$if macos {
		extensions := cfg.extensions.join(',')
		c_result := C.gui_native_save_dialog(cfg.ns_window, cfg.title.str, cfg.start_dir.str,
			cfg.default_name.str, cfg.default_extension.str, extensions.str, bool_to_int(cfg.confirm_overwrite))
		return bridge_dialog_result_from_c(c_result)
	} $else {
		return bridge_dialog_unsupported_result()
	}
}

pub fn folder_dialog(cfg BridgeFolderCfg) BridgeDialogResult {
	$if macos {
		c_result := C.gui_native_folder_dialog(cfg.ns_window, cfg.title.str, cfg.start_dir.str,
			bool_to_int(cfg.can_create_directories))
		return bridge_dialog_result_from_c(c_result)
	} $else {
		return bridge_dialog_unsupported_result()
	}
}
