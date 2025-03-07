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
			ui_mode:      true // only draw on events
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
	mut shapes := window.shapes.clone()
	window.mutex.unlock()

	window.ui.begin()
	window.do_layout(mut shapes)
	window.draw_shapes(shapes)
	window.ui.end()
}

fn (mut window Window) do_layout(mut shapes ShapeTree) {
	set_sizes(mut shapes)
	set_positions(mut shapes, 0, 0)
}

fn (mut window Window) draw_shapes(shapes ShapeTree) {
	shapes.shape.draw(window.ui)
	for child in shapes.children {
		window.draw_shapes(child)
	}
}

pub fn (mut window Window) update_view(view UI_Tree) {
	mut shapes := generate_shapes(view)
	window.mutex.lock()
	window.shapes = shapes
	window.mutex.unlock()
	window.ui.refresh_ui()
}
