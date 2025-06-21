module titlebar

$if windows {
	#include "@DIR/titlebar_window.h"
	#flag windows -ldwmapi
}

fn C.gui_prefer_dark_titlebar(voidptr, bool)

pub fn prefer_dark_titlebar(handle voidptr, dark bool) { // only windows
	$if windows {
		C.gui_prefer_dark_titlebar(handle, dark)
	}
}
