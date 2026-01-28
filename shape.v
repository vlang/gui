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
	id         string // Unique identifier assigned by the user
	name       string // Internal name, useful for debugging (e.g., 'Container', 'Text')
	text       string // Text content for text-based shapes
	image_name string // Filename or path for image shapes

	// Pointer fields (8 bytes)
	vglyph_layout   &vglyph.Layout = unsafe { nil } // Unified layout engine object for both plain and rich text
	rich_text       &RichText      = unsafe { nil } // Source data structure for Rich Text Format (RTF)
	shadow          &BoxShadow     = unsafe { nil } // Drop shadow configuration
	gradient        &Gradient      = unsafe { nil } // Gradient background configuration
	border_gradient &Gradient      = unsafe { nil } // Gradient border configuration

	// Event Handlers
	on_char         fn (&Layout, mut Event, mut Window)    = unsafe { nil } // Handle character input
	on_keydown      fn (&Layout, mut Event, mut Window)    = unsafe { nil } // Handle key press
	on_click        fn (&Layout, mut Event, mut Window)    = unsafe { nil } // Handle mouse click
	on_mouse_move   fn (&Layout, mut Event, mut Window)    = unsafe { nil } // Handle mouse movement over shape
	on_mouse_up     fn (&Layout, mut Event, mut Window)    = unsafe { nil } // Handle mouse button release
	on_mouse_scroll fn (&Layout, mut Event, mut Window)    = unsafe { nil } // Handle scroll wheel events
	on_scroll       fn (&Layout, mut Window)               = unsafe { nil } // Handle scroll container updates
	amend_layout    fn (mut Layout, mut Window)            = unsafe { nil } // Custom hook to modify layout during the pipeline
	on_hover        fn (mut Layout, mut Event, mut Window) = unsafe { nil } // Handle hover state changes

	// Structs (Large/Aligned)
	text_style TextStyle // Configuration for text rendering (font, size, color)
	shape_clip DrawClip  // Calculated clipping rectangle for rendering and hit-testing
	padding    Padding   // Inner spacing
	sizing     Sizing    // Sizing logic (e.g. fixed, fit, grow)

	// 4 bytes (f32/u32/Color)
	x                     f32 // Final calculated X position (absolute)
	y                     f32 // Final calculated Y position (absolute)
	width                 f32 // Final calculated width
	min_width             f32 // Minimum width constraint
	max_width             f32 // Maximum width constraint
	height                f32 // Final calculated height
	min_height            f32 // Minimum height constraint
	max_height            f32 // Maximum height constraint
	radius                f32 // Corner radius for rounded rectangles
	blur_radius           f32 // Gaussian blur radius
	spacing               f32 // Spacing between children (loaded from style)
	float_offset_x        f32 // X offset for floating elements relative to anchor
	float_offset_y        f32 // Y offset for floating elements relative to anchor
	id_focus              u32 // Focus ID. >0 means focusable. Value determines tab order.
	id_scroll             u32 // Scroll ID. >0 means receives scroll events.
	id_scroll_container   u32 // ID of the parent scroll container
	text_sel_beg          u32 // Start index of text selection (runes)
	text_sel_end          u32 // End index of text selection (runes)
	text_tab_size         u32 = 4 // Tab width in spaces
	last_constraint_width f32   // Optimization: cached width used for last text layout generation
	color                 Color // Background or foreground color
	color_border          Color // Border color (if different from color)
	size_border           f32   // Thickness of the border

	// 1 byte (Enums/Bools)
	axis                Axis            // Layout direction (row/column)
	shape_type          ShapeType       // Discriminator for shape kind
	h_align             HorizontalAlign // Horizontal alignment of children/content
	v_align             VerticalAlign   // Vertical alignment of children/content
	text_mode           TextMode        // Text wrapping/multiline mode
	scroll_mode         ScrollMode      // Scrolling behavior (e.g. auto, always, never)
	float_anchor        FloatAttach     // Anchor point on the parent for floating shapes
	float_tie_off       FloatAttach     // Anchor point on the floating shape itself
	clip                bool            // Whether to clip children/content to bounds
	disabled            bool            // Visual and interactive disabled state
	float               bool            // Whether the shape is floating (removed from flow)
	focus_skip          bool            // If true, skip this element in focus navigation
	over_draw           bool            // If true, allows drawing into padding and ignores spacing impact
	text_is_password    bool            // If true, mask text characters
	text_is_placeholder bool            // If true, text is a placeholder (affects styling)
	hero                bool            // If true, element participates in hero transitions
	opacity             f32 = 1.0 // Opacity multiplier (0.0 = transparent, 1.0 = opaque)
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

// padding_left returns the effective left padding (padding + border)
@[inline]
pub fn (shape &Shape) padding_left() f32 {
	return shape.padding.left + shape.size_border
}

// padding_top returns the effective top padding (padding + border)
@[inline]
pub fn (shape &Shape) padding_top() f32 {
	return shape.padding.top + shape.size_border
}

// padding_width returns the total horizontal padding (left + right + 2 * border)
@[inline]
pub fn (shape &Shape) padding_width() f32 {
	return shape.padding.width() + (shape.size_border * 2)
}

// padding_height returns the total vertical padding (top + bottom + 2 * border)
@[inline]
pub fn (shape &Shape) padding_height() f32 {
	return shape.padding.height() + (shape.size_border * 2)
}
