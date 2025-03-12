module gui

pub const version = '0.1.0'

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

// Padding is the anount of space surrounding a Shape.
// The size of a Shape always includes its padding.
pub struct Padding {
pub mut:
	top    f32
	right  f32
	bottom f32
	left   f32
}

// Some useful padding and spacing consts
pub const radius_default = 5
pub const spacing_default = 10
pub const padding_default = Padding{10, 10, 10, 10}
