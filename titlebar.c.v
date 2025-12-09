module gui

// Utilities for controlling the native window titlebar appearance on Windows.
// Provides `titlebar_dark(dark bool)` which toggles the dark/light titlebar
// using the Desktop Window Manager (DWM) API on Windows 10+.
// The code is compiled and active only on Windows via `$if windows`.
//
import sokol.sapp

$if windows {
	$if tinyc {
		#include <windows.h>
	} $else {
		#include <dwmapi.h>
	}
	#flag -ldwmapi
}

// HRESULT DwmSetWindowAttribute(HWND handle, int attr, int* isDarkMode, int size);
fn C.DwmSetWindowAttribute(voidptr, u32, &u8, u32)

// titlebar_dark set the window titlebar to be dark or light, api is from dwmapi.h, windows 10+ only
pub fn titlebar_dark(dark bool) {
	$if windows {
		C.DwmSetWindowAttribute(sapp.win32_get_hwnd(), 20, &dark, sizeof(dark))
	}
}
