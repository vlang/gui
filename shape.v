module gui

import rand
import vglyph

// Shape is the only data structure in GUI used to draw to the screen.
@[minify]
pub struct Shape {
pub:
	uid u64 = rand.u64() // internal use only
pub mut:
	// String fields (16 bytes)
	id         string // user assigned
	name       string // internal shape name, useful for debugging
	text       string
	image_name string // filename of image

	// Pointer fields (8 bytes)
	vglyph_layout &vglyph.Layout = unsafe { nil } // unified layout for text and rtf

	on_char         fn (&Layout, mut Event, mut Window)    = unsafe { nil }
	on_keydown      fn (&Layout, mut Event, mut Window)    = unsafe { nil }
	on_click        fn (&Layout, mut Event, mut Window)    = unsafe { nil }
	on_mouse_move   fn (&Layout, mut Event, mut Window)    = unsafe { nil }
	on_mouse_up     fn (&Layout, mut Event, mut Window)    = unsafe { nil }
	on_mouse_scroll fn (&Layout, mut Event, mut Window)    = unsafe { nil }
	on_scroll       fn (&Layout, mut Window)               = unsafe { nil }
	amend_layout    fn (mut Layout, mut Window)            = unsafe { nil }
	on_hover        fn (mut Layout, mut Event, mut Window) = unsafe { nil }

	// Structs (Large/Aligned)
	text_style TextStyle
	shape_clip DrawClip // used for hit-testing
	padding    Padding
	rich_text  RichText // source text for RTF re-layout

	// 4 bytes (f32/u32/Color)
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
	id_focus              u32 // >0 indicates shape is focusable. Value determines tabbing order
	id_scroll             u32 // >0 indicates shape is scrollable
	id_scroll_container   u32
	text_sel_beg          u32
	text_sel_end          u32
	text_tab_size         u32 = 4
	last_constraint_width f32 // Optimization: track the width used for the current text_layout to avoid redundant regeneration
	color                 Color

	// 2 bytes
	sizing Sizing

	// 1 byte (Enums/Bools)
	axis                Axis
	shape_type          ShapeType
	h_align             HorizontalAlign
	v_align             VerticalAlign
	text_mode           TextMode
	scroll_mode         ScrollMode
	float_anchor        FloatAttach
	float_tie_off       FloatAttach
	clip                bool
	disabled            bool
	fill                bool
	float               bool
	focus_skip          bool
	over_draw           bool // allows scrollbars to draw in padding area and removes shape from spacing calculations
	text_is_password    bool
	text_is_placeholder bool
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
	if shape_clip.width <= 0 || shape_clip.height <= 0 {
		return false
	}
	return x >= shape_clip.x && y >= shape_clip.y && x < (shape_clip.x + shape_clip.width)
		&& y < (shape_clip.y + shape_clip.height)
}

// has_text_layout returns true if the shape has a valid vglyph text layout.
@[inline]
pub fn (shape &Shape) has_text_layout() bool {
	return shape.vglyph_layout != unsafe { nil } && shape.shape_type == .text
}

// has_rtf_layout returns true if the shape has a valid vglyph rich text layout.
@[inline]
pub fn (shape &Shape) has_rtf_layout() bool {
	return shape.vglyph_layout != unsafe { nil } && shape.shape_type == .rtf
}
