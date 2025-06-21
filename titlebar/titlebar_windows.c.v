module titlebar

import sokol.sapp

#include <windows.h>
#include <dwmapi.h>
#flag windows -ldwmapi

const dwmwa_use_immersive_dark_mode = 20

// set_dark_mode set the window titlebar to be dark or light, api is from dwmapi.h, windows 10+ only
pub fn set_dark_mode(dark bool) {
	C.DwmSetWindowAttribute(C.HWND(sapp.win32_get_hwnd()), 20, &dark, sizeof(dark))
}
