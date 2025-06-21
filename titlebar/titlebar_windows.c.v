module titlebar
import sokol.sapp

#include <windows.h>
#flag windows -ldwmapi

const DWMWA_USE_IMMERSIVE_DARK_MODE = 20

// set_dark_titlebar set the window titlebar to be dark or light, api is from dwmapi.h, windows 10+ only
pub fn set_dark_titlebar( dark bool) {
	C.DwmSetWindowAttribute(sapp.win32_get_hwnd(),DWMWA_USE_IMMERSIVE_DARK_MODE, &dark, C.sizeof(dark))
}


