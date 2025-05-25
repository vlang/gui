module gui

import rand

// Shape is the only data structure in GUI used to draw to the screen.
pub struct Shape {
pub mut:
	id         string // user assigned
	id_focus   u32    // >0 indicates shape is focusable. Value determines tabbing order
	id_scroll  u32    // >0 indicates shape is scrollable
	type       ShapeType
	uid        u64 = rand.u64() // internal use only
	axis       Axis
	cfg        voidptr
	clip       bool
	draw_clip  DrawClip // used for hit-testing
	color      Color
	disabled   bool
	fill       bool
	focus_skip bool
	// --- sizes, positions ---
	x          f32
	y          f32
	width      f32
	min_width  f32
	max_width  f32
	height     f32
	min_height f32
	max_height f32
	h_align    HorizontalAlign
	v_align    VerticalAlign
	padding    Padding
	radius     f32
	sizing     Sizing
	spacing    f32
	// -- text ---
	text             string
	text_lines       []string
	text_style       TextStyle
	text_mode        TextMode
	text_is_password bool
	text_sel_beg     u32
	text_sel_end     u32
	text_tab_size    u32 = 4
	// --- image ---
	image_name string // filename of image
	// --- float ---
	float          bool
	float_anchor   FloatAttach
	float_tie_off  FloatAttach
	float_offset_x f32
	float_offset_y f32
	// --- user callbacks ---
	on_char       fn (voidptr, mut Event, mut Window) = unsafe { nil }
	on_keydown    fn (voidptr, mut Event, mut Window) = unsafe { nil }
	on_click      fn (voidptr, mut Event, mut Window) = unsafe { nil }
	on_mouse_move fn (voidptr, mut Event, mut Window) = unsafe { nil }
	on_mouse_up   fn (voidptr, mut Event, mut Window) = unsafe { nil }
	// --- for internal use and not intended for end users   ---
	// --- however, composite views can set these in the     ---
	// --- layout amend callback. See input view for example ---
	on_char_shape         fn (&Shape, mut Event, mut Window) = unsafe { nil }
	on_keydown_shape      fn (&Shape, mut Event, mut Window) = unsafe { nil }
	on_mouse_down_shape   fn (&Shape, mut Event, mut Window) = unsafe { nil }
	on_mouse_move_shape   fn (&Shape, mut Event, mut Window) = unsafe { nil }
	on_mouse_up_shape     fn (&Shape, mut Event, mut Window) = unsafe { nil }
	on_mouse_scroll_shape fn (&Shape, mut Event, mut Window) = unsafe { nil }
	// amend_layout called after all other layout operations complete
	amend_layout fn (mut Layout, mut Window)            = unsafe { nil }
	on_hover     fn (mut Layout, mut Event, mut Window) = unsafe { nil }
}

// ShapeType defines the kind of Shape.
pub enum ShapeType {
	none
	rectangle
	text
	image
	circle
}

// point_in_shape determines if the given point is within the shape's draw_clip
// rectangle. The draw_clip rectangle is the intersection of the current drawable
// rectangle and thd shapes rectangle. Computed in layout_set_draw_clips()
pub fn (shape &Shape) point_in_shape(x f32, y f32) bool {
	draw_clip := shape.draw_clip
	return x >= draw_clip.x && y >= draw_clip.y && x < (draw_clip.x + draw_clip.width)
		&& y < (draw_clip.y + draw_clip.height)
}
