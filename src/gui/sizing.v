module gui

// SizingType describes the three sizing modes of GUI
pub enum SizingType {
	fit   // element fitted to content
	fill  // content fills to element (grow or shrinks)
	fixed // element unchanged
}

// Sizing is describes how the shape is sized horizontally and vertically.
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
