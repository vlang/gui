module gui

import gg
import sokol.sapp

// background_color returns the window background color
pub fn (window &Window) color_background() Color {
	return from_gx_color(window.ui.config.bg_color)
}

// context gets the windows gg.Context
pub fn (window &Window) context() &gg.Context {
	return window.ui
}

// dialog creates an dialog dialog centered on the window.
// Dialog presents a dialog with a message and buttons.
// Predefined types include: **message**, **confirm**
// **prompt** and others. See [DialogType](#DialogType)
//
// The custom type displays the given content. Custom content
// provides any needed callbacks as the standard ones work
// only for the predfined types.
//
// Body text wraps as needed. Newlines in body text display
// appropriately.
//
// Ctrl-C copies the title and body portions to the clipboard
// (predefined types only). See [DialogCfg](#DialogCfg).
pub fn (mut window Window) dialog(cfg DialogCfg) {
	window.dialog_cfg = cfg
	window.dialog_cfg.visible = true
	window.dialog_cfg.old_id_focus = window.view_state.id_focus
	window.set_id_focus(cfg.id_focus)
}

// dialog_dismiss closes an dialog box without invoking callbacks.
// Useful for custom dialog types.
pub fn (mut window Window) dialog_dismiss() {
	window.view_state.input_state[window.dialog_cfg.id_focus] = InputState{}
	window.dialog_cfg = DialogCfg{}
}

// dialog_is_visible return true if a dialog is visible.
pub fn (mut window Window) dialog_is_visible() bool {
	return window.dialog_cfg.visible
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
pub fn (mut window Window) get_text_width(text string, text_style TextStyle) f32 {
	return get_text_width(text, text_style, mut window)
}

// id_focus gets the window's focus id
pub fn (window &Window) id_focus() u32 {
	return window.view_state.id_focus
}

// is_focus tests if the given id_focus is equal to the windows's id_focus
pub fn (window &Window) is_focus(id_focus u32) bool {
	return window.view_state.id_focus > 0 && window.view_state.id_focus == id_focus
}

// pub fn (window &Window) menu_is_selected(id string) bool {
// 	return window.view_state.menu_selected.exists(id)
// }

// pub fn (mut window Window) menu_select(id string) {
// 	window.view_state.menu_selected.add(id)
// }

// mouse_is_locked determines if mouse is currently in a locked state
// Locked states are used for mouse drag operations
pub fn (window &Window) mouse_is_locked() bool {
	return window.view_state.mouse_lock.mouse_down != none
		|| window.view_state.mouse_lock.mouse_move != none
		|| window.view_state.mouse_lock.mouse_up != none
}

// mouse_lock locks the mouse so all mouse events go to the
// handlers in MouseLockCfg
pub fn (mut window Window) mouse_lock(cfg MouseLockCfg) {
	window.view_state.mouse_lock = cfg
}

// mouse_unlock returns mouse handling events to normal behavior
pub fn (mut window Window) mouse_unlock() {
	window.view_state.mouse_lock = MouseLockCfg{}
	sapp.lock_mouse(false)
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

// scroll_horizontal_by scrolls the given scrollable by delta.
// Use update_window() if not called from event handler
pub fn (mut window Window) scroll_horizontal_by(id_scroll u32, delta f32) {
	window.view_state.offset_x_state[id_scroll] += delta
}

// scroll_horizontal_to scrolls the given scrollable to the offset. offset is negative.
// Use update_window() if not called from event handler
pub fn (mut window Window) scroll_horizontal_to(id_scroll u32, offset f32) {
	window.view_state.offset_x_state[id_scroll] = offset
}

// scroll_vertical_by scrolls the given scrollable by delta.
// Use update_window() if not called from event handler
pub fn (mut window Window) scroll_vertical_by(id_scroll u32, delta f32) {
	window.view_state.offset_y_state[id_scroll] += delta
}

// scroll_vertical_to scrolls the given scrollable to the offset. offset is negative.
// Use update_window() if not called from event handler
pub fn (mut window Window) scroll_vertical_to(id_scroll u32, offset f32) {
	window.view_state.offset_y_state[id_scroll] = offset
}

// set_id_focus sets the window's focus id.
pub fn (mut window Window) set_id_focus(id u32) {
	window.view_state.id_focus = id
}

// set_mouse_cursor_arrow sets the window's mouse cursor to an arrow
pub fn (mut window Window) set_mouse_cursor_arrow() {
	window.view_state.mouse_cursor = .arrow
}

// set_mouse_cursor_ibeam sets the window's mouse cursor to an I-Beam
// typically indicating text handling.
pub fn (mut window Window) set_mouse_cursor_ibeam() {
	window.view_state.mouse_cursor = .ibeam
}

// set_mouse_cursor_pointing_hand sets the window's mouse cursor to a pointy finger
pub fn (mut window Window) set_mouse_cursor_pointing_hand() {
	window.view_state.mouse_cursor = .pointing_hand
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

pub fn (window &Window) window_rect() gg.Rect {
	return gg.Rect{0, 0, window.window_size.width, window.window_size.height}
}
