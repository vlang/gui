module gui

// module gui provides a GUI framework.
// Components:
// - Window: Manages views, events, rendering
// - View: Interface elements generating layouts
// - Layout: Arranged elements ready for render
// - Renderers: Drawing instructions
//
import gg
import sokol.sapp
import sync
import log
import vglyph

// WindowCommand is a callback function that executes on the main thread
// to update the window state. Used for thread-safe state mutations.
pub type WindowCommand = fn (mut Window)

pub struct Window {
mut:
	commands_mutex           &sync.Mutex                 = sync.new_mutex() // Mutex for command queue
	focused                  bool                        = true // Window focus state
	mutex                    &sync.Mutex                 = sync.new_mutex() // Mutex for thread-safety
	on_event                 fn (e &Event, mut w Window) = fn (_ &Event, mut _ Window) {}           // Global event handler
	state                    voidptr                     = unsafe { nil }    // User state passed to the window
	text_system              &vglyph.TextSystem          = unsafe { nil }    // Text rendering system
	ui                       &gg.Context                 = &gg.Context{} // Main sokol/gg graphics context
	view_generator           fn (&Window) View           = empty_view        // Function to generate the UI view
	animations               map[string]Animation // Active animations (keyed by id)
	commands                 []WindowCommand      // Atomic command queue for UI state updates
	debug_layout             bool                 // enable layout performance stats
	dialog_cfg               DialogCfg            // Configuration for the active dialog (if any)
	filter_state             SvgFilterState       // Offscreen state for SVG filters
	ime                      IME                  // Input Method Editor state (lazily initialized)
	init_error               string               // error during initialization (e.g. text system fail)
	layout                   Layout               // The current calculated layout tree
	layout_stats             LayoutStats          // populated when debug_layout is true
	pip                      Pipelines            // GPU rendering pipelines (lazily initialized)
	refresh_layout           bool                 // Trigger full view/layout/renderer rebuild next frame
	refresh_render_only      bool                 // Trigger renderer-only rebuild from existing layout
	renderers                []Renderer           // Flat list of drawing instructions for the current frame
	filter_renderers_scratch []Renderer           // Reused by filter post-process pass
	render_guard_warned      map[string]bool      // Renderer kinds warned by render guard (prod only)
	stats                    Stats                // Rendering statistics
	view_state               ViewState            // Manages state for widgets (scroll, selection, etc.)
	window_size              gg.Size              // cached, gg.window_size() relatively slow
}

// Window is the main application window. `state` holds app state.
// `on_init` sets the initial view. See `examples/get-started.v`.
// Example:
// ```v
// import gui
//
// fn main() {
// 	mut window := gui.window(
// 		width:   300
// 		height:  300
// 		on_init: fn (mut w gui.Window) {
// 			w.update_view(main_view)
// 		}
// 	)
// 	window.run()
// }
//
// fn main_view(window &gui.Window) gui.View {
// 	w, h := window.window_size()
// 	return gui.column(
// 		width:   w
// 		height:  h
// 		sizing:  gui.fixed_fixed
// 		h_align: .center
// 		v_align: .middle
// 		content: [gui.text(text: 'Welcome to GUI')]
// 	)
// }
// ```
pub struct WindowCfg {
pub:
	state               voidptr = unsafe { nil }
	title               string  = app_title
	width               int
	height              int
	cursor_blink        bool
	bg_color            Color           = gui_theme.color_background
	dragndrop           bool            = true
	dragndrop_files_max u32             = 10
	dragndrop_path_max  u32             = 2048
	on_init             fn (mut Window) = fn (mut w Window) {
		w.update_view(empty_view)
	}
	on_event            fn (e &Event, mut w Window) = fn (_ &Event, mut _ Window) {}
	log_level           log.Level                   = default_log_level()
}

fn default_log_level() log.Level {
	tag := $d('gui_window_log_level', 'disabled')
	res := log.level_from_tag(tag) or { log.Level.disabled }
	return res
}

