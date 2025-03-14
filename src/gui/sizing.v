module gui

// SizingType describes the three sizing modes of GUI
pub enum SizingType {
	fit   // Shape is fitted to child shapes
	flex  // Shape can grow or shrink as needed
	fixed // Shape is only the given size.
}

// Sizing is describes how the shape is sized horizontally and vertically.
pub struct Sizing {
pub:
	width  SizingType
	height SizingType
}

pub const fit_fit = Sizing{.fit, .fit}
pub const fit_flex = Sizing{.fit, .flex}
pub const fit_fixed = Sizing{.fit, .fixed}

pub const fixed_fixed = Sizing{.fixed, .fixed}
pub const fixed_flex = Sizing{.fixed, .flex}
pub const fixed_fit = Sizing{.fixed, .fit}

pub const flex_fit = Sizing{.flex, .fit}
pub const flex_flex = Sizing{.flex, .flex}
pub const flex_fixed = Sizing{.flex, .fixed}
