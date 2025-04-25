module gui

import gg
import sokol.sapp
import sync

@[heap]
pub struct Window {
mut:
	ui             &gg.Context       = &gg.Context{}
	state          voidptr           = unsafe { nil }
	mutex          &sync.Mutex       = sync.new_mutex()
	view_generator fn (&Window) View = empty_view
	layout         Layout
	renderers      []Renderer
	alert_cfg      AlertCfg
	focused        bool = true
	id_focus       u32                // id of view that has focus
	input_state    map[u32]InputState // [id_focus] -> input state
	scroll_state   map[u32]f32        // [id_scroll] -> scroll offset
	text_widths    map[string]int     // [text + hash(text_style)] -> text width
	mouse_cursor   sapp.MouseCursor   // arrow, finger, ibeam, etc.
	window_size    gg.Size            // cached, gg.window_size() relatively slow
	on_event       fn (e &Event, mut w Window) = fn (_ &Event, mut _ Window) {}
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
	state    voidptr = unsafe { nil }
	title    string  = app_title
	width    int
	height   int
	bg_color Color        = gui_theme.color_background
	on_init  fn (&Window) = fn (mut w Window) {
		w.update_window_size()
		w.update_view(empty_view)
	}
	on_event fn (e &Event, mut w Window) = fn (_ &Event, mut _ Window) {}
}

// window creates the application window. See WindowCfg on how to configure it
pub fn window(cfg &WindowCfg) &Window {
	mut window := &Window{
		state:    cfg.state
		on_event: cfg.on_event
	}
	window.ui = gg.new_context(
		bg_color:     cfg.bg_color.to_gx_color()
		width:        cfg.width
		height:       cfg.height
		window_title: cfg.title
		event_fn:     event_fn
		frame_fn:     frame_fn
		ui_mode:      true // only draw on events
		user_data:    window
		init_fn:      fn [cfg] (mut w Window) {
			w.update_window_size()
			cfg.on_init(w)
		}
	)
	return window
}

// frame_fn is the only place where the window is rendered.
fn frame_fn(mut window Window) {
	window.mutex.lock()
	window.ui.begin()
	renderers_draw(window.renderers, window.ui)
	window.ui.end()
	window.mutex.unlock()
	sapp.set_mouse_cursor(window.mouse_cursor)
}

// event_fn is where all user events are handled. Mostly it delegates
// to child views.
fn event_fn(ev &gg.Event, mut w Window) {
	mut e := from_gg_event(ev)
	if !w.focused && e.typ !in [.focused, .mouse_scroll] {
		return
	}

	// The top level layout's children each represent layers in the z-axis
	// It looks like this:
	//
	// layout
	//  - shape // empty, not used
	//  - children
	//      - main layout
	//      - floating layout
	//      - ... floating layout
	//      - alert layout
	//
	// While not always present, a floating layout occurs with views like menus
	// and drop downs. The alert layout if present is always last. Keyboard event
	// handling is from the bottom up (leaf nodes) and the top down (last layout
	// first). When an alert dialog is present, it is the only layer allowed to
	// handle keyboard events. This effectively makes it modal. Otherwise, the
	// float layers get first crack at the events and finally the main layout.
	// Events are processed until an event handler sets the `event.is_handled`
	// memeber set to true.
	w.mutex.lock()
	layout := if w.alert_cfg.visible {
		w.layout.children.last()
	} else {
		Layout{
			shape:    w.layout.shape
			children: w.layout.children.reverse()
		}
	}
	w.mutex.unlock()

	match e.typ {
		.char {
			char_handler(layout, mut e, w)
		}
		.focused {
			w.focused = true
		}
		.unfocused {
			w.focused = false
		}
		.key_down {
			keydown_handler(layout, mut e, mut w)
			m := unsafe { gg.Modifier(e.modifiers) }
			if !e.is_handled && e.key_code == .tab && m == gg.Modifier.shift {
				if shape := layout.previous_focusable(mut w) {
					w.id_focus = shape.id_focus
				}
			} else if !e.is_handled && e.key_code == .tab {
				if shape := layout.next_focusable(mut w) {
					w.id_focus = shape.id_focus
				}
			}
		}
		.mouse_down {
			w.set_mouse_cursor_arrow()
			w.set_id_focus(0)
			mouse_down_handler(layout, mut e, mut w)
		}
		.mouse_move {
			if w.pointer_over_app(e) {
				w.set_mouse_cursor_arrow()
				mouse_move_handler(layout, mut e, mut w)
			}
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
	w.update_window()
}

// update_view sets the Window's view generator. A window can have only one
// view generator. Giving a Window a new view generator replaces the current
// view generator and clears the input states, scroll states and other
// internal management states.
pub fn (mut window Window) update_view(gen_view fn (&Window) View) {
	// Clear internal state management buffers.
	// This is the only place these are cleared.
	window.id_focus = 0
	window.input_state.clear()
	window.scroll_state.clear()
	window.text_widths.clear()

	view := gen_view(window)
	layout := window.compose_layout(view)
	renderers := render_layout(layout, window.color_background(), 0, window.ui)

	window.mutex.lock()
	defer { window.mutex.unlock() }

	window.view_generator = gen_view
	window.layout = layout
	window.renderers = renderers
}

// update_window generates a new layout from the window's currnet
// view generator. It does not clear the input states. It should
// rarely be needed since event handling calls it regularly.
pub fn (mut window Window) update_window() {
	window.mutex.lock()
	defer { window.mutex.unlock() }

	view := window.view_generator(window)
	layout := window.compose_layout(view)
	renderers := render_layout(layout, window.color_background(), 0, window.ui)

	window.layout = layout
	window.renderers = renderers
}

// compose_layout produces a layout from the given view that is
// fully arranged and ready for generating renderers.
fn (window &Window) compose_layout(view &View) Layout {
	mut layout := generate_layout(view, window)
	layouts := layout_arrange(mut layout, window)
	// Combine the layouts into one layout to rule them all
	// and bind them in the darkness
	return Layout{
		children: layouts
	}
}