// window creates the application window. See [WindowCfg](#WindowCfg) on how to configure it
pub fn window(cfg &WindowCfg) &Window {
	log.set_level(cfg.log_level)
	log.set_always_flush(true)

	mut window := &Window{
		state:    cfg.state
		on_event: cfg.on_event
	}
	on_init := cfg.on_init
	cursor_blink := cfg.cursor_blink
	window.ui = gg.new_context(
		bg_color:                     cfg.bg_color.to_gx_color()
		width:                        cfg.width
		height:                       cfg.height
		window_title:                 cfg.title
		event_fn:                     event_fn
		enable_dragndrop:             cfg.dragndrop
		max_dropped_files:            int(cfg.dragndrop_files_max)
		max_dropped_file_path_length: int(cfg.dragndrop_path_max)
		frame_fn:                     frame_fn
		ui_mode:                      true // only draw on events
		user_data:                    window
		init_fn:                      fn [on_init, cursor_blink] (mut w Window) {
			w.update_window_size()

			// Initialize text rendering system
			w.text_system = vglyph.new_text_system(mut w.ui) or {
				w.init_error = 'Failed to initialize text rendering system: ${err.str()}\n\nThis is typically caused by OpenGL compatibility issues.'
				log.error(w.init_error)
				sapp.quit()
				return
			}

			// Initialize fonts with graceful degradation
			initialize_fonts(mut w.text_system) or {
				log.warn('Font initialization failed: ${err.msg()}')
				log.warn('Application will continue with system fonts only.')
				// Continue without custom fonts as fallback
			}

			spawn w.animation_loop()
			if cursor_blink {
				w.blinky_cursor_animation()
			}
			on_init(mut w)
		}
	)

	$if !prod {
		at_exit(fn [window] () {
			println(window.stats())
		}) or {}
	}

	return window
}

// frame_fn is the only place where the window is rendered.
fn frame_fn(mut window Window) {
	window.flush_commands()
	window.init_ime()

	if window.refresh_layout {
		window.update()
		window.refresh_layout = false
		window.refresh_render_only = false
	} else if window.refresh_render_only {
		window.update_render_only()
		window.refresh_render_only = false
	}

	// Process SVG filters in offscreen passes BEFORE the
	// swapchain pass; sokol doesn't support nested passes.
	process_svg_filters(mut window)

	window.lock()
	window.ui.begin()
	renderers_draw(mut window)
	window.ui.end()
	window.unlock()
	sapp.set_mouse_cursor(window.view_state.mouse_cursor)
}

// event_fn handles user events, mostly delegating to child views.
fn event_fn(ev &gg.Event, mut w Window) {
	mut e := from_gg_event(ev)
	if !w.focused && e.typ == .mouse_down && e.mouse_button == MouseButton.right {
		// allow right clicks without focus.
		// motivation: browsers allow this action.
	} else if !w.focused && e.typ !in [.focused, .mouse_scroll] {
		return
	}

	// Top-level layout children represent z-axis layers:
	// layout -> [main layout, floating layouts..., dialog layout]
	// Dialogs are modal if present. Events process bottom-up (leaf nodes) then
	// top-down (layers). Processing stops when `event.is_handled` is true.
	w.lock()

	// Layout is immutable here. Unlock immediately to allow handlers to lock
	// window for state updates.
	layout := if w.dialog_cfg.visible { w.layout.children.last() } else { w.layout }
	w.unlock()

	match e.typ {
		.char {
			char_handler(layout, mut e, mut w)
		}
		.focused {
			w.focused = true
		}
		.unfocused {
			w.focused = false
		}
		.key_down {
			keydown_handler(layout, mut e, mut w)
			if !e.is_handled && e.key_code == .tab && e.modifiers == .shift {
				if shape := layout.previous_focusable(mut w) {
					w.set_id_focus(shape.id_focus)
				}
			} else if !e.is_handled && e.key_code == .tab {
				if shape := layout.next_focusable(mut w) {
					w.set_id_focus(shape.id_focus)
				}
			}
		}
		.mouse_down {
			w.set_mouse_cursor_arrow()
			mouse_down_handler(layout, false, mut e, mut w)
			if !e.is_handled {
				w.view_state.select_state.clear()
			}
		}
		.mouse_move {
			w.set_mouse_cursor_arrow()
			w.view_state.menu_key_nav = false
			w.view_state.rtf_tooltip_text = '' // Clear before checking for new tooltip
			mouse_move_handler(layout, mut e, mut w)
		}
		.mouse_up {
			mouse_up_handler(layout, mut e, mut w)
		}
		.mouse_scroll {
			mouse_scroll_handler(layout, mut e, mut w)
		}
		.resized {
			w.update_window_size()
		}
		else {
			// dump(e)
		}
	}
	if !e.is_handled {
		w.on_event(e, mut w)
	}
	if e.is_handled {
		log.debug('event_fn: ${e.typ} handled: ${e}')
	}
	w.view_state.tooltip.id = ''
	w.update_window()
}

