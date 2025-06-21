module titlebar
import sokol.sapp

#include <windows.h>
#flag windows -ldwmapi

const DWMWA_USE_IMMERSIVE_DARK_MODE = 20

pub fn prefer_dark_titlebar( dark bool) {
	C.DwmSetWindowAttribute(sapp.win32_get_hwnd(),DWMWA_USE_IMMERSIVE_DARK_MODE, &dark, C.sizeof(dark))
}


