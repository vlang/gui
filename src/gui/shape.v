module gui

import gg
import gx

// Shape is the only data structure in GUI used to draw to the screen.
pub struct Shape {
pub:
	id       string // asigned by user
	uid      string
	focus_id int // >0 indicates text is focusable. Value indiciates tabbing order
	axis     Axis
	type     ShapeType
mut:
	x          f32
	y          f32
	width      f32
	height     f32
	bounds     gg.Rect
	color      gg.Color
	fill       bool
	min_height f32
	min_width  f32
	padding    Padding
	radius     int
	sizing     Sizing
	spacing    f32
	text       string
	lines      []string
	text_cfg   gx.TextCfg
	cursor_x   int = -1
	cursor_y   int = -1
	wrap       bool
	on_click   fn (string, MouseEvent, &Window)      = unsafe { nil }
	on_char    fn (u32, &Window)                     = unsafe { nil }
	on_keydown fn (gg.KeyCode, gg.Modifier, &Window) = unsafe { nil }
}

// ShapeType defines the kind of Shape.
pub enum ShapeType {
	none
	container
	text
}

// Axis defines if a Shape arranges its child
// shapes horizontally, vertically or not at all.
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

// point_in_shape determines if the given point is within the shape's layout rectangle
// Internal use mostly, but useful if designing a new Shape
pub fn (shape Shape) point_in_shape(x f32, y f32) bool {
	return x >= shape.x && x < (shape.x + shape.width) && y >= shape.y
		&& y < (shape.y + shape.height)
}

// shape_from_point_on_click walks the ShapeTree and returns the first
// shape where the sahpe region contains the point and the shape has
// a click handler. Search is in reverse order
// Internal use mostly, but useful if designing a new Shape
pub fn shape_from_point_on_click(node ShapeTree, x f32, y f32) ?Shape {
	for child in node.children {
		if shape := shape_from_point_on_click(child, x, y) {
			return shape
		}
	}
	if node.shape.point_in_shape(x, y) && node.shape.on_click != unsafe { nil } {
		return node.shape
	}
	return none
}

// shape_from_on_char
// Internal use mostly, but useful if designing a new Shape
pub fn shape_from_on_char(node ShapeTree) ?Shape {
	for child in node.children {
		if shape := shape_from_on_char(child) {
			return shape
		}
	}
	if node.shape.on_char != unsafe { nil } {
		return node.shape
	}
	return none
}

// shape_from_on_char
// Internal use mostly, but useful if designing a new Shape
pub fn shape_from_on_key_down(node ShapeTree) ?Shape {
	for child in node.children {
		if shape := shape_from_on_key_down(child) {
			return shape
		}
	}
	if node.shape.on_keydown != unsafe { nil } {
		return node.shape
	}
	return none
}
