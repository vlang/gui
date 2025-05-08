module gui

pub const padding_none = Padding{}
pub const padding_one = Padding{1, 1, 1, 1}
pub const padding_two = Padding{2, 2, 2, 2}
pub const padding_three = Padding{3, 3, 3, 3}
pub const padding_two_three = Padding{2, 3, 2, 3}
pub const padding_two_four = Padding{2, 4, 2, 4}
pub const padding_two_five = Padding{2, 5, 2, 5}
pub const padding_small = Padding{5, 5, 5, 5}
pub const padding_medium = Padding{10, 10, 10, 10}
pub const padding_large = Padding{15, 15, 15, 15}

// Padding is the gap inside the edges of a Shape. The size of a Shape always
// includes its padding. Parameter order is the same as CSS.
pub struct Padding {
pub:
	top    f32
	right  f32
	bottom f32
	left   f32
}

// padding creates a padding with the given parameters.
pub fn padding(top f32, right f32, bottom f32, left f32) Padding {
	return Padding{
		top:    top
		right:  right
		bottom: bottom
		left:   left
	}
}

// width computes the padding's width
pub fn (p Padding) width() f32 {
	return p.left + p.right
}

// height computes the padding's height
pub fn (p Padding) height() f32 {
	return p.top + p.bottom
}

// is_none tests if padding is equal to padding_none (i.e no padding)
pub fn (p Padding) is_none() bool {
	test := p.left != 0 || p.right != 0 || p.top != 0 || p.bottom != 0
	return !test
}

// pad_4 creates a padding with all 4 sides set to the `p` parameter
pub fn pad_4(p f32) Padding {
	return Padding{p, p, p, p}
}

// pad_2 creates a padding with the top and bottome set to the `tb` parameter
// and the left and right set to the `lr` parameter.
pub fn pad_2(tb f32, lr f32) Padding {
	return Padding{
		top:    tb
		right:  lr
		bottom: tb
		left:   lr
	}
}
