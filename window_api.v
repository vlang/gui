module gui

// AI-DOC: window_api.v
// - Scope: Window public API helpers not tied to init/event/render loop.
// - Exposes: dialog, focus, lock, queue, cursor, scroll, theme, locale, stats.
// - Thread model: queue_command() for cross-thread UI mutation; lock/unlock guard
//   direct state writes when needed.
// - Update model: methods that mutate visible state call update_window() when
//   not guaranteed to run inside event handlers.
import gg
import sokol.sapp
import log

fn (mut window Window) blinky_cursor_animation() {
	window.animation_add(mut BlinkCursorAnimation{})
}

// color_background returns the window background color
pub fn (_ &Window) color_background() Color {
	return gui_theme.color_background
}

// context gets the windows gg.Context
pub fn (window &Window) context() &gg.Context {
	return window.ui
}

// dialog creates a dialog centered on the window.
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
	window.view_state.input_state.set(window.dialog_cfg.id_focus, InputState{})
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
	return text_width(text, text_style, mut window)
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

pub fn (mut window Window) try_lock() bool {
	return window.mutex.try_lock()
}

// unlock unlocks the locked mutex. Same precautions apply as with [lock](#lock)
pub fn (mut window Window) unlock() {
	window.mutex.unlock()
}

// queue_command adds a command to the window's atomic command queue.
// The command will be executed on the main thread during the next frame
// update. This is the preferred way to update UI state from other threads.
pub fn (mut window Window) queue_command(cb WindowCommand) {
	window.commands_mutex.lock()
	window.commands << cb
	window.commands_mutex.unlock()
	window.ui.refresh_ui()
}

// flush_commands executes all pending commands in the command queue.
// Internal use only; called by the main loop.
fn (mut window Window) flush_commands() {
	window.commands_mutex.lock()
	if window.commands.len == 0 {
		window.commands_mutex.unlock()
		return
	}
	// Swap instead of clone+clear: avoids heap allocation and
	// prevents GC false retention from stale pointers.
	to_run := window.commands
	window.commands = []WindowCommand{}
	window.commands_mutex.unlock()

	for cb in to_run {
		cb(mut window)
	}
}

// run starts the UI and handles events
pub fn (mut window Window) run() {
	window.ui.run()

	// If initialization failed, report it and exit with error
	if window.init_error != '' {
		separator := '============================================================'
		eprintln('\n' + separator)
		eprintln('GUI INITIALIZATION ERROR')
		eprintln(separator)
		eprintln(window.init_error)
		eprintln(separator + '\n')
		exit(1)
	}
}

