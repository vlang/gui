module gui

import rand
import datatypes

// Shape is the only data structure in GUI used to draw to the screen.
// Members are arranged for packing to reduce memory footprint.
pub struct Shape {
pub mut:
	shape_clip            DrawClip // used for hit-testing
	color                 Color
	padding               Padding
	text_style            TextStyle
	sizing                Sizing
	id                    string // user assigned
	name                  string // internal shape name, useful for debugging
	text                  string
	image_name            string // filename of image
	text_lines            []string
	cfg                   voidptr
	uid                   u64 = rand.u64() // internal use only
	text_spans            datatypes.LinkedList[TextSpan] // rich text format spans
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
	id_focus              u32 // >0 indicates shape is focusable. Value determines tabbing order
	text_sel_beg          u32
	text_sel_end          u32
	text_tab_size         u32 = 4
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
	axis                  Axis
	type                  ShapeType
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
pub enum ShapeType {
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

// cleanup cleans up shape-specific resources
pub fn (mut shape Shape) cleanup() {
	// Clear string fields that might be holding references
	shape.id = ''
	shape.name = ''
	shape.text = ''
	shape.image_name = ''

	shape.shape_clip = DrawClip{} // used for hit-testing
	shape.color = Color{}
	shape.padding = Padding{}
	shape.text_style = TextStyle{}
	shape.sizing = Sizing{}

	// Clear text lines array
	shape.text_lines.clear()

	// Clear text spans linked list
	for ; !shape.text_spans.is_empty(); {
		shape.text_spans.pop() or { break }
	}

	// Clear function pointers to break potential circular references
	shape.on_char = unsafe { nil }
	shape.on_keydown = unsafe { nil }
	shape.on_click = unsafe { nil }
	shape.on_mouse_move = unsafe { nil }
	shape.on_mouse_up = unsafe { nil }
	shape.on_char_shape = unsafe { nil }
	shape.on_keydown_shape = unsafe { nil }
	shape.on_mouse_down_shape = unsafe { nil }
	shape.on_mouse_move_shape = unsafe { nil }
	shape.on_mouse_up_shape = unsafe { nil }
	shape.on_mouse_scroll_shape = unsafe { nil }
	shape.amend_layout = unsafe { nil }
	shape.on_hover = unsafe { nil }

	// u32, f32
	shape.x = 0
	shape.y = 0
	shape.min_width = 0
	shape.max_width = 0
	shape.min_height = 0
	shape.radius = 0
	shape.float_offset_y = 0
	shape.id_scroll = 0
	shape.id_focus = 0
	shape.text_sel_beg = 0
	shape.text_sel_end = 0
	shape.text_tab_size = 4
	shape.clip = false
	shape.disabled = false
	shape.fill = false
	shape.focus_skip = false
	shape.text_is_password = false
	shape.text_is_placeholder = false
	shape.float = false
	shape.over_draw = false // allows scrollbars to draw in padding area

	// Enum
	shape.type = .none
	shape.axis = .none
	shape.h_align = .start
	shape.v_align = .top
	shape.text_mode = .single_line
	shape.scroll_mode = .both
	shape.float_anchor = .top_left
	shape.float_tie_off = .top_left

	// Clear cfg pointer
	shape.cfg = unsafe { nil }
}
