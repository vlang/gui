module gui

import sokol.sapp

$if windows {
	$if tinyc {
		$compile_error('tcc does not support linking to dwmapi for now, use `-cc msvc` or `-cc gcc` instead')
	}
	#include <dwmapi.h>
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
