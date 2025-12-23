module gui

import gg
import sokol.sapp
import time

fn (mut window Window) blinky_cursor_animation() {
	window.animation_add(mut Animate{
		id:       '___blinky_cursor_animation___'
		delay:    600 * time.millisecond
		repeat:   true
		callback: fn (mut an Animate, mut w Window) {
			if w.view_state.cursor_on_sticky {
				w.view_state.input_cursor_on = true
				w.view_state.cursor_on_sticky = false
			} else {
				w.view_state.input_cursor_on = !w.view_state.input_cursor_on
			}
		}
	})
}

// color_background returns the window background color
pub fn (_ &Window) color_background() Color {
	return gui_theme.color_background
}

// clear_view_states clears all cached view_states. Gui keeps a number of items
// like scroll positions, cursor positions, etc.
pub fn (mut window Window) clear_view_states() {
	window.view_state.clear(mut window)
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
// only for the predefined types.
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

// empty_view - default_view creates an empty view
fn empty_view(window &Window) View {
	w, h := window.window_size()
	return column(
		width:  w
		height: h
	)
}

// get_dropped_file_paths gets the paths names of the dropped files.
// Use in EventType.dropped_files. See `drop_files_demo.v` in examples.
pub fn (_ &Window) get_dropped_file_paths() []string {
	len := sapp.get_num_dropped_files()
	mut paths := []string{cap: len}
	for i in 0 .. len {
		paths << sapp.get_dropped_file_path(i)
	}
	return paths.filter(it.len > 0)
}

// get_text_width gets the width of the text in logical units
pub fn (mut window Window) get_text_width(text string, text_style TextStyle) f32 {
	return get_text_width(text, text_style, mut window)
}

// has_focus returns true if window has focus
pub fn (window &Window) has_focus() bool {
	return window.focused
}

// id_focus gets the window's focus id
pub fn (window &Window) id_focus() u32 {
	return window.view_state.id_focus
}

// is_focus tests if the given id_focus is equal to the windows's id_focus
pub fn (window &Window) is_focus(id_focus u32) bool {
	return window.view_state.id_focus > 0 && window.view_state.id_focus == id_focus
}

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

// @lock locks the window's mutex semaphore. This is the same mutex used
// to access the app model internally. There is usually no need to lock
// when responding to events (mouse, keyboard, etc.) It is good practice
// to lock when updating the app model from other threads. Locking twice
// in the same thread results in a dead lock or panic. Use with caution.
// Call [unlock](#unlock) to unlock.
pub fn (mut window Window) @lock() {
	window.mutex.lock()
}

// unlock unlocks the locked mutex. Same precautions apply as with [lock](#lock)
pub fn (mut window Window) unlock() {
	window.mutex.unlock()
}

// resize_to_content is currently not working. Need to implement gg.resize()
pub fn (mut window Window) resize_to_content() {
	window.lock()
	defer { window.unlock() }
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
	window.view_state.scroll_x[id_scroll] += delta
}

// scroll_horizontal_to scrolls the given scrollable to the offset. offset is negative.
// Use update_window() if not called from event handler
pub fn (mut window Window) scroll_horizontal_to(id_scroll u32, offset f32) {
	window.view_state.scroll_x[id_scroll] = offset
}

// scroll_vertical_by scrolls the given scrollable by delta.
// Use update_window() if not called from event handler
pub fn (mut window Window) scroll_vertical_by(id_scroll u32, delta f32) {
	window.view_state.scroll_y[id_scroll] += delta
}

// scroll_vertical_to scrolls the given scrollable to the offset. offset is negative.
// Use update_window() if not called from event handler
pub fn (mut window Window) scroll_vertical_to(id_scroll u32, offset f32) {
	window.view_state.scroll_y[id_scroll] = offset
}

// set_id_focus sets the window's focus id.
pub fn (mut window Window) set_id_focus(id u32) {
	window.view_state.clear_input_selections()
	window.view_state.id_focus = id
}

// set_mouse_cursor_all sets the window's mouse cursor to cross arrows
pub fn (mut window Window) set_mouse_cursor_all() {
	window.view_state.mouse_cursor = .resize_all
}

// set_mouse_cursor_crosshair sets the window's mouse cursor to crosshair
pub fn (mut window Window) set_mouse_cursor_crosshair() {
	window.view_state.mouse_cursor = .crosshair
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

// set_mouse_cursor_not_allowed sets the window's mouse cursor not allowed symbol
pub fn (mut window Window) set_mouse_cursor_not_allowed() {
	window.view_state.mouse_cursor = .not_allowed
}

// set_mouse_cursor_pointing_hand sets the window's mouse cursor to a pointy finger
pub fn (mut window Window) set_mouse_cursor_pointing_hand() {
	window.view_state.mouse_cursor = .pointing_hand
}

// set_mouse_cursor_ns sets the window's mouse cursor to up/down arrows
pub fn (mut window Window) set_mouse_cursor_ns() {
	window.view_state.mouse_cursor = .resize_ns
}

// set_mouse_cursor_ew sets the window's mouse cursor to up/down arrows
pub fn (mut window Window) set_mouse_cursor_ew() {
	window.view_state.mouse_cursor = .resize_ew
}

// set_mouse_cursor_resize_nesw sets the window's mouse cursor to slanted arrows
pub fn (mut window Window) set_mouse_cursor_resize_nesw() {
	window.view_state.mouse_cursor = .resize_nesw
}

// set_mouse_cursor_resize_nwse sets the window's mouse cursor to slanted arrows
pub fn (mut window Window) set_mouse_cursor_resize_nwse() {
	window.view_state.mouse_cursor = .resize_nwse
}

// set_theme sets the current theme to the given theme.
// GUI has two builtin themes. theme_dark, theme_light
pub fn (mut window Window) set_theme(theme Theme) {
	gui_theme = theme
	titlebar_dark(theme.titlebar_dark)
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

// window_rect gets the cached size of the window in logical units as a [Rect](#Rect).
pub fn (window &Window) window_rect() gg.Rect {
	return gg.Rect{0, 0, window.window_size.width, window.window_size.height}
}
