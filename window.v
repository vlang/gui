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
	commands_mutex        &sync.Mutex                 = sync.new_mutex() // Mutex for command queue
	focused               bool                        = true // Window focus state
	mutex                 &sync.Mutex                 = sync.new_mutex() // Mutex for thread-safety
	on_event              fn (e &Event, mut w Window) = fn (_ &Event, mut _ Window) {}           // Global event handler
	state                 voidptr                     = unsafe { nil }    // User state passed to the window
	text_system           &vglyph.TextSystem          = unsafe { nil }    // Text rendering system
	ui                    &gg.Context                 = &gg.Context{} // Main sokol/gg graphics context
	view_generator        fn (&Window) View           = empty_view        // Function to generate the UI view
	a11y                  A11y                          // Accessibility backend state (lazily initialized)
	animations            map[string]Animation          // Active animations (keyed by id)
	commands              []WindowCommand               // Atomic command queue for UI state updates
	debug_layout          bool                          // enable layout performance stats
	inspector_enabled     bool                          // dev-only inspector overlay (F12)
	inspector_tree_cache  []TreeNodeCfg                 // previous-frame tree for inspector
	inspector_props_cache map[string]InspectorNodeProps // previous-frame node properties
	dialog_cfg            DialogCfg                     // Configuration for the active dialog (if any)
	filter_state          SvgFilterState                // Offscreen state for SVG filters
	ime                   IME             // Input Method Editor state (lazily initialized)
	init_error            string          // error during initialization (e.g. text system fail)
	layout                Layout          // The current calculated layout tree
	layout_stats          LayoutStats     // populated when debug_layout is true
	pip                   Pipelines       // GPU rendering pipelines (lazily initialized)
	refresh_layout        bool            // Trigger full view/layout/renderer rebuild next frame
	refresh_render_only   bool            // Trigger renderer-only rebuild from existing layout
	render_guard_warned   map[string]bool // Renderer kinds warned by render guard (prod only)
	renderers             []Renderer      // Flat list of drawing instructions for the current frame
	scratch               ScratchPools    // Bounded scratch arrays reused in hot paths
	stats                 Stats           // Rendering statistics
	clip_radius           f32             // rounded clip radius, render-time only
	view_state            ViewState       // Manages state for widgets (scroll, selection, etc.)
	window_size           gg.Size         // cached, gg.window_size() relatively slow
	file_access           FileAccessState // security-scoped bookmark state
	file_access_mutex     &sync.Mutex = sync.new_mutex() // guards file access state
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
	state               voidptr = unsafe { nil } // passed through as w.state; cast to app struct pointer
	app_id              string // bundle/app identifier for bookmark persistence (e.g. "com.example.myapp")
	title               string = app_title
	width               int
	height              int
	cursor_blink        bool // enable blinking text cursor (blink animation)
	bg_color            Color           = gui_theme.color_background
	dragndrop           bool            = true
	dragndrop_files_max u32             = 10
	dragndrop_path_max  u32             = 2048
	on_init             fn (mut Window) = fn (mut w Window) {
		w.update_view(empty_view)
	} // called once after GPU init; set the initial view here via w.update_view()
	on_event            fn (e &Event, mut w Window) = fn (_ &Event, mut _ Window) {} // global event hook; fires for all events
	log_level           log.Level                   = default_log_level()
	debug_layout        bool // print layout timing stats to stdout each frame
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
		state:        cfg.state
		on_event:     cfg.on_event
		debug_layout: cfg.debug_layout
		file_access:  FileAccessState{
			app_id: cfg.app_id
		}
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
		cleanup_fn:                   window_cleanup
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
