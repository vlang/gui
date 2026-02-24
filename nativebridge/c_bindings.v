module nativebridge

#flag -I@VMODROOT/nativebridge
#flag darwin -fobjc-arc
#flag darwin -framework AppKit
#flag darwin -framework Foundation
#flag darwin @VMODROOT/nativebridge/dialog_macos.m
#flag darwin @VMODROOT/nativebridge/bookmark_macos.m
#flag darwin @VMODROOT/nativebridge/print_macos.m
#flag darwin @VMODROOT/nativebridge/readback_macos.m
#flag darwin -framework Metal
#flag darwin @VMODROOT/nativebridge/portal_stub.c
#flag darwin @VMODROOT/nativebridge/a11y_macos.m
#flag linux @VMODROOT/nativebridge/a11y_linux.c
#flag linux -ldbus-1
#flag linux -I/usr/include/dbus-1.0
#flag linux -I/usr/lib/x86_64-linux-gnu/dbus-1.0/include
#flag linux @VMODROOT/nativebridge/readback_linux.c
#flag linux @VMODROOT/nativebridge/bookmark_stub.c
#flag linux @VMODROOT/nativebridge/portal_linux.c
#flag linux -lGL
#include "@VMODROOT/nativebridge/a11y_bridge.h"
#include "@VMODROOT/nativebridge/dialog_bridge.h"
#include "@VMODROOT/nativebridge/print_bridge.h"
#include "@VMODROOT/nativebridge/readback_bridge.h"

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

pub struct BridgeBookmarkEntry {
pub:
	path string
	data []u8
}

