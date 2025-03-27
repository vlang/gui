module gui

import gg
import gx
import sokol.sapp
import sync

@[heap]
pub struct Window {
mut:
	ui           &gg.Context = &gg.Context{}
	state        voidptr     = unsafe { nil }
	layout       ShapeTree   = ShapeTree{}
	renderers    []Renderer  = []
	mutex        &sync.Mutex = sync.new_mutex()
	bg_color     gx.Color
	gen_view     fn (&Window) View = empty_view
	id_focus     FocusId
	focused      bool = true
	input_state  map[FocusId]InputState
	mouse_cursor sapp.MouseCursor
	on_event     fn (e &gg.Event, mut w Window) = fn (_ &gg.Event, mut _ Window) {}
}

// Window is the application window. The state parameter is a reference to where
// the application state is stored. `on_init` is where to set the application's
// first view.
pub struct WindowCfg {
pub:
	state    voidptr = unsafe { nil }
	title    string  = app_title_default
	width    int
	height   int
	bg_color gx.Color                       = app_background
	on_init  fn (&Window)                   = fn (_ &Window) {}
	on_event fn (e &gg.Event, mut w Window) = fn (_ &gg.Event, mut _ Window) {}
}

// window creates the application window. See WindowCfg on how to configure it
pub fn window(cfg WindowCfg) &Window {
	mut window := &Window{
		state:    cfg.state
		bg_color: cfg.bg_color
		on_event: cfg.on_event
	}
	window.ui = gg.new_context(
		bg_color:     cfg.bg_color
		width:        cfg.width
		height:       cfg.height
		window_title: cfg.title
		event_fn:     event_fn
		frame_fn:     frame_fn
		init_fn:      cfg.on_init
		ui_mode:      true // only draw on events
		user_data:    window
	)
	return window
}

fn frame_fn(mut window Window) {
	window.mutex.lock()
	window.ui.begin()
	for renderer in window.renderers {
		render_draw(renderer, window.ui)
	}
	window.ui.end()
	window.mutex.unlock()
	sapp.set_mouse_cursor(window.mouse_cursor)
}

fn event_fn(e &gg.Event, mut w Window) {
	match e.typ {
		.char {
			if !w.focused {
				return
			}
			w.mutex.lock()
			layout := w.layout
			w.mutex.unlock()

			if shape := shape_from_on_char(layout, w.id_focus) {
				if shape.on_char != unsafe { nil } {
					shape.on_char(e.char_code, w)
				}
			}
		}
		.focused {
			w.focused = true
		}
		.unfocused {
			w.focused = false
		}
		.key_down {
			if !w.focused {
				return
			}
			w.mutex.lock()
			layout := w.layout
			w.mutex.unlock()

			k := e.key_code
			m := unsafe { gg.Modifier(e.modifiers) }

			mut handled := false
			if shape := shape_from_on_key_down(layout) {
				if shape.on_keydown != unsafe { nil } {
					handled = shape.on_keydown(k, m, w)
				}
			}

			if !handled && k == .tab && m == gg.Modifier.shift {
				if shape := shape_previous_focusable(layout, mut w) {
					w.id_focus = shape.id_focus
				}
			} else if !handled && k == .tab {
				if shape := shape_next_focusable(layout, mut w) {
					w.id_focus = shape.id_focus
				}
			}
		}
		.mouse_down {
			if !w.focused {
				return
			}
			w.mutex.lock()
			layout := w.layout
			w.mutex.unlock()

			w.set_id_focus(0)
			if shape := shape_from_on_click(layout, e.mouse_x, e.mouse_y) {
				if shape.on_click != unsafe { nil } {
					if shape.id_focus > 0 {
						w.set_id_focus(shape.id_focus)
					}
					me := MouseEvent{
						mouse_x:      e.mouse_x
						mouse_y:      e.mouse_y
						mouse_button: e.mouse_button
					}
					shape.on_click(shape.cfg, me, w)
				}
			}
		}
		.mouse_move {
			if !w.pointer_over_app(e) {
				return
			}
			w.set_mouse_cursor_arrow()
		}
		else {
			// dump(e)
		}
	}
	w.on_event(e, mut w)
	w.update_window()
}

fn empty_view(_ &Window) View {
	return row(id: 'empty-view')
}

// context gets the windows gg.Context
pub fn (window &Window) context() &gg.Context {
	return window.ui
}

// id_focus gets the window's focus id
pub fn (window &Window) id_focus() int {
	return window.id_focus
}

// pointer_over_app returns true if the mouse pointer is over the app
pub fn (window &Window) pointer_over_app(e &gg.Event) bool {
	if e.mouse_x < 0 || e.mouse_y < 0 {
		return false
	}
	size := window.ui.window_size()
	if e.mouse_x > size.width || e.mouse_y > size.height {
		return false
	}
	return true
}

// state returns a reference to user supplied data
pub fn (window &Window) state[T]() &T {
	assert window.state != unsafe { nil }
	return unsafe { &T(window.state) }
}

// run starts the UI and handles events
pub fn (mut window Window) run() {
	window.ui.run()
}

// set_id_focus sets the window's focus id.
pub fn (mut window Window) set_id_focus(id FocusId) {
	window.id_focus = id
	window.update_window()
}

// update_view sets the Window's view. A window can have only one view. Giving a
// Window a new view replaces the current view. Clears the input states.
pub fn (mut window Window) update_view(gen_view fn (&Window) View) {
	view := gen_view(window)
	mut shapes := generate_shapes(view, window)
	layout_do(mut shapes, window)
	renderers := render(shapes, window.bg_color, window.ui)

	window.mutex.lock()
	defer { window.mutex.unlock() }

	window.id_focus = 0
	window.input_state.clear()
	window.gen_view = gen_view
	window.layout = shapes
	window.renderers = renderers
}

// update_window generates a new layout from the windows view. Does not clear
// the input states
pub fn (mut window Window) update_window() {
	window.mutex.lock()
	defer { window.mutex.unlock() }

	view := window.gen_view(window)
	mut shapes := generate_shapes(view, window)
	layout_do(mut shapes, window)
	renderers := render(shapes, window.bg_color, window.ui)
	window.layout = shapes
	window.renderers = renderers
}

// window_size gets the size of the window in logical units.
pub fn (window &Window) window_size() (int, int) {
	size := window.ui.window_size()
	return size.width, size.height
}

pub fn (mut window Window) resize_to_content() {
	window.mutex.lock()
	window.ui.resize(int(window.layout.shape.width), int(window.layout.shape.height))
	window.mutex.unlock()
}

pub fn (mut window Window) set_mouse_cursor_arrow() {
	window.mouse_cursor = .arrow
}

pub fn (mut window Window) set_mouse_cursor_pointing_hand() {
	window.mouse_cursor = .pointing_hand
}
