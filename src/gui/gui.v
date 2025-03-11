module gui

pub const version = '0.1.0'

pub enum SizingType {
	fit
	fixed
	grow
}

pub struct Sizing {
pub:
	width  SizingType
	height SizingType
}

pub struct Padding {
pub mut:
	top    f32
	right  f32
	bottom f32
	left   f32
}

// Some useful padding and spacing consts
pub const radius_normal = 5
pub const spacing_normal = 10
pub const padding_normal = Padding{10, 10, 10, 10}
