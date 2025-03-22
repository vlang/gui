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
	height       f32
	bounds       gg.Rect
	color        gg.Color
	fill         bool
	min_height   f32
	min_width    f32
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
	on_char      fn (u32, &Window)                          = unsafe { nil }
	on_click     fn (string, MouseEvent, &Window)           = unsafe { nil }
	on_keydown   fn (gg.KeyCode, gg.Modifier, &Window) bool = unsafe { nil }
	amend_layout fn (mut ShapeTree, &Window)                = unsafe { nil }
}

// ShapeType defines the kind of Shape.
pub enum ShapeType {
	none
	container
	text
}

// Axis defines if a Shape arranges its child shapes horizontally, vertically or
// not at all.
pub enum Axis {
	none
	top_to_bottom
	left_to_right
}

// ShapeTree defines a tree of Shapes. Views generate ShapeTrees
pub struct ShapeTree {
pub mut:
	shape    Shape
	children []ShapeTree
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

// shape_from_point_on_click walks the ShapeTree and returns the first shape
// where the sahpe region contains the point and the shape has a click handler.
// Search is in reverse order Internal use mostly, but useful if designing a new
// Shape
fn shape_from_on_click(node ShapeTree, x f32, y f32) ?Shape {
	return node.find_shape(fn [x, y] (n ShapeTree) bool {
		return n.shape.point_in_shape(x, y) && n.shape.on_click != unsafe { nil }
	})
}

// shape_from_on_char finds the first control with an on_char handler and has
// focus
fn shape_from_on_char(node ShapeTree, id_focus FocusId) ?Shape {
	return node.find_shape(fn [id_focus] (n ShapeTree) bool {
		return id_focus > 0 && n.shape.id_focus == id_focus && n.shape.on_char != unsafe { nil }
	})
}

// shape_from_on_char finds first control with on_keydown handler
fn shape_from_on_key_down(node ShapeTree) ?Shape {
	return node.find_shape(fn (n ShapeTree) bool {
		return n.shape.on_keydown != unsafe { nil }
	})
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
