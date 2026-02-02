module gui

// SizingType describes the three sizing modes of GUI
pub enum SizingType as u8 {
	fit   // element fits to content
	fill  // element fills to parent (grows or shrinks)
	fixed // element unchanged
}

// Sizing describes how the shape is sized horizontally and vertically.
pub struct Sizing {
pub:
	width  SizingType
	height SizingType
}

pub const fit_fit = Sizing{.fit, .fit}
pub const fit_fill = Sizing{.fit, .fill}
pub const fit_fixed = Sizing{.fit, .fixed}

pub const fixed_fit = Sizing{.fixed, .fit}
pub const fixed_fill = Sizing{.fixed, .fill}
pub const fixed_fixed = Sizing{.fixed, .fixed}

pub const fill_fit = Sizing{.fill, .fit}
pub const fill_fill = Sizing{.fill, .fill}
pub const fill_fixed = Sizing{.fill, .fixed}

// apply_fixed_sizing_constraints sets min = max = size when sizing is .fixed.
// Call this on Shape after initial field assignment.
@[inline]
pub fn apply_fixed_sizing_constraints(mut shape Shape) {
	if shape.sizing.width == .fixed && shape.width > 0 {
		shape.min_width = shape.width
		shape.max_width = shape.width
	}
	if shape.sizing.height == .fixed && shape.height > 0 {
		shape.min_height = shape.height
		shape.max_height = shape.height
	}
}
