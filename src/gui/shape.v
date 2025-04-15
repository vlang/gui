module gui

import rand

// Shape is the only data structure in GUI used to draw to the screen.
pub struct Shape {
pub mut:
	id       string // user assigned
	type     ShapeType
	uid      u64 = rand.u64() // internal use only
	axis     Axis
	cfg      voidptr
	clip     bool
	color    Color
	disabled bool
	id_focus u32 // >0 indicates shape is focusable. Value determines tabbing order
	// sizes, positions
	x          f32
	y          f32
	width      f32
	min_width  f32
	max_width  f32
	height     f32
	min_height f32
	max_height f32
	fill       bool
	h_align    HorizontalAlign
	v_align    VerticalAlign
	padding    Padding
	radius     f32
	sizing     Sizing
	// text
	text        string
	lines       []string
	text_style  TextStyle
	wrap        bool
	keep_spaces bool
	spacing     f32 // addtional vertical space added to lines of text
	cursor_x    int = -1
	cursor_y    int = -1
	// scroll
	id_scroll_v u32 // >0 indicates shape is scrollable
	scroll_v    f32
	// float
	float          bool
	float_attach   FloatAttach
	float_offset_x f32
	float_offset_y f32
	// callbacks
	on_char      fn (voidptr, &Event, &Window) bool = unsafe { nil }
	on_click     fn (voidptr, &Event, &Window) bool = unsafe { nil }
	on_keydown   fn (voidptr, &Event, &Window) bool = unsafe { nil }
	amend_layout fn (mut Layout, &Window)           = unsafe { nil }
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
