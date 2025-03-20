module gui

import gg
import gx
import sync

@[heap]
pub struct Window {
mut:
	ui               &gg.Context       = &gg.Context{}
	state            voidptr           = unsafe { nil }
	layout           ShapeTree         = ShapeTree{}
	renderers        []Renderer        = []
	mutex            &sync.Mutex       = sync.new_mutex()
	gen_view         fn (&Window) View = fn (_ &Window) View {
		return canvas(id: 'empty-view')
	}
	id_focus         FocusId
	input_state      map[FocusId]InputState
	update_on_resize bool
	mouse_x          f32
	mouse_y          f32
	on_char          fn (u32, &Window)                      = fn (c u32, _ &Window) {}
	on_click         fn (f32, f32, gg.MouseButton, &Window) = fn (x f32, y f32, _ gg.MouseButton, _ &Window) {}
	on_keydown       fn (gg.KeyCode, gg.Modifier, &Window)  = fn (k gg.KeyCode, _ gg.Modifier, _ &Window) {}
	on_mouseover     fn (f32, f32, &Window)                 = fn (x f32, y f32, _ &Window) {}
	on_resized       fn (&Window) = fn (_ &Window) {}
}

// Window is the application window. The state parameter is a reference to where
// the application state is stored. `on_init` is where to set the application's
// first view.
pub struct WindowCfg {
pub:
	state            voidptr = unsafe { nil }
	title            string
	width            int
	height           int
	bg_color         gx.Color
	update_on_resize bool         = true
	on_init          fn (&Window) = fn (_ &Window) {}
	on_resized       fn (&Window) = fn (_ &Window) {}
}

// window creates the application window. See WindowCfg on how to configure it
pub fn window(cfg WindowCfg) &Window {
	mut window := &Window{
		state:            cfg.state
		update_on_resize: cfg.update_on_resize
		on_resized:       cfg.on_resized
	}
	window.ui = gg.new_context(
		bg_color:     cfg.bg_color
		height:       cfg.height
		init_fn:      cfg.on_init
		ui_mode:      true // only draw on events
		user_data:    window
		width:        cfg.width
		window_title: cfg.title
		char_fn:      char_fn
		click_fn:     click_fn
		frame_fn:     frame_fn
		keydown_fn:   keydown_fn
		move_fn:      move_fn
		resized_fn:   resized_fn
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
}

fn char_fn(c u32, mut w Window) {
	w.mutex.lock()
	layout := w.layout
	w.mutex.unlock()

	if shape := shape_from_on_char(layout, w.id_focus) {
		if shape.on_char != unsafe { nil } {
			shape.on_char(c, w)
		}
	}
	w.update_window()
	w.on_char(c, w)
}

fn keydown_fn(c gg.KeyCode, m gg.Modifier, mut w Window) {
	w.mutex.lock()
	layout := w.layout
	w.mutex.unlock()

	mut handled := false
	if shape := shape_from_on_key_down(layout) {
		if shape.on_keydown != unsafe { nil } {
			handled = shape.on_keydown(c, m, w)
		}
	}

	if !handled && c == .tab {
		if shape := shape_next_focusable(layout, mut w) {
			w.id_focus = shape.id_focus
		}
	}
	w.update_window()
	w.on_keydown(c, m, w)
}

// clicked_fn delegates to the first Shape that has a click handler within its
// rectanguler area. The search for the Shape is in reverse order.
fn click_fn(x f32, y f32, button gg.MouseButton, mut w Window) {
	w.mutex.lock()
	layout := w.layout
	w.mutex.unlock()

	w.set_id_focus(0)
	if shape := shape_from_on_click(layout, x, y) {
		if shape.on_click != unsafe { nil } {
			if shape.id_focus > 0 {
				w.set_id_focus(shape.id_focus)
			}
			me := MouseEvent{
				mouse_x:      x
				mouse_y:      y
				mouse_button: button
			}
			shape.on_click(shape.id, me, w)
		}
	}
	w.update_window()
	w.on_click(x, y, button, w)
}

// x and y are logical units relative to the top, left corner of window
fn move_fn(x f32, y f32, mut w Window) {
	w.mouse_x = x
	w.mouse_y = y
	width, height := w.window_size()
	if x >= 0 && x < width && y >= 0 && y < height {
		w.update_window()
		w.on_mouseover(x, y, w)
	}
}

fn resized_fn(e &gg.Event, mut w Window) {
	w.on_resized(w)
	if w.update_on_resize {
		w.update_window()
	}
}

// id_focus gets the window's focus id
pub fn (window &Window) id_focus() int {
	return window.id_focus
}

// get_state returns a reference to user supplied data
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
	renderers := render(shapes, window.ui)

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
	renderers := render(shapes, window.ui)

	window.layout = shapes
	window.renderers = renderers
}

// window_size gets the size of the window in logical units.
pub fn (window &Window) window_size() (int, int) {
	size := window.ui.window_size()
	return size.width, size.height
}