// update_view replaces the current view generator and clears view state.
pub fn (mut window Window) update_view(gen_view fn (&Window) View) {
	window.lock()
	window.clear_view_state()
	window.view_generator = gen_view
	window.unlock()
	window.update_window()
}

// update_window marks the window as needing an update. The actual update
// (re-calculating layout and generating renderers) is performed at the start
// of the next frame to batch multiple state changes.
pub fn (mut window Window) update_window() {
	window.mark_layout_refresh()
	window.ui.refresh_ui()
}

fn (mut window Window) request_render_only() {
	window.mark_render_only_refresh()
	window.ui.refresh_ui()
}

fn (mut window Window) mark_layout_refresh() {
	window.refresh_layout = true
	window.refresh_render_only = false
}

fn (mut window Window) mark_render_only_refresh() {
	if !window.refresh_layout {
		window.refresh_render_only = true
	}
}

// update generates a new layout from the window's current view generator.
fn (mut window Window) update() {
	log.debug('update_window')
	//--------------------------------------------
	window.lock()
	clip_rect := window.window_rect()
	background_color := window.color_background()

	mut view := window.view_generator(window)
	layout_clear(mut window.layout)
	window.layout = window.compose_layout(mut view)
	window.rebuild_renderers(background_color, clip_rect)
	window.unlock()
	//--------------------------------------------

	view_clear(mut view)
	window.stats.update_max_renderers(usize(window.renderers.len))
}

fn (mut window Window) update_render_only() {
	log.debug('update_render_only')
	//--------------------------------------------
	window.lock()
	clip_rect := window.window_rect()
	background_color := window.color_background()
	window.rebuild_renderers(background_color, clip_rect)
	window.unlock()
	//--------------------------------------------

	window.stats.update_max_renderers(usize(window.renderers.len))
}

fn (mut window Window) rebuild_renderers(background_color Color, clip_rect DrawClip) {
	// process_svg_filters swaps renderer buffers. Detach scratch before
	// freeing renderers to avoid stale aliasing to freed storage.
	window.filter_renderers_scratch = []Renderer{}
	unsafe { window.renderers.free() }
	render_layout(mut window.layout, background_color, clip_rect, mut window)

	// Render RTF tooltip if active
	if window.view_state.rtf_tooltip_text != '' {
		window.render_rtf_tooltip(clip_rect)
	}
}

// compose_layout takes the View generated by the user's view function and
// processes it into a fully resolved Layout tree. This involves:
// 1. Transforming the View tree into a Layout tree (`generate_layout`)
// 2. Calculating sizes and positions for all elements (`layout_arrange`)
// 3. Wrapping the result in a root Layout with a transparent background
fn (mut window Window) compose_layout(mut view View) Layout {
	timer := if window.debug_layout { layout_stats_timer_start() } else { LayoutStatsTimer{} }

	mut layout := generate_layout(mut view, mut window)
	layouts := layout_arrange(mut layout, mut window)
	result := Layout{
		shape:    &Shape{
			color: color_transparent
		}
		children: layouts
	}

	if window.debug_layout {
		window.layout_stats = LayoutStats{
			total_time_us:  timer.elapsed_us()
			node_count:     count_nodes(&result)
			floating_count: layouts.len - 1
		}
	}

	return result
}
