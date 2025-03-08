module gui

import gg
import gx
import sync

@[heap]
pub struct Window {
mut:
	shapes ShapeTree   = empty_shape_tree
	layout ShapeTree   = empty_shape_tree
	mutex  &sync.Mutex = unsafe { nil }
pub mut:
	ui &gg.Context = unsafe { nil }
}

pub struct WindowCfg {
pub:
	title    string
	width    int
	height   int
	bg_color gx.Color
	on_init  fn (&Window) = unsafe { nil }
}

pub fn window(cfg WindowCfg) &Window {
	mut window := &Window{
		mutex: sync.new_mutex()
	}
	window.ui = gg.new_context(
		ui_mode:      true // only draw on events
		bg_color:     cfg.bg_color
		width:        cfg.width
		height:       cfg.height
		window_title: cfg.title
		init_fn:      cfg.on_init
		frame_fn:     frame
		resized_fn:   resized
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

fn resized(e &gg.Event, mut window Window) {
	window.mutex.lock()
	window.layout = window.layout_shapes(window.shapes)
	window.mutex.unlock()
}

fn (mut window Window) layout_shapes(shapes ShapeTree) ShapeTree {
	mut layout := shapes.clone()
	size := window.ui.window_size()
	do_layout(mut layout, size.width, size.height)
	return layout
}

fn (mut window Window) draw_shapes(shapes ShapeTree) {
	shapes.shape.draw(window.ui)
	for child in shapes.children {
		window.draw_shapes(child)
	}
}

pub fn (mut window Window) update_view(view UI_Tree) {
	mut shapes := generate_shapes(view)
	mut layout := window.layout_shapes(shapes)

	window.mutex.lock()
	window.shapes = shapes
	window.layout = layout
	window.mutex.unlock()
	window.ui.refresh_ui()
}
