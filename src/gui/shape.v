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
	id_focus     u32 // >0 indicates shape is focusable. Value determines tabbing order
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
	radius       f32
	sizing       Sizing
	spacing      f32
	text         string
	lines        []string
	disabled     bool
	text_cfg     gx.TextCfg
	cursor_x     int = -1
	cursor_y     int = -1
	wrap         bool
	keep_spaces  bool
	id_scroll_v  u32 // >0 indicates shape is scrollable
	scroll_v     f32
	cfg          voidptr
	on_char      fn (voidptr, &gg.Event, &Window) bool = unsafe { nil }
	on_click     fn (voidptr, &gg.Event, &Window) bool = unsafe { nil }
	on_keydown   fn (voidptr, &gg.Event, &Window) bool = unsafe { nil }
	amend_layout fn (mut Layout, &Window)              = unsafe { nil }
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
fn (node Layout) find_shape(predicate fn (n Layout) bool) ?Shape {
	for child in node.children {
		if found := child.find_shape(predicate) {
			return found
		}
	}
	return if predicate(node) { node.shape } else { none }
}

fn shape_previous_focusable(node Layout, mut w Window) ?Shape {
	ids := get_focus_ids(node).reverse()
	return next_focusable(node, ids, mut w)
}

fn shape_next_focusable(node Layout, mut w Window) ?Shape {
	ids := get_focus_ids(node)
	return next_focusable(node, ids, mut w)
}

// next_focusable finds the next focusable that is not disabled.
// If none are found it tries to find the first focusable that
// is not disabled.
fn next_focusable(node Layout, ids []u32, mut w Window) ?Shape {
	// ids are sorted either ascending or descending.
	if w.id_focus > 0 {
		mut found := false
		for id in ids {
			if id == w.id_focus {
				found = true
				continue
			}
			if !found {
				continue
			}
			shape := node.find_shape(fn [id] (n Layout) bool {
				return n.shape.id_focus == id && !n.shape.disabled
			}) or { continue }
			return shape
		}
	}
	// did not find anything. Try to return the first non disabled.
	mut first := ?Shape(none)
	for id in ids {
		first = node.find_shape(fn [id] (n Layout) bool {
			return n.shape.id_focus == id && !n.shape.disabled
		}) or { continue }
		break
	}
	return first
}

// get_focus_ids returns an ordered list of focus ids
fn get_focus_ids(node Layout) []u32 {
	mut focus_ids := []u32{}
	if node.shape.id_focus > 0 {
		focus_ids << node.shape.id_focus
	}
	for child in node.children {
		focus_ids << get_focus_ids(child)
	}
	return arrays.distinct(focus_ids).sorted()
}

fn char_handler(node Layout, e &gg.Event, w &Window) bool {
	for child in node.children {
		if char_handler(child, e, w) {
			return true
		}
	}
	if node.shape.id_focus > 0 && !node.shape.disabled && node.shape.id_focus == w.id_focus {
		if node.shape.on_char != unsafe { nil } && node.shape.on_char(node.shape.cfg, e, w) {
			return true
		}
	}
	return false
}
