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
	id       string // Unique identifier assigned by the user
	resource string // Image path or SVG source (discriminated by shape_type)

	// Optional sub-structs (nil when unused)
	events &EventHandlers   = unsafe { nil } // Event handlers
	tc     &ShapeTextConfig = unsafe { nil } // Text/RTF fields
	fx     &ShapeEffects    = unsafe { nil } // Visual effects
	a11y   &AccessInfo      = unsafe { nil } // Accessibility metadata

	// Structs (Large/Aligned)
	shape_clip DrawClip // Calculated clipping rectangle for rendering and hit-testing
	padding    Padding  // Inner spacing
	sizing     Sizing   // Sizing logic (e.g. fixed, fit, grow)

	// 4 bytes (f32/u32/Color)
	x                   f32   // Final calculated X position (absolute)
	y                   f32   // Final calculated Y position (absolute)
	width               f32   // Size value. For .fixed sizing, this IS the size.
	min_width           f32   // Min constraint. Ignored when sizing.width == .fixed
	max_width           f32   // Max constraint. Ignored when sizing.width == .fixed
	height              f32   // Size value. For .fixed sizing, this IS the size.
	min_height          f32   // Min constraint. Ignored when sizing.height == .fixed
	max_height          f32   // Max constraint. Ignored when sizing.height == .fixed
	radius              f32   // Corner radius for rounded rectangles
	spacing             f32   // Spacing between children (loaded from style)
	float_offset_x      f32   // X offset for floating elements relative to anchor
	float_offset_y      f32   // Y offset for floating elements relative to anchor
	id_focus            u32   // Focus ID. >0 means focusable. Value determines tab order.
	id_scroll           u32   // Scroll ID. >0 means receives scroll events.
	id_scroll_container u32   // ID of the parent scroll container
	color               Color // Background or foreground color
	color_border        Color // Border color (if different from color)
	size_border         f32   // Thickness of the border

	// 2 bytes (Accessibility)
	a11y_role  AccessRole  // Semantic role for assistive technology
	a11y_state AccessState // Dynamic accessibility state flags

	// 1 byte (Enums/Bools)
	axis                  Axis                 // Layout direction (row/column)
	shape_type            ShapeType            // Discriminator for shape kind
	h_align               HorizontalAlign      // Horizontal alignment of children/content
	v_align               VerticalAlign        // Vertical alignment of children/content
	scroll_mode           ScrollMode           // Scrolling behavior (e.g. auto, always, never)
	scrollbar_orientation ScrollbarOrientation // Scrollbar type (.none for non-scrollbar shapes)
	text_dir              TextDirection        // Text/layout direction (.auto = inherit)
	float_anchor          FloatAttach          // Anchor point on the parent for floating shapes
	float_tie_off         FloatAttach          // Anchor point on the floating shape itself
	clip                  bool                 // Whether to clip children/content to bounds
	disabled              bool                 // Visual and interactive disabled state
	float                 bool                 // Whether the shape is floating (removed from flow)
	focus_skip            bool                 // If true, skip this element in focus navigation
	over_draw             bool                 // If true, allows drawing into padding and ignores spacing impact
	hero                  bool                 // If true, element participates in hero transitions
	opacity               f32 = 1.0 // Opacity multiplier (0.0 = transparent, 1.0 = opaque)
}

// ShapeTextConfig holds text/RTF-specific fields for a Shape.
// Allocated only for shapes with shape_type .text or .rtf.
// Internal cache fields below are runtime-only implementation details.
// They are not user-facing config semantics and may change anytime.
@[heap]
pub struct ShapeTextConfig {
pub mut:
	text                  string
	vglyph_layout         &vglyph.Layout = unsafe { nil }
	rich_text             &RichText      = unsafe { nil }
	text_style            TextStyle
	text_mode             TextMode
	text_sel_beg          u32
	text_sel_end          u32
	text_tab_size         u32 = 4
	text_is_password      bool
	text_is_placeholder   bool
	hanging_indent        f32
	last_constraint_width f32
	last_text_hash        int
	cached_line_height    f32
	// Internal transformed-layout cache entry for DrawLayoutTransformed.
	cached_transform_layout &vglyph.Layout = unsafe { nil }
	// Internal transformed-layout cache key.
	cached_transform_key u64
	// Cached password mask text and its source hash.
	cached_pw_mask string
	cached_pw_hash int
}

// EventHandlers holds optional event callback fields for a Shape.
// Allocated only when a shape has at least one handler.
@[heap]
pub struct EventHandlers {
pub mut:
	on_char         fn (&Layout, mut Event, mut Window)    = unsafe { nil }
	on_keydown      fn (&Layout, mut Event, mut Window)    = unsafe { nil }
	on_click        fn (&Layout, mut Event, mut Window)    = unsafe { nil }
	on_mouse_move   fn (&Layout, mut Event, mut Window)    = unsafe { nil }
	on_mouse_up     fn (&Layout, mut Event, mut Window)    = unsafe { nil }
	on_mouse_scroll fn (&Layout, mut Event, mut Window)    = unsafe { nil }
	on_scroll       fn (&Layout, mut Window)               = unsafe { nil }
	amend_layout    fn (mut Layout, mut Window)            = unsafe { nil }
	on_hover        fn (mut Layout, mut Event, mut Window) = unsafe { nil }
	on_ime_commit   fn (&Layout, string, mut Window)       = unsafe { nil }
}

// has_events returns true if the shape has an allocated EventHandlers.
@[inline]
pub fn (shape &Shape) has_events() bool {
	return shape.events != unsafe { nil }
}

// ShapeEffects holds optional visual effect fields for a Shape.
// Allocated only for shapes with shadows, gradients, shaders, or blur.
@[heap]
pub struct ShapeEffects {
pub mut:
	shadow          &BoxShadow = unsafe { nil }
	gradient        &Gradient  = unsafe { nil }
	border_gradient &Gradient  = unsafe { nil }
	shader          &Shader    = unsafe { nil }
	blur_radius     f32
}

// ShapeType defines the kind of Shape.
pub enum ShapeType as u8 {
	none
	rectangle
	text
	image
	circle
	rtf
	svg
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
	return shape.tc != unsafe { nil } && shape.tc.vglyph_layout != unsafe { nil }
		&& shape.shape_type == .text
}

// has_rtf_layout returns true if the shape has a valid vglyph rich text layout.
@[inline]
pub fn (shape &Shape) has_rtf_layout() bool {
	return shape.tc != unsafe { nil } && shape.tc.vglyph_layout != unsafe { nil }
		&& shape.shape_type == .rtf
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
