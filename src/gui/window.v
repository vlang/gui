module gui

import gg
import gx
import sync

@[heap]
pub struct Window {
mut:
	state      voidptr   = unsafe { nil }
	layout     ShapeTree = empty_shape_tree
	focus_id   int
	cursor_x   int // char position of cursor in focused text
	cursor_y   int // line position of cursor in focuses text
	mutex      &sync.Mutex  = unsafe { nil }
	ui         &gg.Context  = unsafe { nil }
	on_resized fn (&Window) = unsafe { nil }
}

// Window is the application window. The state parameter is
// a reference to where your application state is stored.
// `on_init` is where you should set the applications first view.
// If resizing is desired, define a function that updates the
// view and assign to `on_resize`
pub struct WindowCfg {
pub:
	state      voidptr = unsafe { nil }
	title      string
	width      int
	height     int
	bg_color   gx.Color
	on_init    fn (&Window) = unsafe { nil }
	on_resized fn (&Window) = unsafe { nil }
}

// window creates the application window.
// See WindowCfg on how to configure it
pub fn window(cfg WindowCfg) &Window {
	mut window := &Window{
		state:      cfg.state
		mutex:      sync.new_mutex()
		on_resized: cfg.on_resized
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
		resized_fn:   resized_fn
	)
	return window
}

fn frame_fn(mut window Window) {
	window.mutex.lock()
	window.ui.begin()
	window.draw_shapes(window.layout)
	window.ui.end()
	window.mutex.unlock()
}

fn (mut window Window) draw_shapes(shapes ShapeTree) {
	shapes.shape.draw(window.ui)
	for child in shapes.children {
		window.draw_shapes(child)
	}
}

fn char_fn(c u32, mut w Window) {
	w.mutex.lock()
	layout := w.layout
	w.mutex.unlock()

	shape := shape_from_on_char(layout)

	if shape.on_char != unsafe { nil } {
		shape.on_char(c, w)
	}
}

// clicked delegates to the first Shape that has a click
// handler within its rectanguler area. The search for
// the Shape is in reverse order.
fn click_fn(x f32, y f32, button gg.MouseButton, mut w Window) {
	w.mutex.lock()
	layout := w.layout
	w.mutex.unlock()

	shape := shape_from_point_on_click(layout, x, y)

	if shape.on_click != unsafe { nil } {
		me := MouseEvent{
			mouse_x:      x
			mouse_y:      y
			mouse_button: MouseButton(button)
		}
		shape.on_click(shape.id, me, w)
	}
}

fn resized_fn(e &gg.Event, mut w Window) {
	if w.on_resized != unsafe { nil } {
		w.on_resized(w)
	}
}

// get_state returns a reference to user supplied data
pub fn (window &Window) get_state[T]() &T {
	assert window.state != unsafe { nil }
	return unsafe { &T(window.state) }
}

// run starts the UI and handles events
pub fn (mut window Window) run() {
	window.ui.run()
}

// set_focus_id sets the window's focus id.
pub fn (mut window Window) set_focus_id(id int) {
	window.focus_id = id
}

// update_view sets the Window's view. A window can have
// only one view. Giving a Window a new view replaces the
// current view.
pub fn (mut window Window) update_view(view View) {
	mut shapes := generate_shapes(view, window)
	layout_do(mut shapes, window)

	window.mutex.lock()
	window.layout = shapes
	window.mutex.unlock()
}

// window_size returns the size of the window in logical units.
pub fn (window &Window) window_size() (int, int) {
	size := window.ui.window_size()
	return size.width, size.height
}
