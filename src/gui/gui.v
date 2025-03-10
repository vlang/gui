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
