module gui

import gg
import gx
import sync

@[heap]
pub struct Window {
mut:
	shapes ShapeTree   = empty_shape_tree
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
		ui:    gg.new_context(
			ui_mode:      true
			bg_color:     cfg.bg_color
			width:        cfg.width
			height:       cfg.height
			window_title: cfg.title
			init_fn:      cfg.on_init
			frame_fn:     frame
		)
		mutex: sync.new_mutex()
	}
	window.ui.user_data = window
	return window
}

fn frame(mut window Window) {
	window.mutex.lock()
	shapes := window.shapes

	window.ui.begin()
	draw_shapes(shapes, mut window)
	window.ui.end()

	window.mutex.unlock()
}

fn draw_shapes(shapes ShapeTree, mut window Window) {
	shapes.shape.draw(window.ui)
	for child in shapes.children {
		draw_shapes(child, mut window)
	}
}

pub fn (mut window Window) set_view(view UI_Tree) {
	mut shapes := generate_shapes(view)
	window.mutex.lock()
	window.shapes = shapes
	window.do_layout()
	window.mutex.unlock()
	window.ui.refresh_ui()
}

pub fn (mut window Window) update_layout() {
	window.mutex.lock()
	window.do_layout()
	window.mutex.unlock()
	window.ui.refresh_ui()
}

fn (mut window Window) do_layout() {
	set_sizes(mut window.shapes)
	set_positions(mut window.shapes, 0, 0)
}
