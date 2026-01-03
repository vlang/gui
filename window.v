module gui

// module gui provides a GUI framework for creating windows and user interfaces.
// The main components are:
// - Window: The main application window that manages views, events and rendering
// - View: User-defined interface elements that generate layouts
// - Layout: Arranged interface elements ready for rendering
// - Renderers: Draw instructions for the window
//
import gg
import sokol.sapp
import sync
import log

pub struct Window {
mut:
	ui             &gg.Context                 = &gg.Context{}
	state          voidptr                     = unsafe { nil }
	mutex          &sync.Mutex                 = sync.new_mutex()
	view_generator fn (&Window) View           = empty_view
	on_event       fn (e &Event, mut w Window) = fn (_ &Event, mut _ Window) {}
	focused        bool                        = true
	view_state     ViewState
	dialog_cfg     DialogCfg
	layout         Layout
	renderers      []Renderer
	animations     []Animation
	window_size    gg.Size // cached, gg.window_size() relatively slow
	refresh_window bool
}

// Window is the application window. The state parameter is a reference to where
// the application state is stored. `on_init` is where to set the application's
// first view. See `examples/get-started.v` for complete example.
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
	samples             u32                         = 2 // MSAA sample count; rounded corners of buttons with 0 and 1 look jagged on linux/windows
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
		sample_count:                 int(cfg.samples)
		init_fn:                      fn [on_init, cursor_blink] (mut w Window) {
			w.update_window_size()
			spawn w.animation_loop()
			if cursor_blink {
				w.blinky_cursor_animation()
			}
			on_init(mut w)
		}
	)
	initialize_fonts()

	$if !prod {
		at_exit(fn [window] () {
			println(window.stats())
		}) or {}
	}

	return window
}

// frame_fn is the only place where the window is rendered.
fn frame_fn(mut window Window) {
	if window.refresh_window {
		window.do_update_window()
		window.refresh_window = false
	}

	window.lock()
	window.ui.begin()
	renderers_draw(window.renderers, window)
	window.ui.end()
	window.unlock()
	sapp.set_mouse_cursor(window.view_state.mouse_cursor)
}

// event_fn is where all user events are handled. Mostly it delegates
// to child views.
fn event_fn(ev &gg.Event, mut w Window) {
	mut e := from_gg_event(ev)
	if !w.focused && e.typ == .mouse_down && e.mouse_button == MouseButton.right {
		// allow right clicks without focus.
		// motivation: browsers allow this action.
	} else if !w.focused && e.typ !in [.focused, .mouse_scroll] {
		return
	}

	// The top level layout's children each represent layers in the z-axis
	// It looks like this:
	//
	// layout
	//  - shape // empty
	//  - children
	//      - main layout
	//      - floating layout
	//      - ... floating layout
	//      - dialog layout
	//
	// While not always present, a floating layout occurs with views like menus
	// drop downs and dialogs. The dialog layout if present is always last.
	// Keyboard event handling is from the bottom up (leaf nodes) and the top
	// down (last layout first). When an dialog is present, it is the only layer
	// allowed to handle mouse/keyboard events. This effectively makes it modal.
	// An Event is processed until an event handler sets the event.is_handled`
	// member to true.
	w.lock()

	// layout is not modified else where at this point in the life cycle.
	// Locks in V do not nest, which is why unlock() is called immediately after
	// acquiring the layout. This allows event handlers to lock the window to
	// update view state, etc.
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
					w.view_state.id_focus = shape.id_focus
				}
			} else if !e.is_handled && e.key_code == .tab {
				if shape := layout.next_focusable(mut w) {
					w.view_state.id_focus = shape.id_focus
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
	gui_tooltip.id = ''
	w.update_window()
}

// update_view sets the Window's view generator. A window can have only one
// view generator. Giving a Window a new view generator clears the view_state
// and replaces the current view generator.
pub fn (mut window Window) update_view(gen_view fn (&Window) View) {
	window.lock()
	window.view_state.clear(mut window)
	window.view_generator = gen_view
	window.unlock()
	window.update_window()
}

// update_window marks the window as needing an update.
pub fn (mut window Window) update_window() {
	window.refresh_window = true
	window.ui.refresh_ui()
}

// do_update_window generates a new layout from the window's current view generator.
fn (mut window Window) do_update_window() {
	//--------------------------------------------
	window.lock()
	window.renderers.clear()
	mut old_layout := window.layout
	clip_rect := window.window_rect()
	background_color := window.color_background()

	mut view := window.view_generator(window)
	window.layout = window.compose_layout(mut view)
	render_layout(mut window.layout, background_color, clip_rect, mut window)
	window.unlock()
	//--------------------------------------------

	$if !prod {
		gui_stats.update_max_renderers(usize(window.renderers.len))
	}

	// Technically, clearing views and layouts should not be needed,
	// but it appears to help the GC in some instances.
	clear_views(mut view)
	clear_layouts(mut old_layout)
}

// compose_layout produces a layout from the given view that is
// arranged and ready for generating renderers.
fn (mut window Window) compose_layout(mut view View) Layout {
	mut layout := generate_layout(mut view, mut window)
	layouts := layout_arrange(mut layout, mut window)
	return Layout{
		shape:    &Shape{
			color: color_transparent
		}
		children: layouts
	}
}
