module gui

import arrays
import gg
import gx
import rand

// Shape is the only data structure in GUI used to draw to the screen.
pub struct Shape {
pub mut:
	id           string // asigned by user
	type         ShapeType
	uid          u64 = rand.u64() // internal use only
	id_focus     FocusId // >0 indicates shape is focusable. Value determines tabbing order
	axis         Axis
	x            f32
	y            f32
	width        f32
	min_width    f32
	max_width    f32
	height       f32
	min_height   f32
	max_height   f32
	color        gg.Color
	fill         bool
	h_align      HorizontalAlign
	v_align      VerticalAlign
	clip         bool
	padding      Padding
	radius       int
	sizing       Sizing
	spacing      f32
	text         string
	lines        []string
	text_cfg     gx.TextCfg
	cursor_x     int = -1
	cursor_y     int = -1
	wrap         bool
	keep_spaces  bool
	cfg          voidptr
	on_char      fn (voidptr, &gg.Event, &Window) bool = unsafe { nil }
	on_click     fn (voidptr, &gg.Event, &Window) bool = unsafe { nil }
	on_keydown   fn (voidptr, &gg.Event, &Window) bool = unsafe { nil }
	amend_layout fn (mut ShapeTree, &Window)           = unsafe { nil }
}

// ShapeTree defines a tree of Shapes. Views generate ShapeTrees
pub struct ShapeTree {
pub mut:
	shape    Shape
	children []ShapeTree
}

// ShapeType defines the kind of Shape.
pub enum ShapeType {
	none
	container
	text
}

// point_in_shape determines if the given point is within the shape's layout
// rectangle Internal use mostly, but useful if designing a new Shape
pub fn (shape Shape) point_in_shape(x f32, y f32) bool {
	return x >= shape.x && x < (shape.x + shape.width) && y >= shape.y
		&& y < (shape.y + shape.height)
}

// find_shape walks the ShapeGTree in reverse until predicate is satisfied.
// shape_uid limits the depth of the search into tree. Used in event bubbling. 0
// is not a valid shape_uid and is used to search the entire tree
fn (node ShapeTree) find_shape(predicate fn (n ShapeTree) bool) ?Shape {
	for child in node.children {
		if found := child.find_shape(predicate) {
			return found
		}
	}
	return if predicate(node) { node.shape } else { none }
}

fn shape_previous_focusable(node ShapeTree, mut w Window) ?Shape {
	ids := get_focus_ids(node)
	if ids.len == 0 {
		return none
	}
	mut next_id := ids.last()
	if w.id_focus > 0 {
		idx := ids.index(int(w.id_focus))
		if idx >= 1 && idx < ids.len {
			next_id = ids[idx - 1]
		}
	}
	return node.find_shape(fn [next_id] (n ShapeTree) bool {
		return n.shape.id_focus == next_id
	})
}

fn shape_next_focusable(node ShapeTree, mut w Window) ?Shape {
	ids := get_focus_ids(node)
	if ids.len == 0 {
		return none
	}
	mut next_id := ids.first()
	if w.id_focus > 0 {
		idx := ids.index(int(w.id_focus))
		if idx >= 0 && idx < ids.len - 1 {
			next_id = ids[idx + 1]
		}
	}
	return node.find_shape(fn [next_id] (n ShapeTree) bool {
		return n.shape.id_focus == next_id
	})
}

fn get_focus_ids(node ShapeTree) []int {
	mut focus_ids := []int{}
	if node.shape.id_focus > 0 {
		focus_ids << node.shape.id_focus
	}
	for child in node.children {
		focus_ids << get_focus_ids(child)
	}
	return arrays.distinct(focus_ids).sorted()
}

fn char_handler(node ShapeTree, e &gg.Event, w &Window) bool {
	for child in node.children {
		if char_handler(child, e, w) {
			return true
		}
	}
	if node.shape.id_focus > 0 && node.shape.id_focus == w.id_focus {
		if node.shape.on_char != unsafe { nil } && node.shape.on_char(node.shape.cfg, e, w) {
			return true
		}
	}
	return false
}

fn click_handler(node ShapeTree, e &gg.Event, mut w Window) bool {
	for child in node.children {
		if click_handler(child, e, mut w) {
			return true
		}
	}
	if node.shape.on_click != unsafe { nil } {
		if node.shape.point_in_shape(e.mouse_x, e.mouse_y) {
			if node.shape.id_focus > 0 {
				w.set_id_focus(node.shape.id_focus)
			}
			if node.shape.on_click(node.shape.cfg, e, w) {
				return true
			}
		}
	}
	return false
}

fn keydown_handler(node ShapeTree, e &gg.Event, w &Window) bool {
	for child in node.children {
		if keydown_handler(child, e, w) {
			return true
		}
	}
	if node.shape.id_focus > 0 && node.shape.id_focus == w.id_focus {
		if node.shape.on_keydown != unsafe { nil } && node.shape.on_keydown(node.shape.cfg, e, w) {
			return true
		}
	}
	return false
}
