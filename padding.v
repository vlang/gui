module gui

pub const pad_x_small = 3
pub const pad_small = 5
pub const pad_medium = 10
pub const pad_large = 15

pub const padding_none = Padding{}
pub const padding_one = padding(1, 1, 1, 1)
pub const padding_two = padding(2, 2, 2, 2)
pub const padding_three = padding(3, 3, 3, 3)
pub const padding_two_three = padding(2, 3, 2, 3)
pub const padding_two_four = padding(2, 4, 2, 4)
pub const padding_two_five = padding(2, 5, 2, 5)
pub const padding_x_small = pad_all(pad_x_small)
pub const padding_small = pad_all(pad_small)
pub const padding_medium = pad_all(pad_medium)
pub const padding_large = pad_all(pad_large)
pub const padding_button = padding(5,9,7,9)

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

// pad_all creates a padding with all 4 sides set to the `p` parameter
pub fn pad_all(p f32) Padding {
	return Padding{p, p, p, p}
}

// pad_tblr creates a padding with the top and bottom set to the `tb` parameter
// and the left and right set to the `lr` parameter.
pub fn pad_tblr(tb f32, lr f32) Padding {
	return Padding{
		top:    tb
		right:  lr
		bottom: tb
		left:   lr
	}
}
