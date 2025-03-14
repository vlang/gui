module gui

import gg
import gx
import sync

@[heap]
pub struct Window {
mut:
	state      voidptr      = unsafe { nil }
	layout     ShapeTree    = empty_shape_tree
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
	title      string
	width      int
	height     int
	bg_color   gx.Color
	state      voidptr      = unsafe { nil }
	on_init    fn (&Window) = unsafe { nil }
	on_resized fn (&Window) = unsafe { nil }
}

// window creates the application window.
// See WindowCfg on how to configure it
pub fn window(cfg WindowCfg) &Window {
	mut window := &Window{
		mutex:      sync.new_mutex()
		on_resized: cfg.on_resized
		state:      cfg.state
	}
	window.ui = gg.new_context(
		ui_mode:      true // only draw on events
		bg_color:     cfg.bg_color
		width:        cfg.width
		height:       cfg.height
		window_title: cfg.title
		init_fn:      cfg.on_init
		resized_fn:   resized
		click_fn:     clicked
		char_fn:      char_in
		frame_fn:     frame
		user_data:    window
	)
	return window
}

fn frame(mut window Window) {
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

// run starts the UI and handles events
pub fn (mut window Window) run() {
	window.ui.run()
}

// get_state returns a reference to user supplied data
pub fn (window &Window) get_state[T]() &T {
	assert window.state != unsafe { nil }
	return unsafe { &T(window.state) }
}

fn resized(e &gg.Event, mut w Window) {
	if w.on_resized != unsafe { nil } {
		w.on_resized(w)
	}
}

// clicked delegates to the first Shape that has a click
// handler within its rectanguler area. The search for
// the Shape is in reverse order.
fn clicked(x f32, y f32, button gg.MouseButton, mut w Window) {
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

fn char_in(c u32, mut w Window) {
	w.mutex.lock()
	layout := w.layout
	w.mutex.unlock()

	shape := shape_from_on_char(layout)

	if shape.on_char != unsafe { nil } {
		shape.on_char(c, w)
	}
}
