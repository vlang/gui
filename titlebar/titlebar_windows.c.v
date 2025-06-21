module titlebar

#include <windows.h>
#flag windows -ldwmapi

const DWMWA_USE_IMMERSIVE_DARK_MODE = 20

pub fn prefer_dark_titlebar(handle voidptr, dark bool) {
	C.DwmSetWindowAttribute(handle,DWMWA_USE_IMMERSIVE_DARK_MODE, &dark, C.sizeof(C.BOOL))//need sizeof dark?
}


