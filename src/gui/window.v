module gui

import gg
import gx
import sync

@[heap]
pub struct Window {
mut:
	layout     ShapeTree    = empty_shape_tree
	mutex      &sync.Mutex  = unsafe { nil }
	ui         &gg.Context  = unsafe { nil }
	on_resized fn (&Window) = unsafe { nil }
}

pub struct WindowCfg {
pub:
	title      string
	width      int
	height     int
	bg_color   gx.Color
	on_init    fn (&Window) = unsafe { nil }
	on_resized fn (&Window) = unsafe { nil }
}

pub fn window(cfg WindowCfg) &Window {
	mut window := &Window{
		mutex:      sync.new_mutex()
		on_resized: cfg.on_resized
	}
	window.ui = gg.new_context(
		ui_mode:      true // only draw on events
		bg_color:     cfg.bg_color
		width:        cfg.width
		height:       cfg.height
		window_title: cfg.title
		init_fn:      cfg.on_init
		resized_fn:   resized
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

fn resized(e &gg.Event, mut w Window) {
	if w.on_resized != unsafe { nil } {
		w.on_resized(w)
	}
}

fn (mut window Window) draw_shapes(shapes ShapeTree) {
	shapes.shape.draw(window.ui)
	for child in shapes.children {
		window.draw_shapes(child)
	}
}

fn (window &Window) do_layout(mut layout ShapeTree) {
	layout_do(mut layout, window)
}

pub fn (mut window Window) update_view(view UI_Tree) {
	mut shapes := generate_shapes(view)
	window.do_layout(mut shapes)

	window.mutex.lock()
	window.layout = shapes
	window.mutex.unlock()
}

pub fn (window &Window) window_size() (int, int) {
	size := window.ui.window_size()
	return size.width, size.height
}

pub fn (mut window Window) run() {
	window.ui.run()
}
