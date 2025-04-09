module gui

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
