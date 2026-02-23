module nativebridge

// a11y_bindings.v — V-side FFI for the platform accessibility backends.

pub struct C.GuiA11yNode {
pub mut:
	parent_idx    int
	role          int
	state         int
	x             f32
	y             f32
	w             f32
	h             f32
	label         &char
	description   &char
	value_text    &char
	value_num     f32
	value_min     f32
	value_max     f32
	focus_id      int
	heading_level int
}

fn C.gui_a11y_init(voidptr, voidptr, voidptr)
fn C.gui_a11y_sync(&C.GuiA11yNode, int, int)
fn C.gui_a11y_destroy()
fn C.gui_a11y_announce(&char)

pub fn a11y_init(ns_window voidptr, cb voidptr, user_data voidptr) {
	$if macos {
		C.gui_a11y_init(ns_window, cb, user_data)
	} $else $if linux {
		C.gui_a11y_init(ns_window, cb, user_data)
	}
}

pub fn a11y_sync(nodes &C.GuiA11yNode, count int, focused_idx int) {
	$if macos {
		C.gui_a11y_sync(nodes, count, focused_idx)
	} $else $if linux {
		C.gui_a11y_sync(nodes, count, focused_idx)
	}
}

pub fn a11y_destroy() {
	$if macos {
		C.gui_a11y_destroy()
	} $else $if linux {
		C.gui_a11y_destroy()
	}
}

pub fn a11y_announce(msg string) {
	$if macos {
		C.gui_a11y_announce(msg.str)
	} $else $if linux {
		C.gui_a11y_announce(msg.str)
	}
}
