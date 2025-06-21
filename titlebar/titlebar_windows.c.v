module titlebar

import sokol.sapp

#include <windows.h>
#flag windows -ldwmapi

// HRESULT DwmSetWindowAttribute(HWND handle, int attr, int* isDarkMode, int size);
fn C.DwmSetWindowAttribute(voidptr, u32, &u8, u32)

// set_dark_mode set the window titlebar to be dark or light, api is from dwmapi.h, windows 10+ only
pub fn set_dark_mode(dark bool) {
	C.DwmSetWindowAttribute(sapp.win32_get_hwnd(), 20, &dark, sizeof(dark))
}
