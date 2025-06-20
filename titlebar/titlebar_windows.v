module titlebar

$if windows {
	#include "@VMODROOT/titlebar/gui_window.h"
	#flag windows -ldwmapi
}

fn C.gui_prefer_dark_titlebar(voidptr, bool)

pub fn prefer_dark_titlebar(handle voidptr, dark bool) { // only windows
	$if windows {
		C.mui_prefer_dark_titlebar(handle, dark)
	}
}
