module gui

import rand
import datatypes

// Shape is the only data structure in GUI used to draw to the screen.
// Members are arranged for packing to reduce memory footprint.
pub struct Shape {
pub:
	id       string // user assigned
	name     string // internal shape name, useful for debugging
	uid      u64 = rand.u64() // internal use only
	id_focus u32 // >0 indicates shape is focusable. Value determines tabbing order
	axis     Axis
	type     ShapeType
pub mut:
	text_spans            &datatypes.LinkedList[TextSpan] = unsafe { nil } // rich text format spans
	text                  string
	image_name            string // filename of image
	text_lines            []string
	shape_clip            DrawClip // used for hit-testing
	color                 Color
	padding               Padding
	text_style            &TextStyle = &gui_theme.text_style
	sizing                Sizing
	x                     f32
	y                     f32
	width                 f32
	min_width             f32
	max_width             f32
	height                f32
	min_height            f32
	max_height            f32
	radius                f32
	spacing               f32
	float_offset_x        f32
	float_offset_y        f32
	id_scroll             u32 // >0 indicates shape is scrollable
	id_scroll_container   u32
	text_sel_beg          u32
	text_sel_end          u32
	text_tab_size         u32 = 4
	cfg                   voidptr
	on_char               fn (voidptr, mut Event, mut Window)    = unsafe { nil }
	on_keydown            fn (voidptr, mut Event, mut Window)    = unsafe { nil }
	on_click              fn (voidptr, mut Event, mut Window)    = unsafe { nil }
	on_mouse_move         fn (voidptr, mut Event, mut Window)    = unsafe { nil }
	on_mouse_up           fn (voidptr, mut Event, mut Window)    = unsafe { nil }
	on_char_shape         fn (&Shape, mut Event, mut Window)     = unsafe { nil }
	on_keydown_shape      fn (&Shape, mut Event, mut Window)     = unsafe { nil }
	on_mouse_down_shape   fn (&Shape, mut Event, mut Window)     = unsafe { nil }
	on_mouse_move_shape   fn (&Shape, mut Event, mut Window)     = unsafe { nil }
	on_mouse_up_shape     fn (&Shape, mut Event, mut Window)     = unsafe { nil }
	on_mouse_scroll_shape fn (&Shape, mut Event, mut Window)     = unsafe { nil }
	amend_layout          fn (mut Layout, mut Window)            = unsafe { nil }
	on_hover              fn (mut Layout, mut Event, mut Window) = unsafe { nil }
	h_align               HorizontalAlign
	v_align               VerticalAlign
	text_mode             TextMode
	scroll_mode           ScrollMode
	float_anchor          FloatAttach
	float_tie_off         FloatAttach
	clip                  bool
	disabled              bool
	fill                  bool
	focus_skip            bool
	text_is_password      bool
	text_is_placeholder   bool
	float                 bool
	over_draw             bool // allows scrollbars to draw in padding area
}

// ShapeType defines the kind of Shape.
pub enum ShapeType as u8 {
	none
	rectangle
	text
	image
	circle
	rtf
}

// point_in_shape determines if the given point is within the shape's shape_clip
// rectangle. The shape_clip rectangle is the intersection of the current drawable
// rectangle and thd shapes rectangle. Computed in layout_set_shape_clips()
pub fn (shape &Shape) point_in_shape(x f32, y f32) bool {
	shape_clip := shape.shape_clip
	return x >= shape_clip.x && y >= shape_clip.y && x < (shape_clip.x + shape_clip.width)
		&& y < (shape_clip.y + shape_clip.height)
}
