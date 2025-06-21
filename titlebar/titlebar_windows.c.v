module titlebar

#include <windows.h>
#flag windows -ldwmapi

const DWMWA_USE_IMMERSIVE_DARK_MODE = 20

pub fn prefer_dark_titlebar(handle voidptr, dark bool) {
	C.DwmSetWindowAttribute(handle,DWMWA_USE_IMMERSIVE_DARK_MODE, &dark, C.sizeof(C.BOOL))//need sizeof dsrk?
}

//
// #include "@DIR/titlebar_windows.h"
// #flag windows -ldwmapi
//
// fn C.gui_prefer_dark_titlebar(voidptr, bool)
//
// pub fn prefer_dark_titlebar(handle voidptr, dark bool) {
// 	C.gui_prefer_dark_titlebar(handle, dark)
// }
//