// resolve_font_name returns the actual font family name that Pango resolves
// for the given font description string. Useful for debugging system font loading.
pub fn (mut window Window) resolve_font_name(desc string) string {
	return window.text_system.resolve_font_name(desc) or { desc }
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

// find_layout_by_id searches the layout tree for a layout with the given ID.
pub fn (window &Window) find_layout_by_id(id string) ?Layout {
	return window.layout.find_by_id(id)
}

// scroll_to_view scrolls the parent scroll container to make the view with the given id visible.
pub fn (mut w Window) scroll_to_view(id string) {
	mut target := w.layout.find_by_id(id) or { return }
	mut p := &target
	for p.parent != unsafe { nil } {
		p = p.parent
		if p.shape.id_scroll > 0 {
			scroll_id := p.shape.id_scroll
			current_scroll := w.view_state.scroll_y.get(scroll_id) or { f32(0) }
			base_y := p.shape.y + p.shape.padding.top
			new_scroll := base_y - target.shape.y + current_scroll
			w.view_state.scroll_y.set(scroll_id, new_scroll)
			w.update_window()
			return
		}
	}
}

// scroll_horizontal_by scrolls the given scrollable by delta.
// Use update_window() if not called from event handler
pub fn (mut window Window) scroll_horizontal_by(id_scroll u32, delta f32) {
	current := window.view_state.scroll_x.get(id_scroll) or { f32(0) }
	window.view_state.scroll_x.set(id_scroll, current + delta)
}

// scroll_horizontal_to scrolls the given scrollable to the offset. offset is negative.
// Use update_window() if not called from event handler
pub fn (mut window Window) scroll_horizontal_to(id_scroll u32, offset f32) {
	window.view_state.scroll_x.set(id_scroll, offset)
}

// scroll_vertical_by scrolls the given scrollable by delta.
// Use update_window() if not called from event handler
pub fn (mut window Window) scroll_vertical_by(id_scroll u32, delta f32) {
	current := window.view_state.scroll_y.get(id_scroll) or { f32(0) }
	window.view_state.scroll_y.set(id_scroll, current + delta)
}

// scroll_vertical_to scrolls the given scrollable to the offset. offset is negative.
// Use update_window() if not called from event handler
pub fn (mut window Window) scroll_vertical_to(id_scroll u32, offset f32) {
	window.view_state.scroll_y.set(id_scroll, offset)
}

// set_id_focus sets the window's focus id.
// Side-effect: triggers update_ime_focus(), which routes the IME overlay to
// the focused field. Always use set_id_focus for tab navigation — do NOT
// assign w.view_state.id_focus directly. See CLAUDE.md §IME Integration.
pub fn (mut window Window) set_id_focus(id u32) {
	window.view_state.clear_input_selections()
	if id != window.view_state.id_focus {
		log.debug('set_id_focus: ${id}')
		// Cancel active IME composition on focus change
		if window.text_system != unsafe { nil } && window.text_system.is_composing() {
			window.text_system.reset_ime_state()
		}
	}
	window.view_state.id_focus = id
	// Route IME overlay to focused field
	window.update_ime_focus(id)
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

// set_rtf_tooltip shows a tooltip with the given text at the specified rect.
// Used for abbreviation tooltips in RTF views.
pub fn (mut window Window) set_rtf_tooltip(text string, rect gg.Rect) {
	window.view_state.rtf_tooltip_text = text
	window.view_state.rtf_tooltip_rect = rect
}

// render_rtf_tooltip renders an active RTF abbreviation tooltip.
fn (mut window Window) render_rtf_tooltip(clip DrawClip) {
	tooltip_text := window.view_state.rtf_tooltip_text
	rect := window.view_state.rtf_tooltip_rect

	// Create and layout tooltip view with max width and wrapping
	mut tooltip_view := tooltip(TooltipCfg{
		id:      '__rtf_tooltip__'
		padding: padding_none
		content: [
			column(
				padding:   padding_small
				max_width: 200
				content:   [View(text(TextCfg{ text: tooltip_text, mode: .wrap }))]
			),
		]
		anchor:  .bottom_center
	})
	mut layout := generate_layout(mut tooltip_view, mut window)

	// Calculate sizes (without position)
	layout_widths(mut layout)
	layout_fill_widths_with_scratch(mut layout, mut window.scratch.distribute)
	layout_wrap_text(mut layout, mut window)
	layout_heights(mut layout)
	layout_fill_heights_with_scratch(mut layout, mut window.scratch.distribute)

	// Calculate position below abbreviation, clamped to stay on screen
	mut x := rect.x + rect.width / 2 - layout.shape.width / 2
	if x < 0 {
		x = 0
	}
	y := rect.y + rect.height + 3

	// Now compute positions with the offset
	layout_positions(mut layout, x, y, window)

	layout.shape.shape_clip = DrawClip{
		x:      layout.shape.x
		y:      layout.shape.y
		width:  layout.shape.width
		height: layout.shape.height
	}

	render_layout(mut layout, color_transparent, clip, mut window)
}

// set_locale sets the current locale and triggers a full rebuild.
pub fn (mut window Window) set_locale(locale Locale) {
	gui_locale = locale
	window.update_window()
}

// set_locale_id switches to a registered locale by id.
pub fn (mut window Window) set_locale_id(id string) ! {
	locale := locale_get(id)!
	window.set_locale(locale)
}

// set_theme sets the current theme to the given theme.
// GUI has two builtin themes. theme_dark, theme_light
pub fn (mut window Window) set_theme(theme Theme) {
	gui_theme = theme
	titlebar_dark(theme.titlebar_dark)
	window.view_state.markdown_cache.clear()
	window.view_state.diagram_cache.clear()
	window.set_color_background(theme.color_background)
}

// state returns a reference to user supplied data
pub fn (window &Window) state[T]() &T {
	assert window.state != unsafe { nil }
	return unsafe { &T(window.state) }
}

// get_layout_stats returns layout performance statistics.
// Populated when debug_layout is true.
pub fn (window &Window) get_layout_stats() LayoutStats {
	return window.layout_stats
}

// renderers_count returns the number of active renderers.
pub fn (window &Window) renderers_count() int {
	return window.renderers.len
}

// window_size gets the cached size of the window in logical units.
pub fn (window &Window) window_size() (int, int) {
	return window.window_size.width, window.window_size.height
}

// window_rect gets the cached size of the window in logical units as a [Rect](#Rect).
pub fn (window &Window) window_rect() gg.Rect {
	return gg.Rect{0, 0, window.window_size.width, window.window_size.height}
}
