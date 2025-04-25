module gui

import gg

// background_color returns the window background color
pub fn (window &Window) color_background() Color {
	return from_gx_color(window.ui.config.bg_color)
}

// context gets the windows gg.Context
pub fn (window &Window) context() &gg.Context {
	return window.ui
}

// alert creates a alert box centered on the window.
// Alerts (sometimes called message box, confirmations, etc.)
// are the general purpose way of presenting a dialog with a
// message and buttons. Several differnt types are supported
// like OK, and YES_NO. Icons, styles, text wrapping and
// multi-line are available. See [AlertCfg](#AlertCfg) for options.
pub fn (mut window Window) alert(cfg AlertCfg) {
	window.alert_cfg = cfg
	window.alert_cfg.visible = true
	window.alert_cfg.old_id_focus = window.id_focus
	window.set_id_focus(cfg.id_focus)
}

// default_view creates an empty view
fn empty_view(window &Window) View {
	w, h := window.window_size()
	return column(
		width:  w
		height: h
	)
}

// get_text_width gets the width of the text in logical units
pub fn (mut window Window) get_text_width(text string, text_style TextStyle) int {
	return get_text_width(text, text_style, mut window)
}

// id_focus gets the window's focus id
pub fn (window &Window) id_focus() u32 {
	return window.id_focus
}

// is_focus tests if the given id_focus is equal to the windows's id_focus
pub fn (window &Window) is_focus(id_focus u32) bool {
	return window.id_focus > 0 && window.id_focus == id_focus
}

// pointer_over_app returns true if the mouse pointer is over the app
pub fn (window &Window) pointer_over_app(e &Event) bool {
	if e.mouse_x < 0 || e.mouse_y < 0 {
		return false
	}
	width, height := window.window_size()
	if e.mouse_x > width || e.mouse_y > height {
		return false
	}
	return true
}

// resize_to_content is currently not working. Need to implement gg.resize()
pub fn (mut window Window) resize_to_content() {
	window.mutex.lock()
	defer { window.mutex.unlock() }
	window.ui.resize(window.window_size.width, window.window_size.height)
}

// run starts the UI and handles events
pub fn (mut window Window) run() {
	window.ui.run()
}

// set_color_background changes the windows background color
pub fn (mut window Window) set_color_background(color Color) {
	window.ui.set_bg_color(color.to_gx_color())
}

// update_window_size caches `window.ui.window_size()` because profiler
// showed it to be a hot spot.
fn (mut window Window) update_window_size() {
	window.window_size = window.ui.window_size()
}

// scroll_vertical_by scrolls the given scrollable by delta.
// Use update_window() if not called from event handler
pub fn (mut window Window) scroll_vertical_by(id_scroll u32, delta f32) {
	window.scroll_state[id_scroll] += delta
}

// scroll_vertical_by scrolls the given scrollable to the offset. offset is negative.
// Use update_window() if not called from event handler
pub fn (mut window Window) scroll_vertical_to(id_scroll u32, offset f32) {
	window.scroll_state[id_scroll] = offset
}

// set_id_focus sets the window's focus id.
pub fn (mut window Window) set_id_focus(id u32) {
	window.id_focus = id
}

// set_mouse_cursor_arrow sets the window's mouse cursor to an arrow
pub fn (mut window Window) set_mouse_cursor_arrow() {
	window.mouse_cursor = .arrow
}

// set_mouse_cursor_ibeam sets the window's mouse cursor to an I-Beam
// typically indicating text handling.
pub fn (mut window Window) set_mouse_cursor_ibeam() {
	window.mouse_cursor = .ibeam
}

// set_mouse_cursor_pointing_hand sets the window's mouse cursor to a pointy finger
pub fn (mut window Window) set_mouse_cursor_pointing_hand() {
	window.mouse_cursor = .pointing_hand
}

// set_theme sets the current theme to the given theme.
// GUI has two builtin themes. theme_dark, theme_light
pub fn (mut window Window) set_theme(theme Theme) {
	gui_theme = theme
	window.set_color_background(theme.color_background)
}

// state returns a reference to user supplied data
pub fn (window &Window) state[T]() &T {
	assert window.state != unsafe { nil }
	return unsafe { &T(window.state) }
}

// window_size gets the cached size of the window in logical units.
pub fn (window &Window) window_size() (int, int) {
	return window.window_size.width, window.window_size.height
}
