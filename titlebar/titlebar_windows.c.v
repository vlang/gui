module titlebar

import sokol.sapp

#include <windows.h>
#flag windows -ldwmapi

const dwmwa_use_immersive_dark_mode = 20

// set_dark_titlebar set the window titlebar to be dark or light, api is from dwmapi.h, windows 10+ only
pub fn set_dark_mode(dark bool) C.HRESULT {
	return C.DwmSetWindowAttribute(sapp.win32_get_hwnd(), dwmwa_use_immersive_dark_mode,
		&dark, C.sizeof(dark))
}
