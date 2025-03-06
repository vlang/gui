module gui

import gg
import gx
import sync

@[heap]
pub struct Window {
mut:
	view   UI_Tree       = empty_tree
	shapes ShapeTree     = empty_shape_tree
	mutex  &sync.RwMutex = unsafe { nil }
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
		mutex: sync.new_rwmutex()
	}
	window.ui.user_data = window
	return window
}

fn frame(mut window Window) {
	window.ui.begin()
	window.mutex.rlock()
	draw_shapes(window.shapes, mut window)
	window.mutex.runlock()
	window.ui.end()
}

fn draw_shapes(shapes ShapeTree, mut window Window) {
	for shape in shapes.shapes {
		shape.draw(window.ui)
	}
	for child in shapes.children {
		draw_shapes(child, mut window)
	}
}

pub fn (mut window Window) set_view(view UI_Tree) {
	window.mutex.lock()
	window.view = view
	window.mutex.unlock()

	window.update_layout()
	window.ui.refresh_ui()
}

fn (mut window Window) update_layout() {
	window.mutex.rlock()
	view := window.view
	window.mutex.runlock()

	mut shapes := generate_shapes(view)
	set_positions(mut shapes, 0, 0)

	window.mutex.lock()
	window.shapes = shapes
	window.mutex.unlock()
}