pub struct BridgeDialogResultEx {
pub:
	status        BridgeDialogStatus
	entries       []BridgeBookmarkEntry
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

pub struct BridgePrintCfg {
pub:
	ns_window     voidptr
	title         string
	job_name      string
	pdf_path      string
	paper_width   f32
	paper_height  f32
	margin_top    f32
	margin_right  f32
	margin_bottom f32
	margin_left   f32
	orientation   int
	copies        int = 1
	page_ranges   string
	duplex_mode   int
	color_mode    int
	scale_mode    int
}

pub enum BridgePrintStatus {
	ok
	cancel
	error
}

pub struct BridgePrintResult {
pub:
	status        BridgePrintStatus
	error_code    string
	error_message string
	warnings      []string
}

struct C.GuiBookmarkEntry {
pub:
	path     &char
	data     &u8
	data_len int
}

struct C.GuiNativeDialogResultEx {
pub:
	status        int
	path_count    int
	entries       &C.GuiBookmarkEntry
	error_code    &char
	error_message &char
}

fn C.gui_native_open_dialog_ex(voidptr, &char, &char, &char, int) C.GuiNativeDialogResultEx
fn C.gui_native_save_dialog_ex(voidptr, &char, &char, &char, &char, &char, int) C.GuiNativeDialogResultEx
fn C.gui_native_folder_dialog_ex(voidptr, &char, &char, int) C.GuiNativeDialogResultEx
fn C.gui_native_dialog_result_ex_free(C.GuiNativeDialogResultEx)

fn C.gui_bookmark_store(&char, &char, &u8, int) int
fn C.gui_bookmark_count(&char) int
fn C.gui_bookmark_load_all(&char, &int) &C.GuiBookmarkEntry
fn C.gui_bookmark_remove(&char, &char) int
fn C.gui_bookmark_entries_free(&C.GuiBookmarkEntry, int)
fn C.gui_bookmark_start_access(&u8, int, &&char) int
fn C.gui_bookmark_stop_access(&u8, int)

fn C.gui_portal_available() int
fn C.gui_portal_open_file(&char, &char, &char, int) C.GuiNativeDialogResultEx
fn C.gui_portal_save_file(&char, &char, &char, &char, &char) C.GuiNativeDialogResultEx
fn C.gui_portal_open_directory(&char, &char) C.GuiNativeDialogResultEx

struct C.GuiNativePrintResult {
pub:
	status        int
	error_code    &char
	error_message &char
}

fn C.gui_native_print_pdf_dialog(voidptr, &char, &char, &char, f64, f64, f64, f64, f64, f64, int, int, &char, int, int, int) C.GuiNativePrintResult
fn C.gui_native_print_result_free(C.GuiNativePrintResult)

fn C.gui_readback_metal_texture(mtl_texture voidptr, mtl_device voidptr, width int, height int) &u8
fn C.gui_readback_gl_framebuffer(framebuffer u32, width int, height int) &u8

fn bridge_print_unsupported_result() BridgePrintResult {
	return BridgePrintResult{
		status:        .error
		error_code:    'unsupported'
		error_message: 'native print is not implemented on this platform'
		warnings:      []string{}
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

fn bridge_print_status_from_int(value int) BridgePrintStatus {
	return match value {
		0 { .ok }
		1 { .cancel }
		else { .error }
	}
}

fn bridge_dialog_result_ex_from_c(c_result C.GuiNativeDialogResultEx) BridgeDialogResultEx {
	status := bridge_status_from_int(c_result.status)
	mut entries := []BridgeBookmarkEntry{}
	if c_result.path_count > 0 && c_result.entries != unsafe { nil } {
		entries = []BridgeBookmarkEntry{cap: c_result.path_count}
		for i in 0 .. c_result.path_count {
			c_entry := unsafe { c_result.entries[i] }
			path := if c_entry.path != unsafe { nil } {
				unsafe { cstring_to_vstring(c_entry.path) }
			} else {
				''
			}
			mut data := []u8{}
			if c_entry.data != unsafe { nil } && c_entry.data_len > 0 {
				data = []u8{len: c_entry.data_len}
				unsafe {
					vmemcpy(data.data, c_entry.data, c_entry.data_len)
				}
			}
			entries << BridgeBookmarkEntry{
				path: path
				data: data
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

	C.gui_native_dialog_result_ex_free(c_result)

	return BridgeDialogResultEx{
		status:        status
		entries:       entries
		error_code:    error_code
		error_message: error_message
	}
}

fn bridge_dialog_unsupported_result_ex() BridgeDialogResultEx {
	return BridgeDialogResultEx{
		status:        .error
		error_code:    'unsupported'
		error_message: 'native dialogs are not implemented on this platform'
	}
}

fn bridge_print_result_from_c(c_result C.GuiNativePrintResult) BridgePrintResult {
	status := bridge_print_status_from_int(c_result.status)
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

	C.gui_native_print_result_free(c_result)

	return BridgePrintResult{
		status:        status
		error_code:    error_code
		error_message: error_message
		warnings:      []string{}
	}
}

pub fn print_pdf_dialog(cfg BridgePrintCfg) BridgePrintResult {
	$if macos {
		c_result := C.gui_native_print_pdf_dialog(cfg.ns_window, cfg.title.str, cfg.job_name.str,
			cfg.pdf_path.str, f64(cfg.paper_width), f64(cfg.paper_height), f64(cfg.margin_top),
			f64(cfg.margin_right), f64(cfg.margin_bottom), f64(cfg.margin_left), cfg.orientation,
			cfg.copies, cfg.page_ranges.str, cfg.duplex_mode, cfg.color_mode, cfg.scale_mode)
		return bridge_print_result_from_c(c_result)
	} $else $if linux {
		return linux_print_pdf_dialog(cfg)
	} $else {
		return bridge_print_unsupported_result()
	}
}

fn bridge_result_from_ex(ex BridgeDialogResultEx) BridgeDialogResult {
	mut paths := []string{cap: ex.entries.len}
	for entry in ex.entries {
		paths << entry.path
	}
	return BridgeDialogResult{
		status:        ex.status
		paths:         paths
		error_code:    ex.error_code
		error_message: ex.error_message
	}
}

@[deprecated: 'use open_dialog_ex']
pub fn open_dialog(cfg BridgeOpenCfg) BridgeDialogResult {
	return bridge_result_from_ex(open_dialog_ex(cfg))
}

@[deprecated: 'use save_dialog_ex']
pub fn save_dialog(cfg BridgeSaveCfg) BridgeDialogResult {
	return bridge_result_from_ex(save_dialog_ex(cfg))
}

@[deprecated: 'use folder_dialog_ex']
pub fn folder_dialog(cfg BridgeFolderCfg) BridgeDialogResult {
	return bridge_result_from_ex(folder_dialog_ex(cfg))
}

// open_dialog_ex opens a native file picker and returns
// paths with access grants. On macOS each path includes a
// security-scoped bookmark blob that can be persisted to
// retain file access across app relaunches in sandboxed
// apps. On Linux the grant data is empty; paths are usable
// directly. Prefers XDG Desktop Portal when available,
// falling back to zenity/kdialog. On Windows returns
// .error with error_code 'unsupported'; grants are not
// yet implemented.
pub fn open_dialog_ex(cfg BridgeOpenCfg) BridgeDialogResultEx {
	$if macos {
		extensions := cfg.extensions.join(',')
		c_result := C.gui_native_open_dialog_ex(cfg.ns_window, cfg.title.str, cfg.start_dir.str,
			extensions.str, bool_to_int(cfg.allow_multiple))
		return bridge_dialog_result_ex_from_c(c_result)
	} $else $if linux {
		if C.gui_portal_available() != 0 {
			extensions := cfg.extensions.join(',')
			c_result := C.gui_portal_open_file(cfg.title.str, cfg.start_dir.str, extensions.str,
				bool_to_int(cfg.allow_multiple))
			return bridge_dialog_result_ex_from_c(c_result)
		}
		return bridge_result_ex_from_legacy(linux_open_dialog(cfg))
	} $else {
		return bridge_dialog_unsupported_result_ex()
	}
}

// save_dialog_ex opens a native save-as dialog and returns
// the chosen path with an access grant. On macOS the grant
// contains a security-scoped bookmark blob for persisting
// write access across relaunches in sandboxed apps. On
// Linux the grant data is empty; the path is usable
// directly. Prefers XDG Desktop Portal when available,
// falling back to zenity/kdialog. On Windows returns
// .error with error_code 'unsupported'; grants are not
// yet implemented.
pub fn save_dialog_ex(cfg BridgeSaveCfg) BridgeDialogResultEx {
	$if macos {
		extensions := cfg.extensions.join(',')
		c_result := C.gui_native_save_dialog_ex(cfg.ns_window, cfg.title.str, cfg.start_dir.str,
			cfg.default_name.str, cfg.default_extension.str, extensions.str, bool_to_int(cfg.confirm_overwrite))
		return bridge_dialog_result_ex_from_c(c_result)
	} $else $if linux {
		if C.gui_portal_available() != 0 {
			extensions := cfg.extensions.join(',')
			c_result := C.gui_portal_save_file(cfg.title.str, cfg.start_dir.str, cfg.default_name.str,
				cfg.default_extension.str, extensions.str)
			return bridge_dialog_result_ex_from_c(c_result)
		}
		return bridge_result_ex_from_legacy(linux_save_dialog(cfg))
	} $else {
		return bridge_dialog_unsupported_result_ex()
	}
}

// folder_dialog_ex opens a native folder picker and returns
// the chosen directory path with an access grant. On macOS
// the grant contains a security-scoped bookmark blob for
// persisting access across relaunches in sandboxed apps. On
// Linux the grant data is empty; the path is usable
// directly. Prefers XDG Desktop Portal when available,
// falling back to zenity/kdialog. On Windows returns
// .error with error_code 'unsupported'; grants are not
// yet implemented.
pub fn folder_dialog_ex(cfg BridgeFolderCfg) BridgeDialogResultEx {
	$if macos {
		c_result := C.gui_native_folder_dialog_ex(cfg.ns_window, cfg.title.str, cfg.start_dir.str,
			bool_to_int(cfg.can_create_directories))
		return bridge_dialog_result_ex_from_c(c_result)
	} $else $if linux {
		if C.gui_portal_available() != 0 {
			c_result := C.gui_portal_open_directory(cfg.title.str, cfg.start_dir.str)
			return bridge_dialog_result_ex_from_c(c_result)
		}
		return bridge_result_ex_from_legacy(linux_folder_dialog(cfg))
	} $else {
		return bridge_dialog_unsupported_result_ex()
	}
}

// bookmark_store persists a security-scoped bookmark via the
// native backend (macOS NSUserDefaults).
pub fn bookmark_store(app_id string, path string, data []u8) {
	C.gui_bookmark_store(app_id.str, path.str, data.data, data.len)
}

// bookmark_load_all loads and activates all persisted bookmarks
// for the given app_id. macOS: resolves and starts security
// scope for each; stale bookmarks are refreshed or removed.
pub fn bookmark_load_all(app_id string) []BridgeBookmarkEntry {
	count := 0
	c_entries := C.gui_bookmark_load_all(app_id.str, &count)
	if c_entries == unsafe { nil } || count <= 0 {
		return []
	}
	mut entries := []BridgeBookmarkEntry{cap: count}
	for i in 0 .. count {
		c_entry := unsafe { c_entries[i] }
		path := if c_entry.path != unsafe { nil } {
			unsafe { cstring_to_vstring(c_entry.path) }
		} else {
			''
		}
		mut data := []u8{}
		if c_entry.data != unsafe { nil } && c_entry.data_len > 0 {
			data = []u8{len: c_entry.data_len}
			unsafe {
				vmemcpy(data.data, c_entry.data, c_entry.data_len)
			}
		}
		entries << BridgeBookmarkEntry{
			path: path
			data: data
		}
	}
	C.gui_bookmark_entries_free(c_entries, count)
	return entries
}

// bookmark_stop_access releases the security scope for a
// bookmark identified by its raw data blob.
pub fn bookmark_stop_access(data []u8) {
	if data.len > 0 {
		C.gui_bookmark_stop_access(data.data, data.len)
	}
}

// readback_metal_texture reads BGRA pixels from a Metal
// render-target texture via blit to shared staging texture.
// mtl_device is used to create a transient command queue.
// Caller must gfx.commit() before calling. macOS only.
pub fn readback_metal_texture(mtl_texture voidptr, mtl_device voidptr, width int, height int) ![]u8 {
	$if macos {
		ptr := C.gui_readback_metal_texture(mtl_texture, mtl_device, width, height)
		if ptr == unsafe { nil } {
			return error('Metal texture readback failed')
		}
		size := width * height * 4
		mut pixels := []u8{len: size}
		unsafe {
			vmemcpy(pixels.data, ptr, size)
			free(ptr)
		}
		return pixels
	} $else {
		return error('Metal readback not available on this platform')
	}
}

// readback_gl_framebuffer reads RGBA pixels from an OpenGL
// framebuffer via glReadPixels. Rows are flipped to top-down
// order. Caller must gfx.commit() before calling. Linux only.
pub fn readback_gl_framebuffer(framebuffer u32, width int, height int) ![]u8 {
	$if linux {
		ptr := C.gui_readback_gl_framebuffer(framebuffer, width, height)
		if ptr == unsafe { nil } {
			return error('GL framebuffer readback failed')
		}
		size := width * height * 4
		mut pixels := []u8{len: size}
		unsafe {
			vmemcpy(pixels.data, ptr, size)
			free(ptr)
		}
		return pixels
	} $else {
		return error('GL readback not available on this platform')
	}
}
